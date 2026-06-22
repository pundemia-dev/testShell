import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts

// Config.border → borderconfig/BorderConfig.qml
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
            text: qsTr("Borders")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("Border chrome")
            icon: "\uea3b" // tabler border-all

            SettingRow {
                label: qsTr("Enabled")
                description: qsTr("Draw the visible border frame.")
                StyledSwitch {
                    checked: Config.border.enabled
                    onToggled: Config.border.enabled = checked
                }
            }

            SettingRow {
                label: qsTr("Thickness")
                description: qsTr("Border width in pixels.")
                CustomSpinBox {
                    value: Config.border.thickness
                    min: 0
                    max: 40
                    onValueModified: v => Config.border.thickness = v
                }
            }

            SettingRow {
                label: qsTr("Rounding")
                CustomSpinBox {
                    value: Config.border.rounding
                    min: 0
                    max: 60
                    onValueModified: v => Config.border.rounding = v
                }
            }

            SettingRow {
                label: qsTr("Fill bar area")
                description: qsTr("Extend the border across the bar zone.")
                showSeparator: false
                StyledSwitch {
                    checked: Config.border.fillBar
                    onToggled: Config.border.fillBar = checked
                }
            }
        }

        // Interaction-strip tuning — rarely touched.
        SettingSection {
            title: qsTr("Interaction strips")
            icon: "\uea3b" // tabler border-all
            advanced: true

            SettingRow {
                label: qsTr("Min mouse area")
                CustomSpinBox {
                    value: Config.border.minMouseArea
                    min: 0
                    max: 40
                    onValueModified: v => Config.border.minMouseArea = v
                }
            }

            SettingRow {
                label: qsTr("Default zone length")
                CustomSpinBox {
                    value: Config.border.defaultZoneLength
                    min: 0
                    max: 600
                    step: 10
                    onValueModified: v => Config.border.defaultZoneLength = v
                }
            }

            SettingRow {
                label: qsTr("Default strip thickness")
                CustomSpinBox {
                    value: Config.border.defaultMouseAreaThickness
                    min: 0
                    max: 60
                    onValueModified: v => Config.border.defaultMouseAreaThickness = v
                }
            }

            SettingRow {
                label: qsTr("Zone gap")
                description: qsTr("Gap kept between adjacent same-edge strips.")
                showSeparator: false
                CustomSpinBox {
                    value: Config.border.zoneGap
                    min: 0
                    max: 40
                    onValueModified: v => Config.border.zoneGap = v
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
