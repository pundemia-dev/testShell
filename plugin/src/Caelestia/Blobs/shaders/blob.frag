#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float paddedX;
    float paddedY;
    float paddedW;
    float paddedH;
    float smoothFactor;
    int rectCount;
    int myIndex;
    vec4 color;
    int hasInverted;
    float invertedRadius;
    // Guard band width (px) protecting the border-rounding arcs from
    // присасывание; 0 disables. Occupies the former std140 padding slot, so
    // the buffer layout/size is unchanged.
    float cornerGuard;
    // Multiplier on smoothFactor used as the smin blend radius between two
    // sticking rects (>1 widens the bridge into a tight capsule neck). 1 = legacy.
    float stickSmooth;
    vec4 invertedOuter;
    vec4 invertedInner;
    vec4 zoneRoundingsLow;   // zones 0..3 (topLeft, top, topRight, right)
    vec4 zoneRoundingsHigh;  // zones 4..7 (bottomRight, bottom, bottomLeft, left)
    vec4 rectData[80];
};

// Look up the per-zone присасывание strength for a given rect's zone.
// Returns 0.0 if zoneIndex < 0 (no zone — bg does NOT pull the frame).
// This matches the goal: center-anchored bgs (rail 4) and unzoned defaults
// don't generate the corner-pull effect anymore.
float zoneStrength(int zi) {
    if (zi < 0) return 0.0;
    if (zi == 0) return zoneRoundingsLow.x;
    if (zi == 1) return zoneRoundingsLow.y;
    if (zi == 2) return zoneRoundingsLow.z;
    if (zi == 3) return zoneRoundingsLow.w;
    if (zi == 4) return zoneRoundingsHigh.x;
    if (zi == 5) return zoneRoundingsHigh.y;
    if (zi == 6) return zoneRoundingsHigh.z;
    if (zi == 7) return zoneRoundingsHigh.w;
    return 0.0;
}

float sdRoundedBox(vec2 p, vec2 center, vec2 halfSize, float radius) {
    vec2 d = abs(p - center) - halfSize + vec2(radius);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

float sdRoundedBox4(vec2 p, vec2 center, vec2 halfSize, vec4 r) {
    // r = (topRight, bottomRight, bottomLeft, topLeft)
    p -= center;
    r.xy = (p.x > 0.0) ? r.xy : r.wz;
    r.x  = (p.y > 0.0) ? r.y : r.x;
    vec2 q = abs(p) - halfSize + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

float sdBox(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float smin(float a, float b, float k) {
    // Cubic smooth min (C2 continuous — no curvature kinks at blend boundary)
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0/6.0);
}

float smax(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return max(a, b) + h * h * h * k * (1.0/6.0);
}

float smaxSharpA(float a, float b, float k) {
    // smax variant that keeps a's boundary sharp (no inward rounding at a = 0).
    // Used for the frame outer edge so it always fills to the edges.
    float h = max(k - abs(a - b), 0.0) / k;
    float blend = h * h * h * k * (1.0/6.0);
    blend *= smoothstep(0.0, k * 0.5, -a);
    return max(a, b) + blend;
}

// Corner guard: 1 away from the inner-cutout corner arcs, falling to 0 on
// the arcs themselves. Gates the sink and the final smin-with-frame so
// присасывание only deforms the straight border runs — the configured
// border rounding (invertedRadius) is never overridden. The abs() fold maps
// all four arc centers onto one, so a single distance covers every corner.
float cornerGuardAt(vec2 p) {
    if (cornerGuard <= 0.0)
        return 1.0;
    vec2 ac = max(invertedInner.zw - vec2(invertedRadius), vec2(0.0));
    float d = length(abs(p - invertedInner.xy) - ac);
    return smoothstep(invertedRadius, invertedRadius + cornerGuard, d);
}

void main() {
    vec2 pixel = vec2(paddedX, paddedY) + qt_TexCoord0 * vec2(paddedW, paddedH);

    // Phase 1: compute per-rect SDF, track owner. We can't smin yet because excluded
    // pairs need to skip the smooth blend, which requires pairwise pass below.
    float dArr[16];
    int owner = -2;
    float minDist = 1e10;

    for (int i = 0; i < rectCount; i++) {
        vec4 rect = rectData[i * 5];         // cx, cy, hw, hh
        vec4 props = rectData[i * 5 + 1];    // excludeMask(int bits), offsetX, offsetY, minEig
        vec4 invDm = rectData[i * 5 + 2];    // inverse deform matrix
        vec4 sh = rectData[i * 5 + 3];       // screenHalfX, screenHalfY, zoneIndex(float), unused
        vec4 radii = rectData[i * 5 + 4];    // effective per-corner radii (tr, br, bl, tl)

        // Per-rect zone strength: 0 disables присасывание for this bg entirely.
        int zi = int(sh.z);
        float zs = zoneStrength(zi);

        // Per-rect stick flag (sh.w): 0 → this bg floats (no boost / sink /
        // frame-merge). Folded into zs so the магнит corner-shrink vanishes.
        float st = sh.w;
        zs *= st;

        // Offset center for asymmetric deformation
        vec2 center = rect.xy + props.yz;

        // AABB early-out: skip rects far from this pixel
        vec2 extent = sh.xy + vec2(smoothFactor * 1.5);
        if (abs(pixel.x - center.x) > extent.x || abs(pixel.y - center.y) > extent.y) {
            dArr[i] = 1e10;
            continue;
        }

        // Apply pre-computed inverse deformation to the evaluation point
        mat2 invDeform = mat2(invDm.xy, invDm.zw);
        vec2 transformedPixel = center + invDeform * (pixel - center);

        // Use pre-computed effective per-corner radii
        float d = sdRoundedBox4(transformedPixel, center, rect.zw, radii);

        // Use pre-computed minimum eigenvalue for SDF correction
        d *= max(props.w, 0.01);

        // Scale SDF on the axis facing a nearby border to narrow the smin blend
        // zone in that direction only. Gated by zone strength: zs == 0 leaves
        // scale at 1.0 (no boost, no apparent "pull" toward the frame).
        if (hasInverted != 0 && zs > 0.0) {
            vec2 screenHalf = sh.xy;

            float distY0 = (center.y + screenHalf.y) - (invertedInner.y - invertedInner.w);
            float distY1 = (invertedInner.y + invertedInner.w) - (center.y - screenHalf.y);
            float distX0 = (center.x + screenHalf.x) - (invertedInner.x - invertedInner.z);
            float distX1 = (invertedInner.x + invertedInner.z) - (center.x - screenHalf.x);

            // 0 = far from border, 1 = at border (max compression)
            float yProx = 1.0 - min(
                smoothstep(0.0, smoothFactor, distY0),
                smoothstep(0.0, smoothFactor, distY1)
            );
            float xProx = 1.0 - min(
                smoothstep(0.0, smoothFactor, distX0),
                smoothstep(0.0, smoothFactor, distX1)
            );

            // Smooth axis weights: gradient-based at corners, face-based inside.
            vec2 q = abs(pixel - center) - screenHalf;
            vec2 qp = max(q, vec2(0.0));
            float cornerLen = length(qp);

            // Gradient direction in corner region (smooth 90-degree rotation)
            float gradX = qp.x / max(cornerLen, 0.001);
            float gradY = qp.y / max(cornerLen, 0.001);

            // Smooth face weights for inside/edge (no hard branch)
            float faceY = smoothstep(-4.0, 4.0, q.y - q.x);
            float faceX = 1.0 - faceY;

            // Blend: gradient in corner region, face-based inside
            float t = smoothstep(0.0, 2.0, cornerLen);
            float xWeight = mix(faceX, gradX, t);
            float yWeight = mix(faceY, gradY, t);

            float boost = 3.0 * zs;
            float scale = 1.0 + (xProx * xWeight + yProx * yWeight) * boost;
            d *= scale;
        }

        dArr[i] = d;
        if (d < smoothFactor && d < minDist) {
            minDist = d;
            owner = i;
        }
    }

    // Phase 2: hard-min baseline over all rects.
    float mergedSdf = 1e10;
    for (int i = 0; i < rectCount; i++) {
        mergedSdf = min(mergedSdf, dArr[i]);
    }

    // Phase 3: pair-wise smin contributions, skipping excluded pairs. Pair smin <= min,
    // so taking the min over all non-excluded pair smins gives the smoothly-merged SDF.
    for (int i = 0; i < rectCount; i++) {
        if (dArr[i] >= 1e9)
            continue;
        int excludeMask = floatBitsToInt(rectData[i * 5 + 1].x);
        float sti = rectData[i * 5 + 3].w;
        for (int j = i + 1; j < rectCount; j++) {
            if (dArr[j] >= 1e9)
                continue;
            if ((excludeMask & (1 << j)) != 0)
                continue;
            // A floating rect (sticks == 0) never smin-merges with a neighbour —
            // it keeps its own clean rounded contour.
            float stj = rectData[j * 5 + 3].w;
            if (sti < 0.5 || stj < 0.5)
                continue;
            // Sticking pair: widen the blend radius so the bridge across a gap
            // fills into a tight capsule neck rather than a thin pinch.
            float kPair = smoothFactor * stickSmooth;
            // smin only deviates from min within kPair
            if (abs(dArr[i] - dArr[j]) >= kPair)
                continue;
            mergedSdf = min(mergedSdf, smin(dArr[i], dArr[j], kPair));
        }
    }

    if (hasInverted != 0) {
        float guard = cornerGuardAt(pixel);

        float dOuter = sdBox(pixel, invertedOuter.xy, invertedOuter.zw) - 1.0;
        float dInner = sdRoundedBox(pixel, invertedInner.xy, invertedInner.zw, invertedRadius);

        // Border sinks: track the opposite rect edge, clamped to border thickness
        float innerTop = invertedInner.y - invertedInner.w;
        float innerBot = invertedInner.y + invertedInner.w;
        float innerLeft = invertedInner.x - invertedInner.z;
        float innerRight = invertedInner.x + invertedInner.z;
        float outerTop = invertedOuter.y - invertedOuter.w;
        float outerBot = invertedOuter.y + invertedOuter.w;
        float outerLeft = invertedOuter.x - invertedOuter.z;
        float outerRight = invertedOuter.x + invertedOuter.z;

        float sinkValue = 0.0;
        for (int i = 0; i < rectCount; i++) {
            vec4 rect = rectData[i * 5];
            vec4 sinkProps = rectData[i * 5 + 1];
            vec4 d3 = rectData[i * 5 + 3];
            vec2 sinkSh = d3.xy;
            int zi = int(d3.z);

            // Per-zone присасывание enable: zoneStrength = 0 → this bg does
            // NOT pull the frame's inner edge inward. -1 (no zone) gets 1.0
            // (legacy unscaled behavior).
            float zs = zoneStrength(zi);
            // Floating rects (d3.w == 0) don't sink the frame inner edge.
            zs *= d3.w;

            // Screen-space center (with offset) and pre-computed AABB half-extents
            vec2 ctr = rect.xy + sinkProps.yz;

            // Delay sink to absorb smin blend depth (cubic smin max = k/6)
            float preOff = smoothFactor * (1.0/6.0);

            // Top border: track rect's BOTTOM edge, only within border thickness
            float topPen = clamp(innerTop - (ctr.y + sinkSh.y) - preOff, 0.0, innerTop - outerTop);

            // Bottom border: track rect's TOP edge
            float botPen = clamp((ctr.y - sinkSh.y) - innerBot - preOff, 0.0, outerBot - innerBot);

            // Left border: track rect's RIGHT edge
            float leftPen = clamp(innerLeft - (ctr.x + sinkSh.x) - preOff, 0.0, innerLeft - outerLeft);

            // Right border: track rect's LEFT edge
            float rightPen = clamp((ctr.x - sinkSh.x) - innerRight - preOff, 0.0, outerRight - innerRight);

            // Lateral distance from pixel to rect's extent along each edge
            float hLat = max(abs(pixel.x - ctr.x) - sinkSh.x, 0.0);
            float vLat = max(abs(pixel.y - ctr.y) - sinkSh.y, 0.0);

            // Perpendicular proximity: full strength in border, fade inside inner area
            float topZone = 1.0 - smoothstep(innerTop, innerTop + smoothFactor, pixel.y);
            float botZone = smoothstep(innerBot - smoothFactor, innerBot, pixel.y);
            float leftZone = 1.0 - smoothstep(innerLeft, innerLeft + smoothFactor, pixel.x);
            float rightZone = smoothstep(innerRight - smoothFactor, innerRight, pixel.x);

            float s = smoothFactor * 2.0;
            float sink = max(
                max(topPen * smoothstep(s, 0.0, hLat) * topZone,
                    botPen * smoothstep(s, 0.0, hLat) * botZone),
                max(leftPen * smoothstep(s, 0.0, vLat) * leftZone,
                    rightPen * smoothstep(s, 0.0, vLat) * rightZone)
            );
            sinkValue = max(sinkValue, sink * zs);
        }

        // Corner guard: sinks never reshape the border-rounding arcs.
        dInner -= sinkValue * guard;

        float dFrame = smaxSharpA(dOuter, -dInner, smoothFactor);

        // Gate the final union-with-frame by the winning rect's zone strength.
        // If the closest rect at this pixel has zs == 0, the bg does NOT visually
        // merge with the frame here — preserving its natural rounded contour.
        float winnerZs = 1.0;
        if (owner >= 0) {
            int wzi = int(rectData[owner * 5 + 3].z);
            // Floating winner (d3.w == 0) does not merge with the frame.
            winnerZs = zoneStrength(wzi) * rectData[owner * 5 + 3].w;
        }
        if (winnerZs > 0.0) {
            // The smin k collapses toward a hard min inside the corner-guard
            // band, so the merge fillet cannot roll over the rounding arcs.
            float kGuard = max(smoothFactor * guard, 1.0);
            mergedSdf = smin(mergedSdf, dFrame, kGuard);
            if (dFrame < minDist) {
                owner = -1;
            }
        } else {
            // Still resolve frame ownership where the bg has no SDF presence
            // (so the frame's pixels are owned correctly), without smin-blending.
            mergedSdf = min(mergedSdf, dFrame);
            if (dFrame < minDist) {
                owner = -1;
            }
        }
    }

    // Each renderer only outputs pixels it owns, but allow rendering
    // blend zones to prevent gaps (mergedSdf < smoothFactor means in blend)
    // myIndex == -1: inverted rect renders border-owned pixels
    // myIndex >= 0: individual rect renders its owned pixels
    if (owner != myIndex && mergedSdf > smoothFactor)
        discard;

    float fw = fwidth(mergedSdf);
    float alpha = 1.0 - smoothstep(-fw, fw, mergedSdf);
    fragColor = vec4(color.rgb * alpha, alpha) * qt_Opacity;
}
