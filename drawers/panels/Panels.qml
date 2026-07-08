import QtQuick
import Quickshell
import qs.modules.bar
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property PerMonitorVisibilities visibilities
    // required property Item bar
    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area

    // readonly property

    anchors.fill: parent
    anchors.leftMargin: left_area
    anchors.topMargin: top_area
    anchors.rightMargin: right_area
    anchors.bottomMargin: bottom_area

    // The OSD now lives as a proper module (modules/osd/OsdWrapper.qml),
    // instanced in drawers/Drawers.qml via the rails contract.
}
