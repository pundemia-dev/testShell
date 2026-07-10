#version 440

// Liquid content squeeze: fit the rectangular content grid into a rounded
// rectangle of radius `radiusPx`, blended by `amount` (0..1). Per vertex:
// the available half-extent at this row/column is the rounded-rect inset
// (circle-arc pullback inside the corner bands), and the vertex is pulled
// toward the centre proportionally — a rectangle pressed into a chamfered
// one, concave "dents" growing with the animated rounding.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 texCoord;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 contentSize;
    float radiusPx;
    float amount;
};

void main() {
    texCoord = qt_MultiTexCoord0;
    vec2 p = qt_Vertex.xy;
    vec2 c = contentSize * 0.5;
    float R = min(radiusPx, min(c.x, c.y));
    vec2 q = clamp(p, vec2(0.0), contentSize);
    // Distance to the nearer horizontal/vertical edge.
    float dy = min(q.y, contentSize.y - q.y);
    float dx = min(q.x, contentSize.x - q.x);
    // Corner-arc inset: how much narrower the rounded rect is at this
    // row (ix) / column (iy) compared to the full rect.
    float ix = (dy < R) ? (R - sqrt(max(R * R - (R - dy) * (R - dy), 0.0))) : 0.0;
    float iy = (dx < R) ? (R - sqrt(max(R * R - (R - dx) * (R - dx), 0.0))) : 0.0;
    vec2 avail = c - vec2(ix, iy);
    vec2 warped = c + (q - c) * (avail / max(c, vec2(1.0)));
    gl_Position = qt_Matrix * vec4(p + (warped - q) * amount, qt_Vertex.zw);
}
