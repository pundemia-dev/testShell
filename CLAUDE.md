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
    ├── Border, Corners     ← visual chrome
    ├── Backgrounds         ← SDF Rails system (see below)
    ├── BarWrapper, LauncherWrapper, NotificationsWrapper, StashWrapper
    └── NiriFocusGrab       ← Niri-specific focus capture
```

### Backgrounds: Rails system (post-Phase A–D)

`drawers/backgrounds/Backgrounds.qml` owns:

- **One `BlobGroup`** (Caelestia.Blobs) — SDF compositor for all painted backgrounds. Backgrounds render at z=0.
- **One `RailBorder`** — `BlobInvertedRect` at screen edges. Default invisible (frame outside viewport); enable per-side `<side>Join` for SDF stick-to-edge.
- **9 `Rail` instances**, one per anchor position (topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight). Each `Rail` is a Repeater over its slice of `manager.rails[i]`.
- **One `contentLayer` (`z: 100`)** — every window's `wrapper.content` (and overlay-mode bgs) is reparented here with `z = arrivalSeq + 0.5`, so new content always paints above old content cross-rail.

The whole renderer is in:

- `utils/BackgroundsManager.qml` — `rails[][]` state, `requestBackground(wrapper)`, `removeBackground(wrapper)`, `reservedTop/Bottom/Left/Right` (aggregated exclusion).
- `drawers/backgrounds/components/Rail.qml` — sorts `pinned → push → overlay`, drives Repeater.
- `drawers/backgrounds/components/WindowSlot.qml` — single window: BlobRect + content Loader, position math, **L-step** for layer 2 on corner rails when a side reservation exists.
- `drawers/backgrounds/components/RailBorder.qml` — screen-edge SDF frame.

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
    readonly property int layer: 0      // assigned by Rail
    property int windowRounding: -1
    property int invertedJoinRounding: -1

    property Component content: null
}
```

Call sites:
```qml
manager.requestBackground(wrapper)
manager.removeBackground(wrapper)
```

**Don't pass legacy positional args** (`isolate`, `excludeBarArea`) — they're gone.

### Module System

Each module is `modules/<name>/<Name>Wrapper.qml` + `modules/<name>/content/`. The wrapper owns the contract object(s) and lifecycle; content is a `Component` that renders the actual UI.

| Module | Purpose |
|--------|---------|
| `modules/bar` | Status bar (3 pinned segments: begin/center/end) |
| `modules/launcher` | Application launcher with pluggable search |
| `modules/notifications` | D-Bus notification popups |
| `modules/stash` | File tray (drag/drop + LocalSend share); hover-trigger demo |
| `modules/settings` | Settings UI |

### Visibility & Focus

- `utils/VisibilitiesManager.qml` — per-monitor show/hide hub. `addVisibility(screen, name, shortcut, isolated, autostart, description)` registers the module; `setVisibility(screen, name, bool)` toggles.
- Shortcuts on Niri use `Quickshell.Io.IpcHandler` (see `components/misc/CustomShortcut.qml`). There's no `hyprland_global_shortcuts_v1` on Niri — bind in `~/.config/niri/config.kdl`:
  ```kdl
  binds {
      Mod+Space hotkey-overlay-title="Toggle launcher" {
          spawn "qs" "-c" "pShell" "ipc" "call" "launcher" "activate";
      }
  }
  ```
- `utils/FocusManager.qml` — coordinates keyboard focus via `NiriFocusGrab`. Modules call `FocusManager.requestFocus(name)` / `releaseFocus(name)`.

### Configuration

`config/Config.qml` reads `~/.config/pShell/shell.json` (hardcoded path; intended `Paths.config`). Sub-configs live in `config/<name>config/`:

- `Config.bar` → `barconfig/BarConfig.qml`
- `Config.launcher` → `launcherconfig/LauncherConfig.qml`
- `Config.notifs` → `notifsconfig/NotifsConfig.qml`
- `Config.backgrounds`, `Config.border`, `Config.corners`
- `Config.stash` → `stashconfig/StashConfig.qml`

`config/Appearance.qml` is the design-token singleton: `rounding.{small,normal,large,full,scale}`, `padding.*`, `spacing.*`, `font.family.{sans,mono,tabler}`, `font.size.*`, `anim.curves.*`, `anim.durations.*`. **Always reference these — never hardcode pixel/ms values.**

### Services

Singletons in `services/`:

- `Niri.qml` — workspaces, toplevels, `dispatch()`
- `Notifs.qml` — D-Bus notification server
- `Network.qml` / `Nmcli.qml`
- `Colours.qml` — dynamic palette (matugen)
- `Time.qml`
- `WallpaperState.qml`

### Caelestia.Blobs plugin

`plugin/src/Caelestia/Blobs/` — SDF panel renderer ported verbatim from upstream caelestia. Builds a single Qt scene-graph material that merges multiple `BlobRect`s and `BlobInvertedRect`s into one shader pass with optional inverted-corner joins. Exposed types:

- `BlobGroup` — shared SDF compositor.
- `BlobRect` — rounded rectangle in the group (radius, deformScale, per-corner radii).
- `BlobInvertedRect` — frame with rounded inner cutout.
- `BlobShape` (base).

**Cap: 16 rects per `BlobGroup`.** All shell panels share one group in `Backgrounds.qml`.

## Key Files by Task

| Task | File(s) |
|------|---------|
| Color scheme / design tokens | `config/Appearance.qml`, `services/Colours.qml` |
| Bar layout sections | `modules/bar/content/Begin.qml`, `Center.qml`, `End.qml` |
| Bar thickness/position | `config/barconfig/BarConfig.qml`, `modules/bar/BarWrapper.qml` |
| Backgrounds rendering | `drawers/backgrounds/Backgrounds.qml`, `drawers/backgrounds/components/*.qml`, `utils/BackgroundsManager.qml` |
| Wrapper contract examples | `modules/{bar,launcher,notifications,stash}/*Wrapper.qml` |
| Keyboard input regions | `utils/InputManager.qml` |
| Edge reservation (exclusion zones) | `drawers/Drawers.qml` (`reservedEdge` aggregation), `drawers/exclusions/Exclusions.qml` |
| Niri integration | `services/Niri.qml`, `utils/NiriFocusGrab.qml` |
| LocalSend integration | `modules/stash/content/StashContent.qml`, `scripts/localsend_{discover,send}.sh` |

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

### Hover-trigger pattern (auto-hide drawers)

When implementing hover-driven panels (like `modules/stash`):
- 4–8px trigger strip at the relevant screen edge with `HoverHandler` + `DropArea` (for drag-to-open).
- Track combined hover state of the trigger AND the open panel in the wrapper.
- `Timer` with `Config.<module>.autoHideMs` to close after both lose hover.
- Hide on shortcut as a fallback (`VisibilitiesManager.setVisibility`).

### Commit style

Imperative present tense, short subject line (≤72 chars), body explains *why*. Co-author with `Claude Opus 4.7 <noreply@anthropic.com>` only when the user explicitly asks for a commit. Never commit without being asked.

### Verification before claiming done

For QML changes, after edits run `qmllint -I /home/pundemia/.config/quickshell/pShell -I /usr/lib/qt6/qml <files>` to catch obvious syntax. For C++ plugin changes, run `cmake --build build` to completion. Don't claim "works" unless the user has reloaded `qs -c pShell` and confirmed.
