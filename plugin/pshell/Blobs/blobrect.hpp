#pragma once

#include "blobshape.hpp"

#include <qelapsedtimer.h>
#include <qpointer.h>
#include <qqmlengine.h>
#include <qqmllist.h>

class BlobRect : public BlobShape {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal stiffness READ stiffness WRITE setStiffness NOTIFY stiffnessChanged)
    Q_PROPERTY(qreal damping READ damping WRITE setDamping NOTIFY dampingChanged)
    Q_PROPERTY(qreal deformScale READ deformScale WRITE setDeformScale NOTIFY deformScaleChanged)
    // Overall deform magnitude multiplier (0..1). Set from QML per panel size so
    // big panels deform less. Applied AFTER the stretch cap, so it tames even the
    // cap-saturated corner-appear. Keyed in QML on the panel's STABLE target size
    // (not the animating size), so the grow-through-small-sizes is attenuated too.
    Q_PROPERTY(qreal deformAtten READ deformAtten WRITE setDeformAtten NOTIFY deformAttenChanged)
    // Speed-keyed rounding: while the rect moves, its corner radii ride toward
    // the full capsule (min(w,h)/2) and settle back as it decelerates. Value =
    // rounding mix per px/s of centre speed (full capsule at 1/value px/s);
    // 0 disables. The speed bell of any easing/spring motion yields the
    // "rounder mid-path, settled at the ends" profile automatically.
    Q_PROPERTY(qreal speedRounding READ speedRounding WRITE setSpeedRounding NOTIFY speedRoundingChanged)
    // Live speed-keyed rounding mix (0..1), read-only. Lets QML drive effects
    // that must track the motion-driven part of the rounding (e.g. the content
    // squeeze) — zero at rest, so magnet-driven unequal radii never trigger them.
    Q_PROPERTY(qreal roundBoost READ roundBoost NOTIFY roundBoostChanged)
    // Whether the boost is APPLIED to the corner radii. Consumers that only
    // need the motion mix (content blur) can keep speedRounding > 0 to have
    // the boost computed while leaving the visible corners untouched.
    Q_PROPERTY(bool speedRoundingApply READ speedRoundingApply WRITE setSpeedRoundingApply NOTIFY
            speedRoundingApplyChanged)
    Q_PROPERTY(QQmlListProperty<BlobRect> exclude READ exclude NOTIFY excludeChanged)
    Q_PROPERTY(qreal topLeftRadius READ topLeftRadius WRITE setTopLeftRadius NOTIFY topLeftRadiusChanged)
    Q_PROPERTY(qreal topRightRadius READ topRightRadius WRITE setTopRightRadius NOTIFY topRightRadiusChanged)
    Q_PROPERTY(qreal bottomLeftRadius READ bottomLeftRadius WRITE setBottomLeftRadius NOTIFY bottomLeftRadiusChanged)
    Q_PROPERTY(
        qreal bottomRightRadius READ bottomRightRadius WRITE setBottomRightRadius NOTIFY bottomRightRadiusChanged)
    // Zone index 0..7 (TL, T, TR, R, BR, B, BL, L). -1 means "no zone" — no присасывание.
    Q_PROPERTY(int zoneIndex READ zoneIndex WRITE setZoneIndex NOTIFY zoneIndexChanged)
    // Whether this rect присасывается (merges with neighbours + frame). Default true.
    Q_PROPERTY(bool sticks READ sticks WRITE setSticks NOTIFY sticksChanged)

public:
    explicit BlobRect(QQuickItem* parent = nullptr);
    ~BlobRect() override;

    qreal stiffness() const { return m_stiffness; }

    void setStiffness(qreal s) {
        if (!qFuzzyCompare(m_stiffness, s)) {
            m_stiffness = s;
            emit stiffnessChanged();
        }
    }

    qreal damping() const { return m_damping; }

    void setDamping(qreal d) {
        if (!qFuzzyCompare(m_damping, d)) {
            m_damping = d;
            emit dampingChanged();
        }
    }

    qreal deformScale() const { return m_deformScale; }

    void setDeformScale(qreal s) {
        if (!qFuzzyCompare(m_deformScale, s)) {
            m_deformScale = s;
            emit deformScaleChanged();
        }
    }

    qreal deformAtten() const { return m_deformAtten; }

    void setDeformAtten(qreal v) {
        if (!qFuzzyCompare(m_deformAtten, v)) {
            m_deformAtten = v;
            emit deformAttenChanged();
        }
    }

    qreal speedRounding() const { return m_speedRounding; }

    void setSpeedRounding(qreal v) {
        if (!qFuzzyCompare(m_speedRounding, v)) {
            m_speedRounding = v;
            emit speedRoundingChanged();
        }
    }

    qreal roundBoost() const { return m_roundBoost; }

    bool speedRoundingApply() const { return m_speedRoundingApply; }

    void setSpeedRoundingApply(bool v);

    QQmlListProperty<BlobRect> exclude();

    bool isExcluded(const BlobShape* other) const override;
    void cornerRadii(float out[4]) const override;

    qreal topLeftRadius() const { return m_topLeftRadius; }

    void setTopLeftRadius(qreal r);

    qreal topRightRadius() const { return m_topRightRadius; }

    void setTopRightRadius(qreal r);

    qreal bottomLeftRadius() const { return m_bottomLeftRadius; }

    void setBottomLeftRadius(qreal r);

    qreal bottomRightRadius() const { return m_bottomRightRadius; }

    void setBottomRightRadius(qreal r);

    int zoneIndex() const override { return m_zoneIndex; }

    void setZoneIndex(int i);

    bool sticks() const override { return m_sticks; }

    void setSticks(bool s);

signals:
    void stiffnessChanged();
    void dampingChanged();
    void deformScaleChanged();
    void deformAttenChanged();
    void speedRoundingChanged();
    void roundBoostChanged();
    void speedRoundingApplyChanged();
    void excludeChanged();
    void topLeftRadiusChanged();
    void topRightRadiusChanged();
    void bottomLeftRadiusChanged();
    void bottomRightRadiusChanged();
    void zoneIndexChanged();
    void sticksChanged();

protected:
    void updatePolish() override;
    void updatePhysics() override;

private:
    void checkAtRest(float speed);

    // Physics state
    QPointF m_prevScenePos;
    QElapsedTimer m_elapsed;
    bool m_physicsActive = false;
    bool m_hasPrevPos = false;

    // Symmetric 2x2 deformation matrix components (3 independent: m00, m01,
    // m11) Rest state is identity: m00=1, m01=0, m11=1
    float m_dm00 = 1.0f;
    float m_dm01 = 0.0f;
    float m_dm11 = 1.0f;

    // Spring velocities for each component
    float m_dmVel00 = 0.0f;
    float m_dmVel01 = 0.0f;
    float m_dmVel11 = 0.0f;

    qreal m_stiffness = 200.0;
    qreal m_damping = 16.0;
    qreal m_deformScale = 0.0005;
    qreal m_deformAtten = 1.0;
    qreal m_speedRounding = 0.0;
    // Smoothed 0..1 mix toward the capsule radius, driven by centre speed in
    // updatePhysics; read by cornerRadii (when m_speedRoundingApply) and
    // published to QML via roundBoost.
    float m_roundBoost = 0.0f;
    bool m_speedRoundingApply = true;

    qreal m_topLeftRadius = -1;
    qreal m_topRightRadius = -1;
    qreal m_bottomLeftRadius = -1;
    qreal m_bottomRightRadius = -1;

    int m_zoneIndex = -1;
    bool m_sticks = true;

    QList<QPointer<BlobRect>> m_exclude;

    static void excludeAppend(QQmlListProperty<BlobRect>* prop, BlobRect* rect);
    static qsizetype excludeCount(QQmlListProperty<BlobRect>* prop);
    static BlobRect* excludeAt(QQmlListProperty<BlobRect>* prop, qsizetype index);
    static void excludeClear(QQmlListProperty<BlobRect>* prop);
    static void excludeReplace(QQmlListProperty<BlobRect>* prop, qsizetype index, BlobRect* rect);
    static void excludeRemoveLast(QQmlListProperty<BlobRect>* prop);
};
