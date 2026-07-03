# Input mask: bridges, resize-union holdover, slot envelope

The layershell `Drawers` window exposes its mask via the
`InputManager` Region collection. The mask defines where the
compositor delivers pointer events to the shell vs lets them pass
through to underlying windows. Every `WindowSlot` contributes the
following Region instances:

- `inputRegion` — the slot's painted rect (using `lastTargetWidth /
  lastTargetHeight` so it doesn't collapse during close animations).
- `holdoverRegion` — the **display** rect (resize-union with cursor-
  aware collapse, see below). When the slot's geometry changes while
  the envelope is engaged, the holdover holds the union of the old
  and new rects; it collapses only when the cursor enters the new
  target rect specifically OR leaves the envelope entirely.
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

Animating geometry exposes a hazard: if the slot shrinks (or shifts)
while the cursor is inside it, the `inputRegion` shrinks too and the
cursor falls outside the mask → wl_pointer.leave → hover handlers
reset → panel hides.

`WindowSlot` mitigates this with two **display rects** that lag their
live targets, identical to the resize-union semantics in
[`BorderZone`'s InteractionStrip](./border-zones.md):

- `_slotTargetRect` — live `(x, y, paintedWidth, paintedHeight)`.
  `_slotDisplayRect` — what `holdoverRegion` is bound to.
- `_slotEnvelopeRect` — stable bounding box of slot + bridges +
  edge extensions (the envelope **target**). `_envelopeDisplayRect`
  — what the envelope `Item` is sized to.

Resync rules (driven by the envelope's `HoverHandler` and `DropArea`):

- On any target change (`_slotTargetRect` or `_slotEnvelopeRect`):
  **always** expand the matching display rect to `union(old display,
  new target)`. The display never shrinks because of a resize itself
  — that path is race-prone (Qt may briefly redirect hover delivery
  when a MouseArea grabs a press during the click that triggered the
  resize, leaving `_envHovered` momentarily false and snapping the
  mask out from under a still-engaged cursor).
- When the cursor enters the new target rect specifically (detected
  via `HoverHandler.point.position` / `DropArea.onPositionChanged`,
  mapped to window-coords): collapse that display to a **buffered**
  target — `inflate(target, Config.backgrounds.resizeHoldoverMargin)`
  clipped to the current display. The buffer protects against
  accidental jitter pushing the cursor one pixel outside the freshly
  shrunk mask; the clip guarantees the buffer never extends past the
  previous bg bounds.
- When the cursor leaves the envelope entirely (`_envHovered` and
  `_envDragOver` both false): snap both displays directly to their
  targets — no buffer needed once the cursor is gone.

The mask = `inputRegion ∪ holdoverRegion ∪ bridges` for that slot.
`inputRegion` follows the live target (jumps the moment
`lastTargetWidth/Height` changes); `holdoverRegion` follows the
union'd display rect so cursor-engaged transitions stay covered.

`Component.onCompleted` seeds both display rects via `Qt.callLater`
(after first frame layout) so the initial state isn't (0, 0, 0, 0).

## Slot envelope (hover + drag tracking)

Bridges keep the **mask** continuous, but the cursor moving through
a bridge area also has to register as "still engaged with the
panel" for hover-trigger modules (e.g. stash) to keep the panel
open without timers. For that, each `WindowSlot` adds a separate
invisible **envelope Item** parented to `contentLayer` at `z=-1`,
with a `HoverHandler` + `DropArea`. The envelope is sized to
`_envelopeDisplayRect` (the resize-union display rect described
above), whose **target** (`_slotEnvelopeRect`) is the bounding box
of the stable slot rect + all non-zero bridges + the screen-edge or
prev-slot extension on the facing side. The target is stable from
the first frame because it's computed from `Math.max(paintedW/H,
lastTargetW/H, targetWrapperW/H)` rather than the live animating
size; the display rect inherits that stability and additionally
unions with the previous shape during cursor-engaged transitions.

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
| `Region` collection + mask aggregation | [`services/InputManager.qml`](../../services/InputManager.qml), [`drawers/Drawers.qml`](../../drawers/Drawers.qml) (mask block) |
| Bridges + holdover + envelope per WindowSlot | [`drawers/backgrounds/components/WindowSlot.qml`](../../drawers/backgrounds/components/WindowSlot.qml) |
| Slot state publishing (`slotRects` / `slotHover` / `slotDragOver`) | [`services/BackgroundsManager.qml`](../../services/BackgroundsManager.qml) |
| Strip resize-union (parallel concept on the BorderZone side) | [`drawers/border/BorderZone.qml`](../../drawers/border/BorderZone.qml) |
