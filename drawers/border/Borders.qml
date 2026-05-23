pragma ComponentBehavior: Bound

import QtQuick

// Orchestrator: 8 BorderZone MouseArea strips (per zone) + the existing
// visible Border chrome rendered on top.
Item {
    id: root

    required property var manager
    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area
    readonly property int zWidth: width
    readonly property int zHeight: height

    anchors.fill: parent

    Repeater {
        model: 8
        delegate: BorderZone {
            required property int index

            manager: root.manager
            zoneIdx: index
            zWidth: root.zWidth
            zHeight: root.zHeight
            left_area: root.left_area
            top_area: root.top_area
            right_area: root.right_area
            bottom_area: root.bottom_area
        }
    }

    Border {
        border_area: root.border_area
        left_area: root.left_area
        top_area: root.top_area
        right_area: root.right_area
        bottom_area: root.bottom_area
    }
}
