pragma ComponentBehavior: Bound

import qs.widgets
import qs.utils
import qs.config
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area

    anchors.fill: parent

    StyledRect {
        anchors.fill: parent
        color: Colours.alpha(Colours.palette.m3surface, false)

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
            anchors.leftMargin: Config.border.fillBar ? left_area : border_area
            anchors.topMargin: Config.border.fillBar ? top_area : border_area
            anchors.rightMargin: Config.border.fillBar ? right_area : border_area
            anchors.bottomMargin: Config.border.fillBar ? bottom_area : border_area
            radius: Config.border.enabled ? Config.border.rounding : 0
        }
    }
}