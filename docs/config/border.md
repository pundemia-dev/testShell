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

The **visible** chrome — a single masked StyledRect drawn above all
wrappers as the 9th instance inside [`drawers/border/Borders.qml`](../../drawers/border/Borders.qml).
The MultiEffect mask cuts out the interior, leaving only a frame.

### `enabled` (bool, default `false`)
When `false`, the chrome paints nothing (`StyledRect` color uses
fully-transparent mask). The 8 invisible zonal interaction surfaces
remain active regardless.

### `thickness` (int, default `10`)
Frame thickness in pixels. Also defines the **per-zone trigger
strip thickness** (combined with each topmost edge-nearest bg's
facing margin — see [Zones](#zones)).

### `rounding` (int, default `15`)
Corner radius (px) of the inner-cutout rounded rectangle of the
visible chrome. Independent from the SDF inner-corner radius of
the invisible `BlobInvertedRect` (which comes from
`Config.backgrounds.rounding`).

### `fillBar` (bool, default `false`)
When `true`, the chrome's mask uses per-side `left_area / top_area /
right_area / bottom_area` (the layershell's reserved edges, picked
up from pinned wrappers' exclusion zones) instead of a uniform
`thickness`. Effect: the chrome fills any reserved bar area solid
instead of cutting around it.

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
Fallback thickness (perpendicular to edge) used when `thickness +
topmost-bg-margin` would be 0.

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

### `minMouseArea` (int, default `1`)
Reserved for [InteractionManager](../development/interaction-manager.md)
slide/drop semantics. Currently unused.

---

## Where the implementation lives

- Config schema:
  [`config/borderconfig/BorderConfig.qml`](../../config/borderconfig/BorderConfig.qml)
- Visible chrome:
  [`drawers/border/Border.qml`](../../drawers/border/Border.qml)
- Zone orchestrator (8 BorderZone + 1 visible Border):
  [`drawers/border/Borders.qml`](../../drawers/border/Borders.qml)
- Zone strip implementation (per-side projection, resize-union,
  hover/click/slide/drop wiring):
  [`drawers/border/BorderZone.qml`](../../drawers/border/BorderZone.qml)
- Rail ↔ zone mapping and zone-edge-nearest helpers:
  [`utils/BackgroundsManager.qml`](../../utils/BackgroundsManager.qml)
- Invisible `BlobInvertedRect` at screen edges driving the SDF
  присасывание:
  [`drawers/backgrounds/Backgrounds.qml`](../../drawers/backgrounds/Backgrounds.qml)
- Per-zone shader logic (zoneStrength → sink + boost + frame smin):
  [`plugin/src/Caelestia/Blobs/shaders/blob.frag`](../../plugin/src/Caelestia/Blobs/shaders/blob.frag)
