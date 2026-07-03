# `Config.border`

Per-screen visual border around the layershell + the **8-zone**
interaction surface that catches hover / drag at the screen edge.
Reads from `~/.config/pShell/shell.json` under the `"border"` key.

Source: [`config/borderconfig/BorderConfig.qml`](../../config/borderconfig/BorderConfig.qml)

---

## Properties at a glance

| Property | Type | Default | Section |
|---|---|---|---|
| `enabled` | `bool` | `false` | [Chrome](#chrome) |
| `thickness` | `int` | `10` | [Chrome](#chrome) |
| `rounding` | `int` | `15` | [Chrome](#chrome) |
| `fillBar` | `bool` | `false` | [Chrome](#chrome) |
| `minMouseArea` | `int` | `1` | [Zones](#zones) |
| `defaultZoneLength` | `int` | `100` | [Zones](#zones) |
| `defaultMouseAreaThickness` | `int` | `10` | [Zones](#zones) |
| `zoneRoundings` | `list<real>` (8) | `[0,0,0,0,0,0,0,0]` | [Zones](#zones) |

Example `shell.json` overrides:

```json
{
  "border": {
    "enabled": true,
    "thickness": 12,
    "rounding": 18,
    "defaultZoneLength": 120,
    "zoneRoundings": [1, 1, 1, 1, 1, 1, 1, 1]
  }
}
```

---

## Chrome

The **visible** chrome — a single masked StyledRect in
[`drawers/border/Border.qml`](../../drawers/border/Border.qml). The
MultiEffect mask cuts out the interior, leaving only a frame.

It is instantiated as the **first child** of the content `Item` in
[`drawers/Drawers.qml`](../../drawers/Drawers.qml), i.e. at the
**lowest z** — below all panel content (`contentLayer`, z=100).
`pinned`/`overlay` panels sit at `edge=0` (into the border strip), so
keeping the chrome at the bottom means their content always paints
**above** it and is never covered. The 8 `BorderZone` input strips
(`Borders.qml`) stay last/topmost so they still catch hover/click
before the bgs. (The chrome used to be the "9th instance" on top of
`Borders.qml`; it was moved down to stop covering content.)

### `enabled` (bool, default `false`)
When `false`, the chrome paints nothing (`StyledRect` color uses
fully-transparent mask). The 8 invisible zonal interaction surfaces
remain active regardless.

### `thickness` (int, default `10`)
Frame thickness in pixels. Also:
- defines the **per-zone trigger strip thickness** (combined with each
  topmost edge-nearest bg's facing margin — see [Zones](#zones));
- **insets the invisible SDF frame's inner cutout** by the same amount,
  so bgs присасываются to the border's **inner edge**, not the bare
  screen edge (see [Frame inset](#frame-inset)).

### `rounding` (int, default `15`)
Corner radius (px) of the inner-cutout rounded rectangle of the
visible chrome. This is **also** the SDF inner-corner radius of the
invisible `BlobInvertedRect` — gated by
`Config.backgrounds.invertBaseRounding` (`true` → use this value,
`false` → square cutout, radius 0). Independent from the panels' own
`Config.backgrounds.rounding`.

### `fillBar` (bool, default `false`)
When `true`, both the visible chrome's mask **and** the SDF frame's
inner-cutout inset use per-side `left_area / top_area / right_area /
bottom_area` (the layershell's reserved edges, picked up from pinned
wrappers' exclusion zones) instead of a uniform `thickness`. Effect:
the border fills any reserved bar area solid instead of cutting
around it, and bgs присасываются to that filled edge.

---

## Frame inset

The invisible `BlobInvertedRect` (the SDF frame that bgs sink/merge
into) has its **inner cutout inset to the visible border's inner
edge**, mirroring the chrome's mask:

- `fillBar: false` → inset by a uniform `Config.border.thickness` on
  every side.
- `fillBar: true` → inset per-side by `left_area / top_area /
  right_area / bottom_area`.

Computed in [`drawers/backgrounds/Backgrounds.qml`](../../drawers/backgrounds/Backgrounds.qml)
as `_frameInset{Left,Right,Top,Bottom}` and added to the frame's
`border*` margins. Without this, the frame's inner edge sat at the
bare screen edge and bgs присасывались **under** the border instead of
to its inner edge.

Consequence: with the inset, the SDF frame's solid band now paints the
border strip **inside** the viewport (colour `surface`, same as the
static chrome) and merges with sticking panels — so a panel rounds
into the border's inner corner (radius `rounding`, gated by
`Config.backgrounds.invertBaseRounding`). The static `Border` chrome
sits below it as a base fill.

---

## Zones

The layershell perimeter is partitioned into **8 logical zones**,
clockwise from top-left:

```
       0 topLeft     1 top         2 topRight
       7 left                      3 right
       6 bottomLeft  5 bottom      4 bottomRight
```

Each zone has 1 (side) or 2 (corner) thin **trigger strips** sized
to the projection of its rail's edge-nearest bgs (layer-1 + overlay),
or to `defaultZoneLength × defaultMouseAreaThickness` when empty.
Strips dispatch hover / click / slide / drop into the
[InteractionManager](../development/interaction-manager.md) per
rail. They live in [`drawers/border/BorderZone.qml`](../../drawers/border/BorderZone.qml)
and are instantiated by `Borders.qml`.

Rail-to-zone map (zone -1 = center rail, no zone):

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

### `defaultZoneLength` (int, default `100`)
Strip length (along its touched edge) used when the zone's rail has
no edge-nearest bgs. For corner zones, the strip is anchored at the
corner; for side zones, centred on the edge.

### `defaultMouseAreaThickness` (int, default `10`)
Base trigger-strip thickness (perpendicular to edge), **always added**
to the strip. The full per-strip thickness is:

| Topmost edge-nearest bg | Strip thickness |
|---|---|
| **pinned or overlay** (sits flush at `edge=0`, under the border) | `facingMargin + defaultMouseAreaThickness` |
| push | `facingMargin + Config.border.thickness + defaultMouseAreaThickness` |
| **empty** zone next to a real same-edge bg | **inherits** that neighbour's thickness |
| empty zone, no real neighbour on that edge | `Config.border.thickness + defaultMouseAreaThickness` |

The pinned/overlay case drops the `Config.border.thickness` term so a
thick border never pushes the strip onto the bg's content — pinned and
overlay bgs are at `edge=0` (under the border), unlike push bgs which
are already inset by it. `facingMargin` is the topmost bg's edge-facing
margin (`mTop`/`mRight`/`mBottom`/`mLeft`); `0` when the zone is empty.

The **empty-inherits-neighbour** rule keeps the band uniform along an
edge: a corner zone next to a full-edge bar (e.g. a non-separated side
bar) takes the bar strip's thickness instead of bulging out by the full
`Config.border.thickness`. Real zones never read empty ones, so there's
no feedback loop.

### `zoneRoundings` (list of 8 reals, default `[0, 0, 0, 0, 0, 0, 0, 0]`)
Per-zone SDF присасывание (sticking) strength — how aggressively
bgs in that zone are pulled toward the screen-edge `BlobInvertedRect`.
Order matches the zone index above:

```
[topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left]
```

The plugin shader uses this value as a **multiplier on three
independent effects**:
- The per-rect SDF boost scale (visual compression toward the frame).
- The sink loop that drags the frame's inner edge inward toward
  each bg.
- The final smin-with-frame for the rect's owned pixels.

`0` disables присасывание entirely for bgs in that zone — they
render as plain rounded rectangles even when their margin is `0`.
`1` is the default unscaled behavior. Values between scale all
three effects linearly. zoneIndex `-1` (bgs in the center rail, or
bgs that never reported a zone) also gets strength `0`.

This is **ANDed** with the per-window
[`sticks`](backgrounds.md#присасывание-sticking) flag: a bg pulls the
frame only when its zone strength `> 0` **and** `sticks: true`. A
floating bg (`sticks: false`) ignores the frame regardless of its
zone's `zoneRoundings` value.

### `minMouseArea` (int, default `1`)
Reserved for [InteractionManager](../development/interaction-manager.md)
slide/drop semantics. Currently unused.

---

## Where the implementation lives

- Config schema:
  [`config/borderconfig/BorderConfig.qml`](../../config/borderconfig/BorderConfig.qml)
- Visible chrome (instantiated at the bottom of the z-stack in
  [`drawers/Drawers.qml`](../../drawers/Drawers.qml)):
  [`drawers/border/Border.qml`](../../drawers/border/Border.qml)
- Zone orchestrator (8 BorderZone input strips only):
  [`drawers/border/Borders.qml`](../../drawers/border/Borders.qml)
- SDF frame inset to the border inner edge:
  [`drawers/backgrounds/Backgrounds.qml`](../../drawers/backgrounds/Backgrounds.qml)
- Zone strip implementation (per-side projection, resize-union,
  hover/click/slide/drop wiring):
  [`drawers/border/BorderZone.qml`](../../drawers/border/BorderZone.qml)
- Rail ↔ zone mapping and zone-edge-nearest helpers:
  [`services/BackgroundsManager.qml`](../../services/BackgroundsManager.qml)
- Invisible `BlobInvertedRect` at screen edges driving the SDF
  присасывание:
  [`drawers/backgrounds/Backgrounds.qml`](../../drawers/backgrounds/Backgrounds.qml)
- Per-zone shader logic (zoneStrength → sink + boost + frame smin):
  [`plugin/pshell/Blobs/shaders/blob.frag`](../../plugin/pshell/Blobs/shaders/blob.frag)
