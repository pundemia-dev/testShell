# Development notes

Architecture & internals docs (sibling to [`../config/`](../config/)
which targets end-user configuration).

Topics that belong here when written up:

- Rails-system architecture (per-anchor rails, BlobGroup, content layer Z-order).
- Wrapper contract (the `QtObject` every module exposes to the manager).
- Caelestia.Blobs plugin internals (SDF shader, scene-graph nodes).
- Niri integration and focus capture.
- Adding a new module (file layout, registration, visibility, shortcut).
- Hover-trigger + drag-trigger drawer pattern (trigger strip ↔
  `incomingDrag` ↔ inner DropAreas; see `modules/stash`).
- Three-state view orchestration in `modules/stash`
  (chooser ↔ tray ↔ device picker, gated on `_dragging` + `lsState`).
- `components/DashedRect.qml` — Canvas-based dashed border (used
  by the stash drop-zone chooser; configurable dash / gap / radius).
- LocalSend discover protocol — line format emitted by
  `scripts/localsend_discover.sh` and how `DeviceUnit.qml` maps
  `deviceType` to glyphs.

(No pages yet — add files here as design decisions get documented.)
