#pragma once

#include <qcolor.h>
#include <qsgmaterial.h>
#include <qsgmaterialshader.h>
#include <qsgtexture.h>

struct BlobRectData {
    float cx = 0, cy = 0, hw = 0, hh = 0;
    float offsetX = 0, offsetY = 0;
    float minEig = 1.0f;
    // Inverse of 2x2 deformation matrix, column-major for GLSL
    float invDeform[4] = { 1, 0, 0, 1 };
    // Screen-space AABB half-extents of the deformed rect
    float screenHalfX = 0, screenHalfY = 0;
    // Effective per-corner radii (tr, br, bl, tl), pre-computed on CPU
    float radius[4] = { 0, 0, 0, 0 };
    // Bitmask of indices in this rect's m_cachedRects that mutually exclude (or are excluded by) this rect.
    // Used by the shader to skip smin between excluded pairs.
    int excludeMask = 0;
    // Zone index 0..7 (topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left).
    // -1 means "no zone" — bg does NOT participate in inverted-frame sink (no присасывание).
    int zoneIndex = -1;
    // Whether this rect присасывается: merges (smin) with neighbours + frame.
    // false → renders as a clean standalone contour (floating panel). Packed into
    // the shader's spare rectData[i*5+3].w slot.
    bool sticks = true;
};

class BlobMaterial : public QSGMaterial {
public:
    QSGMaterialType* type() const override;
    QSGMaterialShader* createShader(QSGRendererInterface::RenderMode) const override;
    int compare(const QSGMaterial* other) const override;

    float m_paddedX = 0;
    float m_paddedY = 0;
    float m_paddedW = 0;
    float m_paddedH = 0;
    float m_smoothFactor = 32.0f;
    int m_rectCount = 0;
    int m_myIndex = -2;
    QColor m_color{ 0x44, 0x88, 0xff };
    int m_hasInverted = 0;
    float m_invertedRadius = 0;
    // Guard band width (px) protecting the border-rounding arcs from
    // присасывание (sink + frame smin); 0 disables.
    float m_cornerGuard = 0;
    // Multiplier on smoothFactor used as the smin blend radius between two
    // sticking rects. >1 widens/deepens the bridge into a tight capsule neck
    // across a gap instead of a thin pinch. Occupies the former pad0 slot.
    float m_stickSmooth = 1.0f;
    float m_invertedOuter[4] = {};
    float m_invertedInner[4] = {};
    // Per-zone присасывание strength (sink multiplier in fragment shader).
    // 0 disables sink for bgs in that zone; >0 enables (1.0 = unscaled).
    // Order: topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left.
    float m_zoneRoundings[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };

    // ── Frosted-glass wallpaper sampling (Approach A) ──
    // A pre-blurred wallpaper texture sampled at scene-pixel/screen UV and mixed
    // with m_color (tint) when m_wpEnabled — so the panel fill is the blurred
    // wallpaper instead of a flat colour. Always non-null at draw time (the
    // group hands a 1x1 dummy when disabled) so binding=1 stays valid.
    QSGTexture* m_wpTexture = nullptr;
    float m_wpEnabled = 0.0f;       // 0 = flat colour (legacy), 1 = frost
    float m_wpTint = 0.3f;          // mix(wallpaper, color, tint): 0 = pure wp
    float m_screenW = 1.0f;         // for scene-pixel → wallpaper UV mapping
    float m_screenH = 1.0f;

    BlobRectData m_rects[16] = {};
};

class BlobMaterialShader : public QSGMaterialShader {
public:
    BlobMaterialShader();
    bool updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial* oldMaterial) override;
    void updateSampledImage(RenderState& state, int binding, QSGTexture** texture, QSGMaterial* newMaterial,
        QSGMaterial* oldMaterial) override;

private:
    // Last non-null wallpaper texture seen. All materials in a group share ONE
    // texture, but the batch renderer can ask this shader to bind a sampler for
    // a material whose m_wpTexture is momentarily null — fall back to this so
    // binding=1 never dangles ("No QSGTexture provided").
    QSGTexture* m_fallbackTex = nullptr;
};
