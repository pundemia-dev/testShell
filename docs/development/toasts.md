# Toasts — shell/OS notifications for module & plugin developers

Toasts are the shell talking about **itself**: "keyboard layout switched",
"audio output changed", "config failed to parse". They are **not** the
freedesktop notification daemon (`services/Notifs.qml`), which relays messages
from external apps. If your code wants to tell the user that *something inside
the shell just happened*, emit a toast.

- **Service:** `services/Toaster.qml` — a pure-QML queue (no C++ plugin).
- **Declarative source:** `components/misc/ToastSource.qml`.
- **Registry:** `services/ToastRegistry.qml`.
- **UI:** `modules/toasts/` (overlay wrapper + card + stack).
- **Config:** `Config.toasts` → `modules/toasts/config/ToastsConfig.qml`.

---

## TL;DR — emit a toast in 3 lines

Declare a `ToastSource` next to your logic and call `notify(...)`:

```qml
import qs.components.misc   // ToastSource lives here

// ... inside your module/service/plugin ...
ToastSource {
    id: toasts
    sourceId: "wallpaperlist.unsplash"       // stable, unique
    label: qsTr("Unsplash")                  // shown in settings
    icon: "\ueXXX"                            // Tabler codepoint
    notifications: [
        { id: "applied",      label: qsTr("Wallpaper applied"), severity: "success", icon: "\ueXXX" },
        { id: "fetch-failed", label: qsTr("Download failed"),   severity: "error",   icon: "\ueXXX" }
    ]
}

// at the call site — only the dynamic bits:
toasts.notify("applied", qsTr("Wallpaper set"), chosen.name);
toasts.notify("fetch-failed", qsTr("Couldn't fetch"), err);
```

That's it. The source **self-registers**, so its category and every
notification it can emit automatically appear under **Settings → Toasts** with
mute toggles — no settings-page code, no `Config.qml` edit.

---

## The rules (read before writing one)

### 1. Prefer `ToastSource` + `notify()` over ad-hoc `Toaster.toast()`

`ToastSource` is the supported path. It gives you:
- self-registration (settings discovery),
- per-notification mute granularity,
- icon/severity resolved from the manifest, so the call site stays terse.

`Toaster.toast(title, message, icon, type, timeout)` still exists for a genuine
one-off with no source, but such a toast is only gated by the **global** enable
switch — it has no category, so the user cannot mute it individually. Don't use
it for anything a module emits repeatedly.

### 2. Every notification you can emit must be declared

Put **all** of a source's notifications in the `notifications` array, each with:

| field | required | purpose |
|---|---|---|
| `id` | yes | stable key used at the call site and for the per-notification mute toggle |
| `label` | yes | the **short description** shown on the settings toggle and as an emit default |
| `severity` | yes | `"info"` \| `"success"` \| `"warning"` \| `"error"` — drives styling, the settings ranking, and the global severity gate |
| `icon` | no | Tabler codepoint; falls back to the source `icon` |

`label` **is** the "short description" — write it so it reads on a toggle
(`"Download failed"`, not `"Error"`). `notify()` takes a declared `id`; passing
an undeclared id still shows a toast but it won't have a settings toggle.

### 3. `sourceId` is a stable, unique key

It is the mute key persisted to disk. Use lowercase, dotted for plugins:
`"audio"`, `"keyboard"`, `"wallpaperlist.unsplash"`. Never reuse an id for two
different sources. Renaming it orphans the user's saved mute state.

### 4. Nest plugins under a module with `parentId`

Set `parentId` to a module node's id to group a plugin under it. The module node
is synthesised automatically (you don't have to register it), and disabling the
module's master toggle mutes every plugin beneath it. Depth is
module → plugin → notification; don't nest deeper.

```qml
ToastSource { sourceId: "wallpaperlist.unsplash"; parentId: "wallpaperlist"; ... }
ToastSource { sourceId: "wallpaperlist.local";    parentId: "wallpaperlist"; ... }
```

### 5. Guard startup so bindings don't fire spurious toasts

If you emit from a property-change handler (`onXChanged`), the initial binding
fire at startup will toast on a value that didn't really "change". Arm after a
short delay:

```qml
property bool _toastArmed: false
Timer { interval: 1500; running: true; onTriggered: root._toastArmed = true }
onSinkChanged: if (_toastArmed && sink) toasts.notify("sink", …);
```

(See `services/Audio.qml`, `services/Players.qml`, `services/Notifs.qml`.)

### 6. Don't spam

A toast is a 5-second interruption. Emit on genuine, user-relevant events.
Note the pShell-specific trap: **`Config` reloads on every settings write**
(`watchChanges` → `onLoaded`), so a "config loaded" toast fires on every toggle
— that's why the `config` source only toasts on **parse failure**
(`config/Config.qml`, `onLoadFailed`). Think about how often your trigger fires.

### 7. Icons are Tabler codepoints — verify them

`ToastSource.icon` / per-notification `icon` are Tabler glyph codepoints
(`"\ueXXX"`). The `// tabler <name>` comments in the codebase are not
authoritative — verify against the installed font's cmap or reuse a codepoint
already used in the repo. See the `tabler-icon-codepoints` note.

### 8. Text is authored; keep it wrapped in `qsTr(...)`

Titles/messages are user-facing — wrap them for translation like the rest of the
shell.

---

## Optional per-emit overrides

`notify(notifId, title, message, extra)` — `extra` overrides the manifest:

```qml
toasts.notify("applied", title, msg, { icon: "\ueXXX", timeout: 8000, type: Toaster.Warning });
```

- `icon` — override the glyph for this one toast.
- `timeout` — ms until auto-dismiss (`<=0` → `Config.toasts.defaultTimeout`).
- `type` — override the `Toaster.Type` (styling + severity bucket).

`notify()` returns the toast id, or `-1` if it was suppressed (globally
disabled, or muted at severity / module / source / notification level).

---

## How muting works (what the user controls)

Three tiers, checked most-global first in `Toaster.shouldShow()`:

1. **Severity** — `Config.toasts.severity.{info,warning,error}`. A global kill by
   importance. `success` folds into the **info** bucket.
2. **Source / module master** — `Config.toasts.overrides["<id>"].enabled`. Walks
   the `parentId` chain, so a disabled module mutes its plugins.
3. **Individual notification** — `Config.toasts.overrides["<sourceId>"].ids["<notifId>"]`.

Everything is **opt-out**: anything undefined means *shown*, so a freshly
registered source is fully on by default. State is written wholesale via
`Toaster.setOverride(sourceId, "enabled", v)` / `setNotifOverride(sourceId,
notifId, v)` (in-place mutation of the nested map won't persist).

The **Settings → Toasts** page builds itself from `ToastRegistry.sources`:
per-source master toggle + a collapsible list of the source's notifications,
ranked Error → Warning → Info and split by dividers. You never touch it.

---

## Severity → styling

`severity` maps to a `Toaster.Type`, which the card (`ToastItem.qml`) colours
(pShell has no `success` palette role, so it borrows `tertiary`):

| severity | Type | card fill |
|---|---|---|
| `info` | `Toaster.Info` | `tPalette.surface_container` (elevated neutral) |
| `success` | `Toaster.Success` | `tertiary_container` |
| `warning` | `Toaster.Warning` | `secondary_container` |
| `error` | `Toaster.Error` | `error_container` |

Info deliberately uses `surface_container`, not `surface` — the base surface is
near-black and would vanish against the panel background.

---

## Ad-hoc / low-level API

For code that legitimately has no registered source:

```qml
import qs.services
Toaster.toast(qsTr("Title"), qsTr("Message"), "\ueXXX", Toaster.Warning, 6000);
// or the canonical form:
Toaster.push({ title, message, icon, type, timeout, sourceId, notifId });
```

`Toaster.dismiss(id)` / `Toaster.clear()` remove toasts programmatically.

---

## Reference

**`ToastSource` (`components/misc/ToastSource.qml`)**
`sourceId` (required) · `label` · `icon` · `parentId` · `notifications: [{id,label,severity,icon}]` ·
`notify(notifId, title, message, extra?) → int`. Auto-registers on load,
unregisters on destruction.

**`Toaster` (`services/Toaster.qml`)**
`enum Type { Info, Success, Warning, Error }` · `toasts` (array) ·
`push(o) → int` · `toast(title,message,icon,type,timeout) → int` ·
`shouldShow(sourceId,notifId,type) → bool` · `severityOf(type) → string` ·
`dismiss(id)` · `clear()` · `setOverride(sourceId,field,v)` ·
`setNotifOverride(sourceId,notifId,v)` · `flag(sourceId,field) → bool` ·
`notifFlag(sourceId,notifId) → bool`.

**`ToastRegistry` (`services/ToastRegistry.qml`)**
`sources` (array) · `register(src)` · `unregister(id)` · `get(id)` · `parentOf(id)`.

**Config (`Config.toasts`)**
`enabled` · `severity {info,warning,error}` · `overrides` (open map) ·
`anchors`/`mode`/`m*`/`padding`/`rounding` (rails geometry) · `defaultTimeout` ·
`maxVisible` · `toastWidth`.

**Rendering** — `ToastsWrapper.qml` is an event-driven rails overlay (requests a
background while `Toaster.toasts.length > 0`); `ToastsContent.qml` is a clipped,
`ScriptModel`-backed `ListView` (identity diffing preserves each delegate's
expiry timer); `ToastItem.qml` is the card.
