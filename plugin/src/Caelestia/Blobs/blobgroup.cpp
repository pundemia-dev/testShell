#include "blobgroup.hpp"
#include "blobinvertedrect.hpp"
#include "blobshape.hpp"

#include <qquickwindow.h>
#include <qsgtexture.h>

#include <algorithm>

// Separable box blur on an RGBA8888 image (in place). Repeated a few times it
// approximates a Gaussian. Cheap and one-time (the wallpaper is static).
static void boxBlur(QImage& img, int radius, int passes) {
    if (radius < 1 || img.isNull())
        return;
    if (img.format() != QImage::Format_RGBA8888)
        img = img.convertToFormat(QImage::Format_RGBA8888);
    const int w = img.width();
    const int h = img.height();
    const int div = radius * 2 + 1;
    QImage tmp(w, h, QImage::Format_RGBA8888);

    for (int pass = 0; pass < passes; ++pass) {
        // Horizontal: img -> tmp
        for (int y = 0; y < h; ++y) {
            const uchar* src = img.constScanLine(y);
            uchar* dst = tmp.scanLine(y);
            for (int x = 0; x < w; ++x) {
                int r = 0, g = 0, b = 0, a = 0;
                for (int k = -radius; k <= radius; ++k) {
                    const uchar* p = src + std::clamp(x + k, 0, w - 1) * 4;
                    r += p[0]; g += p[1]; b += p[2]; a += p[3];
                }
                uchar* d = dst + x * 4;
                d[0] = uchar(r / div); d[1] = uchar(g / div); d[2] = uchar(b / div); d[3] = uchar(a / div);
            }
        }
        // Vertical: tmp -> img
        for (int x = 0; x < w; ++x) {
            for (int y = 0; y < h; ++y) {
                int r = 0, g = 0, b = 0, a = 0;
                for (int k = -radius; k <= radius; ++k) {
                    const uchar* p = tmp.constScanLine(std::clamp(y + k, 0, h - 1)) + x * 4;
                    r += p[0]; g += p[1]; b += p[2]; a += p[3];
                }
                uchar* d = img.scanLine(y) + x * 4;
                d[0] = uchar(r / div); d[1] = uchar(g / div); d[2] = uchar(b / div); d[3] = uchar(a / div);
            }
        }
    }
}

BlobGroup::BlobGroup(QObject* parent)
    : QObject(parent) {}

BlobGroup::~BlobGroup() {
    for (auto* shape : std::as_const(m_shapes))
        shape->m_group = nullptr;
    if (m_invertedRect)
        static_cast<BlobShape*>(m_invertedRect)->m_group = nullptr;
    // Scene-graph textures are owned here; release at teardown.
    delete m_wpTexture;
    delete m_dummyTexture;
}

void BlobGroup::setSmoothing(qreal s) {
    if (qFuzzyCompare(m_smoothing, s))
        return;
    m_smoothing = s;
    emit smoothingChanged();
    markDirty();
}

void BlobGroup::setStickSmooth(qreal s) {
    if (qFuzzyCompare(m_stickSmooth, s))
        return;
    m_stickSmooth = s;
    emit stickSmoothChanged();
    markDirty();
}

void BlobGroup::setColor(const QColor& c) {
    if (m_color == c)
        return;
    m_color = c;
    emit colorChanged();
    markDirty();
}

void BlobGroup::addShape(BlobShape* shape) {
    if (!shape || m_shapes.contains(shape))
        return;
    m_shapes.append(shape);
    markDirty();
}

void BlobGroup::removeShape(BlobShape* shape) {
    m_shapes.removeOne(shape);
    markDirty();
}

void BlobGroup::setInvertedRect(BlobInvertedRect* rect) {
    if (m_invertedRect == rect)
        return;
    m_invertedRect = rect;
    markDirty();
}

void BlobGroup::clearInvertedRect(BlobInvertedRect* rect) {
    if (m_invertedRect != rect)
        return;
    m_invertedRect = nullptr;
    markDirty();
}

void BlobGroup::markDirty() {
    m_physicsUpdated = false;
    for (auto* shape : std::as_const(m_shapes)) {
        shape->polish();
        shape->update();
    }
    if (m_invertedRect) {
        static_cast<BlobShape*>(m_invertedRect)->polish();
        static_cast<BlobShape*>(m_invertedRect)->update();
    }
}

void BlobGroup::markShapeDirty(BlobShape* source) {
    m_physicsUpdated = false;

    source->polish();
    source->update();

    // Use cached padded rects to find spatial neighbors
    const float pad = static_cast<float>(m_smoothing) * 2.0f;
    const QRectF srcRect(static_cast<double>(source->m_cachedPaddedX - pad),
        static_cast<double>(source->m_cachedPaddedY - pad), static_cast<double>(source->m_cachedPaddedW + pad * 2.0f),
        static_cast<double>(source->m_cachedPaddedH + pad * 2.0f));

    for (auto* shape : std::as_const(m_shapes)) {
        if (shape == source)
            continue;
        const QRectF otherRect(static_cast<double>(shape->m_cachedPaddedX), static_cast<double>(shape->m_cachedPaddedY),
            static_cast<double>(shape->m_cachedPaddedW), static_cast<double>(shape->m_cachedPaddedH));
        if (srcRect.intersects(otherRect)) {
            shape->polish();
            shape->update();
        }
    }

    if (m_invertedRect && static_cast<BlobShape*>(m_invertedRect) != source) {
        static_cast<BlobShape*>(m_invertedRect)->polish();
        static_cast<BlobShape*>(m_invertedRect)->update();
    }
}

void BlobGroup::ensurePhysicsUpdated() {
    if (m_physicsUpdated)
        return;
    m_physicsUpdated = true;
    for (auto* shape : std::as_const(m_shapes))
        shape->updatePhysics();
}

void BlobGroup::setWallpaperPath(const QString& p) {
    if (m_wallpaperPath == p)
        return;
    m_wallpaperPath = p;
    rebuildWallpaperImage();
    emit wallpaperPathChanged();
    markDirty();
}

void BlobGroup::setWallpaperEnabled(bool e) {
    if (m_wallpaperEnabled == e)
        return;
    m_wallpaperEnabled = e;
    emit wallpaperEnabledChanged();
    markDirty();
}

void BlobGroup::setWallpaperTint(qreal t) {
    if (qFuzzyCompare(m_wallpaperTint, t))
        return;
    m_wallpaperTint = t;
    emit wallpaperTintChanged();
    markDirty();
}

void BlobGroup::setWallpaperBlur(qreal b) {
    if (qFuzzyCompare(m_wallpaperBlur, b))
        return;
    m_wallpaperBlur = b;
    rebuildWallpaperImage();   // blur strength == downscale target
    emit wallpaperBlurChanged();
    markDirty();
}

void BlobGroup::setScreenSize(const QSizeF& s) {
    if (m_screenSize == s)
        return;
    m_screenSize = s;
    rebuildWallpaperImage();   // crop aspect depends on the screen
    emit screenSizeChanged();
    markDirty();
}

void BlobGroup::rebuildWallpaperImage() {
    m_wallpaperImage = QImage();
    m_wpTextureDirty = true;
    if (m_wallpaperPath.isEmpty() || m_screenSize.width() <= 0 || m_screenSize.height() <= 0)
        return;

    QImage img(m_wallpaperPath);
    if (img.isNull()) {
        qWarning() << "[BlobGroup] failed to load wallpaper" << m_wallpaperPath;
        return;
    }

    // Centre-crop the source to the screen aspect (matches awww's fill/crop) so
    // sampling at uv = pixel/screenSize lands on the right wallpaper region.
    const double screenAspect = m_screenSize.width() / m_screenSize.height();
    const double imgAspect = static_cast<double>(img.width()) / img.height();
    QRect crop(0, 0, img.width(), img.height());
    if (imgAspect > screenAspect) {
        const int w = static_cast<int>(std::lround(img.height() * screenAspect));
        crop = QRect((img.width() - w) / 2, 0, w, img.height());
    } else if (imgAspect < screenAspect) {
        const int h = static_cast<int>(std::lround(img.width() / screenAspect));
        crop = QRect(0, (img.height() - h) / 2, img.width(), h);
    }
    img = img.copy(crop);

    // Downscale to a FIXED moderate resolution (decoupled from blur strength) so
    // the bilinear upscale across the panel stays smooth — no pixelation. The
    // actual blur is a real box blur whose radius scales with wallpaperBlur.
    const double blur = std::clamp(m_wallpaperBlur, 0.0, 1.0);
    const int targetLong = 480;
    const QSize target = (img.width() >= img.height())
        ? QSize(targetLong, std::max(1, static_cast<int>(std::lround(targetLong / screenAspect))))
        : QSize(std::max(1, static_cast<int>(std::lround(targetLong * screenAspect))), targetLong);
    QImage small = img.scaled(target, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                       .convertToFormat(QImage::Format_RGBA8888);
    const int radius = std::max(1, static_cast<int>(std::lround(blur * 48.0)));
    boxBlur(small, radius, 3);
    m_wallpaperImage = small;
}

QSGTexture* BlobGroup::wallpaperTexture(QQuickWindow* window) {
    // A shape can momentarily have a null window() (e.g. mid-reparent), which
    // would otherwise yield a null sampler texture and the "No QSGTexture
    // provided" fault. Fall back to the last window we DID see so we can always
    // hand back at least the dummy.
    if (window)
        m_lastWindow = window;
    else
        window = m_lastWindow;
    if (!window)
        return nullptr; // truly nothing yet (first frame, no window ever seen)

    if (!m_dummyTexture) {
        QImage dummy(1, 1, QImage::Format_RGBA8888);
        dummy.fill(Qt::transparent);
        m_dummyTexture = window->createTextureFromImage(dummy);
    }

    if (m_wallpaperImage.isNull())
        return m_dummyTexture;

    if (m_wpTextureDirty || !m_wpTexture) {
        delete m_wpTexture;
        // NO atlas flag: a custom shader samples uv 0..1 directly, but an
        // atlased texture maps 0..1 to the whole atlas (our sub-image is a tiny
        // corner) → frost would sample garbage. Default options = standalone.
        m_wpTexture = window->createTextureFromImage(m_wallpaperImage);
        if (m_wpTexture)
            m_wpTexture->setFiltering(QSGTexture::Linear); // smooth bilinear upscale
        m_wpTextureDirty = false;
    }
    return m_wpTexture ? m_wpTexture : m_dummyTexture;
}
