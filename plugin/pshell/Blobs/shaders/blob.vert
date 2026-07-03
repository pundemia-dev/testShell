#version 440

layout(location = 0) in vec4 qt_VertexPosition;
layout(location = 1) in vec2 qt_VertexTexCoord;

layout(location = 0) out vec2 qt_TexCoord0;

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
    float cornerGuard;
    float stickSmooth;
    vec4 invertedOuter;
    vec4 invertedInner;
    vec4 zoneRoundingsLow;   // zones 0..3 (topLeft, top, topRight, right)
    vec4 zoneRoundingsHigh;  // zones 4..7 (bottomRight, bottom, bottomLeft, left)
    vec4 wpParams;           // frost: x=screenW, y=screenH, z=enabled, w=tint
    vec4 rectData[80];
};

void main() {
    gl_Position = qt_Matrix * qt_VertexPosition;
    qt_TexCoord0 = qt_VertexTexCoord;
}
