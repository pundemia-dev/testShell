pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services

// Niri replacement for HyprlandFocusGrab.
// Grants exclusive keyboard focus to `window` when active and catches outside-clicks.
Item {
    id: root

    required property PanelWindow window
    required property ShellScreen screen
    property bool active: false

    signal cleared()

    onActiveChanged: root.window.WlrLayershell.keyboardFocus =
        root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Component.onCompleted: root.window.WlrLayershell.keyboardFocus =
        root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Full-screen transparent window on the Top layer.
    // Pointer events outside the shell's registered panel regions land here
    // and trigger dismissal. The mask subtracts InputManager.regions so this
    // window does not claim input where the drawers window already does —
    // without the subtraction, within-layer ordering on Top is undefined and
    // the dismiss surface may shadow drawers (eating clicks meant for the
    // launcher buttons etc).
    PanelWindow {
        id: dismissWin
        screen: root.screen
        color: "transparent"
        visible: root.active

        WlrLayershell.namespace: "pShell-dismiss"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: true
        anchors.bottom: true

        mask: Region {
            x: 0
            y: 0
            width: dismissWin.width
            height: dismissWin.height
            regions: InputManager.regions
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cleared()
        }
    }
}
