pragma ComponentBehavior: Bound

import qs.config
import qs.modules.launcher.content
import QtQuick

// Surfaces launcher-plugin settings as standalone settings pages without
// instantiating the modules themselves: reads each unit's `settingsSchema`
// straight from its manifest (modules/launcher/plugins/<id>/<id>.plugin.qml)
// through LauncherRegistry. Drop a plugin folder in and its page appears —
// the settings UI turns each schema into a generic page via SchemaForm,
// persisting values into Config.custom[key]. See docs/development/settings.md.
//
// Bar widgets are intentionally NOT surfaced here — their schemas render
// inline as a block at the bottom of the Bar page
// (modules/bar/settings/WidgetSettings.qml), not as standalone pages.
Item {
    id: root

    // Discovers the launcher-plugin manifests. Object property — no layout cell.
    readonly property LauncherRegistry registry: LauncherRegistry {}

    // Populated SettingsSchema instances (have title/icon/key/fields).
    // Disabled plugins keep their pages hidden along with the module.
    readonly property var schemas: {
        const out = (registry.active ?? [])
            .map(m => m.settingsSchema)
            .filter(s => s && s.key);
        out.sort((a, b) => String(a.title).localeCompare(String(b.title)));
        return out;
    }

    onSchemasChanged: _seedDefaults(schemas)

    // Seed each discovered schema's defaults into Config.custom so a module
    // reading Config.getCustom(key, field, …) has values even before the
    // settings window is ever opened. One reassign so JsonAdapter persists.
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
}
