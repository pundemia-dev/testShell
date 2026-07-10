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
  Each `Rail` renders its slice of `manager.rails[i]` through two
  `ScriptModel`-backed Repeaters (pinned / dynamic). ScriptModel diffs by
  element identity, so opening or closing one bg touches exactly one delegate —
  rail siblings are never rebuilt.
- **One `contentLayer` (z=100)** — every module's content is reparented here
  with `z = arrivalSeq + 0.5`. Per-slot envelope Items (HoverHandler + DropArea)
  live here at z=−1.

Key files:
- `services/BackgroundsManager.qml` — `rails[][]`, `requestBackground/removeBackground`,
  `dyingState`, `reservedTop/Bottom/Left/Right`, zone helpers,
  `slotRects/slotHover/slotDragOver`.
- `drawers/backgrounds/components/Rail.qml` — sorts `pinned → push → overlay`.
- `drawers/backgrounds/components/WindowSlot.qml` — BlobRect + content Loader,
  position math, L-step, bridges, holdover, envelope.
  See [input-mask.md](./input-mask.md).

Entry lifecycle (close-anim latching): rail entries `{ wrapper, arrivalSeq }`
are **identity-stable** — created once in `requestBackground`, spliced out only
by `finalizeRemoval`. `removeBackground` doesn't touch `rails` at all: it
records the entry in the seq-keyed `manager.dyingState` map (with the last
painted rect as `deathRect`); the live `WindowSlot` sees `dying` flip via its
binding, collapses to 0, then calls `finalizeRemoval` for the real splice.
Re-requesting a dying wrapper revives it by clearing the map key (the in-flight
collapse reverses into a re-open, same `arrivalSeq`). **Never replace or mutate
an entry object, and never store per-entry state on it** — a new object
identity makes ScriptModel destroy + recreate that delegate; transient state
belongs in the seq-keyed maps (`dyingState`, `slotRects`, `slotHover`,
`slotDragOver`). Bindings that consume these queries outside the manager must
depend on `dyingState` too (see `BorderZone._dyingRef`), since a close no
longer reassigns `rails`.

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
| `modules/lock` | Session lock (ext-session-lock + PAM); visuals are swappable skin plugins. See [lock.md](./lock.md). |

New module file layout (feature-sliced — the module owns everything in its
domain; the root holds only the entry point(s)):
```
modules/<name>/
    <Name>Wrapper.qml            ← contract + lifecycle (only file(s) at root)
    config/
        <Name>Config.qml
        structures/<X>Data.qml   (if needed)
    settings/
        <Name>Page.qml           (official settings page, if any)
    content/
        <Name>Content.qml        ← top-level UI + local components
    <slot>/                      (optional extension point, e.g. dashboard pages/)
```
Register the config type in `config/Config.qml`'s adapter (import
`qs.modules.<name>.config`). Import and instance the wrapper in
`drawers/Drawers.qml`. Register the settings page in `SettingsContent.qml`
(import `qs.modules.<name>.settings`); see [settings.md](./settings.md).
Chrome/global configs (border, corners, backgrounds, popouts, general) stay in
`config/<name>config/` and their pages in `modules/settings/pages/`.

### Extension points (modularity inside a module)

When a module hosts pluggable units (dashboard pages, AI pages, bar widgets,
launcher modules), use the shared mechanics instead of a bespoke manager:

- **Unit layout**: `<slot>/<id>/<id>.<slot-singular>.qml` — a manifest
  (`components/misc/PluginManifest.qml`: `id`/`title`/`icon`/`order`/
  `settingsSchema`/lazy `Component content`) plus its implementation files in
  the same folder. Subclass the manifest if the slot needs extra fields.
  A unit folder is **fully self-contained** — implementation, popout content,
  helpers, settings schema all live inside it, so installing a third-party
  unit (the future widget store) means dropping one folder in, nothing else.
  Shared visuals come from `qs.components*`; bar-widget implementations are
  loaded via `file://` URLs (`WidgetHost`), which is what makes same-dir
  types inside the folder resolve (qsintercept URLs can't).
- **Discovery**: instance `components/misc/PluginRegistry.qml` with `folder`,
  `suffix`, and optionally `order`/`disabled` bound to the host config
  (blocklist semantics: everything found is active unless disabled). It
  exposes `all` and `active`; rendering stays host-specific. See
  `modules/dashboard/content/DashboardRegistry.qml` for the canonical binding.
- Manifests are loaded dynamically — they must explicitly import every module
  they use (`qs.components.misc` etc.); implicit same-dir resolution doesn't
  work through qsintercept.
- **Launcher slot** (`modules/launcher/plugins/<id>/<id>.plugin.qml`): the
  manifest subclass is `LauncherManifest` (adds `description`/`trigger`), the
  content root extends `LauncherModule` — both from
  `qs.modules.launcher.content` (anchored by `ModuleManager`'s static import).
  `ModuleManager` keeps the host state machine (default/selecting/active, FZF,
  magic symbol) but takes its module list from `LauncherRegistry`
  (`Config.launcher.order`/`.disabled`, blocklist; `active[0]` = default
  module) and instantiates a module's `content` lazily on first activation.
  Per-module settings ship as `settingsSchema` on the manifest and surface as
  standalone settings pages via `modules/settings/SettingsDiscovery.qml`.

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
| `Config.bar` | `modules/bar/config/BarConfig.qml` | |
| `Config.launcher` | `modules/launcher/config/LauncherConfig.qml` | plugin `order[]`/`disabled[]` |
| `Config.notifs` | `modules/notifications/config/NotifsConfig.qml` | |
| `Config.toasts` | `modules/toasts/config/ToastsConfig.qml` | shell/OS toasts — see `docs/development/toasts.md` |
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
  a `<id>.page.qml` manifest (`components/misc/PluginManifest.qml`:
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

**`plugin/pshell/`** — pShell's own:
- `Caelestia.Blobs` — SDF panel renderer. Types: `BlobGroup` (`smoothing`,
  `stickSmooth`), `BlobRect` (`radius`, per-corner radii, `zoneIndex`, `sticks`),
  `BlobInvertedRect` (`borderLeft/Right/Top/Bottom`, `zoneRoundings`).
  Cap: 16 rects per group. Shader details: [border-zones.md](./border-zones.md).
- `Caelestia` — `ImageAnalyser` (wallpaper luminance/dominant colour, off-thread
  via QtConcurrent) + `CUtils` singleton (`clamp`, `saveItem`, `copyFile`,
  `deleteFile`, `toLocalFile`, `version`, `qtVersion`).

**`plugin/vendor/caelestia/`** — vendored caelestia modules (dashboard backing):
- `Caelestia.Config` — GlobalConfig/Tokens/Appearance (parallel config system,
  NOT pShell's `qs.config`)
- `Caelestia.Internal` — sparkline, visualiser bars, CircularBuffer,
  LinearIndicatorManager
- `Caelestia.Services` — Cpu/Gpu/Memory/Storage sensors + audio/beat/cava +
  `UsageFmt`/`ServiceRef`
- `Caelestia.Components` — WavyLine, ButtonRow, LazyListView

System deps: pipewire, aubio, libsensors, libcava.

**`plugin/vendor/m3shapes/`** — vendored `M3Shapes`: organic shapes (Pill/Gem/ClamShell/
Diamond/Sunny/Cookie…) + `distanceAtAngle`/`pointAtAngle`.

All install to `/usr/lib/qt6/qml/`. C++ changes require:
```bash
cmake --build build
sudo cmake --install build --prefix /usr
# then reload: qs -c pShell
```


