import QtQuick
import Quickshell
import qs.config
import qs.components.controls
import qs.modules.launcher.content

// Todo launcher module. Renders tasks in the launcher's left panel via the
// stock UniversalDelegate (checkbox = leftIcon glyph). All richer interactions
// are driven from the model-item callbacks + keyboard, so the shared delegate
// stays untouched:
//   • click-count (in-plugin, configurable windows): 1=toggle · 2=edit · 3=delete
//   • Enter (empty input) = toggle highlighted · Alt+Enter = delete highlighted
//   • typed text + Enter = create (handleExecute) · typing = live filter
//   • Shift+↑/↓ = reorder (group-clamped when auto-sort is on)
// Order + persistence live in TodoStore.
LauncherModule {
    id: root

    hasLeftPanel: true
    hasRightPanel: false

    // Glyphs (verified against the installed tabler cmap).
    readonly property string _gCircle: "\ueb2c"       // square-dashed (unchecked)
    readonly property string _gCheck: "\ueba6"       // checkbox (checked)

    readonly property bool sortEnabled: Config.getCustom("todo", "autoSort", true) ?? true

    // Click-count windows (ms): after the 1st click wait _clickDelay2 for a 2nd,
    // after the 2nd wait _clickDelay3 for a 3rd. The 3rd click acts immediately.
    readonly property int _clickDelay2: Config.getCustom("todo", "clickDelay2", 220) ?? 220
    readonly property int _clickDelay3: Config.getCustom("todo", "clickDelay3", 220) ?? 220

    property string filterQuery: ""
    property bool shiftHeld: false
    property int editingId: -1
    property int selectedId: -1

    readonly property bool _hasCompleted: (store.items ?? []).some(x => x.done)
    readonly property bool _canUndo: store._undoItem !== null

    TodoStore {
        id: store
    }

    ScriptModel {
        id: model
    }
    listModel: model

    // Any change to the persisted list → rebuild the display model.
    Connections {
        target: store
        function onItemsChanged() {
            root.rebuild();
        }
    }

    // Re-partition live when the auto-sort setting flips.
    onSortEnabledChanged: rebuild()

    // ── Display pipeline ──────────────────────────────────────────────
    // Pure: filter by substring, then (if auto-sort) stable-partition undone
    // before done. Operates on any items array so reorder can pre-compute the
    // landing index against the *new* order.
    function _displayOrderOf(arr) {
        const q = filterQuery.toLowerCase().trim();
        let a = q ? arr.filter(it => it.text.toLowerCase().indexOf(q) >= 0) : arr.slice();
        if (sortEnabled)
            a = a.filter(x => !x.done).concat(a.filter(x => x.done));
        return a;
    }
    function _displayOrder() {
        return _displayOrderOf(store.items);
    }

    function _displayIndexOfId(id) {
        const a = _displayOrder();
        for (let i = 0; i < a.length; i++)
            if (a[i].id === id)
                return i;
        return -1;
    }

    function rebuild() {
        const arr = _displayOrder();
        if (pendingSelection > arr.length - 1)
            pendingSelection = arr.length - 1;
        model.values = arr.map(it => root._toCard(it));
    }

    function _toCard(it) {
        const id = it.id;
        return {
            _id: id,
            leftIcon: it.done ? root._gCheck : root._gCircle,
            header: it.text,
            text: "",
            onClicked: function () {
                root._click(id);
            },
            onSelected: function () {
                root.selectedId = id;
            },
            onAltClicked: function () {
                root._del(id);
            }
        };
    }

    // ── Click-count dispatch ──────────────────────────────────────────
    property int _clickId: -1
    property int _clickCount: 0

    Timer {
        id: clickTimer
        onTriggered: root._dispatchClick()
    }

    function _click(id) {
        if (id !== _clickId) {
            _clickId = id;
            _clickCount = 0;
        }
        _clickCount++;
        if (_clickCount >= 3) {
            // Third click — nothing higher to wait for, dispatch delete now.
            clickTimer.stop();
            _dispatchClick();
            return;
        }
        // Wait for the next click: after the 1st a _clickDelay2 window for a 2nd,
        // after the 2nd a _clickDelay3 window for a 3rd.
        clickTimer.interval = _clickCount === 1 ? _clickDelay2 : _clickDelay3;
        clickTimer.restart();
    }

    function _dispatchClick() {
        const id = _clickId;
        const n = _clickCount;
        _clickCount = 0;
        if (id < 0)
            return;
        if (n === 1)
            _toggle(id);
        else if (n === 2)
            beginEdit(id);
        else
            _del(id);
    }

    // ── Actions ───────────────────────────────────────────────────────
    function _toggle(id) {
        // Keep the highlight on the same *row* (position), so with auto-sort on
        // a completed task drops away and the next task slides under the cursor.
        pendingSelection = _displayIndexOfId(id);
        store.toggle(id);
    }

    function _del(id) {
        pendingSelection = _displayIndexOfId(id);
        store.remove(id);
    }

    function beginEdit(id) {
        if (id < 0)
            return;
        editingId = id;
        requestSetInput(store.textOf(id));
    }

    // ── Reorder (Shift+↑/↓) ───────────────────────────────────────────
    function _reorder(dir) {
        const id = selectedId;
        if (id < 0)
            return;
        const disp = _displayOrder();
        let from = -1;
        for (let i = 0; i < disp.length; i++)
            if (disp[i].id === id) {
                from = i;
                break;
            }
        if (from < 0)
            return;
        const to = from + dir;
        if (to < 0 || to >= disp.length)
            return;
        // Group boundary: with auto-sort on, don't move across done/undone.
        if (sortEnabled && disp[to].done !== disp[from].done)
            return;

        const moved = disp[from];
        const neighbour = disp[to];
        let arr = store.items.filter(x => x.id !== id);
        let ni = -1;
        for (let i = 0; i < arr.length; i++)
            if (arr[i].id === neighbour.id) {
                ni = i;
                break;
            }
        const insertAt = dir > 0 ? ni + 1 : ni;
        arr = arr.slice(0, insertAt).concat([moved], arr.slice(insertAt));

        // Highlight follows the moved item to its new display index.
        const newDisp = _displayOrderOf(arr);
        for (let i = 0; i < newDisp.length; i++)
            if (newDisp[i].id === id) {
                pendingSelection = i;
                break;
            }

        store.setItems(arr);
    }

    // ── Navigation (from RowInput ↑/↓, + Shift) ──────────────────────
    function navigateUp() {
        if (shiftHeld && !filterQuery.trim())
            _reorder(-1);
        else
            defaultNavigateUp();
    }
    function navigateDown() {
        if (shiftHeld && !filterQuery.trim())
            _reorder(1);
        else
            defaultNavigateDown();
    }

    function onModifierPressed(key) {
        if (key === Qt.Key_Shift)
            shiftHeld = true;
    }
    function onModifierReleased(key) {
        if (key === Qt.Key_Shift)
            shiftHeld = false;
    }

    // ── Lifecycle / Enter ─────────────────────────────────────────────
    function onActivated(initialQuery) {
        editingId = -1;
        shiftHeld = false;
        filterQuery = (initialQuery ?? "").trim();
        selectedId = -1;
        rebuild();
    }

    function onDeactivated() {
        editingId = -1;
        filterQuery = "";
        shiftHeld = false;
    }

    function handleInput(q) {
        if (editingId >= 0)
            return;             // editing: RowInput text is the edit buffer
        filterQuery = q ?? "";
        rebuild();
    }

    // First shot at Enter (before the host triggers the highlighted row):
    //  • editing → commit and consume;
    //  • non-empty text → create and consume;
    //  • empty text → return false so Enter toggles / Alt+Enter deletes the row.
    function handleExecute(query, isAlt) {
        if (editingId >= 0) {
            store.setText(editingId, query);   // empty text deletes the task
            editingId = -1;
            filterQuery = "";
            requestSetInput("");
            rebuild();
            return true;
        }
        const t = (query ?? "").trim();
        if (t) {
            filterQuery = "";
            const id = store.add(t);
            requestSetInput("");
            pendingSelection = _displayIndexOfId(id);
            rebuild();
            return true;
        }
        return false;
    }

    // ── Input extension: undo (after a delete) + clear-completed ──────
    inputExtensionComponent: Component {
        Row {
            spacing: Appearance.spacing.small

            IconButton {
                visible: root._canUndo
                icon: ""                 // arrow-back-up
                type: IconButton.Tonal
                onClicked: store.undo()
            }
            IconButton {
                visible: root._hasCompleted
                icon: ""                 // trash (clear completed)
                type: IconButton.Tonal
                onClicked: store.clearCompleted()
            }
        }
    }
}
