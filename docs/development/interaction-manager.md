# InteractionManager

`utils/InteractionManager.qml` is a global Singleton that turns the
8 `BorderZone` strips into a programmable per-rail interaction
surface. Three orthogonal modes share one set of rails:

| Mode | Stack? | Trigger |
|---|---|---|
| `hover` | yes (multi-layer) | strip's `HoverHandler.hovered` becomes true, or `MouseArea.onClicked` |
| `slide` | no (one handler / rail) | `MouseArea.onPressed` inside the strip + cursor leaves the strip while pressed |
| `drop` | no (one handler / rail) | `DropArea.onEntered` (file/text drag) |

## Module registration

```qml
import qs.utils

Component.onCompleted: {
    _myRail = manager.determineRailIndex(content);
    if (_myRail >= 0) {
        const actualLayer = InteractionManager.registerHover(
            _myRail, /*layer*/ 0, "myModule",
            () => VisibilitiesManager.setVisibility(screen, "myModule", true));
        // actualLayer may differ from the requested layer if another
        // module already occupies it (auto-bump on conflict).

        InteractionManager.registerDrop(
            _myRail, "myModule",
            () => VisibilitiesManager.setVisibility(screen, "myModule", true));
    }
}

Component.onDestruction: {
    if (_myRail >= 0) {
        InteractionManager.unregisterHover(_myRail, "myModule");
        InteractionManager.unregisterDrop(_myRail, "myModule");
    }
}
```

`determineRailIndex(wrapper)` reads the wrapper's anchors; the
mapping is the same one used by `BackgroundsManager` when sorting
into rails.

## Hover stack semantics

A fresh **strip enter** (cursor was off-strip, becomes on-strip) OR
a **click** inside the strip advances the rail's counter and fires
the next handler in `hoverStacks[rail]` (sorted ascending by layer).
Stack exhaustion silently no-ops.

The counter resets to 0 on three conditions, in order of reliability:

1. `BackgroundsManager.rails[rail].length === 0` (Connections
   watcher in InteractionManager).
2. The module calls `InteractionManager.resetCounter(rail)` from
   its `onVisibilityChanged → false` handler (explicit reset).
3. Defensive reset inside `fireHover` — if the rail is empty when
   a fresh hover fires, the counter is forced to 0 before reading
   the next handler.

## Conflict resolution

`registerHover(rail, layer, name, onActivate)` returns the actually
assigned layer:

- If `(rail, layer)` is free, returns `layer` unchanged.
- If occupied, walks `layer + 1, layer + 2, …` until free (auto-bump);
  emits a `console.warn` so the conflict is visible.

`registerSlide(rail, name, onActivate)` / `registerDrop(rail, name,
onActivate)` are single-slot. A second registration overwrites the
existing handler with a `console.warn`.

## Strip state exposed to modules

In addition to the fire callbacks, `InteractionManager` publishes
two reactive dicts so modules can hold open their panels while the
strip is engaged:

```qml
property var stripHovered: ({})    // { rail: bool }
property var stripDragOver: ({})   // { rail: bool }
```

Set from `BorderZone._stripEnter` / `_stripExit` /
`_dropEnter` / `_dropExit` after their zone-level dedup counters
transition 0 ↔ 1 (a corner zone has two strips that both contribute
to the same rail).

`StashWrapper` reads these directly:
```qml
readonly property bool _stripHovered: _interactionRail >= 0
    ? (InteractionManager.stripHovered[_interactionRail] ?? false) : false
```

## Multi-screen caveat

State is global (rail-keyed maps + handlers + counters). For multi-
monitor setups, only the **last-loaded `BackgroundsManager`** is
referenced for the reset Connections, and hover handlers fire
across all monitors that have a matching rail strip. Per-screen
isolation is an open follow-up — single-screen behavior is unaffected.

## Where things live

| Concern | File |
|---|---|
| Singleton (registrations + fire + reset) | [`utils/InteractionManager.qml`](../../utils/InteractionManager.qml) |
| Strip wiring (`HoverHandler`, `MouseArea`, `DropArea`) | [`drawers/border/BorderZone.qml`](../../drawers/border/BorderZone.qml) |
| Per-screen `BackgroundsManager` reference (set from Drawers' `Component.onCompleted`) | [`drawers/Drawers.qml`](../../drawers/Drawers.qml) |
| Module-side registration example | [`modules/stash/StashWrapper.qml`](../../modules/stash/StashWrapper.qml) |
