# pShell architecture

## Entry point & rendering layer

`shell.qml` → `drawers/Drawers.qml` (`WlrLayershell`, ExclusionMode.Ignore).
Per-screen tree:

```
Screen
└── Drawers (WlrLayershell)
    ├── Exclusions          ← per-side ExclusionZone windows (border floor)
    ├── Corners             ← visual rounded-corner chrome
    ├── Border              ← visible border chrome — FIRST child (lowest z)
    ├── Backgrounds         ← SDF Rails system
    ├── BarWrapper, LauncherWrapper, NotificationsWrapper, StashWrapper, DashboardWrapper
    ├── Borders             ← 8 BorderZone INPUT strips only — LAST (topmost)
    └── NiriFocusGrab       ← Niri-specific focus capture
```

`Border` is FIRST so it renders below all panel content (content layer z=100).
`Borders` is LAST so strips stay topmost and catch hover/click/slide/drop first.

## Backgrounds: Rails system

`drawers/backgrounds/Backgrounds.qml` owns:

- **One `BlobGroup`** — SDF compositor for all painted backgrounds (z=0).
- **One `BlobInvertedRect`** at screen edges, carrying 8-element `zoneRoundings`
  for per-zone SDF присасывание. Lives inside `bgRenderHost`.
  See [border-zones.md](./border-zones.md).
- **9 `Rail` instances**, one per anchor position (topLeft … bottomRight).
  Each `Rail` is a Repeater over its slice of `manager.rails[i]`.
- **One `contentLayer` (z=100)** — every module's content is reparented here
  with `z = arrivalSeq + 0.5`. Per-slot envelope Items (HoverHandler + DropArea)
  live here at z=−1.

Key files:
- `services/BackgroundsManager.qml` — `rails[][]`, `requestBackground/removeBackground`,
  `reservedTop/Bottom/Left/Right`, zone helpers, `slotRects/slotHover/slotDragOver`.
- `drawers/backgrounds/components/Rail.qml` — sorts `pinned → push → overlay`.
- `drawers/backgrounds/components/WindowSlot.qml` — BlobRect + content Loader,
  position math, L-step, bridges, holdover, envelope.
  See [input-mask.md](./input-mask.md).

## Wrapper contract

Every module registers with `BackgroundsManager` via a `QtObject`:

```qml
QtObject {
    // Size (0 = auto from content)
    property int wrapperWidth: 0; property int wrapperHeight: 0
    property int pLeft, pTop, pRight, pBottom

    // Anchor (chooses rail)
    property bool aLeft, aRight, aTop, aBottom
    property bool aHorizontalCenter, aVerticalCenter

    // Margins
    property int mLeft, mRight, mTop, mBottom
    property int vCenterOffset, hCenterOffset

    // Stacking semantics
    property string mode: "push"        // "push" | "overlay"
    property bool pinned: false         // visually fixed at layer 1
    property bool reservesSpace: false  // → wlr-layer-shell exclusion zone
    property bool sticks: true          // false → no SDF merge, clean floating contour
    readonly property int layer: 0      // assigned by Rail
    property int windowRounding: -1

    property Component content: null
}
```

```qml
const arrivalSeq = manager.requestBackground(wrapper)
// subscribe to manager.slotRects[seq] / slotHover[seq] / slotDragOver[seq]
manager.removeBackground(wrapper)
```

**Margin direction for layer-2+ slots**: gap to prev is taken from **this
slot's own facing margin** (`mLeft` when prev is to the left, `mTop` when prev
is above) — NOT `prev.mRight`/`prev.mBottom`.

## Module system

Each module is `modules/<name>/<Name>Wrapper.qml` + `modules/<name>/content/`.
Wrapper owns the contract object(s) and lifecycle; content is a `Component`.

| Module | Purpose |
|--------|---------|
| `modules/bar` | Status bar (3 pinned segments: begin/center/end) |
| `modules/launcher` | Application launcher |
| `modules/notifications` | D-Bus notification popups |
| `modules/stash` | File tray + LocalSend; hover-trigger; two-zone drag chooser |
| `modules/settings` | Settings UI (normal Window). See [settings.md](./settings.md). |
| `modules/dashboard` | Hover dashboard; modular self-discovering pages |

New module file layout:
```
modules/<name>/
    <Name>Wrapper.qml
    content/
        <Name>Content.qml
config/<name>config/
    <Name>Config.qml
    structures/<X>Data.qml   (if needed)
```
Register the config in `config/Config.qml`. Import and instance the wrapper in
`drawers/Drawers.qml`. Add a settings page per [settings.md](./settings.md).

## Visibility, focus & interaction

- `services/VisibilitiesManager.qml` — `addVisibility(screen, name, shortcut,
  isolated, autostart, description)` / `setVisibility(screen, name, bool)`.
- `services/InteractionManager.qml` — per-rail hover/slide/drop stacks.
  See [interaction-manager.md](./interaction-manager.md).
- `services/FocusManager.qml` — `requestFocus(name)` / `releaseFocus(name)` via
  `NiriFocusGrab`.
- `services/InputManager.qml` — layershell input mask. See [input-mask.md](./input-mask.md).

Niri shortcuts use `Quickshell.Io.IpcHandler` (`components/misc/CustomShortcut.qml`).
Bind in `~/.config/niri/config.kdl`:
```kdl
binds {
    Mod+Space { spawn "qs" "-c" "pShell" "ipc" "call" "launcher" "activate"; }
}
```

## Configuration

`config/Config.qml` reads `~/.config/pShell/shell.json`. Feature modules own
their sub-config (`modules/<name>/config/`); chrome/global sub-configs stay in
`config/<name>config/`:

| Key | File | Notes |
|-----|------|-------|
| `Config.bar` | `barconfig/BarConfig.qml` | |
| `Config.launcher` | `modules/launcher/config/LauncherConfig.qml` | |
| `Config.notifs` | `modules/notifications/config/NotifsConfig.qml` | |
| `Config.backgrounds` | `backgroundsconfig/BackgroundsConfig.qml` | |
| `Config.border` | `borderconfig/BorderConfig.qml` | visible chrome + 8 zonal `zoneRoundings` |
| `Config.corners` | `cornersconfig/CornersConfig.qml` | |
| `Config.stash` | `modules/stash/config/StashConfig.qml` | |
| `Config.capture` | `modules/capture/config/CaptureConfig.qml` | |
| `Config.ai` | `modules/ai/config/AiConfig.qml` | |
| `Config.popouts` | `popoutsconfig/PopoutsConfig.qml` | |
| `Config.general` | `generalconfig/GeneralConfig.qml` | `advanced` toggle, shell-wide prefs |
| `Config.dashboard` | `modules/dashboard/config/DashboardConfig.qml` | per-page tokens, `order[]`/`disabled[]` |
| `Config.custom` | open `var` map | third-party settings; `getCustom(key, field, fallback)` / `setCustom(key, field, value)` |

Presets: `~/.config/pShell/presets/<scope>/<name>.json`, managed by
`services/PresetsManager.qml` (IPC target `presets`).

`config/Appearance.qml` — design-token singleton (M3 scale). CLAUDE.md has the
full token usage rules.

## Dashboard module

Hover-triggered panel (default: top-center) hosting **modular self-discovering pages**.

- **Wrapper** `DashboardWrapper.qml` — opens on hover via
  `InteractionManager.registerHover`; `mode: "push"`.
- **Page contract** — each page is a folder `modules/dashboard/pages/<id>/` with
  a `<id>.page.qml` manifest (`components/misc/DashboardPage.qml`:
  `id`/`title`/`icon`/`order`/`Component content`).
  `content/DashboardRegistry.qml` auto-discovers via `FolderListModel`.
  Add a folder → tab appears automatically; no hardcoded tab list.
- **UI** `content/DashboardContent.qml` — tab bar + swipeable pages.
  Every page outer item **must** expose `implicitHeight`/`implicitWidth` (missing
  it collapses the Flickable). Tab `currentIndex` is one-way input + `tabClicked`
  signal (writing it internally breaks swipe → indicator freezes).
- **Config** `Config.dashboard`: enabled, anchors, margins, padding, rounding,
  shortcut, autoHideMs, `order[]`/`disabled[]` (reassign whole array so
  JsonAdapter persists), weather, per-page tokens
  (`dash`/`media`/`performance`/`weather`), perf `show*` toggles.
- **Services**: `Players.qml` (MPRIS), `Weather.qml` (open-meteo XHR),
  `NetworkUsage.qml` (`/proc/net/dev`), `Audio.qml` (CavaProvider+BeatTracker),
  `SysInfo.qml` (uptime/wm/os). `SystemUsage.qml` is a lightweight `/proc`
  fallback; perf pages use `Caelestia.Services` sensors instead.
- **Rich components**: `components/controls/DashProgress.qml` (sweep gauges +
  wavy arc) and `StyledProgressBar.qml` (linear bar, backed by
  `Caelestia.Internal` + `CUtils`).

## Services

Singletons in `services/`:

| Service | Purpose |
|---------|---------|
| `Niri.qml` | Workspaces, toplevels, `dispatch()` |
| `Notifs.qml` | D-Bus notification server |
| `Network.qml` / `Nmcli.qml` | Network state |
| `Colours.qml` | Dynamic palette (matugen); `palette`/`tPalette`/`layer()`/`alterColour()`/`wallLuminance` |
| `Time.qml` | Clock |
| `WallpaperState.qml` | Current wallpaper per monitor (`forMonitor(name).path`) |
| `Players.qml` | MPRIS |
| `Weather.qml` | open-meteo via XHR; loc/units from `Config.dashboard` |
| `NetworkUsage.qml` | `/proc/net/dev` speeds/totals + history (CircularBuffer) |
| `Audio.qml` | CavaProvider + BeatTracker for the media visualiser |
| `SysInfo.qml` | Uptime / WM / OS glyph |

`services/Icons.qml` — `getWeatherIconWmo(code)` (WMO → tabler).

## Plugin modules

Three `add_subdirectory`s in top-level `CMakeLists.txt`.

**`plugin/src/Caelestia/`** — pShell's own:
- `Caelestia.Blobs` — SDF panel renderer. Types: `BlobGroup` (`smoothing`,
  `stickSmooth`), `BlobRect` (`radius`, per-corner radii, `zoneIndex`, `sticks`),
  `BlobInvertedRect` (`borderLeft/Right/Top/Bottom`, `zoneRoundings`).
  Cap: 16 rects per group. Shader details: [border-zones.md](./border-zones.md).
- `Caelestia` — `ImageAnalyser` (wallpaper luminance/dominant colour, off-thread
  via QtConcurrent) + `CUtils` singleton (`clamp`, `saveItem`, `copyFile`,
  `deleteFile`, `toLocalFile`, `version`, `qtVersion`).

**`plugin/caelestia/`** — vendored caelestia modules (dashboard backing):
- `Caelestia.Config` — GlobalConfig/Tokens/Appearance (parallel config system,
  NOT pShell's `qs.config`)
- `Caelestia.Internal` — sparkline, visualiser bars, CircularBuffer,
  LinearIndicatorManager
- `Caelestia.Services` — Cpu/Gpu/Memory/Storage sensors + audio/beat/cava +
  `UsageFmt`/`ServiceRef`
- `Caelestia.Components` — WavyLine, ButtonRow, LazyListView

System deps: pipewire, aubio, libsensors, libcava.

**`plugin/m3shapes/`** — vendored `M3Shapes`: organic shapes (Pill/Gem/ClamShell/
Diamond/Sunny/Cookie…) + `distanceAtAngle`/`pointAtAngle`.

All install to `/usr/lib/qt6/qml/`. C++ changes require:
```bash
cmake --build build
sudo cmake --install build --prefix /usr
# then reload: qs -c pShell
```
