pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Quickshell
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts

// Auto-generating block of per-widget settings for the Bar page. Scans the bar
// component dir for lightweight `<Name>.settings.qml` schemas (the built-in
// defaults we ship alongside our widgets, plus any third-party widget that drops
// its own) and renders each as a collapsible SchemaForm, persisting values into
// Config.custom[key]. Mirrors SettingsDiscovery, but surfaces bar widgets inline
// here instead of as standalone top-level pages. See docs/development/settings.md.
ColumnLayout {
    id: root

    // Populated SettingsSchema instances (have title/icon/key/fields).
    property var schemas: []

    spacing: Appearance.spacing.small

    function _rebuild(): void {
        const out = [];
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
                console.warn("[WidgetSettings] failed:", url, c.errorString());
            }
        }
        out.sort((a, b) => String(a.title).localeCompare(String(b.title)));
        root.schemas = out;
        _seedDefaults(out);
    }

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

    FolderListModel {
        id: fm
        folder: Qt.resolvedUrl("../../bar/content/components")
        nameFilters: ["*.settings.qml"]
        showDirs: false
        onStatusChanged: if (status === FolderListModel.Ready)
            root._rebuild()
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
