# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pShell is a desktop shell built on **Quickshell**, a Qt6-based Wayland shell framework. It targets the **Niri** compositor (Hyprland support is legacy and partially stripped on the active branch). The UI is written in QML; the only C++ component is the **Caelestia.Blobs** plugin, which provides SDF-based rounded panel rendering.

**Key technologies:** QML/Qt6, C++20 (Blobs plugin only), Quickshell, CMake.

## Building and Running

### Prerequisites

- Qt6 (ShaderTools, Core, Qml, Gui, Quick)
- CMake 3.19+
- C++20 compiler
- Quickshell framework

### Build and Install

```bash
cmake -B build -S . -G Ninja
cmake --build build
sudo cmake --install build --prefix /usr   # installs Caelestia.Blobs to /usr/lib/qt6/qml
```

### Run

```bash
quickshell -c pShell
# or
qs -c pShell
```

### Logs

Quickshell writes runtime logs to `/run/user/<uid>/quickshell/by-id/<id>/log.qslog`. Errors usually appear in stderr too.

## Architecture

### Entry Point and Rendering Layer

`shell.qml` → `drawers/Drawers.qml` (a `WlrLayershell` window, ExclusionMode.Ignore). Per-screen tree:

```
Screen
└── Drawers (WlrLayershell)
    ├── Exclusions          ← per-side ExclusionZone windows (border floor)
    ├── Corners             ← visual rounded-corner chrome
    ├── Border              ← visible border chrome, FIRST (lowest z)
    ├── Backgrounds         ← SDF Rails system (see below)
    ├── BarWrapper, LauncherWrapper, NotificationsWrapper, StashWrapper
    ├── Borders             ← 8 BorderZones (interaction strips only)
    └── NiriFocusGrab       ← Niri-specific focus capture
```

The visible `Border` chrome is the FIRST child (lowest z) so it renders
BELOW all panel content (contentLayer z=100): pinned/overlay panels sit
at edge=0 (into the border strip) and their content must paint above the
chrome, never covered. `Borders` (only the 8 BorderZone INPUT strips now)
is instantiated LAST so its strips sit above all wrapper content in
z-order — strips drive
[InteractionManager](docs/development/interaction-manager.md) and
must catch hover/click/slide/drop before the bgs do.

### Backgrounds: Rails system (post-Phase A–D)

`drawers/backgrounds/Backgrounds.qml` owns:

- **One `BlobGroup`** (Caelestia.Blobs) — SDF compositor for all painted backgrounds. Backgrounds render at z=0.
- **One `BlobInvertedRect`** at screen edges, carrying 8-element `zoneRoundings` for per-zone SDF присасывание (see [docs/development/border-zones.md](docs/development/border-zones.md)). Lives inside `bgRenderHost` and replaces the legacy `RailBorder.qml`.
- **9 `Rail` instances**, one per anchor position (topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight). Each `Rail` is a Repeater over its slice of `manager.rails[i]`.
- **One `contentLayer` (`z: 100`)** — every window's `wrapper.content` (and overlay-mode bgs) is reparented here with `z = arrivalSeq + 0.5`, so new content always paints above old content cross-rail. Per-slot **envelope Items** (invisible HoverHandler + DropArea) also live here at `z=-1`, sized from each slot's stable target geometry.

The whole renderer is in:

- `utils/BackgroundsManager.qml` — `rails[][]` state, `requestBackground(wrapper) → arrivalSeq`, `removeBackground(wrapper)`, `reservedTop/Bottom/Left/Right` (aggregated exclusion), zone helpers (`zoneForRail` / `railForZone` / `zoneSides` / `zoneEdgeNearestEntries` / `zoneTopmostEntry`), and per-slot maps (`slotRects` / `slotHover` / `slotDragOver`).
- `drawers/backgrounds/components/Rail.qml` — sorts `pinned → push → overlay`, drives Repeater.
- `drawers/backgrounds/components/WindowSlot.qml` — single window: BlobRect + content Loader, position math, **L-step** for layer 2 on corner rails when a side reservation exists. Also: 4 bridge `Region`s (one per side), `holdoverRegion` (resize-union with 600 ms stable timer), and the per-slot envelope Item.

### Wrapper contract

Every UI module registers with `BackgroundsManager` via a `QtObject` describing geometry + behaviour. Required shape:

```qml
QtObject {
    // Size (0 = auto from content)
    property int wrapperWidth: 0; property int wrapperHeight: 0
    property int pLeft, pTop, pRight, pBottom

    // Anchor (chooses rail)
    property bool aLeft, aRight, aTop, aBottom
    property bool aHorizontalCenter, aVerticalCenter

    // Margins (perpendicular to growth axis; growth axis driven by neighbour)
    property int mLeft, mRight, mTop, mBottom
    property int vCenterOffset, hCenterOffset

    // Stacking semantics
    property string mode: "push"        // "push" displaces siblings; "overlay" covers
    property bool pinned: false         // visually fixed at layer 1
    property bool reservesSpace: false  // → wlr-layer-shell exclusion zone
    property bool sticks: true          // false → clean floating contour (no SDF merge with neighbours/frame, no magnet)
    readonly property int layer: 0      // assigned by Rail
    property int windowRounding: -1

    property Component content: null
}
```

Call sites:
```qml
const arrivalSeq = manager.requestBackground(wrapper)
// keep arrivalSeq if the module wants to subscribe to
// manager.slotRects[seq] / slotHover[seq] / slotDragOver[seq]
manager.removeBackground(wrapper)
```

**Don't pass legacy positional args** (`isolate`, `excludeBarArea`) — they're gone.

**Margin direction for layer-2+ slots**: when a slot is layer-2+ on
its rail (i.e. has a `prevSlot`), the gap to prev is taken from
**THIS slot's own facing margin** (`mLeft` when prev is to the
left, `mTop` when prev is above, etc.) — NOT `prev.mRight` /
`prev.mBottom`. Each margin reads uniformly as "gap on this side
from whatever is adjacent" (prev bg, reserved space, or screen
edge).

### Module System

Each module is `modules/<name>/<Name>Wrapper.qml` + `modules/<name>/content/`. The wrapper owns the contract object(s) and lifecycle; content is a `Component` that renders the actual UI.

| Module | Purpose |
|--------|---------|
| `modules/bar` | Status bar (3 pinned segments: begin/center/end) |
| `modules/launcher` | Application launcher with pluggable search |
| `modules/notifications` | D-Bus notification popups |
| `modules/stash` | File tray (drag/drop + LocalSend share); hover-trigger; two-zone drag chooser |
| `modules/settings` | Settings UI |

### Visibility & Focus

- `utils/VisibilitiesManager.qml` — per-monitor show/hide hub. `addVisibility(screen, name, shortcut, isolated, autostart, description)` registers the module; `setVisibility(screen, name, bool)` toggles.
- `utils/InteractionManager.qml` — global Singleton coordinating per-rail interaction stacks driven by `BorderZone` strips. Three modes: **hover** (per-rail stack, advances on fresh enter or click; resets when rail empties), **slide** (press inside + drag out; single handler per rail), **drop** (file/text DragEnter; single handler per rail). Modules call `registerHover/registerSlide/registerDrop(rail, …)` from `Component.onCompleted` and `unregisterHover/...` from `Component.onDestruction`. Also publishes `stripHovered[rail]` / `stripDragOver[rail]` for modules' auto-hide logic. See [docs/development/interaction-manager.md](docs/development/interaction-manager.md).
- Shortcuts on Niri use `Quickshell.Io.IpcHandler` (see `components/misc/CustomShortcut.qml`). There's no `hyprland_global_shortcuts_v1` on Niri — bind in `~/.config/niri/config.kdl`:
  ```kdl
  binds {
      Mod+Space hotkey-overlay-title="Toggle launcher" {
          spawn "qs" "-c" "pShell" "ipc" "call" "launcher" "activate";
      }
  }
  ```
- `utils/FocusManager.qml` — coordinates keyboard focus via `NiriFocusGrab`. Modules call `FocusManager.requestFocus(name)` / `releaseFocus(name)`.
- `utils/InputManager.qml` — layershell input mask region collection. Each `WindowSlot` adds its `inputRegion` + `holdoverRegion` + 4 bridges. See [docs/development/input-mask.md](docs/development/input-mask.md).

### Configuration

`config/Config.qml` reads `~/.config/pShell/shell.json` (hardcoded path; intended `Paths.config`). Sub-configs live in `config/<name>config/`:

- `Config.bar` → `barconfig/BarConfig.qml`
- `Config.launcher` → `launcherconfig/LauncherConfig.qml`
- `Config.notifs` → `notifsconfig/NotifsConfig.qml`
- `Config.backgrounds` → `backgroundsconfig/BackgroundsConfig.qml`
- `Config.border` → `borderconfig/BorderConfig.qml` (visible chrome + 8 zonal `zoneRoundings`)
- `Config.corners` → `cornersconfig/CornersConfig.qml`
- `Config.stash` → `stashconfig/StashConfig.qml`
- `Config.general` → `generalconfig/GeneralConfig.qml` (shell-wide prefs; `advanced` drives the settings basic/advanced disclosure)
- `Config.custom` → open `var` map for third-party module settings, keyed by `SettingsSchema.key`. Read with `Config.getCustom(key, field, fallback)`, write with `Config.setCustom(key, field, value)` (it reassigns `custom` wholesale so JsonAdapter persists).

Config **presets** (full-config themes + per-section snapshots) live under `~/.config/pShell/presets/<scope>/<name>.json`, managed by `utils/PresetsManager.qml` (IPC target `presets`; apply = write file → `reload()`).

`config/Appearance.qml` is the design-token singleton: `rounding.{small,normal,large,full,scale}`, `padding.*`, `spacing.*`, `font.family.{sans,mono,tabler}`, `font.size.*`, `anim.curves.*`, `anim.durations.*`. **Always reference these — never hardcode pixel/ms values.**

### Settings module

`modules/settings` is a normal `Window` (toggled via the `settings` IPC). Full design + phase log: [docs/development/settings.md](docs/development/settings.md). Pieces:

- **Editing** — pages two-way-bind to `Config.*` (JsonAdapter auto-writes `shell.json`). Official pages are hand-written in `modules/settings/pages/` (`BarPage`, `BackgroundsPage`, …) over `SettingSection` + `SettingRow`; registered in `SettingsContent.qml`'s `pages` array (`name`/`icon`/`scope`/`component`).
- **Third-party contract** — a module ships a lightweight sibling `<Name>.settings.qml` (a pure `components/SettingsSchema.qml`: `title`/`icon`/`key`/`fields[]`). `SettingsDiscovery.qml` scans `modules/{bar,launcher}/content/components/` for `*.settings.qml` (loads **only the schema**, never the module), and `components/controls/SchemaForm.qml` renders it generically into a `SchemaPage`, persisting values in `Config.custom[key]`. Drop a widget + its `.settings.qml` → its page appears automatically; defaults are seeded into `Config.custom` at discovery.
- **Presets / themes** — `utils/PresetsManager.qml` (scopes = `full` + each config section). `pages/ThemesPage.qml` manages full-config theme cards (apply/rename/delete/save); the sidebar `PresetButton.qml` is scope-aware (follows the current tab). Destructive delete is two-tap confirmed.
- **Hints** — `components/controls/Hint.qml` (a `Popup`, so it renders above everything and is never clipped by the content pane) + `HintIcon.qml`. Wire via `hintText`/`hintMedia` on a `SettingRow`, or `hint: { text, media }` on a schema field (media auto-detects GIF/WebP).
- **basic/advanced** — `Config.general.advanced`; gate any field/section/page with `visible: !advanced || Config.general.advanced`.
- Sidebar icons are **tabler** glyphs (`Appearance.font.family.tabler`, incl. `IconButton`/`StyledIcon`). Write them as `\uXXXX` escapes (literal PUA chars get stripped by the edit tooling) and verify codepoints against the installed font cmap — see [tabler-icon-codepoints memory].

### Services

Singletons in `services/`:

- `Niri.qml` — workspaces, toplevels, `dispatch()`
- `Notifs.qml` — D-Bus notification server
- `Network.qml` / `Nmcli.qml`
- `Colours.qml` — dynamic palette (matugen)
- `Time.qml`
- `WallpaperState.qml`

### Caelestia.Blobs plugin

`plugin/src/Caelestia/Blobs/` — SDF panel renderer adapted from upstream caelestia. Builds a single Qt scene-graph material that merges multiple `BlobRect`s and one `BlobInvertedRect` into one shader pass with optional inverted-corner joins. Exposed types:

- `BlobGroup` — shared SDF compositor. Properties: `smoothing`, **`stickSmooth: real`** (neck-fatness multiplier on the smin radius between two sticking rects; 1 = legacy, >1 = capsule).
- `BlobRect` — rounded rectangle in the group. Properties: `radius`, `deformScale`, per-corner radii (`topLeft/topRight/bottomLeft/bottomRightRadius`), `exclude` (list), **`zoneIndex: int`** (0..7 = zone for per-zone присасывание; -1 = no zone → strength 0), **`sticks: bool`** (default true; false → no SDF merge with neighbours/frame, no boost/sink → clean floating contour).
- `BlobInvertedRect` — frame with rounded inner cutout. Properties: `borderLeft/Right/Top/Bottom`, **`zoneRoundings: list<real>`** (8 elements; per-zone присасывание strength, see [docs/development/border-zones.md](docs/development/border-zones.md)).
- `BlobShape` (base) — exposes `virtual int zoneIndex() const` and `virtual bool sticks() const` (defaults -1 / true, overridden in `BlobRect`).

**Cap: 16 rects per `BlobGroup`.** All shell panels share one group in `Backgrounds.qml`. The single `BlobInvertedRect` carries the per-zone roundings; the shader reads each rect's packed `zoneIndex` (float-encoded in `rectData[i*5+3].z`) and looks up the matching strength to gate three effects: per-rect SDF boost scale, sink loop, and final smin-with-frame. The `.w` slot of the same vec4 carries the per-rect **`sticks`** flag: it's ANDed into the zone strength (kills boost/sink/frame-merge when 0) and gates the inter-rect pairwise smin (skip if either rect doesn't stick; widen to `smoothFactor * stickSmooth` when both do → capsule neck). See [docs/development/border-zones.md](docs/development/border-zones.md).

The uniform buffer is **1472 bytes** (up from 1440) after adding two `vec4` slots (`zoneRoundingsLow/High`); the per-rect `sticks` flag reuses the spare `.w` slot and `stickSmooth` reuses the former `pad0` scalar, so neither changed the buffer size. Both `blob.vert` and `blob.frag` declare the same layout.

## Key Files by Task

| Task | File(s) |
|------|---------|
| Color scheme / design tokens | `config/Appearance.qml`, `services/Colours.qml` |
| Bar layout sections | `modules/bar/content/Begin.qml`, `Center.qml`, `End.qml` |
| Bar thickness/position | `config/barconfig/BarConfig.qml`, `modules/bar/BarWrapper.qml` |
| Backgrounds rendering | `drawers/backgrounds/Backgrounds.qml`, `drawers/backgrounds/components/*.qml`, `utils/BackgroundsManager.qml` |
| Border (chrome + 8 zonal interaction strips) | `drawers/border/Border.qml`, `drawers/border/Borders.qml`, `drawers/border/BorderZone.qml`, `config/borderconfig/BorderConfig.qml` |
| Per-rail interaction stack (hover/slide/drop) | `utils/InteractionManager.qml` |
| Wrapper contract examples | `modules/{bar,launcher,notifications,stash}/*Wrapper.qml` |
| Slot input mask (bridges + holdover + envelope) | `drawers/backgrounds/components/WindowSlot.qml`, `utils/InputManager.qml`, `drawers/Drawers.qml` (mask Region) |
| Edge reservation (exclusion zones) | `drawers/Drawers.qml` (`reservedEdge` aggregation), `drawers/exclusions/Exclusions.qml` |
| Niri integration | `services/Niri.qml`, `utils/NiriFocusGrab.qml` |
| LocalSend send | `modules/stash/content/StashContent.qml`, `modules/stash/content/{DevicePicker,DeviceUnit}.qml`, `scripts/localsend_{discover,send}.py` |
| LocalSend receive | `services/LocalSend.qml` (singleton: owns receive server, accept/reject state), `modules/stash/content/IncomingRequest.qml` (accept/reject card), `scripts/localsend_receive.py` (HTTPS server), `scripts/localsend_pickdir.sh` (folder dialog) |
| Dashed-border component | `components/DashedRect.qml` (Canvas-based, configurable dash / gap / radius) |
| Per-zone shader logic (sink + boost + frame smin gating) | `plugin/src/Caelestia/Blobs/shaders/blob.frag`, `plugin/src/Caelestia/Blobs/blobmaterial.{hpp,cpp}` |
| Per-window присасывание toggle (`sticks`) + capsule (`stickSmooth`) | `plugin/src/Caelestia/Blobs/blobrect.{hpp,cpp}`, `blobgroup.{hpp,cpp}`, `shaders/blob.frag`, `drawers/backgrounds/components/WindowSlot.qml`, `config/backgroundsconfig/BackgroundsConfig.qml` |
| SDF frame inset to border inner edge | `drawers/backgrounds/Backgrounds.qml` (`_frameInset*`) |
| Settings UI (pages, contract, presets, hints) | `modules/settings/{SettingsContent,SettingsDiscovery,PresetButton}.qml`, `modules/settings/pages/*.qml`, `components/{SettingsSchema,SettingRow,SettingSection}.qml`, `components/controls/{SchemaForm,Hint,HintIcon}.qml`, `utils/PresetsManager.qml`, `config/generalconfig/GeneralConfig.qml` — see [docs/development/settings.md](docs/development/settings.md) |

---

## Working conventions (rules for tasks)

These conventions exist because past iterations made mistakes here. Follow them by default; deviate only if the user asks.

### Reuse existing components — don't inline raw Rectangle/Text

Always prefer `StyledRect`, `StyledText`, `StyledIcon`, `IconButton`, `TextButton`, `IconTextButton`, `Anim`, `CAnim`, `StateLayer`, `SettingRow`, `CollapsibleSection`, etc. over raw `QtQuick` primitives. The styled wrappers carry palette bindings, font defaults, and animation Behaviors for free. If a styled variant doesn't exist for what you need, ask before introducing a new one.

### Always use Appearance design tokens

Never hardcode pixel/ms/radius/font-size literals in module code. Always pull from `Appearance.rounding.*`, `Appearance.padding.*`, `Appearance.spacing.*`, `Appearance.font.size.*`, `Appearance.anim.durations.*`, `Appearance.anim.curves.*`. Hardcoded values lurk only in `config/*Config.qml` defaults (where they're per-module configuration, not styling).

### Use the rails contract — don't add fields to it

If you need to add a window-level behaviour, first check whether an existing contract field (mode/pinned/reservesSpace/m*/p*) already covers it. Adding a new contract field is the last resort — it widens the public surface every module has to know about. (See [feedback memory on contract surface minimalism].)

### Niri-specific shortcut binding

When adding a keyboard shortcut for a module:
1. Register with `VisibilitiesManager.addVisibility(screen, name, ipcTarget, ...)`.
2. Document the niri-binds snippet in the module commit. Niri config is `~/.config/niri/config.kdl`, action `spawn "qs" "-c" "pShell" "ipc" "call" "<ipcTarget>" "activate"`.

### File layout for new modules

```
modules/<name>/
    <Name>Wrapper.qml         ← contract QtObject + lifecycle Loader
    content/
        <Name>Content.qml     ← top-level UI
        <other components>.qml
config/<name>config/
    <Name>Config.qml          ← JsonObject (hot-reloaded)
    structures/<X>Data.qml    ← nested JsonObject sub-types
```

Register the config in `config/Config.qml`'s adapter. Import the wrapper in `drawers/Drawers.qml` and instance it as a sibling of the existing wrappers.

### Settings for a new module

- **Official module**: add `modules/settings/pages/<Name>Page.qml` (a `Flickable` of `SettingSection`/`SettingRow` bound to `Config.<section>.*`) and register it in `SettingsContent.qml`'s `pages` array (`name`/`icon`/`scope`/`component`). Gate rarely-used controls with `advanced: true` on the row/section.
- **Third-party module**: ship `<Name>.settings.qml` (a `SettingsSchema`) next to the component and read values at runtime via `Config.getCustom(key, field, default)`. No `Config.qml` edit and no settings-page code needed — discovery + `SchemaForm` surface it automatically. **Never widen the rails contract for settings state — it lives in `Config.custom`.**

### Hover-trigger pattern (auto-hide drawers)

When implementing hover-driven panels (like `modules/stash`):
- **Don't build your own trigger strip.** The strip lives in
  `drawers/border/BorderZone.qml`. Register with
  `InteractionManager.registerHover(rail, layer, name, onActivate)`
  and `registerDrop(rail, name, onActivate)` from `Component.onCompleted`;
  unregister on `Component.onDestruction`. Get the rail from
  `manager.determineRailIndex(content)`.
- Subscribe to `InteractionManager.stripHovered[rail]` and
  `stripDragOver[rail]` for the strip-side signals.
- Capture `arrivalSeq = manager.requestBackground(content)` so you
  can read `manager.slotHover[seq]` / `slotDragOver[seq]` for
  envelope-side signals (these track hover/drag over the slot's
  bg + bridges; reliable from the first frame because envelope is
  sized from the stable target).
- For the panel itself, also wire `notePanelHover(hovered)` and
  `notePanelDragging(active)` callbacks called from the content's
  own `HoverHandler` / outer `DropArea` (these fire reliably because
  the content is the topmost Item over the bg painted rect).
- `_anyHovered` should OR every one of: sticky-strip (300 ms grace
  after `_stripHovered || _stripDragOver` drops), `_slotHovered`,
  `_slotDragOver`, `_panelHovered`, `_panelDragging`. Close on a
  transit-grace timer (≈100 ms) when all are false.
- If the panel also accepts drops, propagate an `incomingDrag` flag
  (= strip drag OR slot drag OR panel drag) so the content shows
  the drop-zone chooser through the entire transit from strip into
  inner tile DropAreas. The content's `_localDragging` should be
  the OR of `containsDrag` across the outer DropTracker + every
  inner tile (so Qt's drag-routing-to-topmost doesn't drop the
  flag when the drag moves into a tile).
- Hide on shortcut as a fallback (`VisibilitiesManager.setVisibility`).

### Stash drag-zone chooser

`modules/stash` has three mutually exclusive view states, picked from `_dragging` and `lsState`:

1. **Drop-zone chooser** (`_dragging && lsState === "idle"`) — two equal-size tiles. FilesTray has no background by default and overlays a `DashedRect` only while the cursor with a drag is over it. LocalSend has a primary-tinted fill whose alpha bumps on hover, and dropping there bypasses the stash dir entirely (calls `sendDroppedFiles`).
2. **File tray** (`!_dragging && lsState === "idle"`) — the GridView/ListView plus the action strip (refresh / open folder / send-all / clear-all).
3. **Device picker** (`lsState !== "idle"`) — `DevicePicker` covers everything; uses `DeviceUnit` rows with type icon + alias + IP badge + OS badge.

Tile dimensions swap with orientation via `Config.stash.dropZoneX` / `dropZoneY`: when `isVertical=true` width=x, height=y; when false they swap. The panel's overall size is content-driven — implicit width/height are computed from file count clamped by `rowsMax` / `colsMax`.

### LocalSend discover protocol

`scripts/localsend_discover.py` emits one line per device, tab-separated: `alias\tip\tdeviceType\tdeviceModel`. The `deviceType` is one of LocalSend's `mobile|laptop|desktop|tablet|headless`; `DeviceUnit.qml` maps it to a Tabler glyph and falls back to a CLI icon for anything unrecognised. `deviceModel` is shown verbatim as the OS/model badge (LocalSend doesn't have a separate OS field — the value comes through as-is).

### Commit style

Imperative present tense, short subject line (≤72 chars), body explains *why*. Co-author with `Claude Opus 4.7 <noreply@anthropic.com>` only when the user explicitly asks for a commit. Never commit without being asked.

### Verification before claiming done

For QML changes, after edits run `qmllint -I /home/pundemia/.config/quickshell/pShell -I /usr/lib/qt6/qml <files>` to catch obvious syntax. For C++ plugin changes, run `cmake --build build` to completion. Don't claim "works" unless the user has reloaded `qs -c pShell` and confirmed.
