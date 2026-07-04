pragma ComponentBehavior: Bound

import Qt.labs.folderlistmodel
import QtQuick

// Generic discovery for intra-module extension points ("modularity inside
// modules"). Point it at a slot folder: every subfolder is one unit shipping
// a `<id>.<suffix>.qml` manifest (a PluginManifest subclass). Only manifests
// are loaded — content stays a dormant Component — and the folder name is
// stamped as the stable `id`. Drop a folder in → the unit appears; no
// hardcoded lists. Hosts bind `order`/`disabled` to their config for
// user-controlled ordering and a blocklist (discovery-first: everything found
// is active unless disabled).
Item {
    id: root

    // Slot folder to scan, e.g. Qt.resolvedUrl("../pages").
    required property url folder

    // Manifest file suffix: `<id>.<suffix>.qml` (e.g. "page", "widget").
    property string suffix: "page"

    // Host config hooks. `order` lists unit ids in display order (unknown
    // units append by their manifest `order` hint, then title); `disabled`
    // is a blocklist of ids.
    property var order: []
    property var disabled: []

    // Every discovered manifest (unordered).
    property var all: []

    // Manifests to show: not disabled, ordered.
    readonly property var active: {
        const dis = root.disabled ?? [];
        const ord = root.order ?? [];
        const visible = (all ?? []).filter(p => p && !dis.includes(p.id));
        return visible.slice().sort((a, b) => {
            const ia = ord.indexOf(a.id);
            const ib = ord.indexOf(b.id);
            if (ia !== -1 || ib !== -1) {
                if (ia === -1)
                    return 1;
                if (ib === -1)
                    return -1;
                return ia - ib;
            }
            if (a.order !== b.order)
                return a.order - b.order;
            return a.title.localeCompare(b.title);
        });
    }

    // Accumulator keyed by id so re-scans of individual folders replace cleanly.
    property var _byId: ({})

    function _rebuild(): void {
        const out = [];
        for (const k in _byId)
            if (_byId[k])
                out.push(_byId[k]);
        all = out;
    }

    function _loadManifest(folderUrl: string, id: string): void {
        const url = `${folderUrl}/${id}.${root.suffix}.qml`;
        const c = Qt.createComponent(url);
        if (c.status === Component.Ready) {
            const obj = c.createObject(root, { id });
            if (obj && obj.title) {
                _byId[id] = obj;
                _rebuild();
            } else if (obj) {
                obj.destroy();
            }
        } else if (c.status === Component.Error) {
            console.warn("[PluginRegistry]", root.folder, "failed:", url, c.errorString());
        }
    }

    FolderListModel {
        id: dirs
        folder: root.folder
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        onStatusChanged: if (status === FolderListModel.Ready) {
            for (let i = 0; i < count; i++) {
                const name = get(i, "fileName");
                if (!name)
                    continue;
                root._loadManifest(`${folder}/${name}`, name);
            }
        }
    }
}
