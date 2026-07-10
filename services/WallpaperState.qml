pragma Singleton

import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string stateFilePath: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/walltool/wallpaper_state.json`

    // Parsed top-level state object, reactive
    property var stateData: ({})

    // Transition tier set by launcher scroll:
    // 0 = idle (full crossfade), 1 = active (fast fade), 2 = rapid (instant)
    property int transitionTier: 0

    // Fires whenever stateData is replaced (monitors can connect to this)
    signal stateUpdated()

    // Current wallpaper image path as reported by awww (`awww query`). awww is
    // the actual wallpaper setter on this setup; the walltool state file above
    // may be absent. awww emits no change signal, so consumers that need
    // freshness call refreshAwww() (Backgrounds polls it while shaderBlur is
    // on; the lock module refreshes on lock). Seeded once at startup.
    property string awwwPath: ""

    function refreshAwww(): void {
        awwwQuery.running = true;
    }

    Process {
        id: awwwQuery

        command: ["sh", "-c", "awww query | sed -n 's/.*image: //p' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p)
                    root.awwwPath = p;
            }
        }
    }

    Component.onCompleted: refreshAwww()

    FileView {
        id: stateFile
        path: root.stateFilePath
        watchChanges: true
        // onLoadFailed already logs everything except FileNotFound — silence
        // FileView's own duplicate WARN (walltool may not have run yet).
        printErrors: false
        onLoaded: root._parse(text())
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("[WallpaperState] Failed to load state file:", err);
        }
    }

    function _parse(jsonText: string): void {
        if (!jsonText || jsonText.trim() === "") return;
        try {
            root.stateData = JSON.parse(jsonText);
            root.stateUpdated();
        } catch (e) {
            console.warn("[WallpaperState] JSON parse error:", e);
        }
    }

    // Returns the resolved state object for a given monitor name.
    // Falls back to stateData.fallback if no per-monitor entry exists.
    // Returns null if nothing is available.
    function forMonitor(monitorName: string): var {
        if (stateData && stateData.monitors && stateData.monitors[monitorName])
            return stateData.monitors[monitorName];
        if (stateData && stateData.fallback)
            return stateData.fallback;
        return null;
    }
}
