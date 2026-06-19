# `Config.backgrounds`

Per-screen visual configuration for the shared **rails system** that
renders every wrapper's background. Reads from
`~/.config/pShell/shell.json` under the `"backgrounds"` key.

Source: [`config/backgroundsconfig/BackgroundsConfig.qml`](../../config/backgroundsconfig/BackgroundsConfig.qml)

---

## Properties at a glance

| Property | Type | Default | Section |
|---|---|---|---|
| `rounding` | `int` | `30` | [Geometry](#geometry) |
| `invertBaseRounding` | `bool` | `false` | [Geometry](#geometry) |
| `margins.{left,right,top,bottom}` | `int` | `0` | [Geometry](#geometry) |
| `paddings.{left,right,top,bottom}` | `int` | `15` | [Geometry](#geometry) |
| `offsets.{vCenterOffset,hCenterOffset}` | `int` | `0` | [Geometry](#geometry) |
| `fadeWidth` | `int` | `40` | [Fade-aura](#fade-aura) |
| `overlapShrink` | `int` | `15` | [Fade-aura](#fade-aura) |
| `fadeStrength` | `real` | `1.0` | [Fade-aura](#fade-aura) |

Example `shell.json` overrides:

```json
{
  "backgrounds": {
    "rounding": 22,
    "fadeWidth": 60,
    "overlapShrink": 20,
    "fadeStrength": 2.0
  }
}
```

---

## Geometry

These properties feed the default geometry shared by every wrapper
that doesn't override them in its own contract.

### `rounding` (int, default `30`)
Corner radius (px) for the painted background rectangle. Each wrapper
can override via its contract's `windowRounding`.

### `invertBaseRounding` (bool, default `false`)
Controls the corner radius of the screen-edge frame's **inner cutout**
(the `BlobInvertedRect`'s rounded hole). When `true`, the cutout corners
are rounded to `Config.border.rounding`, so a bg присасывающийся to the
frame meets it through a rounded inner corner. When `false`, the cutout
is square (radius 0) — sharp inner corners where bgs join the frame.

### `margins` (Directions, default all `0`)
Outer offsets (px) between this background and screen edge or
neighbouring rails. Each side independently:

```json
"margins": { "left": 0, "right": 0, "top": 0, "bottom": 0 }
```

### `paddings` (Directions, default all `15`)
Inner offsets (px) between the painted background and its content
loader. Same shape as `margins`.

### `offsets` (Offsets, default `0`)
Manual offset for centred anchors:

```json
"offsets": { "vCenterOffset": 0, "hCenterOffset": 0 }
```

Used by wrappers whose contract sets `aVerticalCenter`/
`aHorizontalCenter` — shifts them along the centred axis.

---

## Fade-aura

Each rendered wrapper gets an opaque rect drawn in `contentLayer`
just **below** its own content (`z = arrivalSeq`) and **above**
older wrappers' content (smaller `arrivalSeq`). The aura's job is
to hide whatever sits beneath the new wrapper and gradually
**dissolve** lower content into the bg colour near the new
wrapper's edges, making the visual stacking obvious.

Everything is masked by the **SDF union of all backgrounds**, so the
halo respects the rounded contour formed by adjacent bgs together —
when two bgs merge through SDF smoothing, the halo flows through
their join continuously.

### Layout

```
                  fadeWidth halo (extends past paintedRect if
                                  overlapShrink < fadeWidth)
       ↓↓
┌────────────────────────────┐   ← paintedRect (bg edge)
│   ┌────────────────────┐   │   ← inner solid edge (α = 1)
│   │ overlapShrink (os) │   │     = paintedRect shrunk by os
│   │                    │   │
│   │     inner solid    │   │
│   │                    │   │
│   └────────────────────┘   │
└────────────────────────────┘
```

- **`inner_solid`** is the **rectangle the gradient grows outward
  from**. Its size is `paintedRect` shrunk by `overlapShrink` on
  every side, centred.
- **`halo ring`** is `fadeWidth` px wide, sitting **outside** the
  inner solid on all four sides. It may extend past `paintedRect`
  — the SDF-union mask decides what's painted:
  - **No neighbour at that location** → halo trimmed at the rounded
    bg contour.
  - **SDF-merged neighbour** → halo continues into that neighbour
    seamlessly.

### `fadeWidth` (int, default `40`)

Directly controls the **visible gradient distance**. This is the
only knob for how wide the halo is. The SDF-union mask is the only
thing that can shorten the visible fade (when the halo spills past
the rounded contour without a neighbour to flow into).

| Value | Effect |
|---|---|
| `0` | Halo disabled — no gradient at all. Inner solid still drawn if `overlapShrink > 0`. |
| Small (~10–20) | Subtle dissolve, almost a hard edge. |
| Default (`40`) | Visible but soft, ~40 px transition. |
| Large (`80+`) | Long fade — content well past the bg edge gets faded too if neighbours exist. |

### `overlapShrink` (int, default `15`)

How many px (per side) the `inner_solid` is **smaller than** the bg
rect, centred. Determines where the halo starts.

| Relation | Result |
|---|---|
| `overlapShrink = 0` | `inner_solid` covers the entire bg; halo lives **entirely outside** `paintedRect`. Visible only where SDF-merged neighbours exist beyond this bg's edge. |
| `overlapShrink = fadeWidth` | Halo's **outer edge lands exactly on** `paintedRect`'s edge. Halo fills the band `os` px wide inside the bg. |
| `overlapShrink > fadeWidth` | Halo fully inside `paintedRect`; a transparent "moat" remains between halo's outer edge and the bg edge. |
| `0 < overlapShrink < fadeWidth` | Halo partly outside `paintedRect`; the SDF-union mask trims the overshoot. |

### `fadeStrength` (real, default `1.0`)

Curve exponent for the gradient alpha ramp. Internally:

```
alpha(t) = t ^ (1 / fadeStrength)
```

where `t = 0` is the halo's outer (transparent) edge and `t = 1`
is its inner (opaque) edge.

| Value | Shape | Effect |
|---|---|---|
| `1.0` | Linear | Default. Even fade across the full width. |
| `2.0` | Square-root | "Strong at start": alpha climbs quickly near the outer edge — half the halo width already has ~70 % alpha. |
| `3.0` | Cube-root | Even more aggressive: most of the halo width is near-opaque. |
| `0.5` | Quadratic | "Weak at start": slow ramp near outer edge, sharp transition near inner. |
| `0.25` | Quartic | Almost no fade for most of the width, then a hard step at inner edge. |

Use `fadeStrength > 1` when you want the halo to be **prominent
visually** without making `fadeWidth` huge. Use `fadeStrength < 1`
for a tighter, more defined wrapper outline.

---

## Z-order recap

Across all wrappers, render order in the `contentLayer` is:

```
... older wrapper's content      (z = older_arrivalSeq + 0.5)
this wrapper's fade-aura          (z = this_arrivalSeq)
this wrapper's own content        (z = this_arrivalSeq + 0.5)
```

`arrivalSeq` increases each time `requestBackground()` runs — newer
wrappers always paint above older ones. The fade-aura sits between
its own content (on top) and every older wrapper's content (below).

---

## Where the implementation lives

- Config schema:
  [`config/backgroundsconfig/BackgroundsConfig.qml`](../../config/backgroundsconfig/BackgroundsConfig.qml)
- Per-wrapper rendering & fade-aura math:
  [`drawers/backgrounds/components/WindowSlot.qml`](../../drawers/backgrounds/components/WindowSlot.qml)
- SDF union host (`bgRenderHost`) and rail composition:
  [`drawers/backgrounds/Backgrounds.qml`](../../drawers/backgrounds/Backgrounds.qml)
- C++ SDF compositor:
  `plugin/src/Caelestia/Blobs/` (BlobGroup, BlobRect, BlobInvertedRect)
