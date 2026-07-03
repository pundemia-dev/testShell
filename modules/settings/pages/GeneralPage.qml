import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts
import qs.components.containers
import qs.components.misc

// First real settings page. Doubles as the Phase-1 verification surface:
// it exercises the Advanced toggle, an inline hint, and the generic SchemaForm
// (incl. an advanced-only field). See docs/development/settings.md.
Flickable {
    id: root

    contentHeight: contentColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("General")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        StyledText {
            text: qsTr("Shell-wide preferences.")
            font.pointSize: Appearance.font.size.normal
            color: Colours.palette.on_surface_variant
            Layout.fillWidth: true
            Layout.bottomMargin: Appearance.spacing.small
        }

        // ── Settings UI ──────────────────────────────────────────────────
        SettingSection {
            title: qsTr("Settings UI")
            icon: "\ueb20" // tabler settings

            SettingRow {
                label: qsTr("Advanced mode")
                description: qsTr("Reveal every setting, including advanced sections and pages.")
                hintText: qsTr("Basic mode hides advanced controls to keep things simple. Turn this on to see everything.")
                showSeparator: false

                StyledSwitch {
                    checked: Config.general.advanced
                    onToggled: Config.general.advanced = checked
                }
            }
        }

        // ── Transparency ─────────────────────────────────────────────────
        SettingSection {
            title: qsTr("Transparency")
            icon: "" // tabler blur

            SettingRow {
                label: qsTr("Translucent panels")
                description: qsTr("Make panel backgrounds see-through so the wallpaper shows behind them.")

                StyledSwitch {
                    checked: Config.general.transparency.enabled
                    onToggled: Config.general.transparency.enabled = checked
                }
            }

            SettingRow {
                label: qsTr("Base opacity")
                description: qsTr("Opacity of base / background fills (layer 0).")
                visible: Config.general.transparency.enabled

                RowLayout {
                    spacing: Appearance.spacing.medium

                    StyledText {
                        text: Math.round(baseSlider.value * 100) + "%"
                        color: Colours.palette.on_surface_variant
                        Layout.preferredWidth: implicitWidth
                    }

                    StyledSlider {
                        id: baseSlider
                        Layout.preferredWidth: 180
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: Config.general.transparency.base
                        onInteraction: v => Config.general.transparency.base = v
                    }
                }
            }

            SettingRow {
                label: qsTr("Layers opacity")
                description: qsTr("Opacity of stacked container fills (higher layers).")
                visible: Config.general.transparency.enabled
                showSeparator: false

                RowLayout {
                    spacing: Appearance.spacing.medium

                    StyledText {
                        text: Math.round(layersSlider.value * 100) + "%"
                        color: Colours.palette.on_surface_variant
                        Layout.preferredWidth: implicitWidth
                    }

                    StyledSlider {
                        id: layersSlider
                        Layout.preferredWidth: 180
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: Config.general.transparency.layers
                        onInteraction: v => Config.general.transparency.layers = v
                    }
                }
            }

        }

        // ── Background blur (shader frosted glass) ───────────────────────
        SettingSection {
            title: qsTr("Background blur")
            icon: "" // tabler blur

            SettingRow {
                label: qsTr("Frosted glass")
                description: qsTr("Fill panels with a blurred copy of the wallpaper, rendered inside the SDF shader (follows the exact panel shape). Mutually exclusive with compositor blur.")

                StyledSwitch {
                    checked: Config.general.transparency.shaderBlur
                    onToggled: Config.general.transparency.shaderBlur = checked
                }
            }

            SettingRow {
                label: qsTr("Blur amount")
                description: qsTr("Strength of the wallpaper blur.")
                visible: Config.general.transparency.shaderBlur

                RowLayout {
                    spacing: Appearance.spacing.medium

                    StyledText {
                        text: Math.round(blurAmountSlider.value * 100) + "%"
                        color: Colours.palette.on_surface_variant
                        Layout.preferredWidth: implicitWidth
                    }

                    StyledSlider {
                        id: blurAmountSlider
                        Layout.preferredWidth: 180
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: Config.general.transparency.blurAmount
                        onInteraction: v => Config.general.transparency.blurAmount = v
                    }
                }
            }

            SettingRow {
                label: qsTr("Tint")
                description: qsTr("How much of the surface colour veils the frost. Higher = darker / more solid, lower = lighter / more wallpaper.")
                visible: Config.general.transparency.shaderBlur
                showSeparator: false

                RowLayout {
                    spacing: Appearance.spacing.medium

                    StyledText {
                        text: Math.round(blurTintSlider.value * 100) + "%"
                        color: Colours.palette.on_surface_variant
                        Layout.preferredWidth: implicitWidth
                    }

                    StyledSlider {
                        id: blurTintSlider
                        Layout.preferredWidth: 180
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: Config.general.transparency.blurTint
                        onInteraction: v => Config.general.transparency.blurTint = v
                    }
                }
            }
        }

        // ── Schema demo (Phase-1 verification) ───────────────────────────
        SettingSection {
            title: qsTr("Schema demo")
            description: qsTr("Rendered generically from a SettingsSchema; values persist in Config.custom[\"demo\"].")

            SchemaForm {
                Layout.fillWidth: true
                schema: SettingsSchema {
                    key: "demo"
                    fields: [
                        ({ key: "enabled", type: "bool", label: qsTr("Enabled"), "default": true,
                           hint: ({ text: qsTr("Toggle the demo feature.") }) }),
                        ({ key: "count", type: "int", label: qsTr("Count"), "default": 3, min: 0, max: 10 }),
                        ({ key: "name", type: "string", label: qsTr("Name"), "default": "" }),
                        ({ key: "units", type: "enum", label: qsTr("Units"), options: ["C", "F"], "default": "C",
                           hint: ({ text: qsTr("Temperature units.") }) }),
                        ({ key: "ratio", type: "real", label: qsTr("Ratio"), "default": 0.5, min: 0, max: 1, step: 0.1,
                           advanced: true })
                    ]
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
