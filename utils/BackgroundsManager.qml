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

    // Aggregated layer-shell exclusion (consumed by Exclusions.qml in Phase D).
    function reservedEdge(side) {
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
}
