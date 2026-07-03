import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts
import qs.components.containers

// Config.launcher → launcherconfig/LauncherConfig.qml
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
            text: qsTr("Launcher")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("List")
            icon: "\uec45" // tabler rocket

            SettingRow {
                label: qsTr("Max shown")
                description: qsTr("Maximum visible result rows.")
                CustomSpinBox {
                    value: Config.launcher.maxShown
                    min: 1
                    max: 20
                    onValueModified: v => Config.launcher.maxShown = v
                }
            }
            SettingRow {
                label: qsTr("Item height")
                CustomSpinBox {
                    value: Config.launcher.itemHeight
                    min: 24
                    max: 100
                    onValueModified: v => Config.launcher.itemHeight = v
                }
            }
            SettingRow {
                label: qsTr("Gap")
                CustomSpinBox {
                    value: Config.launcher.gap
                    min: 0
                    max: 40
                    onValueModified: v => Config.launcher.gap = v
                }
            }
            SettingRow {
                label: qsTr("Magic symbol")
                description: qsTr("Prefix that opens module search.")
                showSeparator: false
                StyledTextField {
                    implicitWidth: 80
                    text: Config.launcher.magicSymbol
                    onEditingFinished: Config.launcher.magicSymbol = text
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

        SettingSection {
            title: qsTr("Wallpaper carousel")
            icon: "\uec45" // tabler rocket

            SettingRow {
                label: qsTr("Visible items")
                CustomSpinBox {
                    value: Config.launcher.carouselVisibleItems
                    min: 3
                    max: 9
                    step: 2
                    onValueModified: v => Config.launcher.carouselVisibleItems = v
                }
            }
            SettingRow {
                label: qsTr("Image scale")
                showSeparator: false
                CustomSpinBox {
                    value: Config.launcher.carouselImageScale
                    min: 1
                    max: 4
                    step: 0.1
                    onValueModified: v => Config.launcher.carouselImageScale = v
                }
            }
        }

        SettingSection {
            title: qsTr("Integrations")
            icon: "\uec45" // tabler rocket
            advanced: true

            SettingRow {
                label: qsTr("Giphy API key")
                description: qsTr("Used by the GIF search module.")
                showSeparator: false
                StyledTextField {
                    implicitWidth: 220
                    text: Config.launcher.giphyApiKey
                    onEditingFinished: Config.launcher.giphyApiKey = text
                    echoMode: TextInput.PasswordEchoOnEdit
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

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
