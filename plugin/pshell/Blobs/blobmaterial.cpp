#include "blobmaterial.hpp"

#include <cstring>

static_assert(sizeof(decltype(BlobRectData::excludeMask)) == sizeof(float),
    "BlobMaterial packs excludeMask into a float slot via memcpy");

QSGMaterialType* BlobMaterial::type() const {
    static QSGMaterialType s_type;
    return &s_type;
}

QSGMaterialShader* BlobMaterial::createShader(QSGRendererInterface::RenderMode) const {
    return new BlobMaterialShader;
}

int BlobMaterial::compare(const QSGMaterial* other) const {
    if (this < other)
        return -1;
    if (this > other)
        return 1;
    return 0;
}

BlobMaterialShader::BlobMaterialShader() {
    setShaderFileName(VertexStage, QStringLiteral(":/shaders/blob.vert.qsb"));
    setShaderFileName(FragmentStage, QStringLiteral(":/shaders/blob.frag.qsb"));
}

bool BlobMaterialShader::updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial* oldMaterial) {
    Q_UNUSED(oldMaterial);
    auto* mat = static_cast<BlobMaterial*>(newMaterial);
    QByteArray* buf = state.uniformData();
    Q_ASSERT(buf->size() >= 1488);

    if (state.isMatrixDirty()) {
        const QMatrix4x4 m = state.combinedMatrix();
        memcpy(buf->data(), m.constData(), 64);
    }
    if (state.isOpacityDirty()) {
        const float opacity = state.opacity();
        memcpy(buf->data() + 64, &opacity, 4);
    }

    // Padded rect (offset 68)
    memcpy(buf->data() + 68, &mat->m_paddedX, 4);
    memcpy(buf->data() + 72, &mat->m_paddedY, 4);
    memcpy(buf->data() + 76, &mat->m_paddedW, 4);
    memcpy(buf->data() + 80, &mat->m_paddedH, 4);

    // Smooth factor (offset 84)
    memcpy(buf->data() + 84, &mat->m_smoothFactor, 4);

    // Rect count (offset 88)
    memcpy(buf->data() + 88, &mat->m_rectCount, 4);

    // My index (offset 92)
    memcpy(buf->data() + 92, &mat->m_myIndex, 4);

    // Color as vec4 (offset 96, 16 bytes)
    const float color[4] = {
        static_cast<float>(mat->m_color.redF()),
        static_cast<float>(mat->m_color.greenF()),
        static_cast<float>(mat->m_color.blueF()),
        static_cast<float>(mat->m_color.alphaF()),
    };
    memcpy(buf->data() + 96, color, 16);

    // Has inverted (offset 112)
    memcpy(buf->data() + 112, &mat->m_hasInverted, 4);

    // Inverted radius (offset 116)
    memcpy(buf->data() + 116, &mat->m_invertedRadius, 4);

    // Corner guard (offset 120; occupies the former padding slot — buffer
    // size and all later offsets are unchanged).
    memcpy(buf->data() + 120, &mat->m_cornerGuard, 4);

    // Stick-smooth multiplier (offset 124; the former pad0 slot — buffer size
    // and all later offsets are unchanged).
    memcpy(buf->data() + 124, &mat->m_stickSmooth, 4);

    // Inverted outer (offset 128, 16 bytes)
    memcpy(buf->data() + 128, mat->m_invertedOuter, 16);

    // Inverted inner (offset 144, 16 bytes)
    memcpy(buf->data() + 144, mat->m_invertedInner, 16);

    // Zone roundings, packed as two vec4s.
    // Order: topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left.
    memcpy(buf->data() + 160, mat->m_zoneRoundings, 16);      // zones 0..3
    memcpy(buf->data() + 176, mat->m_zoneRoundings + 4, 16);  // zones 4..7

    // Frosted-glass wallpaper params (offset 192, one vec4): screenW, screenH,
    // wpEnabled, wpTint. Pushes rectData to offset 208 (buffer grew to 1488).
    const float wpParams[4] = { mat->m_screenW, mat->m_screenH, mat->m_wpEnabled, mat->m_wpTint };
    memcpy(buf->data() + 192, wpParams, 16);

    // Rect data (offset 208, each rect = 5 vec4s = 80 bytes)
    const int count = qMin(mat->m_rectCount, 16);
    for (int i = 0; i < count; ++i) {
        const auto& r = mat->m_rects[i];
        const int base = 208 + i * 80;
        // Pack excludeMask into props.x via bit-cast (read in shader with floatBitsToInt)
        float maskAsFloat;
        memcpy(&maskAsFloat, &r.excludeMask, sizeof(float));
        const float d0[4] = { r.cx, r.cy, r.hw, r.hh };
        const float d1[4] = { maskAsFloat, r.offsetX, r.offsetY, r.minEig };
        // d3.x = screenHalfX, d3.y = screenHalfY, d3.z = zoneIndex (float-encoded, -1 = no zone),
        // d3.w = sticks (1.0 = присасывается/merges, 0.0 = floating/standalone)
        const float d3[4] = {
            r.screenHalfX, r.screenHalfY, static_cast<float>(r.zoneIndex), r.sticks ? 1.0f : 0.0f
        };
        memcpy(buf->data() + base, d0, 16);
        memcpy(buf->data() + base + 16, d1, 16);
        memcpy(buf->data() + base + 32, r.invDeform, 16);
        memcpy(buf->data() + base + 48, d3, 16);
        memcpy(buf->data() + base + 64, r.radius, 16);
    }

    return true;
}

void BlobMaterialShader::updateSampledImage(RenderState& state, int binding, QSGTexture** texture,
    QSGMaterial* newMaterial, QSGMaterial* /*oldMaterial*/) {
    Q_UNUSED(binding);
    auto* mat = static_cast<BlobMaterial*>(newMaterial);
    // One sampler (wpTex). Provide the material's texture, falling back to the
    // last valid one (shared group texture) so the binding never dangles.
    if (mat->m_wpTexture)
        m_fallbackTex = mat->m_wpTexture;
    QSGTexture* tex = mat->m_wpTexture ? mat->m_wpTexture : m_fallbackTex;
    // Upload pending pixel data to the GPU. A texture from createTextureFromImage
    // is lazily uploaded; without this commit a custom material samples it black.
    if (tex)
        tex->commitTextureOperations(state.rhi(), state.resourceUpdateBatch());
    *texture = tex;
}
