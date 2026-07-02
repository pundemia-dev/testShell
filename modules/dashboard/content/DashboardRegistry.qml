pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import Qt.labs.folderlistmodel
import QtQuick

// Discovers modular dashboard pages without hardcoding a tab list. Each page is
// a folder under ../pages/<id>/ shipping one `*.page.qml` manifest (a
// components/DashboardPage). We scan pages/ for subfolders, then scan each
// subfolder for its manifest, load only the manifest (cheap — content is a
// Component that isn't instantiated until a Loader uses it), and stamp the
// folder name as the stable `id`. Mirrors modules/settings/SettingsDiscovery.
Item {
    id: root

    property int currentTab: 0

    // Every discovered manifest (unordered), keyed internally by id.
    property var all: []

    // Manifests to actually show: not disabled, ordered by Config.dashboard.order
    // (unknown pages appended by their own `order` hint then title).
    readonly property var pages: {
        const disabled = Config.dashboard.disabled ?? [];
        const order = Config.dashboard.order ?? [];
        const visible = (all ?? []).filter(p => p && !disabled.includes(p.id));
        return visible.slice().sort((a, b) => {
            const ia = order.indexOf(a.id);
            const ib = order.indexOf(b.id);
            if (ia !== -1 || ib !== -1) {
                if (ia === -1) return 1;
                if (ib === -1) return -1;
                return ia - ib;
            }
            if (a.order !== b.order) return a.order - b.order;
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
        const url = `${folderUrl}/${id}.page.qml`;
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
            console.warn("[DashboardRegistry] failed:", url, c.errorString());
        }
    }

    FolderListModel {
        id: dirs
        folder: Qt.resolvedUrl("../pages")
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
