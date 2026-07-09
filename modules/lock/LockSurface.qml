pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

// One lock surface per screen. Deliberately visual-free: it only hosts the
// active skin's content Component (see SkinRegistry). Skin contract — the
// created item gets these properties injected (as initial properties, so they
// are valid from the skin's Component.onCompleted / autostart animations):
//   lock   — the WlSessionLock (locked/secure, `unlock()` signal to react to,
//            `finishUnlock()` to call when the exit animation is done)
//   pam    — the Pam scope (buffer/state/fprintState/lockMessage/flashMsg,
//            handleKey(), passwd, fprint)
//   screen — this surface's ShellScreen
// The skin owns everything else: background, enter/exit animations, layout.
//
// Imperative createObject (not a Loader) because Loader.sourceComponent can't
// pass initial properties; it also lets a late-discovered registry (locking
// right at startup) attach the skin as soon as manifests arrive.
WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam
    required property var registry

    property Item skinItem: null

    // Opaque base: the session-lock protocol expects the surface to fully
    // cover the output; a transparent surface lets niri's red "lock client
    // not drawing" backdrop bleed through. Skins paint their background on top.
    color: "black"

    function reloadSkin(): void {
        if (skinItem) {
            skinItem.destroy();
            skinItem = null;
        }

        // `screen` is assigned by WlSessionLock AFTER the surface is
        // instantiated — creating the skin earlier would snapshot
        // screen=undefined into its initial properties and its autostart
        // animations would resolve all screen-derived sizes to 0 (the
        // "everything scattered, no card fills" failure). Wait for it;
        // onScreenChanged retries.
        if (!screen)
            return;

        const comp = registry?.activeSkin?.content ?? null;
        if (!comp)
            return;

        skinItem = comp.createObject(contentItem, {
            lock: root.lock,
            pam: root.pam,
            screen: root.screen
        });
        if (skinItem) {
            skinItem.anchors.fill = contentItem;
            // NOTE: do NOT force skinItem.focus here — the skin's own focused
            // item (e.g. PasswordInput's `focus: true`) registers during
            // creation, and re-focusing the skin root afterwards would steal
            // key focus from it (dead keyboard on the lock screen).
        } else {
            console.warn("[lock] skin failed to instantiate:", registry.activeSkin.id, comp.errorString());
        }
    }

    Component.onCompleted: reloadSkin()
    onScreenChanged: reloadSkin()

    Connections {
        target: root.registry

        function onActiveSkinChanged(): void {
            root.reloadSkin();
        }
    }
}
