pragma Singleton

import Quickshell
import QtQuick

// Registry + arbiter for popout handles. Widget-facing API: a PopoutHandle
// registers itself, reports hover changes, and this singleton computes which
// handle is "active" per (screen, edge). The per-screen PopoutsManager reads
// `activeMap` to drive the actual background.
//
// Active = the highest-priority hovered handle that currently HAS content
// (handles with no popoutContent / not contentReady — e.g. an empty tray that
// still occupies space — never become active, so they don't summon an empty
// popout). On ties, the most-recently-registered wins (so a sub-element handle
// registered after its parent wins when both are hovered).
Singleton {
    id: root

    // All registered handles (plain array; reactivity is driven explicitly via
    // _recompute → activeMap reassignment, so we don't depend on array identity).
    property var _handles: []

    // "<screenName>|<edge>" → active PopoutHandle (or absent). Reassigned as a
    // new object on every change so QML bindings re-evaluate.
    property var activeMap: ({})

    function _key(screen, edge) {
        return (screen ? screen.name : "?") + "|" + edge;
    }

    function register(handle) {
        if (_handles.indexOf(handle) < 0)
            _handles.push(handle);
        _recompute(handle.screen, handle.edge);
    }

    function unregister(handle) {
        const i = _handles.indexOf(handle);
        if (i >= 0)
            _handles.splice(i, 1);
        _recompute(handle.screen, handle.edge);
    }

    // Called by a handle whenever its hover / hasContent state changes.
    function refresh(handle) {
        _recompute(handle.screen, handle.edge);
    }

    function activeFor(screen, edge) {
        return activeMap[_key(screen, edge)] ?? null;
    }

    function _recompute(screen, edge) {
        const k = _key(screen, edge);
        let best = null;
        let bestIdx = -1;
        for (let i = 0; i < _handles.length; i++) {
            const h = _handles[i];
            if (!h || h.screen !== screen || h.edge !== edge)
                continue;
            if (!h.hovering)
                continue;
            // hovering already folds in hasContent (see PopoutHandle), but be
            // defensive in case a caller drives it directly.
            if (!h.hasContent)
                continue;
            if (!best || h.priority > best.priority || (h.priority === best.priority && i >= bestIdx)) {
                best = h;
                bestIdx = i;
            }
        }
        const m = Object.assign({}, activeMap);
        if (best)
            m[k] = best;
        else
            delete m[k];
        activeMap = m;
    }
}
