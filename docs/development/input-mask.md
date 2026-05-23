# Input mask: bridges, resize-union holdover, slot envelope

The layershell `Drawers` window exposes its mask via the
`InputManager` Region collection. The mask defines where the
compositor delivers pointer events to the shell vs lets them pass
through to underlying windows. Every `WindowSlot` contributes the
following Region instances:

- `inputRegion` — the slot's painted rect (using `lastTargetWidth /
  lastTargetHeight` so it doesn't collapse during close animations).
- `holdoverRegion` — the **pre-animation** painted rect, held
  stable for `_stableHoldMs` (600 ms) after any geometry change.
- `bridgeTop / bridgeBottom / bridgeLeft / bridgeRight` — the
  margin gap on each facing side, computed per the rules below.
  Zero-sized when no gap exists on that side.

All four bridges + the holdover + the main `inputRegion` are added
with `Intersection.Subtract` so they contribute to the mask exposed
by `Drawers.qml`.

## Bridge geometry

For each `WindowSlot`, a bridge fills the **margin gap between the
slot's facing edge and its anchor**:

- **Layer-1** (the first slot on a rail, pinned or push): bridge
  extends from the slot's facing edge to the **screen edge** (so
  the cursor can travel through `mLeft/mRight/mTop/mBottom` without
  triggering wl_pointer.leave on the layershell).
- **Layer-2+** (subsequent slot on the same rail): bridge extends
  from the slot's facing edge to **prev slot's far edge**, on the
  rail's growth axis. L-step on corner rails (a layer-2 corner slot
  next to a side-reserving pinned slot) gets a lateral bridge
  instead of one aligned with the growth axis.

The "facing side" is the side of the slot that points toward its
adjacent anchor:

| Anchor | Facing side(s) |
|---|---|
| top | top |
| bottom | bottom |
| left | left |
| right | right |
| topLeft (corner) | top + left |
| topRight (corner) | top + right |
| bottomLeft (corner) | bottom + left |
| bottomRight (corner) | bottom + right |

For layer-2+, the growth-axis facing is determined by the rail:

| Rail | Growth | Facing |
|---|---|---|
| top | down | up |
| bottom | up | down |
| left | right | left |
| right | left | right |
| topLeft (L-step) | right | left |
| topRight (L-step) | left | right |
| bottomLeft (L-step) | right | left |
| bottomRight (L-step) | left | right |

Bridge thickness in the perpendicular direction = the slot's
`paintedHeight` (for horizontal bridges) or `paintedWidth` (for
vertical bridges). These animate from 0 to the target during the
open animation, so the bridge area is briefly zero-sized at open
time.

## Resize-union holdover (slot side)

Animating geometry exposes a hazard: if the slot shrinks while the
cursor is inside it (e.g. content state change shrinks the panel),
the `inputRegion` shrinks too and the cursor falls outside the
mask → wl_pointer.leave → hover handlers reset → panel hides.

`WindowSlot` mitigates this with `holdoverRegion`:

- `_currentRect` is the live (x, y, paintedWidth, paintedHeight).
- `_stableRect` is updated only after `_stableHoldMs` (600 ms) of
  no geometry change (managed by `stableTimer` which restarts on
  every `_currentRect` change).
- `holdoverRegion` is bound to `_stableRect`, so during animation
  it pins the **pre-animation** bounds while `inputRegion` follows
  the live painted size. The mask = `inputRegion ∪ holdoverRegion`
  for that slot.
- `Component.onCompleted` seeds `_stableRect` via `Qt.callLater`
  (after first frame layout) so the initial state isn't (0, 0, 0, 0).

The same idea applies independently to the **strip MouseArea** in
`BorderZone` — see [border zones doc](./border-zones.md) for
resize-union semantics there (display rect union, collapse on
"cursor entered new target" OR "cursor left union").

## Slot envelope (hover + drag tracking)

Bridges keep the **mask** continuous, but the cursor moving through
a bridge area also has to register as "still engaged with the
panel" for hover-trigger modules (e.g. stash) to keep the panel
open without timers. For that, each `WindowSlot` adds a separate
invisible **envelope Item** parented to `contentLayer` at `z=-1`,
with a `HoverHandler` + `DropArea`. Geometry: bounding box of the
stable slot rect + all non-zero bridges, plus the screen-edge or
prev-slot extension on the facing side. Stable from the first
frame because it's computed from `Math.max(paintedW/H,
lastTargetW/H, targetWrapperW/H)` rather than the live animating
size.

The envelope publishes:

```qml
manager.slotHover[arrivalSeq]    // HoverHandler.hovered
manager.slotDragOver[arrivalSeq] // DropArea.containsDrag
```

Modules subscribe by capturing the `arrivalSeq` returned from
`requestBackground()`:

```qml
property int _arrivalSeq: -1
Loader {
    active: stashVisible
    sourceComponent: Item {
        Component.onCompleted: root._arrivalSeq = root.manager.requestBackground(root.content);
        Component.onDestruction: { root.manager.removeBackground(root.content); root._arrivalSeq = -1 }
    }
}

readonly property bool _slotHovered: _arrivalSeq >= 0
    ? (manager.slotHover[_arrivalSeq] ?? false) : false
```

### Why envelope is not enough on its own

`Borders` sits at higher z than `Backgrounds.contentLayer`, so the
strip's `HoverHandler`/`DropArea` can shadow the envelope's when
the cursor is in their overlap. Modules combine the envelope state
with strip state (`InteractionManager.stripHovered/stripDragOver`)
and, for panel content, with content-side handlers
(`StashContent` calls `notePanelHover` / `notePanelDragging` from
its own HoverHandler / outer DropArea). The stash auto-hide logic
is the canonical example — see
[`modules/stash/StashWrapper.qml`](../../modules/stash/StashWrapper.qml).

## Where things live

| Concern | File |
|---|---|
| `Region` collection + mask aggregation | [`utils/InputManager.qml`](../../utils/InputManager.qml), [`drawers/Drawers.qml`](../../drawers/Drawers.qml) (mask block) |
| Bridges + holdover + envelope per WindowSlot | [`drawers/backgrounds/components/WindowSlot.qml`](../../drawers/backgrounds/components/WindowSlot.qml) |
| Slot state publishing (`slotRects` / `slotHover` / `slotDragOver`) | [`utils/BackgroundsManager.qml`](../../utils/BackgroundsManager.qml) |
| Strip resize-union (parallel concept on the BorderZone side) | [`drawers/border/BorderZone.qml`](../../drawers/border/BorderZone.qml) |
