#pragma once

#include "blobmaterial.hpp"

#include <qmatrix4x4.h>
#include <qquickitem.h>
#include <qvector.h>

class BlobGroup;

class BlobShape : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(BlobGroup* group READ group WRITE setGroup NOTIFY groupChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(QMatrix4x4 deformMatrix READ deformMatrix NOTIFY deformMatrixChanged)
    Q_PROPERTY(QMatrix4x4 rawDeformMatrix READ rawDeformMatrix NOTIFY rawDeformMatrixChanged)

    friend class BlobGroup;

public:
    explicit BlobShape(QQuickItem* parent = nullptr);
    ~BlobShape() override = default;

    BlobGroup* group() const { return m_group; }

    void setGroup(BlobGroup* g);

    qreal radius() const { return m_radius; }

    void setRadius(qreal r);

    QMatrix4x4 deformMatrix() const { return m_centeredDeformMatrix; }

    QMatrix4x4 rawDeformMatrix() const { return m_deformMatrix; }

    // Re-dirty this shape in its group. QML calls this when an ANCESTOR moves the
    // shape (e.g. a WindowSlot repositioned by a margin change) — geometryChange
    // only fires on the shape's OWN geometry, so without this nudge the shader
    // keeps its stale cached scene position and renders a ghost at the old spot.
    Q_INVOKABLE void repolish();

signals:
    void groupChanged();
    void radiusChanged();
    void deformMatrixChanged();
    void rawDeformMatrixChanged();

protected:
    void componentComplete() override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void updatePolish() override;
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

    virtual bool isInvertedRect() const { return false; }

    virtual bool isExcluded(const BlobShape* /*other*/) const { return false; }

    // Zone index 0..7 for present-day BlobRect; -1 by default (no zone).
    // BlobRect overrides to expose this as a QML property.
    virtual int zoneIndex() const { return -1; }

    // Whether this shape participates in присасывание: inter-rect smin merge
    // with neighbours AND the inverted-frame boost/sink/merge. true by default;
    // BlobRect overrides to expose this as a QML property. false → the shape
    // renders as a clean standalone rounded contour (floating panel).
    virtual bool sticks() const { return true; }

    virtual void cornerRadii(float out[4]) const;

    virtual void updatePhysics() {}

    virtual void registerWithGroup();
    virtual void unregisterFromGroup();
    void updateCenteredDeformMatrix();

    BlobGroup* m_group = nullptr;
    qreal m_radius = 0;
    QMatrix4x4 m_deformMatrix; // identity by default
    QMatrix4x4 m_centeredDeformMatrix;

    // Cached data from updatePolish
    float m_cachedPaddedX = 0;
    float m_cachedPaddedY = 0;
    float m_cachedPaddedW = 0;
    float m_cachedPaddedH = 0;
    QRectF m_localPaddedRect;
    QVector<BlobRectData> m_cachedRects;
    int m_cachedMyIndex = -2;
    float m_pendingDx = 0;
    float m_pendingDy = 0;
    bool m_cachedHasInverted = false;
    float m_cachedInvertedRadius = 0;
    float m_cachedCornerGuard = 0;
    float m_cachedInvertedOuter[4] = {};
    float m_cachedInvertedInner[4] = {};
    float m_cachedZoneRoundings[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
};
