pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Minimal system-info singleton for the dashboard User card (caelestia SysInfo
// substitute). Uptime via `uptime -p`, WM is fixed to niri, OS glyph from the
// existing Icons singleton.
Singleton {
    id: root

    property string uptime: ""
    readonly property string wm: "niri"
    readonly property string osLogo: Icons.osIcon
    readonly property string user: Quickshell.env("USER") || "user"

    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p"]
        running: true
        stdout: StdioCollector {
            id: uptimeOut
            onStreamFinished: root.uptime = uptimeOut.text.trim().replace(/^up\s+/, "")
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: uptimeProc.running = true
    }
}
