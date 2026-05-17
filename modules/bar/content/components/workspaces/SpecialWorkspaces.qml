import Quickshell
import QtQuick

// Niri does not have a "special workspaces" concept the way Hyprland does.
// This component is referenced from Workspaces.qml via a Loader that is never
// activated under Niri (onSpecial is hardcoded false), but the file still has
// to parse, so it is kept as a stub.
Item {
    id: root

    required property ShellScreen screen
    required property bool isHorizontal
    required property real unitSize

    visible: false
}
