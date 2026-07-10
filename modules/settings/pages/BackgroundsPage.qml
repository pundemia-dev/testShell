import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts
import qs.components.containers

// Config.backgrounds → backgroundsconfig/BackgroundsConfig.qml
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
            text: qsTr("Backgrounds")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("Shape")
            icon: "\uf51b" // tabler texture

            SettingRow {
                label: qsTr("Rounding")
                description: qsTr("Panel corner radius.")
                CustomSpinBox {
                    value: Config.backgrounds.rounding
                    min: 0
                    max: 60
                    onValueModified: v => Config.backgrounds.rounding = v
                }
            }

            SettingRow {
                label: qsTr("Liquid rounding")
                description: qsTr("Panels open and close as droplets: corners start fully round and relax to the set radius, and bloom back on close.")
                StyledSwitch {
                    checked: Config.backgrounds.liquidRounding
                    onToggled: Config.backgrounds.liquidRounding = checked
                }
            }

            SettingRow {
                label: qsTr("Liquid content squeeze")
                description: qsTr("Press the content into the rounded contour while panels move or open/close — concave dents at the corners.")
                enabled: Config.backgrounds.liquidRounding
                StyledSwitch {
                    checked: Config.backgrounds.liquidContentWarp
                    onToggled: Config.backgrounds.liquidContentWarp = checked
                }
            }

            SettingRow {
                label: qsTr("Capsule neck")
                description: qsTr("Fatness of the join when panels stick together (1 = thin).")
                hintText: qsTr("Multiplier on the SDF smoothing radius between two sticking panels. >1 widens the join into a capsule neck.")
                showSeparator: false
                CustomSpinBox {
                    value: Config.backgrounds.stickSmooth
                    min: 1
                    max: 4
                    step: 0.1
                    onValueModified: v => Config.backgrounds.stickSmooth = v
                }
            }
        }

        SettingSection {
            title: qsTr("Padding")
            icon: "\uf51b" // tabler texture

            SettingRow {
                label: qsTr("Left")
                CustomSpinBox {
                    value: Config.backgrounds.paddings.left
                    min: 0
                    max: 60
                    onValueModified: v => Config.backgrounds.paddings.left = v
                }
            }
            SettingRow {
                label: qsTr("Right")
                CustomSpinBox {
                    value: Config.backgrounds.paddings.right
                    min: 0
                    max: 60
                    onValueModified: v => Config.backgrounds.paddings.right = v
                }
            }
            SettingRow {
                label: qsTr("Top")
                CustomSpinBox {
                    value: Config.backgrounds.paddings.top
                    min: 0
                    max: 60
                    onValueModified: v => Config.backgrounds.paddings.top = v
                }
            }
            SettingRow {
                label: qsTr("Bottom")
                showSeparator: false
                CustomSpinBox {
                    value: Config.backgrounds.paddings.bottom
                    min: 0
                    max: 60
                    onValueModified: v => Config.backgrounds.paddings.bottom = v
                }
            }
        }

        // SDF halo / sticking internals.
        SettingSection {
            title: qsTr("SDF internals")
            icon: "\uf51b" // tabler texture
            advanced: true

            SettingRow {
                label: qsTr("Invert base rounding")
                StyledSwitch {
                    checked: Config.backgrounds.invertBaseRounding
                    onToggled: Config.backgrounds.invertBaseRounding = checked
                }
            }
            SettingRow {
                label: qsTr("Corner guard")
                CustomSpinBox {
                    value: Config.backgrounds.cornerGuard
                    min: -1
                    max: 80
                    onValueModified: v => Config.backgrounds.cornerGuard = v
                }
            }
            SettingRow {
                label: qsTr("Fade width")
                CustomSpinBox {
                    value: Config.backgrounds.fadeWidth
                    min: 0
                    max: 120
                    step: 5
                    onValueModified: v => Config.backgrounds.fadeWidth = v
                }
            }
            SettingRow {
                label: qsTr("Overlap shrink")
                CustomSpinBox {
                    value: Config.backgrounds.overlapShrink
                    min: 0
                    max: 80
                    onValueModified: v => Config.backgrounds.overlapShrink = v
                }
            }
            SettingRow {
                label: qsTr("Fade strength")
                CustomSpinBox {
                    value: Config.backgrounds.fadeStrength
                    min: 0.1
                    max: 5
                    step: 0.1
                    onValueModified: v => Config.backgrounds.fadeStrength = v
                }
            }
            SettingRow {
                label: qsTr("Resize holdover margin")
                showSeparator: false
                CustomSpinBox {
                    value: Config.backgrounds.resizeHoldoverMargin
                    min: 0
                    max: 80
                    step: 5
                    onValueModified: v => Config.backgrounds.resizeHoldoverMargin = v
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
