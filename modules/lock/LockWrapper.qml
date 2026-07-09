pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import "content"

// Session lock module. All locking LOGIC lives here (WlSessionLock lifecycle,
// PAM, IPC); ALL visuals live in swappable skins under skins/<id>/ (picked by
// Config.lock.skin — see SkinRegistry).
//
// Unlock handshake: logic requests an unlock via `beginUnlock()` → the lock
// emits `unlock()` → each surface's skin plays its exit animation and calls
// `finishUnlock()` when done → `locked` actually flips. A fallback timer force
// -unlocks in case a skin never answers (broken/missing skin must not brick
// the session).
//
// Niri bind (~/.config/niri/config.kdl):
//   Mod+Escape hotkey-overlay-title="Lock session" {
//       spawn "qs" "-c" "pShell" "ipc" "call" "lock" "activate";
//   }
Scope {
    id: root

    property alias lock: sessionLock

    WlSessionLock {
        id: sessionLock

        // Request an animated unlock; skins listen for this.
        signal unlock

        // awww emits no wallpaper-change signal — re-query the current path so
        // the skins' blurred-wallpaper background is fresh at lock time.
        onLockedChanged: {
            if (locked)
                WallpaperState.refreshAwww();
        }

        function beginUnlock(): void {
            if (!locked)
                return;
            unlockFallback.restart();
            unlock();
        }

        // Called by the active skin once its exit animation finished.
        function finishUnlock(): void {
            unlockFallback.stop();
            locked = false;
        }

        LockSurface {
            lock: sessionLock
            pam: pam
            registry: skins
        }
    }

    SkinRegistry {
        id: skins
    }

    Pam {
        id: pam

        lock: sessionLock
    }

    // If no skin ever calls finishUnlock (skin failed to load / broken exit
    // anim), still release the session.
    Timer {
        id: unlockFallback

        interval: 3000
        onTriggered: sessionLock.locked = false
    }

    // Debug: the active skin in a normal floating window (no session lock).
    // Toggle: qs -c pShell ipc call lock preview
    Loader {
        id: previewLoader

        active: false

        sourceComponent: LockPreview {
            registry: skins
            onDone: previewLoader.active = false
        }
    }

    IpcHandler {
        target: "lock"

        function activate(): void {
            sessionLock.locked = true;
        }

        function lock(): void {
            sessionLock.locked = true;
        }

        function unlock(): void {
            sessionLock.beginUnlock();
        }

        function toggle(): void {
            if (sessionLock.locked)
                sessionLock.beginUnlock();
            else
                sessionLock.locked = true;
        }

        function isLocked(): bool {
            return sessionLock.locked;
        }

        function preview(): void {
            if (!previewLoader.active)
                WallpaperState.refreshAwww();
            previewLoader.active = !previewLoader.active;
        }
    }
}
