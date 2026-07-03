pragma ComponentBehavior: Bound

import Quickshell
import Qt.labs.folderlistmodel
import QtQuick

// Discovers modular AI pages without hardcoding a tab list — a direct port of
// modules/dashboard/content/DashboardRegistry.qml. Each page is a folder under
// ../pages/<id>/ shipping one `<id>.page.qml` manifest (a components/
// DashboardPage). Only the manifest is loaded (cheap — content is a Component
// that isn't instantiated until a Loader uses it); the folder name is stamped
// as the stable `id`. Ordering comes from the manifests' own `order` hints.
Item {
    id: root

    property int currentTab: 0

    // Every discovered manifest (unordered).
    property var all: []

    // Manifests to show, ordered by their `order` hint then title.
    readonly property var pages: {
        const visible = (all ?? []).filter(p => p);
        return visible.slice().sort((a, b) => {
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
            console.warn("[AiRegistry] failed:", url, c.errorString());
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
