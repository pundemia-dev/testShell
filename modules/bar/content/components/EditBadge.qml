import QtQuick
import qs.components
import qs.config
import qs.services

// Small ✕-in-circle delete badge shown (on hover) on a widget / group /
// group-child while the bar is in edit mode. Pinned to the top-right of its
// host by the caller. Emits `clicked` — the host wires it to
// BarEditManager.removeEntry.
StyledRect {
    id: root

    signal clicked

    implicitWidth: Appearance.font.size.large + Appearance.padding.small
    implicitHeight: implicitWidth
    radius: Appearance.rounding.full
    color: ma.containsMouse ? Colours.palette.error : Colours.palette.surface_container_highest

    StyledText {
        anchors.centerIn: parent
        text: "" // tabler x (U+EB55, verified)
        font.family: Appearance.font.family.tabler
        font.pointSize: Appearance.font.size.normal
        color: ma.containsMouse ? Colours.palette.on_error : Colours.palette.error
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
