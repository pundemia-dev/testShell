import Quickshell
import Quickshell.Io
import QtQuick

// Niri does not implement hyprland_global_shortcuts_v1, so we expose shortcuts
// over Quickshell's IPC instead. Bind keys in niri config via:
//   binds { Mod+Space hotkey-overlay-title="Toggle launcher" {
//       spawn "qs" "-c" "pShell" "ipc" "call" "<name>" "activate";
//   } }
// Each shortcut becomes its own IPC target (`name`) with `activate`/`press`/`release` functions.
QtObject {
    id: shortcut

    property string name
    property string description: ""
    property var onActivated: null
    property var onPressed: null
    property var onReleased: null

    function activate(): void {
        if (onActivated && typeof onActivated === "function") onActivated();
    }
    function press(): void {
        if (onPressed && typeof onPressed === "function") onPressed();
    }
    function release(): void {
        if (onReleased && typeof onReleased === "function") onReleased();
    }

    readonly property IpcHandler _handler: IpcHandler {
        target: shortcut.name

        function activate(): void { shortcut.activate(); }
        function press(): void { shortcut.press(); }
        function release(): void { shortcut.release(); }
    }
}
