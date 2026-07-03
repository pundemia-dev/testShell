pragma Singleton

import Quickshell
import QtQuick
import qs.config

// Runtime hub for the in-place bar layout editor. Shared between the Settings
// window (the "enable editing" toggle + widget palette) and the live bar
// surface (jiggle, delete badges, drag/drop reorder, rubber-band grouping).
//
// State here is intentionally EPHEMERAL — it is never persisted. Only committed
// layout changes are written back to Config.bar.<seg>Layout, and those are
// reassigned wholesale (JsonAdapter only persists on identity change, same as
// the Config.custom pattern).
//
// An entry is one of:
//   { "type": "widget", "name": "Clock" }
//   { "type": "group",  "children": [ <widget entries> ] }
//   { "type": "placeholder" }            ← transient, display-only (the drop gap)
//
// A "path" addresses an entry inside a segment:
//   [i]      → top-level entry i
//   [g, c]   → child c of the group at top-level index g
Singleton {
    id: root

    // ── edit-mode state ──────────────────────────────────────────────────
    property bool editing: false

    // The payload currently being dragged: { entry, source }. `source` is
    // "palette" for a fresh widget from the Settings palette, or { seg, path }
    // for an existing entry being moved on the bar. null when nothing drags.
    property var dragPayload: null

    // Origin of an in-bar move ({ seg, path }) so the source slot can dim and
    // moveEntry knows where to pull from. null for a palette insert.
    property var draggingFrom: null

    // px the dragged item measures along the bar's long axis → the gap size.
    property real dragSize: 0

    // Active drop target. dropSeg === "" means no target / no gap shown.
    property string dropSeg: ""
    property var dropPath: []          // where the placeholder is spliced in
    property real dropSize: 0          // px the placeholder animates out to

    // "Drop onto" target: top-level index (in dropSeg) of a widget the dragged
    // widget should GROUP with (phone-folder gesture). -1 = plain insertion.
    // Set as soon as the cursor enters the widget's centre (so the target scales
    // up and the layout holds still — no insert gap to push it out from under
    // the cursor). `dropOntoReady` flips true only after the dwell delay, which
    // gates the highlight ring and the actual merge.
    property int dropOnto: -1
    property bool dropOntoReady: false

    function clearDrop() {
        dropSeg = "";
        dropPath = [];
        dropSize = 0;
        dropOnto = -1;
        dropOntoReady = false;
    }

    function endDrag() {
        dragPayload = null;
        draggingFrom = null;
        dragSize = 0;
        clearDrop();
    }

    function _pathEq(a, b) {
        if (!a || !b || a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++)
            if (a[i] !== b[i])
                return false;
        return true;
    }

    // True for the entry that is currently being dragged (so its slot dims).
    function isDragging(seg, path) {
        return !!draggingFrom && draggingFrom.seg === seg && _pathEq(draggingFrom.path, path);
    }

    // ── drag lifecycle (called from the drag sources / drop areas) ───────
    function beginEntryDrag(seg, path, entry, size) {
        if (!seg || path.some(i => i < 0) || entry === undefined || entry === null)
            return; // stale/destroyed delegate
        dragPayload = { "entry": JSON.parse(JSON.stringify(entry)), "source": { "seg": seg, "path": path.slice() } };
        draggingFrom = { "seg": seg, "path": path.slice() };
        dragSize = size;
    }

    function beginPaletteDrag(entry, size) {
        editing = true; // ensure the bar shows drop targets for the incoming widget
        dragPayload = { "entry": JSON.parse(JSON.stringify(entry)), "source": "palette" };
        draggingFrom = null;
        dragSize = size;
    }

    function setDropTarget(seg, path) {
        dropSeg = seg;
        dropPath = path.slice();
        dropSize = dragSize;
        dropOnto = -1;
        dropOntoReady = false;
    }

    // Focus a widget (top-level `index` in `seg`) as the group-with target — no
    // gap, so the layout holds still and the target stays under the cursor.
    function setGroupTarget(seg, index) {
        dropSeg = seg;
        dropOnto = index;
        dropOntoReady = false;
        dropPath = [];
        dropSize = 0;
    }

    // Promote the focused target to "ready" once the dwell delay elapses.
    function markGroupReady() {
        if (dropOnto >= 0)
            dropOntoReady = true;
    }

    // Commit the drag, called from the source's Drag.onDragFinished — i.e. once,
    // at the drag's conclusion, OUTSIDE the platform DnD nested event loop.
    // (Committing from DropArea.onDropped + Qt.callLater failed: callLater is
    // blocked by the DnD loop and only fired on the NEXT drag, so every drop
    // applied the previous drag's intent — a one-drag lag.) The DropAreas only
    // record dropSeg/dropPath during the drag; here we apply that target.
    //
    // `accepted` is true when the drop landed on one of our drop areas
    // (Qt.MoveAction); false on cancel / drop-outside.
    function finishDrag(accepted) {
        if (accepted && dropSeg !== "" && dragPayload) {
            if (dropOnto >= 0) {
                // Merge only if the dwell completed; a too-quick drop on a
                // centre does nothing (the widget returns).
                if (dropOntoReady)
                    groupOnto(draggingFrom ? draggingFrom.seg : "", draggingFrom ? draggingFrom.path : null, draggingFrom ? null : dragPayload.entry, dropSeg, dropOnto);
            } else if (draggingFrom)
                moveEntry(draggingFrom.seg, draggingFrom.path, dropSeg, dropPath);
            else if (dragPayload.entry)
                insertEntry(dropSeg, dropPath, dragPayload.entry);
        }
        endDrag();
    }

    // ── config array access ──────────────────────────────────────────────
    function layoutFor(seg) {
        if (seg === "begin")
            return Config.bar.beginLayout || [];
        if (seg === "center")
            return Config.bar.centerLayout || [];
        if (seg === "end")
            return Config.bar.endLayout || [];
        return [];
    }

    function setLayoutFor(seg, arr) {
        if (seg === "begin")
            Config.bar.beginLayout = arr;
        else if (seg === "center")
            Config.bar.centerLayout = arr;
        else if (seg === "end")
            Config.bar.endLayout = arr;
    }

    // Deep clone so splices never mutate the live config array in place.
    function _clone(seg) {
        return JSON.parse(JSON.stringify(layoutFor(seg)));
    }

    // ── display model ────────────────────────────────────────────────────
    // The Repeater models render straight from the config arrays — the drop
    // gap is produced by each slot growing its own leading/trailing space (see
    // WidgetHost), NOT by injecting a placeholder entry. Injecting one churned
    // the model every time the target moved, which destroyed the in-flight
    // drag source delegate (lost drags + crashes). Kept as a pass-through so
    // the segment call sites don't need to change.
    function displayModel(seg, baseArr) {
        return baseArr || [];
    }

    // Which BorderZone indices belong to the bar's edge (the side + its two
    // corners), so they can be suppressed while editing — otherwise their
    // hover/drop/click strips sit over the bar and steal the drag.
    function barZones() {
        const horizontal = Config.bar.orientation;
        const far = Config.bar.position;
        if (horizontal)
            return far ? [6, 5, 4] : [0, 1, 2];   // bottom : top
        return far ? [2, 3, 4] : [0, 7, 6];        // right : left
    }

    function barZoneActive(zoneIdx) {
        return editing && barZones().indexOf(zoneIdx) >= 0;
    }

    // ── mutations (all clone → splice → setLayoutFor) ────────────────────
    function insertEntry(seg, path, entry) {
        const arr = _clone(seg);
        if (path.length === 1) {
            arr.splice(Math.min(path[0], arr.length), 0, entry);
        } else {
            const g = arr[path[0]];
            if (g && g.children)
                g.children.splice(Math.min(path[1], g.children.length), 0, entry);
        }
        setLayoutFor(seg, arr);
    }

    function removeEntry(seg, path) {
        const arr = _clone(seg);
        if (path.length === 1) {
            arr.splice(path[0], 1);
        } else {
            const g = arr[path[0]];
            if (g && g.children) {
                g.children.splice(path[1], 1);
                if (g.children.length === 0)
                    arr.splice(path[0], 1); // dissolve an emptied group
            }
        }
        setLayoutFor(seg, arr);
    }

    function entryAt(seg, path) {
        const arr = layoutFor(seg);
        if (path.length === 1)
            return arr[path[0]];
        const g = arr[path[0]];
        return g && g.children ? g.children[path[1]] : undefined;
    }

    // Move an entry from one path to another. For a cross-segment move the two
    // containers are independent, so a plain remove-then-insert is exact. For a
    // same-segment move we do both on ONE working copy so every index shift is
    // accounted for — including a group dissolving when its last child leaves,
    // which removes a whole top-level slot.
    function moveEntry(fromSeg, fromPath, toSeg, toPath) {
        const src = entryAt(fromSeg, fromPath);
        if (src === undefined || src === null) {
            console.warn("BarEditManager.moveEntry: no entry at", fromSeg, JSON.stringify(fromPath));
            return;
        }
        const moved = JSON.parse(JSON.stringify(src));
        // No-op move (same container, same or adjacent index → identical result).
        if (fromSeg === toSeg && fromPath.length === toPath.length && _pathEq(fromPath, toPath))
            return;

        if (fromSeg !== toSeg) {
            removeEntry(fromSeg, fromPath);
            insertEntry(toSeg, toPath, moved);
            return;
        }

        const arr = _clone(fromSeg);
        let dissolvedAt = -1; // top-level index dropped because a group emptied

        if (fromPath.length === 1) {
            arr.splice(fromPath[0], 1);
        } else {
            const g = arr[fromPath[0]];
            if (g && g.children) {
                g.children.splice(fromPath[1], 1);
                if (g.children.length === 0) {
                    arr.splice(fromPath[0], 1);
                    dissolvedAt = fromPath[0];
                }
            }
        }

        // Adjust the destination for the removal that just happened.
        let dest = toPath.slice();
        if (fromPath.length === 1) {
            if (fromPath[0] < dest[0])
                dest[0] -= 1;
        } else {
            if (dissolvedAt >= 0 && dissolvedAt < dest[0])
                dest[0] -= 1; // the emptied group shifted later top-level slots
            else if (dissolvedAt < 0 && dest.length === 2 && dest[0] === fromPath[0] && fromPath[1] < dest[1])
                dest[1] -= 1; // same-group reorder
        }

        if (dest.length === 1) {
            arr.splice(Math.min(dest[0], arr.length), 0, moved);
        } else {
            const g = arr[dest[0]];
            if (g && g.children)
                g.children.splice(Math.min(dest[1], g.children.length), 0, moved);
            else
                arr.splice(Math.min(dest[0], arr.length), 0, moved); // target group gone
        }

        setLayoutFor(fromSeg, arr);
    }

    // Wrap the listed top-level indices (must be plain "widget" entries) into a
    // single new group at the earliest index. (Wired up in Phase 4.)
    function groupWidgets(seg, indices) {
        const idx = (indices || []).slice().sort((a, b) => a - b);
        if (idx.length < 1)
            return;
        const arr = _clone(seg);
        const children = [];
        for (const i of idx) {
            const e = arr[i];
            if (e && e.type === "widget")
                children.push(e);
        }
        if (children.length === 0)
            return;
        // Remove from the back so earlier indices stay valid.
        for (let k = idx.length - 1; k >= 0; k--) {
            if (arr[idx[k]] && arr[idx[k]].type === "widget")
                arr.splice(idx[k], 1);
        }
        arr.splice(idx[0], 0, { "type": "group", "children": children });
        setLayoutFor(seg, arr);
    }

    // Phone-folder gesture: a dragged WIDGET dropped onto the target at
    // `targetIndex` in `toSeg`. If the target is a widget → wrap both into a new
    // group; if it's a group → append the dragged widget to it. The drag source
    // is `fromSeg`/`fromPath` for an in-bar move, or `paletteEntry` (fromPath
    // null) for a fresh palette widget.
    function groupOnto(fromSeg, fromPath, paletteEntry, toSeg, targetIndex) {
        let dragged;
        if (paletteEntry) {
            dragged = JSON.parse(JSON.stringify(paletteEntry));
        } else {
            const src = entryAt(fromSeg, fromPath);
            if (src === undefined || src === null)
                return;
            dragged = JSON.parse(JSON.stringify(src));
        }
        if (!dragged || dragged.type !== "widget")
            return; // only widgets fold into a group this way

        // Cross-segment / palette: remove from source first, then edit target.
        if (paletteEntry || fromSeg !== toSeg) {
            if (!paletteEntry)
                removeEntry(fromSeg, fromPath);
            const arr = _clone(toSeg);
            _foldInto(arr, targetIndex, dragged);
            setLayoutFor(toSeg, arr);
            return;
        }

        // Same segment: remove + fold on one working copy, tracking how the
        // removal shifts the target index.
        if (fromPath.length === 1 && fromPath[0] === targetIndex)
            return; // dropped onto itself
        const arr = _clone(fromSeg);
        let t = targetIndex;
        if (fromPath.length === 1) {
            arr.splice(fromPath[0], 1);
            if (fromPath[0] < t)
                t -= 1;
        } else {
            const g = arr[fromPath[0]];
            if (g && g.children) {
                g.children.splice(fromPath[1], 1);
                if (g.children.length === 0) {
                    arr.splice(fromPath[0], 1);
                    if (fromPath[0] < t)
                        t -= 1;
                }
            }
        }
        _foldInto(arr, t, dragged);
        setLayoutFor(fromSeg, arr);
    }

    function _foldInto(arr, targetIndex, dragged) {
        const t = arr[targetIndex];
        if (!t) {
            arr.push(dragged);
            return;
        }
        if (t.type === "group")
            t.children = (t.children || []).concat([dragged]);
        else if (t.type === "widget")
            arr[targetIndex] = { "type": "group", "children": [t, dragged] };
    }
}
