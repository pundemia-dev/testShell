pragma Singleton

import qs.utils
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

    FileView {
        id: stateFile
        path: root.stateFilePath
        watchChanges: true
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
