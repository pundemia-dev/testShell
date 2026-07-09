# Lock — session lock with swappable visual skins

The lock module implements `ext-session-lock` (via Quickshell's
`WlSessionLock`). The split is strict: **all locking logic lives in the module
core; ALL visuals live in skin plugins** under `modules/lock/skins/<id>/`.
A skin owns everything the user sees — background, enter/exit animations,
layout, the password UI — while PAM, the lock lifecycle and IPC never move.

- **Core:** `modules/lock/LockWrapper.qml` (WlSessionLock + IPC + preview
  loader), `modules/lock/Pam.qml` (auth logic), `modules/lock/LockSurface.qml`
  (per-screen host, visual-free).
- **Skin discovery:** `modules/lock/content/SkinRegistry.qml` — a
  `PluginRegistry` binding over `skins/` (suffix `skin`). Active skin =
  `Config.lock.skin`, falling back to the first discovered one.
- **Skins shipped:** `caelestia/` (full 1:1 port of caelestia's lock) and
  `minimal/` (clock + password pill; doubles as a contract reference).
- **Config:** `Config.lock` → `modules/lock/config/LockConfig.qml`.
- **Settings page:** `modules/lock/settings/LockPage.qml` (skin picker + auth
  and content switches).

---

## TL;DR — add a skin

Create `modules/lock/skins/<id>/<id>.skin.qml`:

```qml
import QtQuick
import qs.components.misc

PluginManifest {
    title: qsTr("My skin")
    icon: "\ueae2" // tabler lock (always the \uXXXX escape, verified against the installed font)

    content: Component {
        MySkin {}
    }
}
```

…and `MySkin.qml` next to it (same-dir types resolve — skins are loaded via
`file://`, not qsintercept). The skin root is an `Item` that will be
`anchors.fill`ed to the lock surface and gets three properties injected as
**initial properties**:

| Property | What it is |
|----------|------------|
| `lock`   | The `WlSessionLock`-ish context: `locked`, `secure`, signal `unlock()`, `beginUnlock()`, `finishUnlock()` |
| `pam`    | The `Pam` scope: `buffer`, `state`, `fprintState`, `lockMessage`, `flashMsg()`, `handleKey(event)`, `passwd`, `fprint` |
| `screen` | This surface's `ShellScreen` (valid from `Component.onCompleted` — see gotchas) |

Declare them `required property var …` — creation fails fast if the contract
changes. Then select it: `Config.lock.skin = "<id>"` (or the Lock settings
page).

## The unlock handshake

`locked` does **not** flip when auth succeeds — the skin gets a chance to play
its exit animation first:

1. Logic (PAM success, IPC `unlock`) calls `lock.beginUnlock()`.
2. The lock emits `unlock()` — the skin listens via `Connections` and starts
   its exit animation.
3. When done, the skin calls `lock.finishUnlock()` → `locked = false`.
4. Safety net: if no skin answers within 3 s (broken/missing skin),
   `LockWrapper`'s fallback timer force-unlocks. A bad skin must never brick
   the session.

Minimum viable skin: `Connections { function onUnlock() { lock.finishUnlock() } }`.

## Keyboard input

The skin handles keys itself — typically one item with `focus: true` and
`Keys.onPressed: event => pam.handleKey(event)`. `handleKey` implements the
buffer (printable chars append, Backspace deletes, Ctrl+Backspace clears,
Enter starts PAM). Never call `passwd.respond()` yourself.

**Rule: nothing outside the skin may touch focus.** `LockSurface` deliberately
does not focus the skin root — re-focusing it after creation steals key focus
from the skin's own `focus: true` item and the lock screen goes deaf (its
`forceActiveFocus()` reclaim never fires if it never had focus).

## Preview mode — iterate without locking

```
qs -c pShell ipc call lock preview
```

Toggles `modules/lock/content/LockPreview.qml`: the active skin in a normal
`FloatingWindow` with a **mock lock** (`beginUnlock()` → `unlock()` signal;
`finishUnlock()` → close) and a **real `Pam` instance** — typing your password
runs actual PAM auth and a correct password plays the skin's exit animation.
Esc closes. This is the debug loop for any skin work; only surface-level
behaviour (keyboard focus grant, per-screen instancing) needs a real lock test.

`Pam.lock` is duck-typed (`var`, not `WlSessionLock`) exactly so the mock can
drive it.

## niri gotchas (why this diverges from caelestia)

These cost a debugging session each — don't undo them:

1. **Lock surfaces must be opaque.** A `color: "transparent"` surface lets
   niri's red "lock client not drawing" backdrop bleed through everything.
   `LockSurface` paints black; skins draw an opaque `Colours.palette.surface`
   base over it.
2. **niri refuses screencopy while the session is locked.** caelestia's
   blurred-`ScreencopyView` background can never work here. Skins blur the
   wallpaper image instead: `CachingImage { path: Colours.wallpaperPath }` +
   `MultiEffect` blur. The path comes from `WallpaperState.awwwPath`
   (`awww query`; awww emits no change signal, so `LockWrapper` calls
   `WallpaperState.refreshAwww()` on lock/preview open).
3. **`WlSessionLockSurface.screen` is assigned AFTER the surface is
   instantiated.** Snapshotting it into createObject initial properties yields
   `undefined`, and a skin's autostart animations then resolve every
   screen-derived size to 0 ("scattered texts, no card fills"). `LockSurface`
   defers skin creation until `screen` is non-null (`onScreenChanged` retries)
   — a skin may safely read `screen` from `Component.onCompleted` on.
4. **caps/num-lock state is stubbed** (`Niri.capsLock/numLock` are always
   false — niri doesn't expose them). Layout-name display works via
   `Niri.kbLayoutFull`.

## PAM

`Pam.qml` runs two independent `PamContext`s against configs in
`assets/pam.d/` (copied verbatim from caelestia; Arch `pam_faillock` style):

- **`passwd`** — started on Enter; responds with the typed buffer; surfaces
  "account locked / N tries left" messages via `lockMessage`.
- **`fprint`** — auto-started while locked when `Config.lock.enableFprint` and
  `fprintd-list $USER` succeeds; retries around PAM's per-call max-tries until
  `Config.lock.maxFprintTries`.

Skins read `pam.state` / `pam.fprintState` (`"" | fail | error | max`, auto
reset after 4 s) and the `flashMsg()` signal for error emphasis.

## IPC & niri bind

Target `lock`: `activate` / `lock` (lock), `unlock` (animated unlock),
`toggle`, `isLocked`, `preview`. Niri bind (`~/.config/niri/config.kdl`):

```kdl
Mod+Escape hotkey-overlay-title="Lock session" {
    spawn "qs" "-c" "pShell" "ipc" "call" "lock" "activate";
}
```

## Locked out? (TTY recovery)

1. `Ctrl+Alt+F3`, log in → `qs -c pShell ipc call lock unlock` — works even
   with a broken skin (fallback timer).
2. If quickshell itself died, niri keeps the session locked (solid red screen;
   niri has no unlock action). Attach a replacement locker and unlock through
   it: `WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 hyprlock`.

## Known limitations

- The caelestia skin drops caelestia's CPU-temperature badge (no temp source
  in pShell) and synthesises the fetch colour row from the M3 palette (no
  `term0..15` roles).
- History notifications may log `Failed to get image from provider:
  image://qsimage/…` for image handles that died with a previous shell
  instance — shared with `modules/notifications`, cosmetic.
- No idle/suspend auto-lock yet (would be a logind/idle-notify integration in
  `LockWrapper`).
