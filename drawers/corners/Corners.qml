pragma ComponentBehavior: Bound

import qs.widgets
import qs.utils
import qs.config
import QtQuick
import QtQuick.Effects

Item {
    id: root

    anchors.fill: parent

    StyledRect {
        anchors.fill: parent
        color: Config.corners.color || Colours.alpha(Colours.palette.m3surface, false)

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: mask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: Config.corners.enabled ? Config.corners.rounding : 0
        }
    }
}