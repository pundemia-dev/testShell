// BackgroundsManager.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Phase C rewrite: rails-based manager. The old slot/isolatedBackgrounds
// machinery is gone — Backgrounds.qml now consumes `rails` directly via
// per-anchor Rail instances.
//
// Lifecycle (close-anim latching):
//   requestBackground(wrapper)  → append to rails[anchor]; if the wrapper's
//                                 entry is dying, REVIVE it (clear its
//                                 dyingState) so its in-flight collapse
//                                 reverses into a re-open instead of finishing.
//   removeBackground(wrapper)   → DON'T splice and DON'T touch `rails` at all.
//                                 Record the entry in `dyingState` (keyed by
//                                 arrivalSeq, stashing the last painted rect).
//                                 The WindowSlot delegate stays alive and
//                                 collapses its size to 0 (mirror of the
//                                 appear); siblings on the same rail re-pack
//                                 smoothly because they track
//                                 prevSlot.paintedWidth as it shrinks.
//   finalizeRemoval(arrivalSeq) → called by the slot once collapsed; now the
//                                 real splice happens, the Repeater destroys the
//                                 delegate, BlobRect deregisters.
//
// Entry objects ({ wrapper, arrivalSeq }) are IDENTITY-STABLE: created once in
// requestBackground and never replaced or mutated until the finalize splice.
// Rail.qml feeds them to ScriptModels, which diff by element identity — so an
// open/close/dying change touches exactly one delegate and never rebuilds the
// rail's siblings. All transient per-entry state (dying, deathRect, painted
// rect, hover, borrow stack) lives out-of-band in seq-keyed maps.
//
// mode "replace" (borrowing): requestBackground for a replace-mode wrapper
// doesn't append an entry — it picks a donor entry on the wrapper's rail
// (chain depth = wrapper.layer) and pushes onto borrowState[donorSeq].stack.
// The donor's WindowSlot morphs to the borrower and back; removeBackground
// on the borrower pops the stack. A donor closed while borrowed defers its
// dying until the stack drains (donorCloseRequested).
//
// Dying entries are excluded from layout-affecting queries (reserved-edge,
// zone interaction targets) so a closing panel releases its exclusion and stops
// catching interaction the moment it starts collapsing.
QtObject {
    id: root

    // 9 rails, one per anchor position. Each entry: { wrapper, arrivalSeq }.
    property var rails: [[], [], [], [], [], [], [], [], []]
    property int _seq: 0

    // Per-arrivalSeq dying state: arrivalSeq → { deathRect: {x,y,w,h} | null }.
    // Kept OUTSIDE the rail entries so flipping an entry into/out of dying
    // never changes its object identity (see lifecycle note above). deathRect
    // is the slot's last painted rect, seeding the collapse start size if the
    // delegate was created after the flag flipped.
    property var dyingState: ({})

    function isDying(arrivalSeq) {
        return dyingState[arrivalSeq] !== undefined;
    }

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

    // ── Per-zone strip RAW extents (along the touched edge) ──────────
    // Each BorderZone publishes its unclipped strip extent per side here so
    // same-edge neighbours can clip themselves against it (longer clipped to
    // shorter + gap). Keyed "<zoneIdx>:<side>" → {lo, hi}. Clipping always
    // reads RAW extents (never the post-clip geometry), so there is no
    // feedback loop. See drawers/border/BorderZone.qml.
    property var zoneStrips: ({})

    function publishZoneStrip(zoneIdx, side, lo, hi, thickness, hasBg) {
        const key = zoneIdx + ":" + side;
        const cur = zoneStrips[key];
        if (cur && cur.lo === lo && cur.hi === hi && cur.thickness === thickness && cur.hasBg === hasBg) return;
        const updated = Object.assign({}, zoneStrips);
        updated[key] = { lo: lo, hi: hi, thickness: thickness, hasBg: hasBg };
        zoneStrips = updated;
    }

    function zoneStripExtent(zoneIdx, side) {
        return zoneStrips[zoneIdx + ":" + side] ?? null;
    }

    // Per-arrivalSeq hover state — true while cursor is over the slot's bg
    // OR any of its bridge regions. Written by WindowSlot. Modules subscribe
    // to this for "is cursor anywhere on my slot's input region" auto-hide
    // logic (no timers — close the moment this goes false).
    property var slotHover: ({})

    function setSlotHover(arrivalSeq, hovered) {
        if (arrivalSeq === undefined || arrivalSeq === null) return;
        const cur = slotHover[arrivalSeq] ?? false;
        if (cur === hovered) return;
        const updated = Object.assign({}, slotHover);
        updated[arrivalSeq] = hovered;
        slotHover = updated;
    }

    function clearSlotHover(arrivalSeq) {
        if (arrivalSeq === undefined || arrivalSeq === null) return;
        if (slotHover[arrivalSeq] === undefined) return;
        const updated = Object.assign({}, slotHover);
        delete updated[arrivalSeq];
        slotHover = updated;
    }

    // Per-arrivalSeq drag-over state — true while a drag (file/text) is over
    // the slot's bg OR any of its bridge regions. Tracked separately from
    // slotHover so modules can distinguish "cursor is here" from "drag is
    // here" (e.g. stash's drop-zone chooser depends on drag, not hover).
    property var slotDragOver: ({})

    function setSlotDragOver(arrivalSeq, dragOver) {
        if (arrivalSeq === undefined || arrivalSeq === null) return;
        const cur = slotDragOver[arrivalSeq] ?? false;
        if (cur === dragOver) return;
        const updated = Object.assign({}, slotDragOver);
        updated[arrivalSeq] = dragOver;
        slotDragOver = updated;
    }

    function clearSlotDragOver(arrivalSeq) {
        if (arrivalSeq === undefined || arrivalSeq === null) return;
        if (slotDragOver[arrivalSeq] === undefined) return;
        const updated = Object.assign({}, slotDragOver);
        delete updated[arrivalSeq];
        slotDragOver = updated;
    }

    // ── Borrowed backgrounds (mode "replace") ────────────────────────
    // donorSeq → { stack: [{ wrapper, borrowSeq }...],  // LIFO, top = last
    //              homeRect: {x,y,w,h} | null,          // donor's painted rect at first borrow
    //              donorCloseRequested: bool }
    // Kept OUTSIDE the rail entries (same identity rule as dyingState): a
    // borrow flips only this map, the donor entry object never changes, so
    // the live WindowSlot delegate sees it as a plain property change and
    // morphs in place. While borrowed, the donor entry stays alive on its
    // rail with its intrinsic contract values — so wlr exclusion zones and
    // zone-strip queries stay frozen at the donor's footprint for free.
    // External bindings over rail queries must depend on this map too (like
    // dyingState) if they need to react to borrows.
    property var borrowState: ({})

    function _findBorrow(wrapper) {
        for (const key in borrowState) {
            const idx = borrowState[key].stack.findIndex(b => b.wrapper === wrapper);
            if (idx >= 0)
                return { donorSeq: Number(key), idx: idx };
        }
        return null;
    }

    // Non-dying entries of a rail in visual chain order (pinned → push →
    // overlay, each group by entryOrder). Depth d in this list is what a
    // replace-mode wrapper's `layer` indexes into when picking a donor.
    function _chainEntries(railIdx) {
        const dying = dyingState;
        const alive = rails[railIdx].filter(e => e.wrapper && dying[e.arrivalSeq] === undefined);
        const groups = groupEntries(alive);
        return groups.pinned.concat(groups.push, groups.overlay);
    }

    // Chain ordering inside a mode group (pinned / push / overlay): explicit
    // wrapper.layer first (lower = nearer the screen edge), arrival order as
    // the tie-breaker. Default layer 0 everywhere preserves pure-arrival
    // ordering. Shared by Rail.sortedWindows and the zone queries so the
    // geometric chain and the interaction targets never disagree.
    function entryOrder(a, b) {
        const la = a.wrapper?.layer ?? 0;
        const lb = b.wrapper?.layer ?? 0;
        return la !== lb ? la - lb : a.arrivalSeq - b.arrivalSeq;
    }

    // Split a rail slice into the three mode groups. mode "replace" entries
    // only exist on a rail as the no-donor fallback — they position like
    // overlays, so they group with them.
    function groupEntries(entries) {
        const mode = e => e.wrapper.mode ?? "push";
        return {
            pinned: entries.filter(e => e.wrapper.pinned).sort(entryOrder),
            push: entries.filter(e => !e.wrapper.pinned && mode(e) !== "overlay" && mode(e) !== "replace").sort(entryOrder),
            overlay: entries.filter(e => !e.wrapper.pinned && (mode(e) === "overlay" || mode(e) === "replace")).sort(entryOrder)
        };
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
    // Returns the assigned arrivalSeq (unique per request), or -1 if invalid.
    // Callers that want to subscribe to slotHover or slotRects later can store
    // the seq.
    function requestBackground(wrapper /*, isolate, excludeBarArea */) {
        if (!wrapper) return -1;
        // Already borrowing → same borrowSeq (idempotent, like revive).
        const curBorrow = _findBorrow(wrapper);
        if (curBorrow)
            return borrowState[curBorrow.donorSeq].stack[curBorrow.idx].borrowSeq;
        const i = determineRailIndex(wrapper);
        const existing = rails[i].find(e => e.wrapper === wrapper);
        if (existing) {
            // Re-requested while still collapsing → revive: clear the dying
            // state (the entry object itself never changed, so the delegate
            // survives) and keep the same arrivalSeq so subscriptions stay valid.
            if (isDying(existing.arrivalSeq)) {
                const updated = Object.assign({}, dyingState);
                delete updated[existing.arrivalSeq];
                dyingState = updated;
            }
            // A re-opened donor no longer wants its deferred close.
            const st = borrowState[existing.arrivalSeq];
            if (st && st.donorCloseRequested) {
                const updated = Object.assign({}, borrowState);
                updated[existing.arrivalSeq] = { stack: st.stack, homeRect: st.homeRect, donorCloseRequested: false };
                borrowState = updated;
            }
            return existing.arrivalSeq;
        }
        // mode "replace": borrow the bg of the chain entry at depth `layer`
        // on this wrapper's rail instead of opening an own bg. The donor's
        // WindowSlot morphs to this wrapper's anchors/margins/size and back.
        if ((wrapper.mode ?? "push") === "replace") {
            const chain = _chainEntries(i);
            if (chain.length > 0) {
                const depth = Math.min(Math.max(wrapper.layer ?? 0, 0), chain.length - 1);
                const donor = chain[depth];
                const seq = _seq++;
                const st = borrowState[donor.arrivalSeq];
                const updated = Object.assign({}, borrowState);
                if (st) {
                    updated[donor.arrivalSeq] = {
                        stack: [...st.stack, { wrapper: wrapper, borrowSeq: seq }],
                        homeRect: st.homeRect,
                        donorCloseRequested: st.donorCloseRequested
                    };
                } else {
                    const r = slotRects[donor.arrivalSeq] ?? null;
                    updated[donor.arrivalSeq] = {
                        stack: [{ wrapper: wrapper, borrowSeq: seq }],
                        homeRect: r ? { x: r.x, y: r.y, w: r.w, h: r.h } : null,
                        donorCloseRequested: false
                    };
                }
                borrowState = updated;
                return seq;
            }
            // Empty rail → fall through: open an own bg (groups with overlays).
        }
        const seq = _seq++;
        const newRails = rails.slice();
        newRails[i] = [...rails[i], { wrapper: wrapper, arrivalSeq: seq }];
        rails = newRails;
        return seq;
    }

    // Move an already-registered wrapper to the rail its current anchors imply,
    // atomically and WITHOUT the dying/collapse path. Used when a wrapper flips
    // edge at runtime (the bar's orientation/position): _applyBgs would mark the
    // old slot `dying` (a collapse animation that can stall, leaving a ghost bar)
    // and request a fresh one. Relocating splices the entry straight into the new
    // rail with the SAME arrivalSeq (subscriptions stay valid) — no ghost, no
    // collapse. A skipped `dying` copy in the old rail is left to finish dying.
    function relocateBackground(wrapper) {
        if (!wrapper) return;
        const target = determineRailIndex(wrapper);
        let curRail = -1, curIdx = -1;
        for (let i = 0; i < 9; i++) {
            const idx = rails[i].findIndex(e => e.wrapper === wrapper && !isDying(e.arrivalSeq));
            if (idx >= 0) { curRail = i; curIdx = idx; break; }
        }
        if (curRail < 0) return;            // not registered → nothing to move
        if (curRail === target) return;     // already on the right rail
        const entry = rails[curRail][curIdx];
        const newRails = rails.slice();
        const fromRail = rails[curRail].slice();
        fromRail.splice(curIdx, 1);
        newRails[curRail] = fromRail;
        // Same entry object — identity-stable across the move.
        newRails[target] = [...rails[target], entry];
        rails = newRails;
    }

    // Latch the wrapper's slot into a dying state instead of splicing it out.
    // Only `dyingState` changes — `rails` (and the entry object) stay untouched,
    // so no delegate is created or destroyed here. The WindowSlot collapses to 0
    // then calls finalizeRemoval.
    function removeBackground(wrapper) {
        if (!wrapper) return;
        // Borrower closing → pop it from its donor's stack (out-of-order
        // closes splice mid-stack). The slot morphs to the next stack top,
        // or home to the donor; a deferred donor close fires once the stack
        // drains.
        const b = _findBorrow(wrapper);
        if (b) {
            const st = borrowState[b.donorSeq];
            const stack = st.stack.slice();
            stack.splice(b.idx, 1);
            const updated = Object.assign({}, borrowState);
            if (stack.length > 0) {
                updated[b.donorSeq] = { stack: stack, homeRect: st.homeRect, donorCloseRequested: st.donorCloseRequested };
                borrowState = updated;
                return;
            }
            delete updated[b.donorSeq];
            borrowState = updated;
            if (st.donorCloseRequested) {
                for (let i = 0; i < 9; i++) {
                    const entry = rails[i].find(e => e.arrivalSeq === b.donorSeq);
                    if (entry) {
                        removeBackground(entry.wrapper);
                        break;
                    }
                }
            }
            return;
        }
        for (let i = 0; i < 9; i++) {
            const entry = rails[i].find(e => e.wrapper === wrapper);
            if (entry) {
                if (isDying(entry.arrivalSeq)) return; // already collapsing
                // Donor with live borrowers: its bg is out on loan — defer
                // the close until the last borrower returns it.
                const st = borrowState[entry.arrivalSeq];
                if (st && st.stack.length > 0) {
                    if (!st.donorCloseRequested) {
                        const updated = Object.assign({}, borrowState);
                        updated[entry.arrivalSeq] = { stack: st.stack, homeRect: st.homeRect, donorCloseRequested: true };
                        borrowState = updated;
                    }
                    return;
                }
                const r = slotRects[entry.arrivalSeq] ?? null;
                const updated = Object.assign({}, dyingState);
                updated[entry.arrivalSeq] = {
                    deathRect: r ? { x: r.x, y: r.y, w: r.w, h: r.h } : null
                };
                dyingState = updated;
                return;
            }
        }
    }

    // Called by a WindowSlot once its dying collapse has reached zero. Performs
    // the real splice. No-op if the entry was revived (no longer dying) or is
    // already gone, so a late call is harmless.
    function finalizeRemoval(arrivalSeq) {
        if (!isDying(arrivalSeq)) return; // revived — keep it
        for (let i = 0; i < 9; i++) {
            const idx = rails[i].findIndex(e => e.arrivalSeq === arrivalSeq);
            if (idx >= 0) {
                const newRail = rails[i].slice();
                newRail.splice(idx, 1);
                const newRails = rails.slice();
                newRails[i] = newRail;
                rails = newRails;
                break;
            }
        }
        const updated = Object.assign({}, dyingState);
        delete updated[arrivalSeq];
        dyingState = updated;
        // Safety: a donor should only die once its stack drained, but never
        // leave a stale borrow record behind the splice.
        if (borrowState[arrivalSeq] !== undefined) {
            const b = Object.assign({}, borrowState);
            delete b[arrivalSeq];
            borrowState = b;
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
        // Read `dyingState` up front so the reservedX property bindings pick it
        // up as a dependency alongside `rails` — removeBackground now flips
        // only the map, not the rails array.
        const dying = dyingState;
        let sum = 0;
        for (let i = 0; i < 9; i++) {
            for (const entry of rails[i]) {
                if (dying[entry.arrivalSeq] !== undefined) continue; // collapsing → release its exclusion now
                const w = entry.wrapper;
                if (!w || !w.pinned || !w.reservesSpace) continue;
                // A wrapper only reserves a STRIP on `side` if it has a real
                // extent along that side's perpendicular axis. A horizontal bar
                // segment sitting in a corner is still aRight/aLeft (it's the
                // right/left piece of the TOP bar) but has wrapperWidth 0 — it
                // reserves the top strip, not a side column. Counting its
                // short-side margin here would masquerade as a side reservation,
                // which wrongly trips the corner L-step (WindowSlot.isLStep) and
                // emits a spurious side exclusion zone. Require the reserving
                // dimension > 0 so only real columns/strips count.
                if (side === "top" && w.aTop && (w.wrapperHeight || 0) > 0) {
                    sum = Math.max(sum, w.wrapperHeight + (w.mTop || 0));
                } else if (side === "bottom" && w.aBottom && (w.wrapperHeight || 0) > 0) {
                    sum = Math.max(sum, w.wrapperHeight + (w.mBottom || 0));
                } else if (side === "left" && w.aLeft && (w.wrapperWidth || 0) > 0) {
                    sum = Math.max(sum, w.wrapperWidth + (w.mLeft || 0));
                } else if (side === "right" && w.aRight && (w.wrapperWidth || 0) > 0) {
                    sum = Math.max(sum, w.wrapperWidth + (w.mRight || 0));
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

        const dying = dyingState;
        const alive = rail.filter(e => e.wrapper && dying[e.arrivalSeq] === undefined);
        const groups = groupEntries(alive);

        const layer1 = groups.pinned.length > 0 ? [groups.pinned[0]]
                                                : (groups.push.length > 0 ? [groups.push[0]] : []);
        return layer1.concat(groups.overlay);
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
