import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts

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
        spacing: Appearance.spacing.normal

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
