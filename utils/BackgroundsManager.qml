// BackgroundsManager.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Phase C rewrite: rails-based manager. The old slot/isolatedBackgrounds
// machinery is gone — Backgrounds.qml now consumes `rails` directly via
// per-anchor Rail instances.
//
// Lifecycle (Phase C simple form, no close-anim latching):
//   requestBackground(wrapper)  → append to rails[anchor]
//   removeBackground(wrapper)   → immediately splice from rails; Repeater
//                                 destroys the delegate, BlobRect deregisters.
QtObject {
    id: root

    // 9 rails, one per anchor position. Each entry: { wrapper, arrivalSeq }.
    property var rails: [[], [], [], [], [], [], [], [], []]
    property int _seq: 0

    // Per-arrivalSeq painted geometry of each WindowSlot. Written by
    // WindowSlot via setSlotRect on every x/y/paintedWidth/paintedHeight
    // change so BorderZones can use the actual rendered size (vs the
    // intrinsic wrapperWidth/Height which is 0 for auto-sized wrappers).
    property var slotRects: ({})

    function setSlotRect(arrivalSeq, x, y, w, h) {
        if (arrivalSeq === undefined || arrivalSeq === null) return;
        const cur = slotRects[arrivalSeq];
        if (cur && cur.x === x && cur.y === y && cur.w === w && cur.h === h) return;
        const updated = Object.assign({}, slotRects);
        updated[arrivalSeq] = { x: x, y: y, w: w, h: h };
        slotRects = updated;
    }

    function clearSlotRect(arrivalSeq) {
        if (arrivalSeq === undefined || arrivalSeq === null) return;
        if (!slotRects[arrivalSeq]) return;
        const updated = Object.assign({}, slotRects);
        delete updated[arrivalSeq];
        slotRects = updated;
    }

    function slotRectByArrivalSeq(arrivalSeq) {
        return slotRects[arrivalSeq] ?? null;
    }

    function determineRailIndex(wrapper) {
        const left = wrapper.aLeft ?? false;
        const right = wrapper.aRight ?? false;
        const top = wrapper.aTop ?? false;
        const bottom = wrapper.aBottom ?? false;
        const hCenter = wrapper.aHorizontalCenter ?? false;
        const vCenter = wrapper.aVerticalCenter ?? false;

        if (top && !vCenter) {
            if (left && !hCenter) return 0;
            if (hCenter) return 1;
            if (right && !hCenter) return 2;
        }
        if (vCenter || (!top && !bottom)) {
            if (left && !hCenter) return 3;
            if (hCenter || (!left && !right)) return 4;
            if (right && !hCenter) return 5;
        }
        if (bottom && !vCenter) {
            if (left && !hCenter) return 6;
            if (hCenter) return 7;
            if (right && !hCenter) return 8;
        }
        return 4;
    }

    // Legacy alias: callers passing (wrapper, isolate, excludeBarArea) still work
    // — the extra args are silently ignored. Phase D will clean up call sites.
    function requestBackground(wrapper /*, isolate, excludeBarArea */) {
        if (!wrapper) return;
        const i = determineRailIndex(wrapper);
        if (rails[i].find(e => e.wrapper === wrapper)) return;
        const newRails = rails.slice();
        newRails[i] = [...rails[i], { wrapper: wrapper, arrivalSeq: _seq++ }];
        rails = newRails;
    }

    function removeBackground(wrapper) {
        if (!wrapper) return;
        for (let i = 0; i < 9; i++) {
            const idx = rails[i].findIndex(e => e.wrapper === wrapper);
            if (idx >= 0) {
                const newRail = rails[i].slice();
                newRail.splice(idx, 1);
                const newRails = rails.slice();
                newRails[i] = newRail;
                rails = newRails;
                return;
            }
        }
    }

    // Aggregated layer-shell exclusion per side. Cached as readonly properties
    // so QML bindings re-evaluate whenever `rails` is reassigned. Consumers
    // (Drawers.qml, Exclusions.qml) read these directly.
    readonly property int reservedTop: _computeReservedEdge("top")
    readonly property int reservedBottom: _computeReservedEdge("bottom")
    readonly property int reservedLeft: _computeReservedEdge("left")
    readonly property int reservedRight: _computeReservedEdge("right")

    function reservedEdge(side) {
        if (side === "top") return reservedTop;
        if (side === "bottom") return reservedBottom;
        if (side === "left") return reservedLeft;
        if (side === "right") return reservedRight;
        return 0;
    }

    function _computeReservedEdge(side) {
        let sum = 0;
        for (let i = 0; i < 9; i++) {
            for (const entry of rails[i]) {
                const w = entry.wrapper;
                if (!w || !w.pinned || !w.reservesSpace) continue;
                if (side === "top" && w.aTop) {
                    sum = Math.max(sum, (w.wrapperHeight || 0) + (w.mTop || 0));
                } else if (side === "bottom" && w.aBottom) {
                    sum = Math.max(sum, (w.wrapperHeight || 0) + (w.mBottom || 0));
                } else if (side === "left" && w.aLeft) {
                    sum = Math.max(sum, (w.wrapperWidth || 0) + (w.mLeft || 0));
                } else if (side === "right" && w.aRight) {
                    sum = Math.max(sum, (w.wrapperWidth || 0) + (w.mRight || 0));
                }
            }
        }
        return sum;
    }

    // ── Zone system ─────────────────────────────────────────────────
    //
    // 8 zones (clockwise from top-left, mirroring screen edges):
    //   0 = topLeft     1 = top         2 = topRight
    //   7 = left                        3 = right
    //   6 = bottomLeft  5 = bottom      4 = bottomRight
    //
    // Rails 0..8 (9 entries) map to zones 0..7 (8 entries) — rail 4 (center)
    // is anchorless and has no zone. zoneForRail(rail) returns -1 for center.

    // rail index → zone index (or -1 for center)
    readonly property var _railToZone: [
        0,  // rail 0 topLeft     → zone 0
        1,  // rail 1 top         → zone 1
        2,  // rail 2 topRight    → zone 2
        7,  // rail 3 left        → zone 7
       -1,  // rail 4 center      → no zone
        3,  // rail 5 right       → zone 3
        6,  // rail 6 bottomLeft  → zone 6
        5,  // rail 7 bottom      → zone 5
        4   // rail 8 bottomRight → zone 4
    ]
    // zone index → rail index
    readonly property var _zoneToRail: [0, 1, 2, 5, 8, 7, 6, 3]

    function zoneForRail(railIdx) {
        if (railIdx < 0 || railIdx >= 9) return -1;
        return _railToZone[railIdx];
    }

    function railForZone(zoneIdx) {
        if (zoneIdx < 0 || zoneIdx >= 8) return -1;
        return _zoneToRail[zoneIdx];
    }

    function zoneIsCorner(zoneIdx) {
        return zoneIdx === 0 || zoneIdx === 2 || zoneIdx === 4 || zoneIdx === 6;
    }

    // Which screen edges does this zone touch? Returns object {top, right, bottom, left}.
    function zoneSides(zoneIdx) {
        switch (zoneIdx) {
            case 0: return { top: true,  right: false, bottom: false, left: true  }; // topLeft
            case 1: return { top: true,  right: false, bottom: false, left: false }; // top
            case 2: return { top: true,  right: true,  bottom: false, left: false }; // topRight
            case 3: return { top: false, right: true,  bottom: false, left: false }; // right
            case 4: return { top: false, right: true,  bottom: true,  left: false }; // bottomRight
            case 5: return { top: false, right: false, bottom: true,  left: false }; // bottom
            case 6: return { top: false, right: false, bottom: true,  left: true  }; // bottomLeft
            case 7: return { top: false, right: false, bottom: false, left: true  }; // left
        }
        return { top: false, right: false, bottom: false, left: false };
    }

    // Edge-nearest entries of a zone's rail: the layer-1 (first pinned/push) bg
    // plus all overlay bgs. Returns array of {wrapper, arrivalSeq}, sorted by
    // arrivalSeq for determinism.
    function zoneEdgeNearestEntries(zoneIdx) {
        const r = railForZone(zoneIdx);
        if (r < 0) return [];
        const rail = rails[r];
        if (!rail || rail.length === 0) return [];

        const pinned = rail.filter(e => e.wrapper && e.wrapper.pinned)
                           .sort((a, b) => a.arrivalSeq - b.arrivalSeq);
        const push = rail.filter(e => e.wrapper && !e.wrapper.pinned
                                       && (e.wrapper.mode ?? "push") !== "overlay")
                         .sort((a, b) => a.arrivalSeq - b.arrivalSeq);
        const overlay = rail.filter(e => e.wrapper && !e.wrapper.pinned
                                          && e.wrapper.mode === "overlay")
                            .sort((a, b) => a.arrivalSeq - b.arrivalSeq);

        const layer1 = pinned.length > 0 ? [pinned[0]]
                                          : (push.length > 0 ? [push[0]] : []);
        return layer1.concat(overlay);
    }

    // The "topmost" edge-nearest entry — used to derive MouseArea thickness
    // from its edge-facing margin. Preference order:
    //   1. The latest overlay (highest arrivalSeq among overlays), if any
    //   2. The layer-1 entry (pinned/push), if any
    // Returns null when the zone is empty.
    function zoneTopmostEntry(zoneIdx) {
        const entries = zoneEdgeNearestEntries(zoneIdx);
        if (entries.length === 0) return null;
        const overlays = entries.filter(e => e.wrapper && e.wrapper.mode === "overlay");
        if (overlays.length > 0) return overlays[overlays.length - 1];
        return entries[0];
    }
}
