#version 440

// Fragment stage of the liquid content effects: the vertex stage warps the
// grid; this stage applies the liquid content BLUR — a 13-tap Poisson-disc
// sample (centre + two 6-tap rings) whose radius `blurPx` rides the same
// animated mix as the rounding, so content frosts on open/close AND while
// moving, and resolves sharp at rest. UBO must match the vertex stage
// member-for-member.

layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 contentSize;
    float radiusPx;
    float amount;
    float invertMode;
    float edgeStrength;
    float pinchStrength;
    float blurPx;
    // Quality dials (Config.backgrounds.liquidContentBlur*):
    //   blurSpread   — tap-ring radius multiplier (1 = rings at blurPx).
    //   blurSoftness — mip-bias scale: each tap samples a prefiltered mip
    //                  level ≈ softness·log2(blurPx), which is what kills
    //                  the 13-tap graininess at large radii. 0 = raw taps.
    float blurSpread;
    float blurSoftness;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    if (blurPx < 0.01) {
        fragColor = texture(source, texCoord) * qt_Opacity;
        return;
    }
    vec2 texel = (blurPx * blurSpread) / max(contentSize, vec2(1.0));
    float bias = blurSoftness * max(log2(max(blurPx, 1.0)) - 1.0, 0.0);
    vec4 acc = texture(source, texCoord, bias);
    // Outer ring (radius 1.0), angles 0/60/…/300.
    acc += texture(source, texCoord + vec2( 1.000,  0.000) * texel, bias);
    acc += texture(source, texCoord + vec2( 0.500,  0.866) * texel, bias);
    acc += texture(source, texCoord + vec2(-0.500,  0.866) * texel, bias);
    acc += texture(source, texCoord + vec2(-1.000,  0.000) * texel, bias);
    acc += texture(source, texCoord + vec2(-0.500, -0.866) * texel, bias);
    acc += texture(source, texCoord + vec2( 0.500, -0.866) * texel, bias);
    // Inner ring (radius 0.45), angles 30/90/…/330.
    acc += texture(source, texCoord + vec2( 0.390,  0.225) * texel, bias);
    acc += texture(source, texCoord + vec2( 0.000,  0.450) * texel, bias);
    acc += texture(source, texCoord + vec2(-0.390,  0.225) * texel, bias);
    acc += texture(source, texCoord + vec2(-0.390, -0.225) * texel, bias);
    acc += texture(source, texCoord + vec2( 0.000, -0.450) * texel, bias);
    acc += texture(source, texCoord + vec2( 0.390, -0.225) * texel, bias);
    fragColor = (acc / 13.0) * qt_Opacity;
}
