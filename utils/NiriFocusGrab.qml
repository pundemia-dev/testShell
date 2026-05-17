pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

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
    // Pointer events that fall through the Overlay window (outside registered
    // panel regions) land here and trigger dismissal.
    PanelWindow {
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

        MouseArea {
            anchors.fill: parent
            onClicked: root.cleared()
        }
    }
}
