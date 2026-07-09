pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import QtQuick
import QtQuick.Layouts
import "../content"

// Config.lock → modules/lock/config/LockConfig.qml
// Skin (visual plugin) selection + auth & content options. Skins are
// discovered from modules/lock/skins/ — drop a folder in, it appears here.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    SkinRegistry {
        id: skins
    }

    ColumnLayout {
        id: col

        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Lock")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("Skin")
            icon: "" // tabler palette
            description: qsTr("Visual plugin used for the lock screen. All lock visuals live in the skin; drop a folder into modules/lock/skins/ to add one.")

            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: skins.active

                    delegate: StyledRect {
                        id: pill

                        required property var modelData
                        readonly property bool active: (skins.activeSkin?.id ?? "") === modelData.id

                        implicitWidth: pillRow.implicitWidth + Appearance.padding.medium * 2
                        implicitHeight: pillRow.implicitHeight + Appearance.padding.small * 2
                        radius: Appearance.rounding.small
                        color: active ? Colours.palette.secondary_container : Colours.palette.surface_container_high

                        StateLayer {
                            color: Colours.palette.on_surface

                            function onClicked(): void {
                                Config.lock.skin = pill.modelData.id;
                            }
                        }

                        RowLayout {
                            id: pillRow

                            anchors.centerIn: parent
                            spacing: Appearance.spacing.small

                            StyledIcon {
                                visible: text !== ""
                                text: pill.modelData.icon
                                font.pointSize: Appearance.font.icon.small.pointSize
                                color: pill.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                            }

                            StyledText {
                                text: pill.modelData.title
                                font.pointSize: Appearance.font.size.small
                                color: pill.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                            }
                        }
                    }
                }
            }
        }

        SettingSection {
            title: qsTr("Authentication")
            icon: "" // tabler fingerprint

            SwitchRow {
                label: qsTr("Fingerprint unlock")
                checked: Config.lock.enableFprint
                onToggled: checked => Config.lock.enableFprint = checked
            }

            SpinBoxRow {
                label: qsTr("Max fingerprint tries")
                value: Config.lock.maxFprintTries
                min: 1
                max: 10
                onValueModified: v => Config.lock.maxFprintTries = v
            }
        }

        SettingSection {
            title: qsTr("Content")
            icon: "" // tabler bell

            SwitchRow {
                label: qsTr("Hide notifications")
                tooltip: qsTr("Show only a placeholder in the notification dock until unlocked")
                checked: Config.lock.hideNotifs
                onToggled: checked => Config.lock.hideNotifs = checked
            }

            SwitchRow {
                label: qsTr("Use distro logo")
                tooltip: qsTr("Show the distro glyph instead of the shell logo in the fetch card")
                checked: Config.lock.useDistroLogo
                onToggled: checked => Config.lock.useDistroLogo = checked
            }

            SwitchRow {
                label: qsTr("Recolour logo")
                checked: Config.lock.recolourLogo
                onToggled: checked => Config.lock.recolourLogo = checked
            }
        }
    }
}
