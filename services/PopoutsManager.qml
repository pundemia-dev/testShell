pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// Per-screen popout coordinator. Instantiated once per Drawers scope with the
// screen's BackgroundsManager. Owns one EdgeChannel per edge; each channel
// reads the active handle for (screen, edge) from the Popouts singleton and
// drives a reused rails background.
//
// Non-visual (no geometry of its own). Widgets never touch this directly —
// they talk to the Popouts singleton via PopoutHandle; this side only renders.
Item {
    id: root

    required property var manager          // BackgroundsManager
    required property ShellScreen screen

    readonly property int screenWidth: screen ? screen.width : 0
    readonly property int screenHeight: screen ? screen.height : 0

    Instantiator {
        model: ["top", "bottom", "left", "right"]
        delegate: EdgeChannel {
            required property string modelData
            edge: modelData
            manager: root.manager
            screen: root.screen
            screenWidth: root.screenWidth
            screenHeight: root.screenHeight
            // Reactive: activeMap is reassigned wholesale on every change.
            activeHandle: Popouts.activeMap[(root.screen ? root.screen.name : "?") + "|" + modelData] ?? null
        }
    }
}
