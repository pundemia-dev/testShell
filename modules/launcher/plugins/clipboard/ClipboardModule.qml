import QtQuick
import qs.config
import Quickshell
import qs.modules.launcher.content

// Clipboard history launcher module. Lists cliphist entries as UniversalDelegate
// cards, classified per type (image thumbnail / colour swatch / url / path /
// text). Left click copies (and optionally auto-pastes); Alt-click copies the
// raw text; the right panel previews the highlighted entry.
LauncherModule {
    id: root

    hasLeftPanel: true
    hasRightPanel: false
    customRightWidth: 380

    property string query: ""
    property var selectedRecord: null
    property var _pendingRecord: null

    ClipboardService {
        id: service
    }

    ScriptModel {
        id: internalModel
    }
    listModel: internalModel

    Timer {
        id: selDebounce
        interval: 60
        onTriggered: root.selectedRecord = root._pendingRecord
    }

    Connections {
        target: service
        function onRecordsChanged() { root.rebuild(); }
    }

    function onActivated(initialQuery) {
        query = "";
        selectedRecord = null;
        // Re-fetch on every open so entries copied while closed (incl. images,
        // which don't fire clipboardTextChanged) show up without an external
        // IPC callback. Live text copies are still caught by the service watcher.
        service.refresh();
        handleInput(initialQuery ?? "");
    }

    function onDeactivated() {
        selectedRecord = null;
        hasRightPanel = false;
    }

    function handleInput(q) {
        query = (q ?? "").trim();
        rebuild();
    }

    function _matches(rec, q) {
        if (!q)
            return true;
        const needle = q.toLowerCase();
        const hay = (rec.value ?? rec.firstLine ?? rec.raw ?? "").toLowerCase();
        return hay.indexOf(needle) >= 0;
    }

    function rebuild() {
        const q = query;
        const filtered = service.records.filter(r => _matches(r, q));
        internalModel.values = filtered.map(r => root._toCard(r));

        if (filtered.length > 0) {
            selectedRecord = filtered[0];
            hasRightPanel = true;
        } else {
            selectedRecord = null;
            hasRightPanel = false;
        }
    }

    function _toCard(rec) {
        const base = {
            _rec: rec,
            onClicked: function () {
                if (rec.type === "image")
                    service.copyImage(rec, service.autoPaste);
                else
                    service.copy(rec.raw, service.autoPaste);
                root.requestClose(true);
            },
            onAltClicked: function () {
                // Alt = copy without auto-paste.
                if (rec.type === "image")
                    service.copyImage(rec, false);
                else
                    service.copy(rec.raw, false);
                root.requestClose(true);
            },
            onSelected: function () {
                root._pendingRecord = rec;
                selDebounce.restart();
            }
        };

        switch (rec.type) {
        case "image":
            return Object.assign(base, {
                header: "Image",
                text: (rec.width && rec.height ? rec.width + "×" + rec.height : "")
                    + (rec.size ? " · " + rec.size : ""),
                backgroundImage: "file://" + rec.imagePath
            });
        case "color":
            return Object.assign(base, {
                header: rec.value,
                text: rec.label,
                swatchColor: rec.hex,
                rightText: rec.label
            });
        case "url":
            return Object.assign(base, {
                leftIcon: "", // tabler link
                header: rec.host,
                text: rec.value
            });
        case "path":
            return Object.assign(base, {
                leftIcon: "", // tabler file
                header: rec.base,
                text: rec.dir
            });
        default:
            return Object.assign(base, {
                leftIcon: "", // tabler typography
                header: rec.firstLine,
                text: rec.lineCount > 1
                    ? rec.chars + " chars · " + rec.lineCount + " lines"
                    : rec.chars + " chars"
            });
        }
    }

    rightPanelComponent: Component {
        ClipboardPreviewPanel {
            mod: root
            svc: service
        }
    }
}
