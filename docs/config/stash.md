# `Config.stash`

File tray + LocalSend share panel. A hover-driven side / top / bottom
drawer that holds dropped files for quick re-use, and routes outbound
file drops to LocalSend devices on the local network. Reads from
`~/.config/pShell/shell.json` under the `"stash"` key.

Source: [`config/stashconfig/StashConfig.qml`](../../config/stashconfig/StashConfig.qml)

---

## Properties at a glance

| Property | Type | Default | Section |
|---|---|---|---|
| `enabled` | `bool` | `true` | [Module gate](#module-gate) |
| `stashDir` | `string` | `"$HOME/Downloads/qs_stash"` | [Storage](#storage) |
| `dropMode` | `string` | `"copy"` | [Storage](#storage) |
| `shortcut` | `string` | `"stash"` | [Visibility](#visibility) |
| `hoverStripPx` | `int` | `4` | [Visibility](#visibility) |
| `autoHideMs` | `int` | `400` | [Visibility](#visibility) |
| `columns` | `int` | `2` | [Grid](#grid) |
| `rowsMax` | `int` | `6` | [Grid](#grid) |
| `colsMax` | `int` | `8` | [Grid](#grid) |
| `cellSize` | `int` | `96` | [Grid](#grid) |
| `dropZoneX` | `int` | `160` | [Drop-zone chooser](#drop-zone-chooser) |
| `dropZoneY` | `int` | `96` | [Drop-zone chooser](#drop-zone-chooser) |
| `dashedBorderWidth` | `int` | `2` | [Drop-zone chooser](#drop-zone-chooser) |
| `dashedBorderDashLength` | `int` | `10` | [Drop-zone chooser](#drop-zone-chooser) |
| `dashedBorderGapLength` | `int` | `6` | [Drop-zone chooser](#drop-zone-chooser) |
| `dashedBorderRadius` | `int` | `4` | [Drop-zone chooser](#drop-zone-chooser) |
| `localsendEnabled` | `bool` | `true` | [LocalSend](#localsend) |
| `visibleDevicesMax` | `int` | `5` | [LocalSend](#localsend) |
| `deviceUnitSpacing` | `int` | `2` | [LocalSend](#localsend) |
| `direction` | `string` | `"auto"` | [Geometry](#geometry) |
| `anchors.{left,right,top,bottom,horizontalCenter,verticalCenter}` | `bool` | right + vCenter | [Geometry](#geometry) |
| `mode` | `string` | `"overlay"` | [Geometry](#geometry) |
| `mTop` / `mBottom` / `mLeft` / `mRight` | `int` | `0` | [Geometry](#geometry) |
| `padding` | `int` | `12` | [Geometry](#geometry) |
| `rounding` | `int` | `-1` (inherit) | [Geometry](#geometry) |
| `invertedJoinRounding` | `int` | `-1` (inherit) | [Geometry](#geometry) |

Example `shell.json` overrides:

```json
{
  "stash": {
    "stashDir": "$HOME/Pictures/inbox",
    "dropMode": "symlink",
    "columns": 3,
    "rowsMax": 8,
    "dropZoneX": 200,
    "dropZoneY": 110,
    "dashedBorderDashLength": 12,
    "dashedBorderGapLength": 8
  }
}
```

---

## Module gate

### `enabled` (bool, default `true`)
Master switch for the trigger strip. When `false`, neither the
hover-to-open behaviour nor the drag-to-open behaviour activates,
even though the shortcut still works (if registered).

---

## Storage

Where dropped files live, and how they get there.

### `stashDir` (string, default `"$HOME/Downloads/qs_stash"`)
Filesystem directory the FilesTray watches and writes into. Leading
`~` and `$HOME` are expanded at runtime. The directory is created on
first refresh if missing.

### `dropMode` (string, default `"copy"`)
Strategy for files dropped onto the FilesTray zone:

| Value | Effect |
|---|---|
| `"copy"` | Duplicates the source file into `stashDir`. Safe — the original can move/delete without affecting the stash entry. |
| `"symlink"` | Creates a symlink in `stashDir` pointing at the source. Zero disk overhead, but the entry breaks if the original moves. |

The send-via-LocalSend path is separate and never touches `stashDir`
— files dropped on the LocalSend zone go straight to the picker.

---

## Visibility

How the panel pops in, how it closes.

### `shortcut` (string, default `"stash"`)
IPC handler name registered with `VisibilitiesManager`. Bind in
`~/.config/niri/config.kdl`:

```kdl
binds {
    Mod+S hotkey-overlay-title="Toggle stash" {
        spawn "qs" "-c" "pShell" "ipc" "call" "stash" "activate";
    }
}
```

### `hoverStripPx` (int, default `4`)
Thickness (px) of the invisible edge strip that opens the panel on
mouse-enter or drag-enter. Set to `0` to disable hover-to-open
entirely — the shortcut becomes the only way in.

| Value | Effect |
|---|---|
| `0` | Hover-to-open disabled. |
| `2–4` | Hard to trigger accidentally; intentional edge fling. |
| `6–10` | Forgiving; fires on casual edge-grazing. |

### `autoHideMs` (int, default `400`)
Delay (ms) after both the trigger strip and the open panel lose
hover before the panel hides. `0` disables auto-hide entirely —
the panel then stays open until toggled via shortcut.

---

## Grid

The open file tray's geometry. One axis is fixed by `columns`
(vertical mode) or by a single row of cells (horizontal mode); the
other axis is content-driven and capped by `rowsMax` / `colsMax`.

### `columns` (int, default `2`)
Column count when `isVertical=true`. Drives the panel's fixed
width: `(cellSize + gap) * columns + gap`. Keep low (2–3) for a
narrow side drawer.

### `rowsMax` (int, default `6`)
Maximum rows shown before the GridView scrolls. Only consulted in
vertical mode. The actual row count is
`min(rowsMax, ceil(fileCount / columns))`.

### `colsMax` (int, default `8`)
Maximum columns shown before the ListView scrolls. Only consulted
in horizontal mode (single row, scroll horizontally).

### `cellSize` (int, default `96`)
Edge length (px) of each file tile. The thumbnail/icon is
auto-sized to ~0.66 × `cellSize`.

---

## Drop-zone chooser

While a file drag is in progress, the panel pivots from "file tray"
to a two-zone chooser: **FilesTray** (stores the file) and
**LocalSend** (sends without storing).

### `dropZoneX` (int, default `160`)
### `dropZoneY` (int, default `96`)

Tile dimensions for each chooser zone. The two values **swap with
orientation** so a single config describes both panel modes:

| Orientation | Each zone is |
|---|---|
| `isVertical=true` (side panel, zones stacked) | `dropZoneX` × `dropZoneY` (W × H) |
| `isVertical=false` (top/bottom panel, zones side-by-side) | `dropZoneY` × `dropZoneX` (W × H) |

The chooser's overall implicit size is `(zone + gap)` along the
stack axis × the single-zone dimension on the other axis.

### `dashedBorderWidth` (int, default `2`)
Stroke width (px) of the dashed border that fades in over the
FilesTray zone while a drag hovers over it.

### `dashedBorderDashLength` (int, default `10`)
Length (px) of each dash segment.

### `dashedBorderGapLength` (int, default `6`)
Length (px) of each gap between dashes.

### `dashedBorderRadius` (int, default `4`)
Corner radius (px) of the dashed rectangle. The dashes themselves
have rounded caps (`lineCap = "round"`) regardless.

The LocalSend zone has no border — its fill is `primary @ alpha 0.18`
by default, rising to `0.34` while a drag hovers over it.

---

## LocalSend

File share over the LocalSend protocol (UDP multicast + HTTPS
fallback). Outbound: `scripts/localsend_discover.py` (find peers) and
`scripts/localsend_send.py` (upload). Inbound: `scripts/localsend_receive.py`
runs an HTTPS receive server, coordinated by the `services/LocalSend.qml`
singleton; the accept/reject card is `IncomingRequest.qml`. All three Python
scripts are self-contained [uv](https://docs.astral.sh/uv/) scripts (PEP 723
shebang) — executable and run directly, no venv.

### `localsendEnabled` (bool, default `true`)
Toggles the LocalSend share button on each file tile, the "send all"
button in the action strip, and the LocalSend drop zone in the
chooser. When `false`, only the FilesTray side of the chooser is
shown and dropped files always go to `stashDir`.

The device picker shows one row per discovered peer, with a
type-derived glyph (mobile / laptop / desktop / tablet / cli),
the alias, and two badges: `#<last-octet-of-IP>` and the device
model string the peer advertised. A lone rescan button re-runs
discovery; the picker auto-closes when the queue completes (or
auto-hide kicks in after mouse-out).

### `visibleDevicesMax` (int, default `5`)
Maximum device rows shown before the picker's list scrolls.
Indirectly caps panel height in picker mode — the panel grows to
fit `min(discovered, visibleDevicesMax)` rows and stops; extra
devices live in the scrollable region.

### `deviceUnitSpacing` (int, default `2`)
Vertical gap (px) between alias and badge row inside a
`DeviceUnit`. Tighter than the default `spacing.smaller` so the
icon + name + badge stack reads as one block. Increase to `4`–`6`
if you prefer more breathing room.

### `localsendReceiveEnabled` (bool, default `false`)
Turns the inbound receive server on/off. When `true`, pShell announces
itself on the LAN (alias `localsendAlias`) so other LocalSend apps can
send to it, and `services/LocalSend.qml` keeps `localsend_receive.py`
running. Toggled from the antenna button in the action strip; the value
is persisted to `shell.json`, so the server comes back up on restart.
When a transfer request arrives the stash pops open and shows an
accept/reject card (`IncomingRequest.qml`) listing the sender and files.

### `localsendAlias` (string, default `"pShell Stash"`)
The device name broadcast to other LocalSend peers — what they see in
their target list.

### `downloadDir` (string, default `"$HOME/Downloads"`)
Where accepted incoming files are written. `~`/`$HOME` are resolved at
runtime. The accept card shows this as the default destination and
offers a one-off override via a system folder dialog
(`scripts/localsend_pickdir.sh`, zenity/kdialog/yad) for the current
transfer only.

---

## Geometry

Where the panel anchors and how it interacts with the rails system.
These feed the wrapper's contract directly — see
[`docs/config/backgrounds.md`](./backgrounds.md) for the broader
rails-system behaviour.

### `direction` (string, default `"auto"`)
Layout orientation override:

| Value | Effect |
|---|---|
| `"auto"` | Top/bottom anchor → horizontal; left/right anchor → vertical; only-center fallback → vertical. |
| `"horizontal"` | Force horizontal (single row, scrolls). |
| `"vertical"` | Force vertical (GridView, scrolls). |

### `anchors.{left, right, top, bottom, horizontalCenter, verticalCenter}` (bool, default `right=true, verticalCenter=true`)
Drives both the rail position and the trigger-strip placement. Mix
one edge (e.g. `right`) with one centring (e.g. `verticalCenter`)
for a side drawer. Combine two adjacent edges (e.g. `bottom` +
`right`) to corner-mount.

### `mode` (string, default `"overlay"`)
Rails-system stacking semantics:

| Value | Effect |
|---|---|
| `"overlay"` | Covers underlying content; doesn't displace siblings on the rail. |
| `"push"` | Joins the rail and displaces neighbouring wrappers. |

### `mTop` / `mBottom` / `mLeft` / `mRight` (int, default `0`)
Margins (px) on each side of the panel relative to its rail
neighbour or screen edge. Used as-is by the wrapper contract.

### `padding` (int, default `12`)
Inner spacing (px) between the painted background and the panel
content (same value applied to all four sides).

### `rounding` (int, default `-1`)
Override for the painted background's corner radius. `-1` inherits
from `Config.backgrounds.rounding`.

### `invertedJoinRounding` (int, default `-1`)
Override for SDF-inverted-join corners when the panel touches a
screen-edge frame. `-1` inherits from `Config.backgrounds.rounding`.

---

## View-state recap

The open panel has three mutually exclusive view states:

```
            ┌───────────────────────────────┐
            │ stashVisible = false (closed) │
            └───────────────────────────────┘
                          │ hover / drag / shortcut
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 1. File tray   (default open view)              │
   │    GridView/ListView + action strip             │
   │    [refresh] [open folder] [send all] [clear]   │
   └─────────────────────────────────────────────────┘
                  │ drag enters trigger or content
                  ▼
   ┌─────────────────────────────────────────────────┐
   │ 2. Drop-zone chooser  (drag in progress)        │
   │   ┌───────────────┐ ┌───────────────┐           │
   │   │ FilesTray     │ │ LocalSend     │           │
   │   │ (dashed       │ │ (primary tint │           │
   │   │  on hover)    │ │  rises on hover)          │
   │   └───────────────┘ └───────────────┘           │
   └─────────────────────────────────────────────────┘
                  │ drop on LocalSend / click [send all]
                  ▼
   ┌─────────────────────────────────────────────────┐
   │ 3. Device picker  (lsState != "idle")           │
   │    DeviceUnit rows + rescan button              │
   └─────────────────────────────────────────────────┘
```

`isVertical` is computed from `direction` + `anchors`; everything
else (panel implicit size, zone dimensions, action-strip flow) is
derived from it.

---

## Where the implementation lives

- Config schema:
  [`config/stashconfig/StashConfig.qml`](../../config/stashconfig/StashConfig.qml)
- Wrapper (trigger strip, watcher, contract):
  [`modules/stash/StashWrapper.qml`](../../modules/stash/StashWrapper.qml)
- Three-state content & LocalSend orchestration:
  [`modules/stash/content/StashContent.qml`](../../modules/stash/content/StashContent.qml)
- File tile (thumbnail + per-file menu):
  [`modules/stash/content/StashDelegate.qml`](../../modules/stash/content/StashDelegate.qml)
- Device picker (scanning / sending):
  [`modules/stash/content/DevicePicker.qml`](../../modules/stash/content/DevicePicker.qml)
- Per-device row:
  [`modules/stash/content/DeviceUnit.qml`](../../modules/stash/content/DeviceUnit.qml)
- Dashed border component:
  [`components/DashedRect.qml`](../../components/DashedRect.qml)
- LocalSend scripts (uv, PEP 723):
  [`scripts/localsend_discover.py`](../../scripts/localsend_discover.py),
  [`scripts/localsend_send.py`](../../scripts/localsend_send.py),
  [`scripts/localsend_receive.py`](../../scripts/localsend_receive.py),
  [`scripts/localsend_pickdir.sh`](../../scripts/localsend_pickdir.sh)
- LocalSend receive service:
  [`services/LocalSend.qml`](../../services/LocalSend.qml),
  [`modules/stash/content/IncomingRequest.qml`](../../modules/stash/content/IncomingRequest.qml)
