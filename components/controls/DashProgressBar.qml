import qs.config
import qs.services
import qs.components
import QtQuick

// Material-3 linear progress bar with a stop-indicator dot at the far end, like
// caelestia's StyledProgressBar (determinate path). Filled portion on the left,
// a gap, the remaining track, then the fg dot pinned to the right edge.
Item {
    id: root

    property real value: 0
    property color fgColour: Colours.palette.primary
    property color bgColour: Colours.palette.secondary_container
    readonly property real gap: Appearance.spacing.small
    readonly property real frac: Math.max(0, Math.min(1, isNaN(value) ? 0 : value))

    implicitWidth: 200
    implicitHeight: 5

    // Filled portion.
    StyledRect {
        id: fill
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: parent.height
        implicitWidth: Math.max(0, parent.width * root.frac - (root.frac < 1 ? root.gap : 0))
        radius: Appearance.rounding.full
        color: root.fgColour

        Behavior on implicitWidth {
            Anim {}
        }
    }

    // Remaining track between the fill and the stop dot.
    StyledRect {
        anchors.right: dot.left
        anchors.rightMargin: root.gap
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: parent.height
        implicitWidth: Math.max(0, dot.x - root.gap - (fill.implicitWidth + root.gap))
        radius: Appearance.rounding.full
        color: root.bgColour
        visible: implicitWidth > 0
    }

    // Stop indicator dot at the far right.
    StyledRect {
        id: dot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: parent.height
        implicitHeight: parent.height
        radius: Appearance.rounding.full
        color: root.fgColour
    }
}
