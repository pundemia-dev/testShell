import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts

// Config.corners → cornersconfig/CornersConfig.qml
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
            text: qsTr("Corners")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("Screen corners")
            icon: "\ufd63" // tabler border-corner-rounded

            SettingRow {
                label: qsTr("Enabled")
                description: qsTr("Draw rounded chrome in the screen corners.")
                StyledSwitch {
                    checked: Config.corners.enabled
                    onToggled: Config.corners.enabled = checked
                }
            }

            SettingRow {
                label: qsTr("Rounding")
                description: qsTr("Corner radius in pixels.")
                CustomSpinBox {
                    value: Config.corners.rounding
                    min: 0
                    max: 80
                    onValueModified: v => Config.corners.rounding = v
                }
            }

            SettingRow {
                label: qsTr("Colour")
                description: qsTr("Any QML colour name or #hex.")
                showSeparator: false
                StyledTextField {
                    implicitWidth: 140
                    text: Config.corners.color
                    onEditingFinished: Config.corners.color = text
                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.normal
                    rightPadding: Appearance.padding.normal
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
