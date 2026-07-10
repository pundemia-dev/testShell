pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts
import qs.components.containers

// Full hand-written settings for the Workspaces bar widget, bound directly to
// the typed Config.bar.workspaces sub-config (the rich nested config doesn't fit
// the flat SchemaForm). Rendered inline in WidgetSettings.qml as the Workspaces
// collapsible. The per-state blocks (active / occupied / unit) reuse one inline
// component since their shape is identical.
ColumnLayout {
    id: root

    readonly property var ws: Config.bar.workspaces

    spacing: Appearance.spacing.small
    Layout.fillWidth: true

    // ── General ──────────────────────────────────────────────────────────
    SettingRow {
        label: qsTr("Workspaces shown")
        CustomSpinBox {
            value: root.ws.shown
            min: 1
            max: 20
            onValueModified: v => root.ws.shown = v
        }
    }
    SettingRow {
        label: qsTr("Spacing")
        hintText: qsTr("-1 = automatic (half the small spacing token).")
        CustomSpinBox {
            value: root.ws.spacing
            min: -1
            max: 40
            onValueModified: v => root.ws.spacing = v
        }
    }
    SettingRow {
        label: qsTr("Rounding")
        hintText: qsTr("-1 = automatic (fully rounded).")
        CustomSpinBox {
            value: root.ws.rounding
            min: -1
            max: 120
            onValueModified: v => root.ws.rounding = v
        }
    }
    SettingRow {
        label: qsTr("Per-monitor workspaces")
        StyledSwitch {
            checked: root.ws.perMonitorWorkspaces
            onToggled: root.ws.perMonitorWorkspaces = checked
        }
    }
    SettingRow {
        label: qsTr("Show window count")
        advanced: true
        StyledSwitch {
            checked: root.ws.showWindows
            onToggled: root.ws.showWindows = checked
        }
    }
    ChoiceRow {
        label: qsTr("Label capitalisation")
        advanced: true
        options: [
            { value: "preserve", label: qsTr("Preserve") },
            { value: "upper", label: qsTr("Upper") },
            { value: "lower", label: qsTr("Lower") }
        ]
        current: root.ws.capitalisation
        onChose: value => root.ws.capitalisation = value
    }
    SettingRow {
        label: qsTr("Custom numerals")
        description: qsTr("Pick a preset numeral set, or type your own comma-separated labels.")
        advanced: true
        NumeralPicker {
            value: root.ws.numerals
            onPicked: arr => root.ws.numerals = arr
        }
    }
    SettingRow {
        label: qsTr("Active indicator on special")
        advanced: true
        StyledSwitch {
            checked: root.ws.activeIndicator
            onToggled: root.ws.activeIndicator = checked
        }
    }
    SettingRow {
        label: qsTr("Special workspace icons")
        description: qsTr("JSON array, e.g. [{\"name\":\"music\",\"icon\":\"\"}].")
        advanced: true
        showSeparator: false
        TextEntry {
            implicitWidth: 220
            text: JSON.stringify(root.ws.specialWorkspaceIcons)
            placeholderText: "[]"
            onEditingFinished: {
                try {
                    root.ws.specialWorkspaceIcons = JSON.parse(text || "[]");
                } catch (e) {
                    text = JSON.stringify(root.ws.specialWorkspaceIcons);
                }
            }
        }
    }

    // ── Per-state blocks ─────────────────────────────────────────────────
    StateBlock {
        title: qsTr("Active workspace")
        cfg: root.ws.active
        withTrail: true
        showOptions: [
            { value: "slider", label: qsTr("Slider") },
            { value: "teleport", label: qsTr("Teleport") },
            { value: "", label: qsTr("Off") }
        ]
    }
    StateBlock {
        title: qsTr("Occupied workspaces")
        cfg: root.ws.occupied
        showOptions: [
            { value: "merge", label: qsTr("Merge") },
            { value: "separate", label: qsTr("Separate") },
            { value: "", label: qsTr("Off") }
        ]
    }
    StateBlock {
        title: qsTr("Unit (every slot)")
        cfg: root.ws.unit
        showOptions: [
            { value: "show", label: qsTr("On") },
            { value: "", label: qsTr("Off") }
        ]
    }

    // ── Reusable inline pieces ───────────────────────────────────────────

    // Styled single-line text entry (matches SchemaForm's string control).
    component TextEntry: StyledTextField {
        implicitWidth: 140
        padding: Appearance.padding.small
        leftPadding: Appearance.padding.medium
        rightPadding: Appearance.padding.medium
        background: StyledRect {
            radius: Appearance.rounding.small
            color: Colours.palette.surface_container_highest
        }
    }

    // A SettingRow whose control is a row of mutually-exclusive toggle chips.
    component ChoiceRow: SettingRow {
        id: choice
        property var options: []   // [{ value, label }]
        property var current
        signal chose(value: var)

        RowLayout {
            spacing: Appearance.spacing.small
            Repeater {
                model: choice.options
                delegate: ToggleButton {
                    required property var modelData
                    accent: "Primary"
                    label: modelData.label
                    toggled: choice.current === modelData.value
                    onClicked: choice.chose(modelData.value)
                }
            }
        }
    }

    // One per-state appearance block (active / occupied / unit). `cfg` is the
    // typed JsonObject sub-config; writes to its properties persist directly.
    component StateBlock: CollapsibleSection {
        id: block
        required property var cfg
        property var showOptions: []
        property bool withTrail: false

        Layout.fillWidth: true
        showBackground: true
        nested: true

        ChoiceRow {
            label: qsTr("Show")
            options: block.showOptions
            current: block.cfg.show
            onChose: value => block.cfg.show = value
        }
        SettingRow {
            visible: block.withTrail
            label: qsTr("Trail")
            StyledSwitch {
                // Only ActiveWsConfig has `trail` — the other state blocks
                // still evaluate this binding even while the row is hidden.
                checked: block.cfg.trail ?? false
                onToggled: block.cfg.trail = checked
            }
        }
        SettingRow {
            label: qsTr("Background colour")
            hintText: qsTr("Hex like #RRGGBB; empty = automatic.")
            TextEntry {
                text: block.cfg.bg
                placeholderText: qsTr("auto")
                onEditingFinished: block.cfg.bg = text
            }
        }
        SettingRow {
            label: qsTr("Label colour")
            TextEntry {
                text: block.cfg.labelColor
                placeholderText: qsTr("auto")
                onEditingFinished: block.cfg.labelColor = text
            }
        }
        SettingRow {
            label: qsTr("Label")
            advanced: true
            TextEntry {
                // Preview the typed glyph in this state's own label font (the
                // glyphs are tabler/PUA icons that won't render in the default
                // sans face) — matches Workspace.qml's fallback to tabler.
                font.family: block.cfg.labelFont || Appearance.font.family.tabler
                text: block.cfg.label
                onEditingFinished: block.cfg.label = text
            }
        }
        SettingRow {
            label: qsTr("Label font")
            advanced: true
            TextEntry {
                text: block.cfg.labelFont
                placeholderText: qsTr("auto")
                onEditingFinished: block.cfg.labelFont = text
            }
        }
        SettingRow {
            label: qsTr("Font size")
            advanced: true
            CustomSpinBox {
                value: block.cfg.fontSize
                min: -1
                max: 40
                onValueModified: v => block.cfg.fontSize = v
            }
        }
        SettingRow {
            label: qsTr("Width")
            advanced: true
            CustomSpinBox {
                value: block.cfg.width
                min: -1
                max: 200
                onValueModified: v => block.cfg.width = v
            }
        }
        SettingRow {
            label: qsTr("Height")
            advanced: true
            CustomSpinBox {
                value: block.cfg.height
                min: -1
                max: 200
                onValueModified: v => block.cfg.height = v
            }
        }
        SettingRow {
            label: qsTr("Rounding")
            advanced: true
            showSeparator: false
            CustomSpinBox {
                value: block.cfg.rounding
                min: -1
                max: 120
                onValueModified: v => block.cfg.rounding = v
            }
        }
    }
}
