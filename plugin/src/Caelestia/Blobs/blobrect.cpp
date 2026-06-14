#include "blobrect.hpp"
#include "blobgroup.hpp"

#include <algorithm>
#include <cmath>

BlobRect::BlobRect(QQuickItem* parent)
    : BlobShape(parent) {}

BlobRect::~BlobRect() {
    if (m_group)
        m_group->removeShape(this);
}

void BlobRect::updatePolish() {
    BlobShape::updatePolish();

    if (m_physicsActive) {
        // Check if deformation is visually imperceptible
        float totalDelta = std::abs(m_dm00 - 1.0f) + std::abs(m_dm01) + std::abs(m_dm11 - 1.0f);
        float totalVel = std::abs(m_dmVel00) + std::abs(m_dmVel01) + std::abs(m_dmVel11);

        if (totalDelta < 0.004f && totalVel < 0.05f) {
            // Snap to rest, no visible deformation
            m_dm00 = 1.0f;
            m_dm01 = 0.0f;
            m_dm11 = 1.0f;
            m_dmVel00 = m_dmVel01 = m_dmVel11 = 0.0f;
            m_deformMatrix = QMatrix4x4();
            emit rawDeformMatrixChanged();
            updateCenteredDeformMatrix();
            m_physicsActive = false;
        } else {
            QMetaObject::invokeMethod(
                this,
                [this]() {
                    if (m_physicsActive && m_group)
                        m_group->markDirty();
                },
                Qt::QueuedConnection);
        }
    }
}

void BlobRect::updatePhysics() {
    const QPointF scenePos = mapToScene(QPointF(width() / 2.0, height() / 2.0));

    if (!m_hasPrevPos) {
        m_prevScenePos = scenePos;
        m_elapsed.start();
        m_hasPrevPos = true;
        return;
    }

    const float dt = static_cast<float>(m_elapsed.restart()) / 1000.0f;
    if (dt > 0.1f || dt < 0.001f) {
        m_prevScenePos = scenePos;
        // Still check atRest on skipped frames to avoid getting stuck
        if (m_physicsActive)
            checkAtRest(0.0f);
        return;
    }

    const float velX = static_cast<float>(scenePos.x() - m_prevScenePos.x()) / dt;
    const float velY = static_cast<float>(scenePos.y() - m_prevScenePos.y()) / dt;
    m_prevScenePos = scenePos;

    const float speed = std::sqrt(velX * velX + velY * velY);

    if (!m_physicsActive) {
        if (speed < 5.0f)
            return;
        m_physicsActive = true;
    }

    // Compute target deformation matrix from velocity
    // R(θ) * diag(stretch, compress) * R(θ)^T
    const float kStretchFactor = static_cast<float>(m_deformScale);
    constexpr float kMaxStretch = 0.35f;

    float target00 = 1.0f;
    float target01 = 0.0f;
    float target11 = 1.0f;

    if (speed > 5.0f) {
        // deformAtten (0..1) is set from QML per panel size so big panels deform
        // less. It's keyed there on the STABLE target size (not this rect's live,
        // still-growing size), so it tames the corner-appear too; and it's applied
        // AFTER the stretch cap, so it reduces even the cap-saturated appear.
        const float mag = std::min(speed * kStretchFactor, kMaxStretch) * static_cast<float>(m_deformAtten);
        const float targetStretch = 1.0f + mag;
        const float targetCompress = 1.0f / targetStretch;

        const float cosA = velX / speed;
        const float sinA = velY / speed;
        const float cos2 = cosA * cosA;
        const float sin2 = sinA * sinA;
        const float cs = cosA * sinA;

        target00 = targetStretch * cos2 + targetCompress * sin2;
        target01 = (targetStretch - targetCompress) * cs;
        target11 = targetStretch * sin2 + targetCompress * cos2;
    }

    // Underdamped spring on each matrix component, SUB-STEPPED. Explicit Euler
    // on a stiff spring (stiffness 200) is only stable while dt ≲ 2/√stiffness
    // ≈ 0.14 s. A single frame's dt can sit near the 0.1 s clamp when the GPU is
    // saturated — e.g. a VAAPI screen recording encoding on the same node the
    // compositor uses — and at that step size the integrator overshoots and the
    // deform "rocks" / blows up. Fixed ~4 ms sub-steps keep each integration
    // step well inside the stability region at any frame rate (dt is already
    // clamped ≤ 0.1 s above, so this is at most ~25 cheap scalar iterations).
    const float kStiffness = static_cast<float>(m_stiffness);
    const float kDamping = static_cast<float>(m_damping);

    constexpr float kMaxSubStep = 1.0f / 240.0f;
    const int subSteps = std::min(64, std::max(1, static_cast<int>(std::ceil(dt / kMaxSubStep))));
    const float h = dt / static_cast<float>(subSteps);

    for (int i = 0; i < subSteps; ++i) {
        const float accel00 = -kStiffness * (m_dm00 - target00) - kDamping * m_dmVel00;
        m_dmVel00 += accel00 * h;
        m_dm00 += m_dmVel00 * h;

        const float accel01 = -kStiffness * (m_dm01 - target01) - kDamping * m_dmVel01;
        m_dmVel01 += accel01 * h;
        m_dm01 += m_dmVel01 * h;

        const float accel11 = -kStiffness * (m_dm11 - target11) - kDamping * m_dmVel11;
        m_dmVel11 += accel11 * h;
        m_dm11 += m_dmVel11 * h;
    }

    m_deformMatrix = QMatrix4x4(m_dm00, m_dm01, 0, 0, m_dm01, m_dm11, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
    emit rawDeformMatrixChanged();
    updateCenteredDeformMatrix();

    checkAtRest(speed);
}

void BlobRect::setTopLeftRadius(qreal r) {
    if (!qFuzzyCompare(m_topLeftRadius, r)) {
        m_topLeftRadius = r;
        emit topLeftRadiusChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::setTopRightRadius(qreal r) {
    if (!qFuzzyCompare(m_topRightRadius, r)) {
        m_topRightRadius = r;
        emit topRightRadiusChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::setBottomLeftRadius(qreal r) {
    if (!qFuzzyCompare(m_bottomLeftRadius, r)) {
        m_bottomLeftRadius = r;
        emit bottomLeftRadiusChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::setBottomRightRadius(qreal r) {
    if (!qFuzzyCompare(m_bottomRightRadius, r)) {
        m_bottomRightRadius = r;
        emit bottomRightRadiusChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::setZoneIndex(int i) {
    if (m_zoneIndex != i) {
        m_zoneIndex = i;
        emit zoneIndexChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::cornerRadii(float out[4]) const {
    const auto maxR = static_cast<float>(std::min(width(), height())) * 0.5f;
    const auto base = std::min(static_cast<float>(m_radius), maxR);
    out[0] = std::min(m_topRightRadius >= 0 ? static_cast<float>(m_topRightRadius) : base, maxR);
    out[1] = std::min(m_bottomRightRadius >= 0 ? static_cast<float>(m_bottomRightRadius) : base, maxR);
    out[2] = std::min(m_bottomLeftRadius >= 0 ? static_cast<float>(m_bottomLeftRadius) : base, maxR);
    out[3] = std::min(m_topLeftRadius >= 0 ? static_cast<float>(m_topLeftRadius) : base, maxR);
}

bool BlobRect::isExcluded(const BlobShape* other) const {
    for (const auto& ptr : m_exclude) {
        if (ptr == other)
            return true;
    }
    return false;
}

QQmlListProperty<BlobRect> BlobRect::exclude() {
    return QQmlListProperty<BlobRect>(
        this, nullptr, &excludeAppend, &excludeCount, &excludeAt, &excludeClear, &excludeReplace, &excludeRemoveLast);
}

void BlobRect::excludeAppend(QQmlListProperty<BlobRect>* prop, BlobRect* rect) {
    auto* self = static_cast<BlobRect*>(prop->object);
    self->m_exclude.append(rect);
    if (self->m_group)
        self->m_group->markDirty();
    emit self->excludeChanged();
}

qsizetype BlobRect::excludeCount(QQmlListProperty<BlobRect>* prop) {
    auto* self = static_cast<BlobRect*>(prop->object);
    return self->m_exclude.size();
}

BlobRect* BlobRect::excludeAt(QQmlListProperty<BlobRect>* prop, qsizetype index) {
    auto* self = static_cast<BlobRect*>(prop->object);
    return self->m_exclude.at(index);
}

void BlobRect::excludeClear(QQmlListProperty<BlobRect>* prop) {
    auto* self = static_cast<BlobRect*>(prop->object);
    if (self->m_exclude.isEmpty())
        return;
    self->m_exclude.clear();
    if (self->m_group)
        self->m_group->markDirty();
    emit self->excludeChanged();
}

void BlobRect::excludeReplace(QQmlListProperty<BlobRect>* prop, qsizetype index, BlobRect* rect) {
    auto* self = static_cast<BlobRect*>(prop->object);
    self->m_exclude[index] = rect;
    if (self->m_group)
        self->m_group->markDirty();
    emit self->excludeChanged();
}

void BlobRect::excludeRemoveLast(QQmlListProperty<BlobRect>* prop) {
    auto* self = static_cast<BlobRect*>(prop->object);
    if (self->m_exclude.isEmpty())
        return;
    self->m_exclude.removeLast();
    if (self->m_group)
        self->m_group->markDirty();
    emit self->excludeChanged();
}

void BlobRect::checkAtRest(float speed) {
    constexpr float kEpsilon = 0.002f;
    const bool atRest = std::abs(m_dm00 - 1.0f) < kEpsilon && std::abs(m_dm01) < kEpsilon &&
                        std::abs(m_dm11 - 1.0f) < kEpsilon && std::abs(m_dmVel00) < kEpsilon &&
                        std::abs(m_dmVel01) < kEpsilon && std::abs(m_dmVel11) < kEpsilon && speed < 5.0f;

    if (atRest) {
        m_dm00 = 1.0f;
        m_dm01 = 0.0f;
        m_dm11 = 1.0f;
        m_dmVel00 = 0.0f;
        m_dmVel01 = 0.0f;
        m_dmVel11 = 0.0f;
        m_deformMatrix = QMatrix4x4(); // identity
        emit rawDeformMatrixChanged();
        updateCenteredDeformMatrix();
        m_physicsActive = false;
    }
}
