pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import ".."

// Debug harness: runs the active lock skin in a regular floating window
// instead of a WlSessionLock surface, so visuals can be iterated without
// locking the session. Toggle with `qs -c pShell ipc call lock preview`.
//
// The skin gets the same contract as on a real surface, but `lock` is a mock:
// beginUnlock() fires the unlock signal (skin plays its exit animation) and
// finishUnlock() closes the window. `pam` is a REAL Pam instance bound to the
// mock — typing your password performs actual PAM auth, Enter on success runs
// the exit animation. Escape closes immediately.
FloatingWindow {
    id: root

    required property var registry

    signal done

    title: "pShell lock preview"
    implicitWidth: (screen?.width ?? 1920) * 0.75
    implicitHeight: (screen?.height ?? 1080) * 0.75
    color: "black"

    property QtObject mockLock: QtObject {
        signal unlock

        property bool locked: true
        property bool secure: true

        function beginUnlock(): void {
            unlock();
        }

        function finishUnlock(): void {
            locked = false;
            root.done();
        }
    }

    Pam {
        id: pam

        lock: root.mockLock
    }

    property Item skinItem: null

    function reloadSkin(): void {
        if (skinItem) {
            skinItem.destroy();
            skinItem = null;
        }

        const comp = registry?.activeSkin?.content ?? null;
        if (!comp)
            return;

        skinItem = comp.createObject(contentItem, {
            lock: root.mockLock,
            pam: pam,
            screen: root.screen
        });
        if (skinItem) {
            skinItem.anchors.fill = contentItem;
        } else {
            console.warn("[lock preview] skin failed to instantiate:", registry.activeSkin.id, comp.errorString());
        }
    }

    Component.onCompleted: reloadSkin()

    Connections {
        target: root.registry

        function onActiveSkinChanged(): void {
            root.reloadSkin();
        }
    }

    Shortcut {
        // qmllint disable unresolved-type
        sequence: "Escape"
        onActivated: root.done()
    }
}
