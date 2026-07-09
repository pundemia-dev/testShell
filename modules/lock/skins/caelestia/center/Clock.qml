pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.config

Item {
    id: root

    required property real centerScale
    readonly property bool twelveHour: Config.services?.useTwelveHourClock ?? false

    function calcTopOff(metrics: TextMetrics): real {
        return metrics.tightBoundingRect.y - metrics.boundingRect.y;
    }

    implicitWidth: hours.implicitWidth + minutes.implicitWidth + Appearance.spacing.small
    implicitHeight: hourMetrics.tightBoundingRect.height

    StyledText {
        id: hours

        y: -root.calcTopOff(hourMetrics)
        text: Time.hourStr
        color: Colours.palette.primary
        font.family: Appearance.font.family.sans
        font.pointSize: Math.max(1, Math.round(Appearance.font.headline.large.pointSize * 7 * root.centerScale))
        font.weight: Font.Medium

        TextMetrics {
            id: hourMetrics

            text: hours.text
            font: hours.font
        }
    }

    StyledText {
        id: minutes

        anchors.right: parent.right
        y: -root.calcTopOff(minuteMetrics)

        text: Time.minuteStr
        color: Colours.palette.secondary
        font.family: Appearance.font.family.sans
        font.pointSize: Math.max(1, Math.round(Appearance.font.headline.large.pointSize * (root.twelveHour ? 3.8 : 7) * root.centerScale))
        font.weight: Font.Medium

        TextMetrics {
            id: minuteMetrics

            text: minutes.text
            font: minutes.font
        }
    }

    Loader {
        anchors.left: minutes.left
        anchors.leftMargin: minuteMetrics.tightBoundingRect.x
        y: hourMetrics.tightBoundingRect.height - implicitHeight

        active: root.twelveHour
        asynchronous: true

        sourceComponent: StyledRect {
            color: Colours.tPalette.surface_container_high
            radius: Appearance.rounding.large

            implicitWidth: minuteMetrics.tightBoundingRect.width
            implicitHeight: amPmMetrics.tightBoundingRect.height + Appearance.padding.large * 2

            StyledText {
                id: amPm

                anchors.centerIn: parent
                width: amPmMetrics.tightBoundingRect.width
                height: amPmMetrics.tightBoundingRect.height
                transform: Translate {
                    x: -amPmMetrics.tightBoundingRect.x
                    y: -root.calcTopOff(amPmMetrics)
                }

                text: Time.amPmStr
                color: Colours.palette.on_surface
                font.family: Appearance.font.family.sans
                font.pointSize: Math.max(1, Math.round(Appearance.font.headline.small.pointSize * 2 * root.centerScale))
                font.weight: Font.Medium

                TextMetrics {
                    id: amPmMetrics

                    text: amPm.text
                    font: amPm.font
                }
            }
        }
    }
}
