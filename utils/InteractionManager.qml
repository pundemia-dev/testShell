pragma Singleton

import Quickshell
import QtQuick

// Coordinates BorderZone MouseArea events into per-rail stacks of registered
// handlers. Three independent modes:
//
//   hover  — per-rail stack of layered handlers. Each fresh onEntered (cursor
//            left the strip and came back) advances the counter and triggers
//            the next handler in the stack. Clicks inside the strip also
//            advance. The counter resets to 0 when the rail's BG-list goes
//            empty (BackgroundsManager.rails[i].length === 0).
//
//   slide  — single handler per rail. Triggered when a press inside the strip
//            transitions to a position outside the strip while still pressed.
//            No stack.
//
//   drop   — single handler per rail. Triggered when a DragEvent (file or
//            text payload) enters the strip. No stack.
//
// Rails are indexed 0..8 (same as BackgroundsManager.rails). Rail 4 (center)
// has no BorderZone and therefore no MouseArea to trigger it, but registration
// is not blocked — center handlers would just never fire.
Singleton {
    id: root

    // BackgroundsManager reference (assigned from Drawers.qml per-screen scope).
    // The connections below depend on it for the stack-reset behavior.
    property var backgroundsManager: null

    // hoverStacks[rail] = array of { layer, name, onActivate } sorted by layer asc
    property var hoverStacks: ({ 0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: [], 8: [] })
    // hoverCounters[rail] = current position in stack (0..stack.length)
    property var hoverCounters: ({ 0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0 })

    // slideHandlers[rail] = { name, onActivate } or undefined
    property var slideHandlers: ({})
    // dropHandlers[rail] = { name, onActivate } or undefined
    property var dropHandlers: ({})

    function _railValid(rail) {
        return typeof rail === "number" && rail >= 0 && rail < 9;
    }

    // ── Hover registration ──────────────────────────────────────────
    //
    // Returns the layer actually assigned (may differ from `layer` on conflict
    // due to auto-bump). Returns -1 on invalid args.
    function registerHover(rail, layer, name, onActivate) {
        if (!_railValid(rail) || typeof onActivate !== "function") return -1;
        const stack = hoverStacks[rail].slice();
        let actualLayer = layer;
        while (stack.some(h => h.layer === actualLayer)) actualLayer++;
        if (actualLayer !== layer) {
            console.warn(`InteractionManager: rail ${rail} hover layer ${layer} occupied — auto-bumped to ${actualLayer} for "${name}"`);
        }
        stack.push({ layer: actualLayer, name: name, onActivate: onActivate });
        stack.sort((a, b) => a.layer - b.layer);
        const next = Object.assign({}, hoverStacks);
        next[rail] = stack;
        hoverStacks = next;
        return actualLayer;
    }

    function unregisterHover(rail, name) {
        if (!_railValid(rail)) return;
        const stack = hoverStacks[rail].filter(h => h.name !== name);
        const next = Object.assign({}, hoverStacks);
        next[rail] = stack;
        hoverStacks = next;
    }

    // ── Slide registration (single handler per rail) ────────────────
    function registerSlide(rail, name, onActivate) {
        if (!_railValid(rail) || typeof onActivate !== "function") return;
        if (slideHandlers[rail]) {
            console.warn(`InteractionManager: rail ${rail} slide already registered by "${slideHandlers[rail].name}" — replacing with "${name}"`);
        }
        const next = Object.assign({}, slideHandlers);
        next[rail] = { name: name, onActivate: onActivate };
        slideHandlers = next;
    }

    function unregisterSlide(rail, name) {
        if (!_railValid(rail)) return;
        if (!slideHandlers[rail] || (name && slideHandlers[rail].name !== name)) return;
        const next = Object.assign({}, slideHandlers);
        delete next[rail];
        slideHandlers = next;
    }

    // ── Drop registration (single handler per rail) ─────────────────
    function registerDrop(rail, name, onActivate) {
        if (!_railValid(rail) || typeof onActivate !== "function") return;
        if (dropHandlers[rail]) {
            console.warn(`InteractionManager: rail ${rail} drop already registered by "${dropHandlers[rail].name}" — replacing with "${name}"`);
        }
        const next = Object.assign({}, dropHandlers);
        next[rail] = { name: name, onActivate: onActivate };
        dropHandlers = next;
    }

    function unregisterDrop(rail, name) {
        if (!_railValid(rail)) return;
        if (!dropHandlers[rail] || (name && dropHandlers[rail].name !== name)) return;
        const next = Object.assign({}, dropHandlers);
        delete next[rail];
        dropHandlers = next;
    }

    // ── Event firing (called from BorderZone MouseAreas) ────────────
    //
    // fireHover advances the rail's counter and triggers the next handler in
    // the stack. Called on fresh onEntered (cursor re-enters strip) and on
    // click inside the strip. Silently no-ops when the stack is exhausted.
    function fireHover(rail) {
        if (!_railValid(rail)) return;
        const stack = hoverStacks[rail];
        if (!stack || stack.length === 0) return;
        const idx = hoverCounters[rail] || 0;
        if (idx >= stack.length) return;
        const handler = stack[idx];
        const next = Object.assign({}, hoverCounters);
        next[rail] = idx + 1;
        hoverCounters = next;
        handler.onActivate();
    }

    // Click acts like a fresh onEntered: advances the stack.
    function fireClick(rail) {
        fireHover(rail);
    }

    function fireSlide(rail) {
        if (!_railValid(rail)) return;
        const handler = slideHandlers[rail];
        if (!handler) return;
        handler.onActivate();
    }

    function fireDrop(rail) {
        if (!_railValid(rail)) return;
        const handler = dropHandlers[rail];
        if (!handler) return;
        handler.onActivate();
    }

    // ── Stack reset on rail empty ───────────────────────────────────
    //
    // When all BGs of a rail close (rails[i].length === 0), reset that rail's
    // hover counter so the next onEntered fires layer 0 again.
    Connections {
        target: root.backgroundsManager
        function onRailsChanged() {
            if (!root.backgroundsManager) return;
            const rails = root.backgroundsManager.rails;
            const next = Object.assign({}, root.hoverCounters);
            let changed = false;
            for (let i = 0; i < 9; i++) {
                if (rails[i].length === 0 && next[i] > 0) {
                    next[i] = 0;
                    changed = true;
                }
            }
            if (changed) root.hoverCounters = next;
        }
    }
}
