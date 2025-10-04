pragma ComponentBehavior: Bound

import qs.widgets
import qs.config
import Quickshell
import QtQuick

Scope {
    id: root

    required property ShellScreen screen
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area

    ExclusionZone {
        anchors.left: true
        exclusiveZone: left_area
    }

    ExclusionZone {
        anchors.top: true
        exclusiveZone: top_area
    }

    ExclusionZone {
        anchors.right: true
        exclusiveZone: right_area
    }

    ExclusionZone {
        anchors.bottom: true
        exclusiveZone: bottom_area
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: Config.border.thickness
        mask: Region {}
    }
}