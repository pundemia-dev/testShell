import Quickshell.Io

JsonObject {
    // Presentation toggles (background/recolour/compact) moved to
    // Config.custom["tray"] (see Tray.settings.qml). iconSubs stays here: it's a
    // structural list consumed by services/Icons.qml with no settings-UI control.
    property list<var> iconSubs: []
}
