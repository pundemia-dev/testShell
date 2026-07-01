#pragma once

#include <qcolor.h>
#include <qimage.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlengine.h>
#include <qsize.h>
#include <qstring.h>

class BlobShape;
class BlobInvertedRect;
class QSGTexture;
class QQuickWindow;

class BlobGroup : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal smoothing READ smoothing WRITE setSmoothing NOTIFY smoothingChanged)
    Q_PROPERTY(qreal stickSmooth READ stickSmooth WRITE setStickSmooth NOTIFY stickSmoothChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    // ── Frosted-glass wallpaper (Approach A) ──
    // When wallpaperEnabled, panels are filled with a pre-blurred copy of the
    // wallpaper image (loaded from wallpaperPath, downscaled on CPU = a cheap
    // one-time blur) mixed with `color` by wallpaperTint, sampled in blob.frag
    // at scene-pixel/screenSize UV. screenSize must be the per-screen logical
    // size so the UV maps the panel pixels onto the wallpaper.
    Q_PROPERTY(QString wallpaperPath READ wallpaperPath WRITE setWallpaperPath NOTIFY wallpaperPathChanged)
    Q_PROPERTY(bool wallpaperEnabled READ wallpaperEnabled WRITE setWallpaperEnabled NOTIFY wallpaperEnabledChanged)
    Q_PROPERTY(qreal wallpaperTint READ wallpaperTint WRITE setWallpaperTint NOTIFY wallpaperTintChanged)
    Q_PROPERTY(qreal wallpaperBlur READ wallpaperBlur WRITE setWallpaperBlur NOTIFY wallpaperBlurChanged)
    Q_PROPERTY(QSizeF screenSize READ screenSize WRITE setScreenSize NOTIFY screenSizeChanged)

public:
    explicit BlobGroup(QObject* parent = nullptr);
    ~BlobGroup() override;

    qreal smoothing() const { return m_smoothing; }

    void setSmoothing(qreal s);

    qreal stickSmooth() const { return m_stickSmooth; }

    void setStickSmooth(qreal s);

    QColor color() const { return m_color; }

    void setColor(const QColor& c);

    QString wallpaperPath() const { return m_wallpaperPath; }
    void setWallpaperPath(const QString& p);

    bool wallpaperEnabled() const { return m_wallpaperEnabled; }
    void setWallpaperEnabled(bool e);

    qreal wallpaperTint() const { return m_wallpaperTint; }
    void setWallpaperTint(qreal t);

    qreal wallpaperBlur() const { return m_wallpaperBlur; }
    void setWallpaperBlur(qreal b);

    QSizeF screenSize() const { return m_screenSize; }
    void setScreenSize(const QSizeF& s);

    // Render-thread: returns the (lazily (re)built) wallpaper texture, or a 1x1
    // dummy when there's no image, so the material's sampler is always valid.
    QSGTexture* wallpaperTexture(QQuickWindow* window);

    // Whether frost should actually paint (enabled AND an image is loaded).
    bool hasWallpaper() const { return m_wallpaperEnabled && !m_wallpaperImage.isNull(); }

    void addShape(BlobShape* shape);
    void removeShape(BlobShape* shape);

    void setInvertedRect(BlobInvertedRect* rect);
    void clearInvertedRect(BlobInvertedRect* rect);

    const QList<BlobShape*>& shapes() const { return m_shapes; }

    BlobInvertedRect* invertedRect() const { return m_invertedRect; }

    void markDirty();
    void markShapeDirty(BlobShape* source);
    void ensurePhysicsUpdated();

signals:
    void smoothingChanged();
    void stickSmoothChanged();
    void colorChanged();
    void wallpaperPathChanged();
    void wallpaperEnabledChanged();
    void wallpaperTintChanged();
    void wallpaperBlurChanged();
    void screenSizeChanged();

private:
    // (Re)load + downscale the wallpaper into m_wallpaperImage (needs both path
    // and a non-empty screenSize). Sets m_wpTextureDirty.
    void rebuildWallpaperImage();

    qreal m_smoothing = 32.0;
    qreal m_stickSmooth = 1.0;
    QColor m_color{ 0x44, 0x88, 0xff };
    QList<BlobShape*> m_shapes;
    BlobInvertedRect* m_invertedRect = nullptr;
    bool m_physicsUpdated = false;

    // Frosted-glass wallpaper state.
    QString m_wallpaperPath;
    bool m_wallpaperEnabled = false;
    qreal m_wallpaperTint = 0.3;
    qreal m_wallpaperBlur = 0.6;   // 0 = light blur (large texture), 1 = heavy
    QSizeF m_screenSize;
    QImage m_wallpaperImage;       // pre-downscaled (cropped to screen aspect)
    QSGTexture* m_wpTexture = nullptr;
    QSGTexture* m_dummyTexture = nullptr;
    QQuickWindow* m_lastWindow = nullptr;
    bool m_wpTextureDirty = false;
};
