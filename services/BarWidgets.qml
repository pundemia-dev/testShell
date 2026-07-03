pragma Singleton

import Quickshell

// Curated registry of widgets that can be dragged from the Settings palette
// into the bar. `name` matches a file in modules/bar/content/components/<name>.qml
// (what WidgetHost loads). Helpers (WidgetHost, TrayItem, Dinamic, workspaces/*)
// are intentionally excluded.
//
// `icon` is an optional tabler glyph used by the palette's fallback tile; the
// palette prefers a live preview of the component. Codepoints are filled in /
// verified against the installed font in Phase 3 (memory: tabler-icon-codepoints).
Singleton {
    id: root

    // `icon` codepoints verified against the installed tabler-icons font.
    readonly property var widgets: [
        { "name": "OsIcon", "label": "OS icon", "icon": "" },          // device-desktop
        { "name": "Workspaces", "label": "Workspaces", "icon": "" },    // layout-grid
        { "name": "Utilities", "label": "Utilities", "icon": "" },      // tools
        { "name": "Tray", "label": "System tray", "icon": "" },         // apps
        { "name": "Clock", "label": "Clock", "icon": "" },              // clock
        { "name": "KeyboardPreview", "label": "Keyboard layout", "icon": "" }, // keyboard
        { "name": "BluetoothStatus", "label": "Bluetooth", "icon": "" }, // bluetooth
        { "name": "NetworkStatus", "label": "Network", "icon": "" },     // wifi
        { "name": "PowerStatus", "label": "Battery", "icon": "" },       // battery
        { "name": "Power", "label": "Power menu", "icon": "" }           // power
    ]

    function labelFor(name) {
        for (const w of widgets)
            if (w.name === name)
                return w.label;
        return name;
    }
}
