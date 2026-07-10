#version 440

// Liquid content squeeze: deform the content grid in step with the animated
// rounding `radiusPx`, blended by `amount` (0..1). Two directions:
//
//   invertMode = 0 — EDGES deform, centre rigid: fit the rectangle into a
//     rounded rectangle. Per vertex, the corner-arc inset at its row/column
//     pulls it toward the centre — concave dents at the corners, like a
//     rectangle pressed into a chamfered one (reads convex toward the viewer).
//
//   invertMode = 1 — corner fit PLUS a radial pinch: the edges still squeeze
//     into the rounded contour (otherwise content pokes past the blob's
//     corners), and on top the centre region is sucked inward (displacement
//     |q-c|·(1-r)² peaks at r=1/3, zero on the borders) — reads concave,
//     dipping away from the viewer.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 texCoord;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 contentSize;
    float radiusPx;
    float amount;
    float invertMode;
    // Strength dials. edgeStrength multiplies the corner-fit displacement
    // (1 = exact geometric fit into the rounded contour, >1 over-pressed).
    // pinchStrength scales the central dip depth relative to R/minHalf.
    float edgeStrength;
    float pinchStrength;
    // Liquid content blur (fragment stage) — in the UBO here only because
    // both stages must declare the identical block.
    float blurPx;
    float blurSpread;
    float blurSoftness;
};

void main() {
    texCoord = qt_MultiTexCoord0;
    vec2 p = qt_Vertex.xy;
    vec2 c = contentSize * 0.5;
    float R = min(radiusPx, min(c.x, c.y));
    vec2 q = clamp(p, vec2(0.0), contentSize);
    // Corner fit (both modes): keeps content inside the rounded contour.
    // Distance to the nearer horizontal/vertical edge.
    float dy = min(q.y, contentSize.y - q.y);
    float dx = min(q.x, contentSize.x - q.x);
    // Corner-arc inset: how much narrower the rounded rect is at this
    // row (ix) / column (iy) compared to the full rect.
    float ix = (dy < R) ? (R - sqrt(max(R * R - (R - dy) * (R - dy), 0.0))) : 0.0;
    float iy = (dx < R) ? (R - sqrt(max(R * R - (R - dx) * (R - dx), 0.0))) : 0.0;
    vec2 avail = c - vec2(ix, iy);
    vec2 fit = c + (q - c) * (avail / max(c, vec2(1.0)));
    vec2 warped = q + (fit - q) * edgeStrength;
    if (invertMode > 0.5) {
        // Radial pinch on top: depth ties to the same animated rounding, so
        // the central dip grows exactly as the corners bloom.
        vec2 n = (warped - c) / max(c, vec2(1.0));
        float rn = clamp(length(n), 0.0, 1.0);
        float w = (1.0 - rn) * (1.0 - rn);
        float depth = pinchStrength * R / max(min(c.x, c.y), 1.0);
        warped = c + (warped - c) * (1.0 - depth * w);
    }
    gl_Position = qt_Matrix * vec4(p + (warped - q) * amount, qt_Vertex.zw);
}
