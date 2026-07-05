pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.modules.bar.content
import Quickshell
import QtQuick
import QtQuick.Layouts

// Auto-generating block of per-widget settings for the Bar page. Reads the
// bar-widget manifests (modules/bar/widgets/<id>/<id>.widget.qml) through
// WidgetRegistry and renders each manifest's `settingsSchema` as a collapsible
// SchemaForm, persisting values into Config.custom[key]. Surfaces bar widgets
// inline here instead of as standalone top-level pages (unlike
// SettingsDiscovery). See docs/development/settings.md.
ColumnLayout {
    id: root

    // Discovers the widget manifests. Object property — no layout cell.
    readonly property WidgetRegistry registry: WidgetRegistry {}

    // Populated SettingsSchema instances (have title/icon/key/fields).
    readonly property var schemas: {
        const out = (registry.all ?? [])
            .map(m => m.settingsSchema)
            .filter(s => s && s.key);
        out.sort((a, b) => String(a.title).localeCompare(String(b.title)));
        return out;
    }

    onSchemasChanged: _seedDefaults(schemas)

    spacing: Appearance.spacing.small

    // Seed each schema's defaults into Config.custom so a widget reading
    // Config.getCustom(key, field, …) has values even before its form is shown.
    function _seedDefaults(schemas): void {
        const c = Object.assign({}, Config.custom);
        let changed = false;
        for (const s of schemas) {
            if (!s.key || !s.fields)
                continue;
            const sub = Object.assign({}, c[s.key] ?? {});
            for (const f of s.fields) {
                if (sub[f.key] === undefined && f["default"] !== undefined) {
                    sub[f.key] = f["default"];
                    changed = true;
                }
            }
            c[s.key] = sub;
        }
        if (changed)
            Config.custom = c;
    }

    StyledText {
        visible: root.schemas.length === 0
        Layout.fillWidth: true
        text: qsTr("No widgets expose settings.")
        font.pointSize: Appearance.font.size.small
        color: Colours.palette.on_surface_variant
    }

    Repeater {
        model: root.schemas

        delegate: CollapsibleSection {
            id: section
            required property var modelData

            Layout.fillWidth: true
            title: modelData.title
            showBackground: true
            nested: true

            SchemaForm {
                Layout.fillWidth: true
                schema: section.modelData
            }
        }
    }

    // Workspaces is a built-in widget with a rich, nested typed sub-config
    // (Config.bar.workspaces) that doesn't fit the flat SchemaForm, so it gets a
    // hand-written block here instead of a *.settings.qml schema.
    CollapsibleSection {
        Layout.fillWidth: true
        title: qsTr("Workspaces")
        showBackground: true
        nested: true

        WorkspacesSettings {
            Layout.fillWidth: true
        }
    }
}
