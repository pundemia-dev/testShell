# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pShell is a desktop shell built on **Quickshell**, a Qt6-based Wayland shell framework. It targets the **Niri** compositor (Hyprland support is legacy and partially stripped on the active branch). The UI is written in QML; the C++ lives in two plugin modules under `plugin/pshell/`: **Caelestia.Blobs** (SDF-based rounded panel rendering) and **Caelestia** (`ImageAnalyser` — wallpaper luminance / dominant colour; plus `CUtils` — QML utility helpers).

**Key technologies:** QML/Qt6, C++20 (plugin only), Quickshell, CMake.

## Building and Running

### Prerequisites

- Qt6 (ShaderTools, Core, Qml, Gui, Quick, Concurrent)
- CMake 3.19+
- C++20 compiler
- Quickshell framework

### Build and Install

```bash
cmake -B build -S . -G Ninja
cmake --build build
sudo cmake --install build --prefix /usr   # installs Caelestia.Blobs + Caelestia to /usr/lib/qt6/qml
```

### Run

```bash
quickshell -c pShell
# or
qs -c pShell
```

### Logs

Quickshell writes runtime logs to `/run/user/<uid>/quickshell/by-id/<id>/log.qslog`. Errors usually appear in stderr too.

## Architecture & key files

Full architecture (rendering tree, Rails system, Wrapper contract, module system,
config schema, services, plugin modules):
→ [`docs/development/architecture.md`](docs/development/architecture.md)

Task → file lookup:
→ [`docs/development/key-files.md`](docs/development/key-files.md)

---

## Working conventions (rules for tasks)

These conventions exist because past iterations made mistakes here. Follow them by default; deviate only if the user asks.

### Reuse existing components — don't inline raw Rectangle/Text

Always prefer `StyledRect`, `StyledText`, `StyledIcon`, `IconButton`/`TextButton`/`IconTextButton`/`ToggleButton` (all on `ButtonBase`), `Anim`, `CAnim`, `StateLayer`, `SettingRow`, `CollapsibleSection`, `StyledProgressBar`, `LoadingIndicator`, `FadeImage`, `VerticalFadeFlickable`, `Colouriser`, `ColouredIcon`, etc. over raw `QtQuick` primitives. The styled wrappers carry palette bindings, font defaults, and animation Behaviors for free. If a styled variant doesn't exist for what you need, ask before introducing a new one.

### Porting components from caelestia

pShell's `components/` base is **ported from caelestia** (checkout under `tmp/caelestia/` when present). The full port log — Phases 0–5: M3 tokens+typescale → `Anim`/`CAnim`/`StyledText` → `ButtonBase`+button family → `StateLayer` (Shape ripple) → containers/fields → new comps (`FadeImage`/`LoadingIndicator`/`StyledProgressBar`/`Mask`/`VerticalFadeFlickable`) → `CUtils` + controlled `StyledSlider` + token migration/alias removal + dead-code prune — lives in the **[caelestia-component-refactor memory]**. When pulling another component over, apply these mechanical translations — then honour the pShell-specific contracts below (they diverge from caelestia on purpose; don't "fix" them back):

| caelestia | pShell |
|---|---|
| `import Caelestia.Config` + `Tokens.*` | `import qs.config` + `Appearance.*` |
| `Tokens.anim.<curve>` | `Appearance.anim.curves.<curve>` (curves sit one level deeper) |
| `easing: Tokens.anim.X` | `easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.curves.X` (pShell curves are `list<real>`, not prebuilt easings) |
| `Colours.palette.m3camelCase` | `Colours.palette.snake_case` (strip `m3`, camelCase→snake_case; note `m3neutral`/`m3success*` have no pShell equivalent) |
| `Tokens.font.*` builder (`.size().weight().build()`) | assign the typescale `font` value directly (`font: Appearance.font.body.small`); pShell has no FontBuilder |
| `MaterialIcon` | `StyledIcon` (Tabler) — and remap Material-Symbol glyph *names* → Tabler codepoints at the call site (see [[tabler-icon-codepoints]] memory) |
| `CUtils.*` | available as-is (`import Caelestia`) |

**pShell contracts that differ from caelestia:**
- **`StateLayer`** exposes an overridable **`function onClicked()`** (not caelestia's `onClicked:` signal). Its ripple is a `Shape`/`RadialGradient`, but the public API (`color`/`radius`/`rect` + corner-radius aliases/`showHoverBackground`/`function onClicked`) is pShell's — keep it so the 30+ existing consumers don't break.
- The button family extends **`ButtonBase`** (M3 colour logic + radius-morph on press). pShell keeps the property name **`toggle`** (not `isToggle`); buttons are rounded-rect by default (`defaultRadius` = `rounding.large`), pass `isRound: true` for a pill/circle.
- **`StyledSlider`** is **controlled**: it emits `interaction(v)` (v already mapped through `from`/`to` + `stepSize`) and does *not* self-update `value` on drag. Bind `value:` to your source and write it back from `onInteraction: v => …` — there is no `onMoved`/`onValueChanged` drag update.
- **`StyledIcon`** carries Tabler variable-font axes (`fill`/`grade` via `font.variableAxes`) — set `font.pointSize`/`font.family` on it, never assign a whole `font:` (that wipes the axes).

### Always use Appearance design tokens

Never hardcode pixel/ms/radius/font-size literals in module code. Always pull from `Appearance.rounding.*`, `Appearance.padding.*`, `Appearance.spacing.*`, the font typescale (`Appearance.font.{body,title,label,…}.*`), `Appearance.anim.durations.*`, `Appearance.anim.curves.*`. Hardcoded values lurk only in config defaults (`config/*config/` and `modules/<name>/config/`), where they're per-module configuration, not styling.

### Token scale & which step to use where

`rounding`/`spacing`/`padding` share one M3 step scale (`extraSmall 4 · small 8 · medium 12 · large 16 · largeIncreased 20 · extraLarge 28 · extraLargeIncreased 32 · extraExtraLarge 48`). **Pick a step by its role, not by eyeballing a pixel count** — these are the conventions caelestia follows (mined from its components), and matching them keeps pShell visually consistent with the ported base.

**`rounding` — corner radius**

| Step | Use for |
|---|---|
| `full` | pills & circles — switches, scrollbar handles, chips, avatars, dots, round `IconButton` |
| `extraLarge` (28) | large top-level surfaces — panels, sheets, dashboard / hover containers, big cards |
| `large` (16) | default interactive radius — buttons (`ButtonBase.defaultRadius`), input fields, standard cards |
| `medium` (12) | small tiles / nested containers, button **checked** state, tooltips, menu rows |
| `small` (8) | **pressed** state (radius-morph), tight internal rounding |
| `extraSmall` (4) | hairline joins — segment caps (often `extraSmall / 2`), slider track corners |

**`spacing` — gap *between* sibling items in a Row/Column/Grid**

| Step | Use for |
|---|---|
| `extraSmall` (4) | very tight — slider handle↔track, progress segments, calendar cells |
| `small` (8) | a closely-bound pair — icon↔text inside a control, label↔value |
| `medium` (12) | **default** gap between items in a layout |
| `large` (16) | gap between distinct groups / sub-sections |
| `largeIncreased`+ | big separations (rare) |

**`padding` — inset between a container edge and its content**

| Step | Use for |
|---|---|
| `extraSmall` (4) | ultra-compact (text-type icon button uses `extraSmall / 2`) |
| `small` (8) | compact control padding — icon buttons, vertical padding of text buttons / rows |
| `medium` (12) | **default** inner / content padding; text-button horizontal padding; section-header padding; tooltip |
| `large` (16) | card / panel content padding; toggle-button horizontal padding |
| `largeIncreased` / `extraLarge`+ | spacious padding on large surfaces (rare) |

**Fonts — assign the typescale by semantic role, not by size.** Each role is a full `font` (family + size + weight) bound wholesale (`font: Appearance.font.body.small`); ranks are `large`/`medium`/`small` (icon also `extraLarge`).

| Role | Use for |
|---|---|
| `headline.*` (32/28/24) | hero text — clocks, big numbers, top-of-page headers (rare) |
| `title.*` (22/16/14, Medium) | section & card titles, dialog headers |
| `body.*` (16/14/12, Normal) | running / content text — **`body.small` is the `StyledText` default**; the bulk of text |
| `label.*` (14/12/11, Medium) | affordance / secondary text — buttons, chips, tabs, captions, trailing / hint text, tooltips |
| `mono.*` | monospace / aligned numbers |
| `icon.*` (via `StyledIcon`) | `icon.medium` default glyph · `icon.large` prominent · `icon.extraLarge` hero · `icon.small` inline |

Prefer the typescale for anything text-role-shaped; the flat `font.size.{small…extraLarge}` is kept only for one-off point sizes (e.g. scaling a glyph). Migrating remaining `font.size.*` / `font.pointSize:` call sites to the typescale is fair game.

### Transparency & the `tPalette` rule

pShell has an opt-in translucency system ported from caelestia. Config is
`Config.general.transparency` (`enabled`, `base` = surface alpha, `layers` =
stacked-layer alpha); `services/Colours.qml` turns it into colours. **When you
write a new module/component, pick the fill colour by this rule:**

| What you're colouring | Use |
|---|---|
| Outermost surface of a panel / popup / card / window / button / bar widget, and `BlobGroup.color` of a standalone blob bg | **`Colours.tPalette.<role>`** |
| A surface **nested on top of** another tPalette/blob surface (card-in-a-card), by depth | **`Colours.layer(Colours.palette.<role>, N)`** (N = 2, 3, 4…) |
| Text, icons, outlines, borders, selected/active-state fills, explicit-alpha overlays | **`Colours.palette.<role>`** (opaque) or `Qt.alpha(Colours.palette.<role>, a)` |

- **`tPalette`** is a parallel palette where each role is pre-wrapped: surface/
  background roles (`surface`, `background`, `surface_dim`, `surface_bright`,
  `surface_variant`, `inverse_surface`) get **layer 0** (`base` alpha, no tint);
  every other role gets **layer 1** (`layers` alpha + a luminance/wallpaper-aware
  tint). When transparency is **off**, `tPalette.X === palette.X` exactly, so it's
  a zero-cost drop-in — there's no reason to use raw `palette.<surface role>` for
  an outer surface; default to `tPalette`.
- **`Colours.layer(c, n)`** — n=0 → `base` alpha; n≥1 → alpha + tint scaled by
  depth `n`. Use it (not tPalette) for nested cards: tPalette only emits layer
  0/1, so deeper nesting needs explicit `n` to stay visually distinct. A common
  shape is `Colours.transparency.enabled ? Colours.layer(palette.surface_container, 2) : palette.surface_container`
  (see `components/containers/SettingSection.qml`).
- **Never make text/icons/outlines/state-fills translucent** — they must read.
  And don't hand-roll panel translucency with `opacity:` or `Qt.rgba(...,0.x)`;
  route it through `tPalette`/`layer` so the global toggle + light/dark + wallpaper
  adaptation all apply uniformly.
- The SDF blob backgrounds in `WindowSlot.qml` are the **exception**: they
  replicate layer 0 manually in the shader fade path (`_fadeColor × _fadeMaxAlpha`).
  Don't bind `tPalette` there.
- Avoid the legacy `Colours.alpha(c, bool)` helper — its second arg is a bool
  (`layers` vs `base`) and it **ignores any numeric value** passed to it; reach for
  `tPalette`/`layer` instead.
- Supporting maths (rarely called directly): `Colours.alterColour(c, a, layer)`
  (the tint), `Colours.wallLuminance` (0..1 wallpaper luminance from the
  `Caelestia.ImageAnalyser` plugin), `Colours.wallpaperPath`. Frosted-glass blur
  (`Config.general.transparency.shaderBlur` / `blurInset`) is a separate shader
  path and doesn't change how you pick colours.

### Use the rails contract — don't add fields to it

If you need to add a window-level behaviour, first check whether an existing contract field (mode/pinned/reservesSpace/m*/p*) already covers it. Adding a new contract field is the last resort — it widens the public surface every module has to know about. (See [feedback memory on contract surface minimalism].)

Rail entries (`{ wrapper, arrivalSeq }` in `BackgroundsManager.rails`) are **identity-stable**: created once, spliced only by `finalizeRemoval`, never replaced or mutated in between. `Rail.qml` feeds them to `ScriptModel`s that diff by object identity — a replaced entry object destroys + recreates that WindowSlot delegate (and everything it hosts). Any transient per-entry state goes in the seq-keyed manager maps (`dyingState`, `slotRects`, `slotHover`, `slotDragOver`), not on the entry; external bindings over rail queries must also depend on `dyingState` (closing flips only the map, not `rails`). Details: [`docs/development/architecture.md`](docs/development/architecture.md) § Entry lifecycle.

### Niri-specific shortcut binding

When adding a keyboard shortcut for a module:
1. Register with `VisibilitiesManager.addVisibility(screen, name, ipcTarget, ...)`.
2. Document the niri-binds snippet in the module commit. Niri config is `~/.config/niri/config.kdl`, action `spawn "qs" "-c" "pShell" "ipc" "call" "<ipcTarget>" "activate"`.

### File layout for new modules

Modules are feature-sliced: the module owns everything in its domain; only the
entry point(s) live at the module root.

```
modules/<name>/
    <Name>Wrapper.qml         ← contract QtObject + lifecycle Loader (root holds only entry points)
    config/
        <Name>Config.qml      ← JsonObject (hot-reloaded)
        structures/<X>Data.qml ← nested JsonObject sub-types
    settings/
        <Name>Page.qml        ← official settings page (if any)
    content/
        <Name>Content.qml     ← top-level UI
        <other components>.qml
```

Register the config type in `config/Config.qml`'s adapter (`import qs.modules.<name>.config`). Import the wrapper in `drawers/Drawers.qml` and instance it as a sibling of the existing wrappers. Chrome/global configs (border, corners, backgrounds, popouts, general) stay in `config/<name>config/`; their settings pages stay in `modules/settings/pages/`.

Types loaded dynamically (`Qt.createComponent`) can't rely on implicit same-dir resolution (qsintercept), and the scanner only registers `qs.*` dirs imported from statically-reachable files — anchor the dir with an import from a static file and import it explicitly in the dynamic ones (see `modules/launcher/ModuleManager.qml`).

### Settings for a new module

- **Official module**: add `modules/<name>/settings/<Name>Page.qml` (a `Flickable` of `SettingSection`/`SettingRow` bound to `Config.<section>.*`) and register it in `SettingsContent.qml`'s `pages` array (`name`/`icon`/`scope`/`component`; import `qs.modules.<name>.settings`). Gate rarely-used controls with `advanced: true` on the row/section. Core/chrome pages (General, Themes, Borders, Corners, Backgrounds) live in `modules/settings/pages/`.
- **Plugin unit** (bar widget, launcher module, …): declare `settingsSchema: SettingsSchema { … }` on the unit's manifest and read values at runtime via `Config.getCustom(key, field, default)`. No `Config.qml` edit and no settings-page code needed — bar-widget schemas render inline on the Bar page (`WidgetSettings`), launcher-plugin schemas become standalone pages (`SettingsDiscovery`), both via `SchemaForm`. **Never widen the rails contract for settings state — it lives in `Config.custom`.**

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

### Lock screen (skins own ALL visuals)

Full guide: [`docs/development/lock.md`](docs/development/lock.md). Hard rules when touching `modules/lock`:
- Locking logic (WlSessionLock lifecycle, PAM, IPC) stays in the module core; **every visual lives in a skin** under `modules/lock/skins/<id>/`. Never add visuals to `LockSurface`/`LockWrapper`.
- Unlock is a handshake: `beginUnlock()` → skin exit anim → `finishUnlock()`; a 3s fallback force-unlocks. Don't set `locked = false` directly.
- Never focus anything from outside the skin (steals key focus → dead keyboard), never use ScreencopyView on the lock (niri refuses capture while locked — blur `Colours.wallpaperPath` instead), keep the surface opaque, and don't read `screen` before `LockSurface` creates the skin (assigned late by the compositor).
- Debug visuals with `qs -c pShell ipc call lock preview` (skin in a normal window + real PAM), not by locking the session.

### Commit style

Imperative present tense, short subject line (≤72 chars), body explains *why*. Co-author with `Claude Opus 4.8 <noreply@anthropic.com>` only when the user explicitly asks for a commit. Never commit without being asked. When committing, stage only the files for the task at hand — the working tree often carries unrelated in-progress changes (plugin edits, `tmp/`), so `git add` explicit paths, never `git add -A`.

### Verification before claiming done

For QML changes, syntax-check each file with `/usr/lib/qt6/qmlcachegen --resource-path /qs/<path> <path> -o /tmp/check.cpp` (exit 0 = clean). The system `qmllint` exits 255 silently on the big shell files even at HEAD, so don't rely on it — the PATH one is also Qt5. For C++ plugin changes, run `cmake --build build` to completion, then (to actually load new/changed types) `sudo cmake --install build --prefix /usr`. Don't claim "works" unless the user has reloaded `qs -c pShell` and confirmed — qmlcachegen validates syntax only, not plugin-import resolution.
