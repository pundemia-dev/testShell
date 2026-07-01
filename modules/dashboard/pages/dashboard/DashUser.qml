pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.images
import M3Shapes
import Quickshell
import QtQuick

// User card: M3-shape avatar (Pill) + OS gem logo + uptime clamshell + WM pill.
// Adapted from caelestia dash/User.qml onto pShell (tabler glyphs, tPalette,
// SysInfo). The avatar photo is ~/.face.
Item {
    id: root

    anchors.fill: parent
    anchors.margins: Appearance.padding.large

    readonly property int logoSize: Config.dashboard.dash.logoSize
    readonly property int uptimeSize: Config.dashboard.dash.uptimeSize

    // ── OS gem logo ────────────────────────────────────────────────
    MaterialShape {
        id: logoShape
        x: Appearance.padding.small
        anchors.verticalCenter: pfpContainer.verticalCenter
        implicitSize: root.logoSize + Appearance.padding.small * 2
        shape: MaterialShape.Gem
        color: Colours.palette.primary_container

        StyledText {
            anchors.centerIn: parent
            text: SysInfo.osLogo
            font.pointSize: root.logoSize * 0.6
            color: Colours.palette.on_primary_container
        }
    }

    // ── Avatar (Pill) ──────────────────────────────────────────────
    Item {
        id: pfpContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: logoShape.right
        anchors.leftMargin: -Appearance.padding.large
        implicitWidth: height

        MaterialShape {
            id: pfpShape
            anchors.centerIn: parent
            implicitSize: parent.height
            shape: MaterialShape.Pill
            color: Colours.layer(Colours.palette.surface_container_highest, 2)
        }

        StyledClippingRect {
            anchors.fill: pfpShape
            anchors.margins: Appearance.padding.small
            radius: width / 2
            color: "transparent"

            StyledText {
                anchors.centerIn: parent
                visible: pfp.status !== Image.Ready
                text: "\ueb4b" // tabler user-plus
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.extraLarge * 1.4
                color: Colours.palette.on_surface_variant
            }

            CachingImage {
                id: pfp
                anchors.fill: parent
                path: (Quickshell.env("HOME") || "") + "/.face"
                visible: status === Image.Ready
            }

            StyledRect {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(Colours.palette.scrim, 0.4)
                opacity: pfpMouse.containsMouse ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { Anim {} }

                MaterialShape {
                    anchors.centerIn: parent
                    implicitSize: parent.height * 0.7
                    shape: MaterialShape.Diamond
                    color: Colours.palette.primary
                    scale: pfpMouse.pressed ? 0.9 : 1

                    Behavior on scale { Anim {} }

                    StyledText {
                        anchors.centerIn: parent
                        text: "\ueb04" // tabler pencil
                        font.family: Appearance.font.family.tabler
                        font.pointSize: Appearance.font.size.large
                        color: Colours.palette.on_primary
                    }
                }
            }

            MouseArea {
                id: pfpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["xdg-open", (Quickshell.env("HOME") || "") + "/.face"])
            }
        }
    }

    // ── Uptime clamshell ───────────────────────────────────────────
    MaterialShape {
        id: uptimeShape
        anchors.bottom: parent.bottom
        anchors.left: pfpContainer.right
        anchors.leftMargin: -Appearance.padding.large
        implicitSize: root.uptimeSize + Appearance.padding.small * 2
        shape: MaterialShape.ClamShell
        color: Colours.palette.tertiary_container

        StyledText {
            anchors.centerIn: parent
            text: "\uef93" // tabler hourglass
            font.family: Appearance.font.family.tabler
            font.pointSize: root.uptimeSize * 0.5
            color: Colours.palette.on_tertiary_container
        }
    }

    StyledText {
        anchors.left: uptimeShape.right
        anchors.verticalCenter: uptimeShape.verticalCenter
        anchors.leftMargin: Appearance.spacing.small
        text: "up " + SysInfo.uptime.split(",").slice(0, 2).join(",")
        width: Config.dashboard.dash.userWidth - x - Appearance.padding.large
        elide: Text.ElideRight
        color: Colours.palette.on_surface
    }

    // ── WM pill + bubbles ──────────────────────────────────────────
    StyledRect {
        id: bubble1
        anchors.left: pfpContainer.right
        anchors.top: bubble2.bottom
        anchors.leftMargin: Appearance.spacing.small
        anchors.topMargin: -Appearance.spacing.small
        implicitWidth: 10
        implicitHeight: 10
        radius: Appearance.rounding.full
        color: Colours.palette.secondary_container
    }
    StyledRect {
        id: bubble2
        anchors.left: bubble1.right
        anchors.verticalCenter: wmContainer.bottom
        anchors.leftMargin: Appearance.spacing.small
        implicitWidth: 15
        implicitHeight: 15
        radius: Appearance.rounding.full
        color: Colours.palette.secondary_container
    }
    StyledRect {
        id: wmContainer
        anchors.left: bubble2.left
        anchors.leftMargin: -Appearance.padding.normal
        y: Appearance.padding.small
        radius: Appearance.rounding.large
        color: Colours.palette.secondary_container
        implicitWidth: wmLabel.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: wmLabel.implicitHeight + Appearance.padding.small * 2

        Row {
            id: wmLabel
            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uefe6" // tabler app-window
                font.family: Appearance.font.family.tabler
                color: Colours.palette.on_secondary_container
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: SysInfo.wm
                color: Colours.palette.on_secondary_container
            }
        }
    }
}
