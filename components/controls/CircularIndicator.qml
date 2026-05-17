import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Templates

// Simple indeterminate circular busy indicator. Replaces the former
// Caelestia.Internal-backed Material 3 motion with a steady rotating arc.
BusyIndicator {
    id: root

    property real implicitSize: Appearance.font.size.normal * 3
    property real strokeWidth: Appearance.padding.small * 0.8
    property color fgColour: Colours.palette.primary
    property color bgColour: Colours.palette.secondary_container

    padding: 0
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    contentItem: CircularProgress {
        id: arc

        anchors.fill: parent
        strokeWidth: root.strokeWidth
        fgColour: root.fgColour
        bgColour: root.bgColour
        padding: root.padding
        value: 0.25
        opacity: root.running ? 1 : 0

        NumberAnimation on startAngle {
            running: root.running
            from: 0
            to: 360
            loops: Animation.Infinite
            duration: 1200
        }

        Behavior on opacity {
            NumberAnimation { duration: Appearance.anim.durations.small }
        }
    }
}
