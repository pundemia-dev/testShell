pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Caelestia.Services
import QtQuick
import QtQuick.Layouts

// Memory card: 270° radial gauge + used/total. 1:1 port of caelestia
// performance/MemoryCard.qml.
StyledRect {
    id: root

    readonly property color accent: Colours.palette.tertiary
    readonly property color cardColour: Colours.transparency.enabled
        ? Colours.layer(Colours.palette.surface_container, 2)
        : Colours.palette.surface_container

    color: cardColour
    radius: Appearance.rounding.normal

    implicitWidth: layout.implicitWidth + Appearance.padding.large * 2
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    ServiceRef { service: Memory }

    ColumnLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        RowLayout {
            spacing: Appearance.spacing.small

            StyledText {
                text: "\ueb2d" // tabler stack
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.large
                color: root.accent
            }
            StyledText {
                text: qsTr("Memory")
                font.pointSize: Appearance.font.size.large
                font.weight: Font.DemiBold
            }
        }

        DashProgress {
            Layout.topMargin: Appearance.spacing.large
            Layout.alignment: Qt.AlignHCenter
            implicitSize: usageColumn.implicitHeight + thickness + Appearance.padding.large * 2
            startAngle: -225
            sweepAngle: 270
            fgColour: root.accent
            value: Memory.percentage

            Behavior on clampedVal { Anim {} }

            ColumnLayout {
                id: usageColumn
                anchors.centerIn: parent
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Math.round(Memory.percentage * 100) + "%"
                    font.pointSize: Appearance.font.size.large
                    font.weight: Font.DemiBold
                    color: root.accent
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Used")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.on_surface_variant
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: {
                const fmt = UsageFmt.formatKib(Memory.used, Memory.total);
                return `${fmt.value.toFixed(1)} / ${Math.floor(fmt.total)} ${fmt.unit}`;
            }
            font.pointSize: Appearance.font.size.normal
        }
    }
}
