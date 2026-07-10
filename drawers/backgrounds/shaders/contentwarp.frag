#version 440

// Passthrough fragment for the liquid content squeeze — all the work happens
// in the vertex stage; the UBO must match it member-for-member.

layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 contentSize;
    float radiusPx;
    float amount;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    fragColor = texture(source, texCoord) * qt_Opacity;
}
