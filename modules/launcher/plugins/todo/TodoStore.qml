pragma ComponentBehavior: Bound

import qs.services
import Quickshell.Io
import QtQuick

// Persistence + mutation backend for the todo launcher plugin. Non-singleton
// (only the launcher consumes it) — instantiated inside TodoModule. Holds the
// task list as the single source of truth in creation/manual order and writes
// it to `${Paths.state}/todos.json` (debounced). Each item:
//   { id: <int, monotonic>, text: <string>, done: <bool>, created: <ms epoch> }
QtObject {
    id: root

    // Source of truth. Kept in manual/creation order; only an explicit reorder
    // mutates the order, toggling `done` never moves an item here.
    property var items: []

    // Guards the save timer until the initial load lands — otherwise the async
    // FileView load races an early onItemsChanged and clobbers todos.json with
    // an empty list on every startup (see the Notifs.qml pattern).
    property bool loaded: false

    property int _nextId: 1

    // ── Undo (soft delete) ────────────────────────────────────────────
    property var _undoItem: null
    property int _undoIndex: -1

    onItemsChanged: if (loaded) saveTimer.restart()

    function _find(id) {
        for (let i = 0; i < items.length; i++)
            if (items[i].id === id)
                return i;
        return -1;
    }

    function textOf(id) {
        const i = _find(id);
        return i >= 0 ? items[i].text : "";
    }

    function doneOf(id) {
        const i = _find(id);
        return i >= 0 ? items[i].done : false;
    }

    // ── Mutations (each reassigns `items` → triggers save) ─────────────
    function add(text) {
        const t = (text ?? "").trim();
        if (!t)
            return -1;
        const id = _nextId++;
        items = items.concat({
            id,
            text: t,
            done: false,
            created: Date.now()
        });
        return id;
    }

    function setText(id, text) {
        const t = (text ?? "").trim();
        const i = _find(id);
        if (i < 0)
            return;
        if (!t) {
            // Empty edit = delete the task.
            remove(id);
            return;
        }
        const next = items.slice();
        next[i] = Object.assign({}, next[i], { text: t });
        items = next;
    }

    function toggle(id) {
        const i = _find(id);
        if (i < 0)
            return;
        const next = items.slice();
        next[i] = Object.assign({}, next[i], { done: !next[i].done });
        items = next;
    }

    function remove(id) {
        const i = _find(id);
        if (i < 0)
            return;
        _undoItem = items[i];
        _undoIndex = i;
        undoTimer.restart();
        items = items.slice(0, i).concat(items.slice(i + 1));
    }

    function undo() {
        if (!_undoItem)
            return;
        const at = Math.max(0, Math.min(_undoIndex, items.length));
        items = items.slice(0, at).concat([_undoItem], items.slice(at));
        _undoItem = null;
        _undoIndex = -1;
        undoTimer.stop();
    }

    function clearCompleted() {
        items = items.filter(x => !x.done);
    }

    // Replace the whole ordered list (used by reorder).
    function setItems(arr) {
        items = arr;
    }

    property Timer _undoTimer: Timer {
        id: undoTimer
        interval: 5000
        onTriggered: {
            root._undoItem = null;
            root._undoIndex = -1;
        }
    }

    property Timer _saveTimer: Timer {
        id: saveTimer
        interval: 500
        onTriggered: storage.setText(JSON.stringify(root.items))
    }

    property FileView _storage: FileView {
        id: storage
        path: `${Paths.state}/todos.json`
        onLoaded: {
            let data = [];
            try {
                data = JSON.parse(text());
            } catch (e) {
                data = [];
            }
            if (!Array.isArray(data))
                data = [];
            let maxId = 0;
            for (const it of data)
                if (typeof it.id === "number" && it.id > maxId)
                    maxId = it.id;
            root._nextId = maxId + 1;
            root.items = data;
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                setText("[]");
            }
        }
    }
}
