pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import qs.components
import qs.components.effects
import qs.services
import qs.config

// CPU/RAM/Disk as filled MaterialShapes (caelestia lock Resources). Values come
// from the SystemUsage singleton (pShell's replacement for caelestia's C++
// Cpu/Memory/Storage services). The CPU-temperature badge is dropped — pShell
// has no temperature source.
StyledRect {
    id: root

    readonly property real fontScale: {
        const diff = width / 391 - 1; // 391 is the width at 1080 height screen
        return 1 + Math.pow(Math.abs(diff), 0.8) * Math.sign(diff);
    }

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2
    radius: Appearance.rounding.extraLarge
    color: Colours.tPalette.surface_container

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.large

        Resource {
            icon: "" // tabler cpu
            value: Math.round(SystemUsage.cpuPerc * 100) + "%"
            fillValue: SystemUsage.cpuPerc
            colour: Colours.palette.primary
            shapeColour: Colours.palette.primary_container
            fillColour: Qt.alpha(Colours.palette.secondary, 0.3)
            shape: MaterialShape.Pentagon
        }

        Resource {
            icon: "" // tabler stack
            value: Math.round(SystemUsage.memPerc * 100) + "%"
            fillValue: SystemUsage.memPerc
            colour: Colours.palette.tertiary
            shapeColour: Colours.palette.on_tertiary
            fillColour: Qt.alpha(Colours.palette.tertiary, 0.3)
            shape: MaterialShape.Slanted
        }

        Resource {
            icon: "" // tabler database
            value: Math.round(SystemUsage.storagePerc * 100) + "%"
            fillValue: SystemUsage.storagePerc
            colour: Colours.palette.secondary
            shapeColour: Colours.palette.secondary_container
            fillColour: Qt.alpha(Colours.palette.secondary, 0.4)
            shape: MaterialShape.Gem
        }
    }

    component Resource: Item {
        id: res

        required property string icon
        required property string value
        required property color colour
        required property color shapeColour
        property color fillColour
        property real fillValue: -1
        property alias shape: shape.shape
        readonly property alias mShape: shape

        Layout.fillWidth: true
        implicitHeight: width

        Behavior on shapeColour {
            CAnim {}
        }

        MaterialShape {
            id: shape

            implicitSize: res.width
            color: Qt.alpha(res.shapeColour, 1)
            opacity: res.shapeColour.a
            layer.enabled: true
        }

        Loader {
            id: fillLoader

            anchors.fill: shape
            active: res.fillValue >= 0
            asynchronous: true

            layer.enabled: active
            layer.effect: Mask {
                maskSource: shape
            }

            sourceComponent: Item {
                WavyTopRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    implicitHeight: shape.implicitSize * res.fillValue
                    color: res.fillColour
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: -Appearance.spacing.extraSmall

            StyledIcon {
                Layout.alignment: Qt.AlignHCenter
                text: res.icon
                color: Colours.palette.secondary
                font.pointSize: Math.max(1, Math.round(Appearance.font.icon.medium.pointSize * root.fontScale))
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: res.value
                color: res.colour
                font.family: Appearance.font.family.sans
                font.pointSize: Math.max(1, Math.round(Appearance.font.headline.large.pointSize * root.fontScale))
                font.weight: Font.Medium
            }
        }

        Behavior on fillValue {
            Anim {}
        }
    }
}
