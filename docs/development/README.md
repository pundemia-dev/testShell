# Development notes

Architecture & internals docs (sibling to [`../config/`](../config/)
which targets end-user configuration).

## Pages

- [`border-zones.md`](./border-zones.md) — the 8-zone perimeter
  partition, rail ↔ zone mapping, trigger strip geometry +
  resize-union, and per-zone SDF присасывание (sink + boost +
  frame smin gated by `zoneStrength`).
- [`interaction-manager.md`](./interaction-manager.md) — global
  singleton coordinating per-rail hover / slide / drop. Hover stack
  semantics, conflict resolution (auto-bump), reset triggers,
  module registration recipe.
- [`input-mask.md`](./input-mask.md) — how the layershell input
  mask is composed: per-slot bridges, resize-union holdover for
  shrinking slots, slot envelope (HoverHandler + DropArea) for
  hover/drag tracking, and `manager.slotRects/slotHover/slotDragOver`.

## Topics that still belong here when written up

- Rails-system architecture (per-anchor rails, BlobGroup, content layer Z-order).
- Wrapper contract (the `QtObject` every module exposes to the manager).
- Caelestia.Blobs plugin internals (SDF shader, scene-graph nodes,
  uniform layout, per-zone packing).
- Niri integration and focus capture.
- Adding a new module (file layout, registration, visibility, shortcut).
- Hover-trigger + drag-trigger drawer pattern (`InteractionManager`
  + sticky-strip + `_panelHovered`/`_panelDragging`; see
  `modules/stash`).
- Three-state view orchestration in `modules/stash`
  (chooser ↔ tray ↔ device picker, gated on `_dragging` + `lsState`).
- `components/DashedRect.qml` — Canvas-based dashed border (used
  by the stash drop-zone chooser; configurable dash / gap / radius).
- LocalSend discover protocol — line format emitted by
  `scripts/localsend_discover.py` and how `DeviceUnit.qml` maps
  `deviceType` to glyphs. Receive side: `scripts/localsend_receive.py`
  (HTTPS server) + `services/LocalSend.qml` (state/coordination).
