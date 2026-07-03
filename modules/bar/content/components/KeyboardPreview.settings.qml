import qs.components
import qs.components.misc

// Per-widget settings for the Keyboard layout indicator. Values persist in
// Config.custom["keyboardPreview"]; read by KeyboardPreview.qml via getCustom.
// (Migrated from the former Config.bar.kbPreview sub-config.)
SettingsSchema {
    title: "Keyboard layout"
    icon: "" // tabler keyboard
    key: "keyboardPreview"
    fields: [
        ({
                key: "colour",
                type: "enum",
                label: "Colour",
                "default": "secondary",
                options: ["primary", "secondary", "tertiary", "error", "on_surface"]
            }),
        ({
                key: "showIcon",
                type: "bool",
                label: "Show icon",
                "default": false
            }),
        ({
                key: "showLayout",
                type: "bool",
                label: "Show layout name",
                "default": true
            })
    ]
}
