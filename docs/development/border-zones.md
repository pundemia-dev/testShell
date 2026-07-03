# Border zones & per-zone SDF присасывание

The shell partitions the layershell perimeter into **8 logical zones**
(4 corners + 4 sides) plus a "no zone" (-1) for center-rail bgs.
Every zone has independent control over:

- The visual trigger strip rendered at the screen edge (geometry +
  hover/click/slide/drop wiring → `InteractionManager`).
- The per-zone присасывание (SDF sticking) strength used by the
  shader.

## Architecture overview

```
Drawers (WlrLayershell)
├── Border                   ← visible chrome (StyledRect + mask),
│                                FIRST child → lowest z (below content)
├── Backgrounds
│   ├── BlobGroup (shared SDF compositor)
│   ├── bgRenderHost (layer.enabled FBO)
│   │   ├── BlobInvertedRect  ← the screen-edge frame, with
│   │   │                         per-zone zoneRoundings; inner cutout
│   │   │                         inset to the border's inner edge
│   │   └── Repeater of 9 Rails → WindowSlots
│   └── contentLayer (z=100)
│       └── per-slot envelope Items (HoverHandler + DropArea)
└── Borders                   ← 8 BorderZone INPUT strips only (last/topmost)
    └── Repeater (model: 8)
        └── BorderZone        ← 1 (side) or 2 (corner) InteractionStrips
```

The visible `Border` chrome was moved OUT of `Borders` to the bottom
of the z-stack (first child of `Drawers`) so it no longer covers the
content of `pinned`/`overlay` panels sitting at `edge=0`. `Borders`
now holds only the 8 invisible `BorderZone` interaction strips, still
instantiated last so they stay topmost for hover/click/slide/drop.

The single `BlobInvertedRect` inside `Backgrounds.bgRenderHost`
replaces the legacy `RailBorder.qml` (deleted) and exposes 8
`zoneRoundings` to the shader. Its inner cutout is **inset to the
visible border's inner edge** (`_frameInset*` in `Backgrounds.qml`,
mirroring `Border.qml`'s mask / `fillBar`), so bgs присасываются to
the border edge, not the bare screen edge.

## Zone indexing

Clockwise from top-left:

```
0 topLeft     1 top         2 topRight
7 left                      3 right
6 bottomLeft  5 bottom      4 bottomRight
```

Rail ↔ zone mapping (rail 4 = center has no zone, returns -1):

| Rail | Anchor | Zone |
|---|---|---|
| 0 | topLeft | 0 |
| 1 | top | 1 |
| 2 | topRight | 2 |
| 3 | left | 7 |
| 4 | center | — |
| 5 | right | 3 |
| 6 | bottomLeft | 6 |
| 7 | bottom | 5 |
| 8 | bottomRight | 4 |

See `BackgroundsManager.zoneForRail(rail)` / `railForZone(zone)` /
`zoneSides(zone)` / `zoneEdgeNearestEntries(zone)` /
`zoneTopmostEntry(zone)`.

## Trigger strip geometry

Each `BorderZone` reads its rail's edge-nearest bgs (layer-1 +
overlays — see `BackgroundsManager.zoneEdgeNearestEntries`) and
projects their union onto the touched edge. The strip:

- **Length** along the edge = projection extent (`xMax - xMin` for
  top/bottom, `yMax - yMin` for left/right); when empty, falls back
  to `Config.border.defaultZoneLength`. Empty corner zones anchor
  at the corner; empty side zones center on the edge.
- **Thickness** perpendicular to edge (`_stripThickness`), with
  `def = Config.border.defaultMouseAreaThickness`:
  - topmost bg is **pinned or overlay** → `facingMargin + def` (drops the
    border thickness, since both sit flush at `edge=0` under the border —
    adding `Config.border.thickness` would push the strip onto them);
  - **push** → `facingMargin + Config.border.thickness + def`;
  - **empty** zone next to a real bg → **inherits** that neighbour's raw
    thickness (uniform band, no bulge). For a **corner** zone both edges
    are considered: each of its two strips also looks at the bg on the
    **perpendicular** edge (a full-height side bar reaching the corner
    occupies both strips' territory), so the whole corner stays flush;
  - empty zone with no real neighbour on either edge →
    `Config.border.thickness + def`.

  `def` is always an additive base band (not a fallback), and
  `facingMargin` is `0` when the zone is empty. The inheritance reads the
  same published `zoneStrips` data as the length clipping (each zone
  publishes its RAW per-side `{lo, hi, thickness, hasBg}`); real zones
  never read empty ones, so there is no feedback loop.

Per-slot live painted rects are read from
`BackgroundsManager.slotRects[arrivalSeq]` (published by
`WindowSlot`), so projection follows the actual rendered geometry
of auto-sized content.

## Resize-union for strips

When a bg in a zone resizes (e.g. SDF physics shrinks it), the
strip's target geometry changes. To prevent the cursor from falling
out of a shrinking strip and triggering hover-close on the open
panel, `InteractionStrip` holds a separate **display rect**:

- While `strip_hover.hovered || strip_drop.containsDrag`, the
  display rect expands to `union(previousDisplay, newTarget)` on
  every target change.
- The display rect collapses back to the live target when **either**:
  - the cursor (or drag) crosses into the new target rect
    specifically (subset check via `point.position` in MouseArea-local
    coords), OR
  - the cursor/drag leaves the display rect entirely
    (`onContainsMouseChanged → false`, `onContainsDragChanged →
    false`).

Same logic the user spec calls for: "старый mousearea пропадает
только когда курсор либо вышел из union, либо нашёл новый
mousearea".

## Per-zone присасывание (shader)

`BlobInvertedRect` exposes `zoneRoundings: QList<qreal>` (length 8,
padded with 0). `BlobRect` exposes `zoneIndex: int` (default -1).
Both are packed into the uniform block (`zoneRoundingsLow/High`
vec4 pair; rect's `zoneIndex` as float in the unused `rectData[i*5+3].z`
slot).

`zoneStrength(zi)` in the fragment shader returns:
- `0.0` if `zi < 0` (no zone — bgs that didn't get assigned, plus
  center-rail bgs by construction).
- `zoneRoundings[zi]` for 0..7.
- `0.0` otherwise.

The strength multiplies into **three independent effects**, each
of which would otherwise cause visual sticking:

1. **Per-rect SDF boost scale** (lines ~99-140 of `blob.frag`).
   Gated by `if (hasInverted != 0 && zs > 0.0)`. With `zs == 0`,
   the rect's SDF is not stretched toward the frame, and no
   apparent compression at the edge.
2. **Sink loop** (lines ~187-228). Each rect contributes a sink
   that pulls the frame's `dInner` toward it. `sinkValue` is
   multiplied by `zs`, so zone-disabled bgs contribute nothing.
3. **Final `smin` with frame** (lines ~230-260). The winning
   rect's `winnerZs` decides whether the merged SDF blends with
   the frame (`smin`) or just takes the global min (no blend).
   Pixels owned by zone-disabled rects don't visually merge with
   the frame contour.

CPU-side mirror (`BlobShape::updatePolish` cornerRadii adjustment):
the per-rect corner radius reduction toward the frame's inner
boundary is also gated by `zs > 0.0f`. Bgs in disabled zones keep
their full corner radius regardless of proximity to the frame.

### Per-window `sticks` gating + capsule bridge

Orthogonal to the per-zone strength, each `BlobRect` carries a
`sticks` bool (default `true`), packed into the spare
`rectData[i*5+3].w` slot (no uniform-buffer size change). A new scalar
uniform `stickSmooth` (from `Config.backgrounds.stickSmooth`, the
former `pad0` slot) controls the neck fatness.

In `blob.frag`:

- **Frame effects** — `sticks` is folded into the zone strength
  (`zs *= st`) in both the boost (Phase 1) and sink loops, and into
  `winnerZs` for the final frame `smin`. So `sticks: false` zeroes all
  three frame effects → no "magnet" corner-shrink, natural contour.
- **Inter-rect merge** (Phase 3 pairwise `smin`) — for each pair the
  two `sticks` flags are read: if **either** is `0`, the pair is
  skipped (plain `min`, no merge) → a floating panel keeps its own
  clean rounded shape. If **both** stick, the blend radius is widened
  to `kPair = smoothFactor * stickSmooth`, turning the bridge across a
  gap into a tight capsule neck instead of a thin pinch.

See [`config/backgrounds.md`](../config/backgrounds.md#присасывание-sticking)
for the user-facing knobs.

## Slot envelope (hover/drag in contentLayer)

Each `WindowSlot` adds an invisible **envelope Item** parented to
`contentLayer` at `z=-1`, with a `HoverHandler` + `DropArea`. Its
geometry is the bounding box of:

- The slot's stable rect, computed from
  `Math.max(paintedWidth, lastTargetWidth, targetWrapperWidth)`
  and the matching ownX/ownY formula for the wrapper's anchor —
  so the envelope is fully sized **from the first frame**, even
  before the open animation finishes.
- The 4 bridge regions (`_bridgeTop/Bottom/Left/RightRect`).
- For layer-1: expanded toward the relevant screen edge(s).
- For layer-2+: expanded toward the prev slot's rect.

The envelope publishes:
- `manager.setSlotHover(arrivalSeq, hovered)` ← `HoverHandler.hovered`.
- `manager.setSlotDragOver(arrivalSeq, containsDrag)` ←
  `DropArea.containsDrag`.

Note: because `Border`s sits at higher z than `contentLayer`, the
strip's `HoverHandler` and `DropArea` can shadow the envelope's
when both are at the same cursor position (Qt's pointer event
delivery routes drag events to the topmost DropArea). This is why
`StashContent`'s own `HoverHandler` is also consulted via
`notePanelHover` / `notePanelDragging` callbacks — that signal
fires reliably because the panel is the topmost interactive Item
when the cursor is on the bg painted rect.

## Where things live

| Concern | File |
|---|---|
| Config schema (8 zone roundings, defaults) | [`config/borderconfig/BorderConfig.qml`](../../config/borderconfig/BorderConfig.qml) |
| Orchestrator (8 BorderZone input strips only) | [`drawers/border/Borders.qml`](../../drawers/border/Borders.qml) |
| Visible chrome (bottom of z-stack, in Drawers) | [`drawers/border/Border.qml`](../../drawers/border/Border.qml), [`drawers/Drawers.qml`](../../drawers/Drawers.qml) |
| Zone strip + resize-union + interaction wiring | [`drawers/border/BorderZone.qml`](../../drawers/border/BorderZone.qml) |
| Visible chrome | [`drawers/border/Border.qml`](../../drawers/border/Border.qml) |
| Single `BlobInvertedRect` driver | [`drawers/backgrounds/Backgrounds.qml`](../../drawers/backgrounds/Backgrounds.qml) |
| Rail/zone helpers + slotRect/slotHover/slotDragOver maps | [`services/BackgroundsManager.qml`](../../services/BackgroundsManager.qml) |
| Bridge regions, slot envelope, holdover, slot publishing | [`drawers/backgrounds/components/WindowSlot.qml`](../../drawers/backgrounds/components/WindowSlot.qml) |
| Per-zone shader gating (sink, boost, frame smin) | [`plugin/src/Caelestia/Blobs/shaders/blob.frag`](../../plugin/src/Caelestia/Blobs/shaders/blob.frag) |
| Plugin material extensions (`zoneRoundings`, `zoneIndex`) | [`plugin/src/Caelestia/Blobs/blobmaterial.{hpp,cpp}`](../../plugin/src/Caelestia/Blobs/blobmaterial.cpp), [`blobinvertedrect.{hpp,cpp}`](../../plugin/src/Caelestia/Blobs/blobinvertedrect.cpp), [`blobrect.{hpp,cpp}`](../../plugin/src/Caelestia/Blobs/blobrect.cpp) |
