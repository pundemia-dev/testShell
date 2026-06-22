# Settings module — design

`modules/settings` is the GUI front-end for `~/.config/pShell/shell.json`.
It is a normal `Window` (not a layershell), toggled via the `settings`
IPC shortcut. This document is the living design for the module: the
config plumbing, the preset system, the contract that lets third-party
modules surface their own settings, inline hints, and the basic/advanced
split. The visual language is adapted from `dots-hyprland` (end-4 `ii`),
mapped onto pShell's existing styled components.

> Status: design fixed, implementation phased (see [Phases](#phases)).
> Existing skeleton: `modules/settings/{Settings,SettingsContent}.qml`
> + `pages/PlaceholderPage.qml`.

## Goals

1. **Edit `shell.json` from the UI** with two-way binding — no manual JSON.
2. **Presets** — full-config "themes" *and* per-module presets, saved/
   applied/renamed/deleted, switchable fast.
3. **Modularity** — a user who drops a new bar widget or launcher module
   gets its settings in the UI automatically, via a lightweight contract.
   Official modules need nothing extra (they have hand-written pages).
4. **Hints** — optional per-control help: text, image, GIF, or any combo,
   rendered above everything (never clipped by the content pane).
5. **Basic / Advanced** — a global toggle; advanced reveals *all* fields,
   sections, and pages.

---

## Layer 0 — Config plumbing

`config/Config.qml` owns one `FileView` + `JsonAdapter` over `shell.json`.
The adapter already gives us everything for editing:

- Assigning `Config.bar.thickness.all = 50` → `onAdapterUpdated` →
  `writeAdapter()` writes the file.
- External file change → `onFileChanged` → `reload()` repopulates the tree.

So the settings pages just **two-way bind** to `Config.<section>.*`. Preset
apply (Layer 1) and hand-editing the file stay consistent for free, because
everything funnels through the adapter or through the file.

Two additions to the adapter:

```qml
JsonAdapter {
    id: adapter
    // ... existing typed sub-configs ...
    property GeneralConfig general: GeneralConfig {}  // NEW
    property var custom: ({})                          // NEW — third-party bag
}
```

- `general` → new `config/generalconfig/GeneralConfig.qml`, a `JsonObject`
  holding shell-wide prefs; for the settings UI it carries
  `property bool advanced: false` (the basic/advanced toggle state).
- `custom` → an open map for third-party module values (see
  [Contract](#layer-2--contract-for-third-party-modules)). Serialized as a
  plain object; not part of the rails contract.

> Aside: the `FileView.path` is currently hard-coded to
> `/home/pundemia/.config/pShell/shell.json`. Switching it to
> `${Paths.config}/shell.json` is desirable but orthogonal to this work.

---

## Layer 1 — Presets

### Storage

Preset scope keys are the adapter section names (≈ the `*config/` folders):
`bar launcher border corners backgrounds notifs stash capture popouts`,
plus `general`, `custom`, and the special `full`.

```
~/.config/pShell/
    shell.json                  ← active config
    presets/
        full/    <name>.json    ← whole-shell.json snapshot (a "theme")
        bar/     <name>.json    ← only the bar section
        launcher/<name>.json
        border/  <name>.json
        ...
```

### Apply mechanism — through the file, not bindings

Applying a preset is **always** "build a new `shell.json` object and write
it once, then let `reload()` repopulate the tree". This is atomic and
avoids per-leaf binding churn from the auto-writer.

- **Apply full**: write `presets/full/<name>.json` → `shell.json`.
- **Apply module**: read `shell.json`, splice `obj[scope] = preset`, write
  back. `onFileChanged` → `reload()`.
- **Save full**: copy `shell.json` → `presets/full/<name>.json`.
- **Save module**: `JSON.parse(shell.json)[scope]` → `presets/<scope>/<name>.json`.

Presets operate on the **file**, not on UI visibility — so a theme authored
in advanced mode applies correctly for someone in basic mode (hidden
advanced fields are still written/read).

### `utils/PresetsManager.qml` (new Singleton)

```qml
pragma Singleton
Singleton {
    readonly property var scopes: [/* section names */, "full", "general", "custom"]

    function listPresets(scope) -> [names]
    function savePreset(scope, name)
    function applyPreset(scope, name)
    function deletePreset(scope, name)
    function renamePreset(scope, from, to)
}
```

Read/write via `Quickshell.Io.FileView` (a small pool of dynamically
created FileViews, or one scratch FileView with path swapping). Testable
headless over IPC before any UI exists.

### Preset UI

- `components/PresetBar.qml` — a row shown on each page: a dropdown of saved
  presets for that scope + Save / Apply / Rename / Delete. Destructive
  actions confirm first.
- `pages/ThemesPage.qml` — `full` snapshots as theme cards (apply/save/delete).

---

## Layer 2 — Contract for third-party modules

Official modules: hand-written pages + typed `JsonObject` sub-configs (full
control, max polish). **Third-party** modules use a lightweight declarative
contract that the settings UI renders with a generic form.

### `components/SettingsSchema.qml` (new base type)

```qml
QtObject {
    property string title: ""
    property string icon:  ""      // tabler glyph
    property string key:   ""      // subtree key inside Config.custom
    property var fields: []        // see field descriptor below
    property bool advanced: false  // whole-schema advanced gate (optional)
}
```

A module ships its schema as a **lightweight sibling file** (no heavy deps),
so discovery can load just the schema without instantiating the live widget:

- bar widget `Weather.qml` → optional `Weather.settings.qml` (a
  `SettingsSchema { ... }`).
- launcher module `WeatherModule.qml` → optional
  `property var settingsSchema` + `property string settingsKey` on the
  already-loaded instance (the `LauncherModule.qml` base gains these as
  `null` / `moduleId` defaults).

### Field descriptor

```js
{
    key: "interval",            // key inside Config.custom[schema.key]
    type: "int",                // see table
    label: "Refresh, min",
    description: "...",         // optional secondary line
    default: 30,
    advanced: false,            // hidden unless advanced mode
    hint: { text, media },      // optional, see Hints
    // type-specific extras:
    min: 5, max: 120, step: 1,  // int / real
    options: ["C", "F"]         // enum / multi
}
```

| `type`   | control (`components/...`)          | extras            |
|----------|-------------------------------------|-------------------|
| `bool`   | `controls/StyledSwitch`             | —                 |
| `int`    | `controls/CustomSpinBox`            | min, max, step    |
| `real`   | `controls/CustomSpinBox` (step<1)   | min, max, step    |
| `string` | `controls/StyledTextField`          | placeholder       |
| `enum`   | chip row (selectable pills)         | options[]         |
| `multi`  | checkbox group *(TODO)*             | options[]         |
| `color`  | swatch + picker dialog *(TODO)*     | —                 |

> Controls are placed bare into a `SettingRow` slot (label + description +
> hint + advanced gate), not the "fat" `SwitchRow`/`SpinBoxRow` variants, so
> every field type gets uniform description/hint/advanced handling. `multi`
> and `color` are deferred past Phase 1.

### `components/controls/SchemaForm.qml` (new)

Repeater over `schema.fields` → maps `type` → the control above → binds the
value to `Config.custom[schema.key][field.key]`, writing back on change.
Seeds defaults from the schema into `Config.custom[key]` on first show.
Resolves `field.hint.media` relative to the schema file (`Qt.resolvedUrl`).

### Where third-party values live

In the open `Config.custom` bag, keyed by `schema.key`:

```qml
// third-party widget reads its own config:
property int interval: Config.custom["weather"]?.interval ?? 30
```

The author never edits `Config.qml`. Minimal contract: ship a schema, read
from `Config.custom[key]`. This deliberately does **not** widen the rails
contract.

### Discovery

The active config already names the modules that exist:
`Config.bar.{begin,center,end}Layout` (widget names) and
`Config.launcher.modules`. For each name the settings UI tries to load
`<Name>.settings.qml`; if present → a generic page via `SchemaForm`.
Launcher modules expose their schema directly on the loaded instance
(`moduleManager.loadedModules[i].settingsSchema`).

> Future: a `FolderListModel` scan of `modules/bar/content/components/` to
> offer an "add a widget that isn't in the layout yet" picker.

---

## Hints

Optional per-control help. Any combination of text and one media file; the
five cases (text / text+photo / text+gif / photo / gif) collapse to **two
fields** — media type (static vs animated) is auto-detected by extension.

```js
hint: {
    text:  "...",          // optional
    media: "preview.gif"   // optional; .gif/.webp → AnimatedImage, else Image
}
```

### Why `Popup` solves clipping

The content pane (`StyledRect` with `clip: true`) would clip a child. Qt
Quick Controls `Popup` reparents into the window's overlay layer when
opened, so it always renders **above everything and outside the clip**.
The existing `components/controls/Tooltip.qml` is a text-only `Popup`; we
keep it for plain button tooltips and add a richer hint component.

### Components

- `components/controls/Hint.qml` (on `Popup`): props `target`, `text`,
  `media`, `delay`, `mediaMaxWidth/Height` (clamp so a big GIF doesn't blow
  up the popup, ~320px). Content = `ColumnLayout { Loader(media) + StyledText }`
  in a `StyledRect` with `Elevation`. Reuses Tooltip's `updatePosition()`
  bounds-clamp logic.
- `components/controls/HintIcon.qml`: a small info glyph (tabler
  `` / help ``) with a `HoverHandler`. Shown only when a hint
  exists (optionality is free). Hover opens the `Hint`; click pins it open
  (handy for GIFs), click/Esc closes.

### Integration

- **Schema** (third-party): `field.hint` → `SchemaForm` passes it into the
  row → `HintIcon` next to the label.
- **Hand-written pages**: `components/SettingRow.qml` gains optional
  `property string hintText` + `property url hintMedia`; when non-empty it
  draws a `HintIcon` in the label column. One line per existing row.

Media for official modules lives under an assets dir (e.g.
`modules/settings/assets/hints/`); third-party media sits next to their
module and is resolved relative to the schema file.

---

## Basic / Advanced split

Binary: **basic** hides advanced elements, **advanced** shows *everything*.
State persisted in `Config.general.advanced`; toggled by a switch in the
settings header. One visibility rule everywhere:

```qml
visible: !element.advanced || Config.general.advanced
```

Three granularities (use any):

1. **Field** — `field.advanced: true` (schema) / `property bool advanced`
   on `SettingRow`.
2. **Section** — `property bool advanced` on `SettingSection` (hides a whole
   block, e.g. SDF blob internals).
3. **Page / nav-item** — `advanced: true` in the page descriptor; the
   nav-rail item disappears in basic mode (e.g. "Borders / SDF internals").

Animate via `visible` + `Behavior on opacity`/height so toggling doesn't
jump. `advanced` is intentionally a bool; it can become a numeric `level`
later without breaking existing schemas.

---

## Visual / window layout

Adapted from `dots-hyprland` `ii` settings, mapped to pShell components.
pShell's `SettingsContent.qml` is already an adaptation of this (nav rail +
page loader + the fade/slide page-switch animation), so most of the shell
exists — the items below are the deltas to converge on the look.

```
Window (modules/settings/Settings.qml)
└── ColumnLayout
    ├── Titlebar           ← title (left/center) + close button
    └── RowLayout
        ├── NavigationRail ← expand button + FAB + tab array
        │     • expands when window width > ~900px
        │     • FAB "Config file" → open / right-click copy shell.json path
        │     • Advanced toggle lives in the header
        └── Content pane   ← surface_container_low rounded rect, clip:true
              └── Loader (fade + top-margin slide on page change)
                    └── ContentPage → ContentSection* → ConfigRow*
```

Component mapping (dots → pShell):

| dots-hyprland widget | pShell equivalent                         |
|----------------------|-------------------------------------------|
| `ContentPage`        | `containers/StyledFlickable` page wrapper |
| `ContentSection`     | `SettingSection` (+ add `icon` prop)      |
| `ContentSubsection`  | nested `SettingSection` / labelled column |
| `ConfigRow`          | horizontal grouping helper (`RowLayout`, optional `uniform`) |
| `ConfigSwitch`       | `controls/SwitchRow`                      |
| `ConfigSpinBox`      | `controls/SpinBoxRow`                     |
| `ConfigSlider`       | `controls/FilledSlider` / `StyledSlider`  |
| `ConfigSelectionArray` | `controls/SplitButtonRow` / button group |
| `StyledToolTip` child | `Hint` / `HintIcon` (richer: media)      |
| `NavigationRailButton` | existing nav delegate in `SettingsContent` |
| `FloatingActionButton` | `controls/IconTextButton` styled as FAB |

Deltas to implement:
- Header: title + close (exists) + **Advanced switch** + **FAB "Config file"**
  (open/copy `shell.json` path).
- `SettingSection`: add an `icon` property to match `ContentSection`.
- Add a `ConfigRow`-style horizontal grouping helper for side-by-side controls.
- Nav-rail: filter items by `advanced`; keep the >900px expand threshold.

Tokens: pull everything from `config/Appearance.qml` (rounding, padding,
spacing, font sizes, anim curves/durations). No hard-coded literals in
module code — see CLAUDE.md conventions.

---

## File layout (new / touched)

```
config/
    Config.qml                         ← + general, + custom
    generalconfig/GeneralConfig.qml    ← NEW (advanced bool, shell-wide prefs)
utils/
    PresetsManager.qml                 ← NEW (Singleton)
components/
    SettingsSchema.qml                 ← NEW (contract base)
    PresetBar.qml                      ← NEW (per-page preset row)
    SettingRow.qml                     ← + hintText/hintMedia, + advanced
    SettingSection.qml                 ← + icon, + advanced
    controls/
        SchemaForm.qml                 ← NEW (generic form from schema)
        Hint.qml                       ← NEW (rich popup: text + media)
        HintIcon.qml                   ← NEW (hover/pin trigger)
modules/settings/
    SettingsContent.qml                ← header (advanced + FAB), dynamic pages
    pages/
        GeneralPage.qml, BarPage.qml, LauncherPage.qml,
        BordersPage.qml, CornersPage.qml, BackgroundsPage.qml,
        StashPage.qml, ThemesPage.qml, AboutPage.qml   ← hand-written
    assets/hints/                      ← official hint media
modules/launcher/LauncherModule.qml    ← + settingsSchema, + settingsKey
```

---

## Phases

0. **Plumbing** ✅ — `GeneralConfig` (+ `advanced`), `Config.custom` +
   `get/setCustom`, `PresetsManager` (+ `presets` IPC). Headless-tested.
1. **Contract + hints** ✅ — `SettingsSchema`, `SchemaForm`, `Hint`/`HintIcon`,
   `hint`/`advanced` on schema fields, `hintText/hintMedia/advanced` on
   `SettingRow`/`SettingSection`, `settingsSchema`/`settingsKey` on
   `LauncherModule`.
2. **Pages** ✅ — hand-written pages bound to `Config.*` (Bar, Backgrounds,
   Borders, Corners, Launcher, General); `SettingsDiscovery` scans
   `*.settings.qml` → dynamic `SchemaPage`s; nav-item `advanced` filtering.
   (Per-page FAB dropped — the sidebar `PresetButton` is scope-aware instead.)
3. **Preset UI** ✅ — `ThemesPage` (full-config theme cards: apply / rename /
   delete / save) + scope-aware sidebar `PresetButton`. (No per-page
   `PresetBar` — it duplicated the sidebar button.)
4. **Polish** ✅ — defaults seeded at discovery (`SettingsDiscovery._seedDefaults`)
   *and* on first show (`SchemaForm`); two-tap destructive-delete confirmation
   (red tint + ✓, 3 s auto-reset) on theme cards and preset popup rows.

Order: 0 → 1 → 2 → 3 → 4. **All shipped.**

### Future (separate session)

- **Module / widget store** — browse + install third-party widgets/launcher
  modules (likely GitHub-sourced), then drop them into the component dirs so
  `SettingsDiscovery` picks up their `*.settings.qml`. This is a bar/launcher
  feature, not settings; the settings side already auto-surfaces whatever lands
  in the component dirs.
- Per-field `color` picker and `multi`-select control (deferred from the field
  type table).

---

## Conventions

- Reuse styled components; never inline raw `Rectangle`/`Text`.
- All sizing/timing from `Appearance.*` tokens.
- Don't widen the rails contract — third-party state goes in `Config.custom`.
- After QML edits, syntax-check via `/usr/lib/qt6/qmlcachegen` (the PATH
  `qmllint` is broken in this env) and verify with a live `qs -c pShell`
  reload.
```
