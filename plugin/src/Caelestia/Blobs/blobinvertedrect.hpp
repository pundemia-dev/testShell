#pragma once

#include "blobshape.hpp"

#include <qlist.h>
#include <qqmlengine.h>

class BlobInvertedRect : public BlobShape {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal borderLeft READ borderLeft WRITE setBorderLeft NOTIFY borderLeftChanged)
    Q_PROPERTY(qreal borderRight READ borderRight WRITE setBorderRight NOTIFY borderRightChanged)
    Q_PROPERTY(qreal borderTop READ borderTop WRITE setBorderTop NOTIFY borderTopChanged)
    Q_PROPERTY(qreal borderBottom READ borderBottom WRITE setBorderBottom NOTIFY borderBottomChanged)
    // Per-zone присасывание strengths (8 floats, padded with 0 if shorter).
    // Order: topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left.
    // 0 = disabled (bg in that zone does NOT pull the frame's inner edge inward).
    // 1 = unscaled (full sink, current default behavior).
    Q_PROPERTY(QList<qreal> zoneRoundings READ zoneRoundings WRITE setZoneRoundings NOTIFY zoneRoundingsChanged)
    // Guard band width (px) around the inner-cutout corner arcs. Inside it
    // the shader gates the присасывание sink and collapses the frame smin to
    // a hard min, so the border rounding (radius) is never overridden by
    // sinking bgs. 0 disables.
    Q_PROPERTY(qreal cornerGuard READ cornerGuard WRITE setCornerGuard NOTIFY cornerGuardChanged)

public:
    explicit BlobInvertedRect(QQuickItem* parent = nullptr);
    ~BlobInvertedRect() override;

    qreal borderLeft() const { return m_borderLeft; }

    void setBorderLeft(qreal v);

    qreal borderRight() const { return m_borderRight; }

    void setBorderRight(qreal v);

    qreal borderTop() const { return m_borderTop; }

    void setBorderTop(qreal v);

    qreal borderBottom() const { return m_borderBottom; }

    void setBorderBottom(qreal v);

    QList<qreal> zoneRoundings() const { return m_zoneRoundings; }

    void setZoneRoundings(const QList<qreal>& v);

    qreal cornerGuard() const { return m_cornerGuard; }

    void setCornerGuard(qreal v);

signals:
    void borderLeftChanged();
    void borderRightChanged();
    void borderTopChanged();
    void borderBottomChanged();
    void zoneRoundingsChanged();
    void cornerGuardChanged();

protected:
    bool isInvertedRect() const override { return true; }

    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

    void registerWithGroup() override;
    void unregisterFromGroup() override;

private:
    qreal m_borderLeft = 0;
    qreal m_borderRight = 0;
    qreal m_borderTop = 0;
    qreal m_borderBottom = 0;
    qreal m_cornerGuard = 0;
    QList<qreal> m_zoneRoundings;
};
