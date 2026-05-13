pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Blobs
import qs.config

// BlobInvertedRect-based frame around the screen edges. Layer-1 windows on
// each rail can visually "stick" to this frame via SDF concave join when
// their edge-margin is 0 AND their invertedJoinRounding > 0 AND this
// border's per-side join radius > 0.
//
// Default: pulls from Config.backgrounds.invertBaseRounding (bool) ×
// Config.backgrounds.rounding (int).
Item {
    id: root

    required property BlobGroup group
    required property int zWidth
    required property int zHeight
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area

    // Per-side SDF join radius. 0 = no join on that side.
    readonly property int defaultJoin: (Config.backgrounds.invertBaseRounding ?? false)
                                       ? (Config.backgrounds.rounding ?? 0)
                                       : 0
    property int topJoin: defaultJoin
    property int rightJoin: defaultJoin
    property int bottomJoin: defaultJoin
    property int leftJoin: defaultJoin

    readonly property int activeRadius: Math.max(topJoin, rightJoin, bottomJoin, leftJoin)
    readonly property bool active: activeRadius > 0

    // Margin trick: the InvertedRect extends `marginAbs` px beyond the parent
    // on every side. Each border<Side> equals marginAbs → the frame is exactly
    // the strip OUTSIDE the visible screen, never inside. So nothing painted
    // visibly; the wall just exists at the screen edges for SDF joining.
    readonly property int marginAbs: 50

    BlobInvertedRect {
        visible: root.active
        anchors.fill: parent
        anchors.margins: -root.marginAbs
        group: root.group
        radius: root.activeRadius
        borderLeft: root.marginAbs
        borderRight: root.marginAbs
        borderTop: root.marginAbs
        borderBottom: root.marginAbs
    }
}
