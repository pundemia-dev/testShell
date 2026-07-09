pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia
import qs.components
import qs.services
import qs.config

// Neofetch-style card (caelestia lock Fetch). Differences from caelestia:
// distro logo is the nerd-font glyph from Icons.osIcon (pShell has no logo
// image paths), and the colour-box row is synthesised from the M3 palette
// (pShell has no term0..15 roles).
StyledRect {
    id: root

    required property real rootHeight
    readonly property int cBoxSize: Appearance.font.body.medium.pointSize * 2
    readonly property list<color> termColours: [Colours.palette.primary, Colours.palette.secondary, Colours.palette.tertiary, Colours.palette.error, Colours.palette.primary_container, Colours.palette.secondary_container, Colours.palette.tertiary_container, Colours.palette.outline]

    implicitHeight: layout.implicitHeight + layout.anchors.topMargin + layout.anchors.margins
    radius: Appearance.rounding.medium
    color: Colours.tPalette.surface_container

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.extraLarge
        anchors.topMargin: Appearance.padding.extraLarge
        anchors.bottomMargin: Appearance.padding.extraLarge

        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: Appearance.spacing.medium

            StyledRect {
                implicitWidth: prompt.implicitWidth + Appearance.padding.medium * 2
                implicitHeight: prompt.implicitHeight + Appearance.padding.small * 2

                color: Colours.palette.primary
                radius: Appearance.rounding.medium

                MonoText {
                    id: prompt

                    anchors.centerIn: parent
                    text: ">"
                    color: Colours.palette.on_primary
                }
            }

            MonoText {
                Layout.fillWidth: true
                text: "pshellfetch.sh"
                elide: Text.ElideRight
            }

            WrappedLoader {
                Layout.fillHeight: true
                Layout.preferredWidth: height
                Layout.preferredHeight: 0
                active: !iconLoader.active

                sourceComponent: Config.lock.useDistroLogo ? distroIcon : pshellLogo
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.extraLarge

            WrappedLoader {
                id: iconLoader

                Layout.fillHeight: true
                active: root.width > Config.lock.sizes.largeLogoWidth

                sourceComponent: Config.lock.useDistroLogo ? distroIcon : pshellLogo
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.padding.medium
                Layout.bottomMargin: iconLoader.active || colourRowLoader.active ? Appearance.padding.medium : 0
                spacing: Appearance.spacing.medium

                Repeater {
                    model: {
                        const items = [];
                        const hasBatt = UPower.displayDevice.isLaptopBattery;
                        const rHeight = root.rootHeight;

                        if (!hasBatt && rHeight > Config.lock.sizes.fetch4LinesHeight)
                            items.push(`OS  : ${Icons.osName || "Linux"}`);

                        if (rHeight > (hasBatt ? Config.lock.sizes.fetch4LinesHeight : Config.lock.sizes.fetch3LinesHeight))
                            items.push(`WM  : ${SysInfo.wm}`);

                        if (!hasBatt || rHeight > Config.lock.sizes.fetch3LinesHeight)
                            items.push(`USER: ${SysInfo.user}`);

                        items.push(`UP  : ${SysInfo.uptime}`);

                        if (hasBatt)
                            items.push(`BATT: ${[UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state) ? "(+) " : ""}${Math.round(UPower.displayDevice.percentage * 100)}%`);

                        return items;
                    }

                    MonoText {
                        required property string modelData

                        Layout.fillWidth: true
                        text: modelData
                        elide: Text.ElideRight
                    }
                }
            }
        }

        WrappedLoader {
            id: colourRowLoader

            Layout.topMargin: iconLoader.active ? Appearance.spacing.small : 0
            Layout.alignment: Qt.AlignHCenter
            active: root.rootHeight > Config.lock.sizes.showColourBoxRowHeight

            sourceComponent: RowLayout {
                id: coloursRow

                spacing: Appearance.spacing.largeIncreased

                Repeater {
                    model: CUtils.clamp(Math.floor((layout.width + coloursRow.spacing) / (root.cBoxSize + coloursRow.spacing)), 0, root.termColours.length)

                    StyledRect {
                        required property int index

                        implicitWidth: implicitHeight
                        implicitHeight: root.cBoxSize
                        color: root.termColours[index]
                        radius: Appearance.rounding.medium
                    }
                }
            }
        }
    }

    Component {
        id: pshellLogo

        Logo {
            width: height
        }
    }

    Component {
        id: distroIcon

        StyledText {
            width: height
            text: SysInfo.osLogo
            color: Config.lock.recolourLogo ? Colours.palette.primary : Colours.palette.on_surface
            font.pointSize: Math.max(1, Math.round(height * 0.55))
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component WrappedLoader: Loader {
        asynchronous: true
        visible: active
    }

    component MonoText: StyledText {
        font.family: Appearance.font.family.mono
        font.pointSize: root.width > Config.lock.sizes.largeFontWidth ? Appearance.font.mono.medium.pointSize : Appearance.font.mono.small.pointSize
    }
}
