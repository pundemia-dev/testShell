import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts
import qs.components.containers

// Config.bar → barconfig/BarConfig.qml
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Docked edge derived from the two underlying bools (orientation = horizontal
    // vs vertical; position = far vs near edge). The four-button selector reads
    // this and writes both bools back through setEdge — no new config fields.
    readonly property string barEdge: {
        const horizontal = Config.bar.orientation;
        const far = Config.bar.position;
        if (!horizontal)
            return far ? "right" : "left";
        return far ? "bottom" : "top";
    }
    function setEdge(edge: string): void {
        switch (edge) {
        case "left":
            Config.bar.orientation = false;
            Config.bar.position = false;
            break;
        case "right":
            Config.bar.orientation = false;
            Config.bar.position = true;
            break;
        case "top":
            Config.bar.orientation = true;
            Config.bar.position = false;
            break;
        case "bottom":
            Config.bar.orientation = true;
            Config.bar.position = true;
            break;
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Bar")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("Layout editing")
            icon: "\uead7" // tabler layout-navbar

            SettingRow {
                label: qsTr("Edit mode")
                description: qsTr("Jiggle widgets on the bar; delete with the \u2715 badge, drag to reorder.")
                StyledSwitch {
                    checked: BarEditManager.editing
                    onToggled: BarEditManager.editing = checked
                }
            }

            SettingRow {
                label: qsTr("Group hold delay")
                description: qsTr("Hold a dragged widget over another widget's centre this long (ms) to merge them into a group.")
                CustomSpinBox {
                    value: Config.bar.groupDwellMs
                    min: 0
                    max: 3000
                    onValueModified: v => Config.bar.groupDwellMs = v
                }
            }

            WidgetPalette {}
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
                label: qsTr("Position")
                description: qsTr("Which screen edge the bar docks to.")

                RowLayout {
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: [
                            {
                                edge: "left",
                                icon: "\uf2a9" // tabler box-align-left
                            },
                            {
                                edge: "bottom",
                                icon: "\uf2a8" // tabler box-align-bottom
                            },
                            {
                                edge: "top",
                                icon: "\uf2ab" // tabler box-align-top
                            },
                            {
                                edge: "right",
                                icon: "\uf2aa" // tabler box-align-right
                            }
                        ]

                        delegate: ToggleButton {
                            required property var modelData
                            accent: "Primary"
                            icon: modelData.icon
                            toggled: root.barEdge === modelData.edge
                            onClicked: root.setEdge(modelData.edge)
                        }
                    }
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
            icon: "\uf291" // tabler ruler-measure
            description: qsTr("Each value has an All base plus per-segment overrides (Begin / Center / End).")

            SeparatedField {
                title: qsTr("Thickness")
                data: Config.bar.thickness
                min: 0
                max: 200
                fallback: 44
                // thickness.all is read raw in BarWrapper → no Auto for it.
                presets: [
                    {
                        label: qsTr("Compact"),
                        value: 36
                    },
                    {
                        label: qsTr("Normal"),
                        value: 44
                    },
                    {
                        label: qsTr("Tall"),
                        value: 52
                    }
                ]
            }
            SeparatedField {
                title: qsTr("Padding")
                data: Config.bar.paddings
                min: 0
                max: 80
                fallback: Appearance.padding.medium
                allCanInherit: true
                presetGroup: Appearance.padding
            }
            SeparatedField {
                title: qsTr("Rounding")
                data: Config.bar.rounding
                min: 0
                max: 120
                fallback: Appearance.rounding.large
                allCanInherit: true
                presetGroup: Appearance.rounding
            }
        }

        SettingSection {
            title: qsTr("Margins")
            icon: "\uee0b" // tabler box-margin
            description: qsTr("Long side = along the bar's length; short side = toward its docked edge.")

            SeparatedField {
                title: qsTr("Long-side margin")
                data: Config.bar.longSideMargin
                min: 0
                max: 400
                fallback: Appearance.padding.small
                allCanInherit: true
                presetGroup: Appearance.padding
            }
            SeparatedField {
                title: qsTr("Short-side margin")
                data: Config.bar.shortSideMargin
                min: 0
                max: 400
                fallback: Appearance.padding.small
                allCanInherit: true
                presetGroup: Appearance.padding
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

        // Per-widget settings, discovered from each widget's `<Name>.settings.qml`
        // schema (built-in widgets we ship + any third-party widget that drops one).
        SettingSection {
            visible: widgetSettings.schemas.length > 0
            title: qsTr("Widget settings")
            icon: "\uefa5" // tabler components

            WidgetSettings {
                id: widgetSettings
                Layout.fillWidth: true
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
