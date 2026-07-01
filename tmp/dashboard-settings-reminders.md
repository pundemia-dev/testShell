# TODO — dashboard settings page (reminders to self)

Goal: finish/expand the **Dashboard** page in the settings module so every
dashboard page has its own section with its design tokens + toggles.
The user's original ask: «дизайн токены пусть будут в конфиге дашборда, у каждой
страницы должен быть свой раздел» → tokens live in `Config.dashboard.<page>.*`
and Settings shows **a section per page**.

## Where things are
- Settings page: `modules/settings/pages/DashboardSettingsPage.qml`
  (registered in `modules/settings/SettingsContent.qml` → `pages` array, entry
  `{ name:"Dashboard", icon:"", scope:"dashboard", component: dashboardPage }`
  + `Component { id: dashboardPage; DashboardSettingsPage {} }`).
- Config: `config/dashboardconfig/DashboardConfig.qml` (JsonObject; two-way bind).
- Page registry (to list pages generically): `modules/dashboard/content/DashboardRegistry.qml`
  — instantiate `Dash.DashboardRegistry { id: registry }` (already used in the
  settings page) → `registry.all` (all manifests: id/title/icon/order).

## What already exists in DashboardSettingsPage.qml
Sections: **General** (enabled / padding / rounding / auto-hide[adv]),
**Position** (anchor edge top/bottom/left/right), **Pages** (drag-reorder + on/off
list — writes `Config.dashboard.order`/`.disabled`, reassign whole array!),
**Performance widgets** (showCpu/Gpu/Memory/Storage/Network/Battery + Fahrenheit),
**Weather** (location `StyledTextField` + Fahrenheit).

## TODO / missing
1. **Per-page token sections** (the main ask). Add a `SettingSection` per page
   exposing its sizing tokens as `CustomSpinBox` rows, ALL `advanced: true`:
   - **Dashboard** (`Config.dashboard.dash.*`): userWidth, logoSize, uptimeSize,
     dateTimeWidth, mediaWidth, mediaProgressThickness, resourceProgressThickness,
     weatherWidth.
   - **Media** (`Config.dashboard.media.*`): coverArtSize, sectionWidth, tabWidth,
     tabHeight, progressSweep, progressThickness, **visualiserBars** (nice as a
     slider/spinbox — controls the cava bar count, default 44).
   - **Performance** (`Config.dashboard.performance.*`): heroCardWidth,
     usageShapeSize, storageTextWidth, networkCardWidth, networkCardHeight,
     battWidth, battWidthSingle, battHeight, placeholderWidth. (Toggles already done.)
   - **Weather** (`Config.dashboard.weather.*`): forecastItemWidth.
   - Also top-level: `tabIndicatorHeight`, `tabIndicatorSpacing`, and
     mode (push/overlay), mLeft/mRight/mTop/mBottom.
2. **Consider auto-generating** the enable/order + token sections per discovered
   page (`registry.all`) so it stays modular. Tension: tokens are TYPED sub-objects
   (`dash`/`media`/`performance`/`weather`), not a generic map — a fully generic
   per-page token UI would need either (a) a token schema declared in each page's
   manifest (extend `components/DashboardPage.qml` with an optional
   `settings: [{key,label,min,max,default}]` list the page reads from
   `Config.dashboard.custom[id]`), or (b) keep typed sections hardwired per page.
   Option (a) is the clean modular path if we want 3rd-party dashboard pages to
   ship their own settings (mirrors `SettingsSchema`/`SchemaForm` for bar/launcher).
3. Anchor: current chooser only sets edge + auto centers. Could add alignment
   (start/center/end) if wanted.

## Patterns / gotchas
- Build over `SettingSection { title; icon } { SettingRow { label; description;
  <control> } }`. Controls: `StyledSwitch { checked; onToggled }`,
  `CustomSpinBox { value; min; max; step; onValueModified: v => ... }`,
  `StyledTextField`. See `modules/settings/pages/CornersPage.qml` for the shape.
- Section icons are **tabler glyphs** written as `\uXXXX`. My tool input turns
  escapes into literal PUA bytes, so insert glyphs via a marker token + `sed`
  (e.g. write `icon: "@DASH@"` then `sed -i 's/@DASH@/\\uea87/'`). Verify codepoints
  with fonttools against `~/.local/share/fonts/tabler-icons/.../tabler-icons.ttf`
  (see [[tabler-icon-codepoints]]).
- Gate niche token rows with `advanced: true` (shown only when
  `Config.general.advanced`).
- Persisting list edits: `Config.dashboard.order`/`.disabled` are `list<string>`
  — reassign the WHOLE array (JsonAdapter ignores in-place mutation), like
  `Config.setCustom`.
- Verify each file: `/usr/lib/qt6/qmlcachegen --resource-path /qs/<path> <path>
  -o /tmp/c.cpp` (exit 0). qmllint is broken here.

## Nice-to-have later
- Live preview / apply is automatic (two-way bind → JsonAdapter writes shell.json).
- A "reset page tokens to defaults" button per section.
