pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.modules.settings.components
import QtQuick
import QtQuick.Layouts

// Config.stash → modules/stash/config/StashConfig.qml
// Tray behaviour, grid sizing, LocalSend + the shared background geometry card.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Stash")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("General")
            icon: "" // tabler inbox

            SwitchRow {
                label: qsTr("Enabled")
                checked: Config.stash.enabled
                onToggled: c => Config.stash.enabled = c
            }

            SettingRow {
                label: qsTr("Stash directory")
                description: qsTr("Where dropped files are collected.")
                StyledTextField {
                    implicitWidth: 220
                    text: Config.stash.stashDir
                    onEditingFinished: Config.stash.stashDir = text
                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.medium
                    rightPadding: Appearance.padding.medium
                    background: StyledRect {
                        radius: Appearance.rounding.small
                        color: Colours.palette.surface_container_high
                    }
                }
            }

            SpinBoxRow {
                label: qsTr("Auto-hide delay (ms) — 0 stays open")
                value: Config.stash.autoHideMs
                min: 0
                max: 300000
                step: 1000
                onValueModified: v => Config.stash.autoHideMs = v
            }
        }

        SettingSection {
            title: qsTr("Grid")
            icon: "" // tabler layout-grid

            SpinBoxRow {
                label: qsTr("Columns")
                value: Config.stash.columns
                min: 1
                max: 12
                step: 1
                onValueModified: v => Config.stash.columns = v
            }
            SpinBoxRow {
                label: qsTr("Max rows")
                value: Config.stash.rowsMax
                min: 1
                max: 20
                step: 1
                onValueModified: v => Config.stash.rowsMax = v
            }
            SpinBoxRow {
                label: qsTr("Max columns")
                value: Config.stash.colsMax
                min: 1
                max: 20
                step: 1
                onValueModified: v => Config.stash.colsMax = v
            }
            SpinBoxRow {
                label: qsTr("Cell size")
                value: Config.stash.cellSize
                min: 48
                max: 200
                step: 4
                onValueModified: v => Config.stash.cellSize = v
            }
        }

        SettingSection {
            title: qsTr("LocalSend")
            icon: "" // tabler send

            SwitchRow {
                label: qsTr("Enabled")
                checked: Config.stash.localsendEnabled
                onToggled: c => Config.stash.localsendEnabled = c
            }
            SwitchRow {
                label: qsTr("Receive")
                checked: Config.stash.localsendReceiveEnabled
                onToggled: c => Config.stash.localsendReceiveEnabled = c
            }
            SettingRow {
                label: qsTr("Alias")
                description: qsTr("Display name other devices see.")
                StyledTextField {
                    implicitWidth: 220
                    text: Config.stash.localsendAlias
                    onEditingFinished: Config.stash.localsendAlias = text
                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.medium
                    rightPadding: Appearance.padding.medium
                    background: StyledRect {
                        radius: Appearance.rounding.small
                        color: Colours.palette.surface_container_high
                    }
                }
            }
        }

        BackgroundCard {
            cfg: Config.stash
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
