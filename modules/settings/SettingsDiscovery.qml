pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import Qt.labs.folderlistmodel
import QtQuick

// Discovers third-party settings without instantiating the modules themselves:
// scans component dirs for lightweight `<Name>.settings.qml` files (each a pure
// SettingsSchema) and loads only those. The settings UI turns each schema into
// a generic page via SchemaForm. Drop a widget + its .settings.qml and its
// page appears. See docs/development/settings.md.
//
// Bar widgets are intentionally NOT scanned here — their schemas are surfaced
// inline as a block at the bottom of the Bar page (pages/WidgetSettings.qml),
// not as standalone top-level pages.
Item {
    id: root

    // Populated SettingsSchema instances (have title/icon/key/fields).
    property var schemas: []

    function _rebuild(): void {
        const out = [];
        for (const fm of [fmLauncher]) {
            const base = String(fm.folder);
            for (let i = 0; i < fm.count; i++) {
                const name = fm.get(i, "fileName");
                if (!name)
                    continue;
                const url = `${base}/${name}`;
                const c = Qt.createComponent(url);
                if (c.status === Component.Ready) {
                    const obj = c.createObject(root);
                    if (obj && obj.key)
                        out.push(obj);
                    else if (obj)
                        obj.destroy();
                } else if (c.status === Component.Error) {
                    console.warn("[SettingsDiscovery] failed:", url, c.errorString());
                }
            }
        }
        root.schemas = out;
        _seedDefaults(out);
    }

    // Seed each discovered schema's defaults into Config.custom so a third-party
    // widget reading Config.getCustom(key, field, …) has values even before the
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

    FolderListModel {
        id: fmLauncher
        folder: Qt.resolvedUrl("../launcher/content/components")
        nameFilters: ["*.settings.qml"]
        showDirs: false
        onStatusChanged: if (status === FolderListModel.Ready)
            root._rebuild()
    }
}
