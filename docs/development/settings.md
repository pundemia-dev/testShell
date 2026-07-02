# Settings module

`modules/settings` is a normal `Window` (toggled via the `settings` IPC), not a
layershell. Full design reference: the live module.

## Config plumbing

Pages two-way bind to `Config.*` — `JsonAdapter` auto-writes `shell.json` on
any assignment, and repopulates the tree on file change. No manual file handling
in pages.

## Presets

Presets live under `~/.config/pShell/presets/<scope>/<name>.json`. Scopes match
adapter section names (`bar`, `launcher`, `border`, `corners`, `backgrounds`,
`notifs`, `stash`, `general`, `custom`) plus `full`.

Apply always goes through the file (write → `reload()`), never through direct
binding. `utils/PresetsManager.qml` (Singleton, IPC target `presets`):

```qml
listPresets(scope) → [names]
savePreset(scope, name)
applyPreset(scope, name)
deletePreset(scope, name)
renamePreset(scope, from, to)
```

UI: `pages/ThemesPage.qml` (full-config theme cards) + scope-aware sidebar
`PresetButton.qml` (follows the current tab). Destructive delete is two-tap
confirmed (red tint → confirm, 3 s auto-reset).

## Third-party module contract

A module ships a `<Name>.settings.qml` sibling — a pure `components/SettingsSchema.qml`:

```qml
QtObject {
    property string title: ""
    property string icon: ""       // tabler glyph
    property string key: ""        // subtree key inside Config.custom
    property var fields: []
}
```

Field descriptor shape:
```js
{ key, type, label, description, default, advanced,
  hint: { text, media },
  // type extras: min/max/step (int/real), options[] (enum) }
```

Supported types: `bool` → `StyledSwitch`, `int`/`real` → `CustomSpinBox`,
`string` → `StyledTextField`, `enum` → chip row.

`SettingsDiscovery.qml` scans `modules/{bar,launcher}/content/components/` for
`*.settings.qml`. `components/controls/SchemaForm.qml` renders the schema
generically, persisting values in `Config.custom[key]` and seeding defaults on
first show. No edits to `Config.qml` needed.

Read values at runtime:
```qml
property int interval: Config.getCustom("myKey", "interval", 30)
```

## Hints

`components/controls/Hint.qml` — a `Popup` (renders above everything, never
clipped by the content pane). `components/controls/HintIcon.qml` — info glyph,
hover-opens, click-pins.

Wire on `SettingRow`:
```qml
SettingRow { hintText: "…"; hintMedia: "preview.gif" }
```

Or on a schema field: `hint: { text: "…", media: "…" }`. Media
auto-detects GIF/WebP → `AnimatedImage`, else `Image`.

## Basic / Advanced split

`Config.general.advanced` (bool). Visibility rule everywhere:
```qml
visible: !element.advanced || Config.general.advanced
```

Three granularities: `advanced` prop on `SettingRow`, `SettingSection`, or the
page descriptor in `SettingsContent.qml`'s `pages` array.

## Adding an official page

1. Create `modules/settings/pages/<Name>Page.qml` — a `Flickable` of
   `SettingSection`/`SettingRow` bound to `Config.<section>.*`.
2. Register in `SettingsContent.qml`'s `pages` array:
   ```qml
   { name: "Name", icon: "\uXXXX", scope: "section", component: Qt.createComponent("pages/NamePage.qml") }
   ```

## Where things live

| Concern | File |
|---------|------|
| Module root | `modules/settings/{Settings,SettingsContent,SettingsDiscovery}.qml` |
| Pages | `modules/settings/pages/*.qml` |
| Preset management | `utils/PresetsManager.qml` |
| Third-party contract | `components/SettingsSchema.qml`, `components/controls/SchemaForm.qml` |
| Hints | `components/controls/{Hint,HintIcon}.qml` |
| Sidebar preset button | `modules/settings/PresetButton.qml` |
| General config (advanced toggle) | `config/generalconfig/GeneralConfig.qml` |
