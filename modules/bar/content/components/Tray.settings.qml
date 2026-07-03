import qs.components
import qs.components.misc

// Per-widget settings for the system tray. Values persist in
// Config.custom["tray"]; read by Tray.qml / TrayItem.qml via getCustom.
// (Migrated from the former Config.bar.tray booleans; iconSubs stays in
// Config.bar.tray since it's a structural list with no UI control.)
SettingsSchema {
    title: "System tray"
    icon: "" // tabler apps
    key: "tray"
    fields: [
        ({
                key: "background",
                type: "bool",
                label: "Background",
                "default": false,
                description: "Draw a filled background behind the tray icons."
            }),
        ({
                key: "compact",
                type: "bool",
                label: "Compact",
                "default": false,
                description: "Collapse icons behind an expand toggle."
            }),
        ({
                key: "recolour",
                type: "bool",
                label: "Recolour icons",
                "default": false
            })
    ]
}
