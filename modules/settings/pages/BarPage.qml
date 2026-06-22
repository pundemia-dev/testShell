import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts

// Config.bar → barconfig/BarConfig.qml
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Bar")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("General")
            icon: "\uead7" // tabler layout-navbar

            SettingRow {
                label: qsTr("Enabled")
                StyledSwitch {
                    checked: Config.bar.enabled
                    onToggled: Config.bar.enabled = checked
                }
            }
            SettingRow {
                label: qsTr("Auto-hide")
                description: qsTr("Reveal the bar on hover only.")
                StyledSwitch {
                    checked: Config.bar.autoHide
                    onToggled: Config.bar.autoHide = checked
                }
            }
            SettingRow {
                label: qsTr("Horizontal")
                description: qsTr("On = top/bottom bar, off = left/right bar.")
                StyledSwitch {
                    checked: Config.bar.orientation
                    onToggled: Config.bar.orientation = checked
                }
            }
            SettingRow {
                label: qsTr("Far side")
                description: qsTr("On = bottom/right edge, off = top/left edge.")
                StyledSwitch {
                    checked: Config.bar.position
                    onToggled: Config.bar.position = checked
                }
            }
            SettingRow {
                label: qsTr("Separated segments")
                description: qsTr("Split begin / center / end into separate panels.")
                showSeparator: false
                StyledSwitch {
                    checked: Config.bar.separated
                    onToggled: Config.bar.separated = checked
                }
            }
        }

        SettingSection {
            title: qsTr("Sizing")
            icon: "\uead7" // tabler layout-navbar

            SettingRow {
                label: qsTr("Thickness")
                description: qsTr("Bar thickness (all segments).")
                CustomSpinBox {
                    value: Config.bar.thickness.all ?? 44
                    min: 20
                    max: 100
                    onValueModified: v => Config.bar.thickness.all = v
                }
            }
            SettingRow {
                label: qsTr("Center thickness")
                CustomSpinBox {
                    value: Config.bar.thickness.center ?? (Config.bar.thickness.all ?? 44)
                    min: 20
                    max: 120
                    onValueModified: v => Config.bar.thickness.center = v
                }
            }
            SettingRow {
                label: qsTr("Padding")
                CustomSpinBox {
                    value: Config.bar.paddings.all ?? 8
                    min: 0
                    max: 40
                    onValueModified: v => Config.bar.paddings.all = v
                }
            }
            SettingRow {
                label: qsTr("Rounding")
                showSeparator: false
                CustomSpinBox {
                    value: Config.bar.rounding.all ?? 12
                    min: 0
                    max: 80
                    onValueModified: v => Config.bar.rounding.all = v
                }
            }
        }

        SettingSection {
            title: qsTr("Widget groups")
            icon: "\uead7" // tabler layout-navbar

            SettingRow {
                label: qsTr("Group thickness")
                CustomSpinBox {
                    value: Config.bar.group.thickness
                    min: 0
                    max: 80
                    onValueModified: v => Config.bar.group.thickness = v
                }
            }
            SettingRow {
                label: qsTr("Group padding")
                CustomSpinBox {
                    value: Config.bar.group.padding
                    min: 0
                    max: 40
                    onValueModified: v => Config.bar.group.padding = v
                }
            }
            SettingRow {
                label: qsTr("Group rounding")
                showSeparator: false
                CustomSpinBox {
                    value: Config.bar.group.rounding
                    min: 0
                    max: 60
                    onValueModified: v => Config.bar.group.rounding = v
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
