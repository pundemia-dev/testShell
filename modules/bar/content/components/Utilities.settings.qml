import qs.components
import qs.components.misc

// Per-widget settings for the Utilities button. Values persist in
// Config.custom["utilities"]; read by Utilities.qml via Config.getCustom.
SettingsSchema {
    title: "Utilities"
    icon: "" // tabler tools
    key: "utilities"
    fields: [
        ({
                key: "colour",
                type: "enum",
                label: "Colour",
                "default": "tertiary",
                options: ["primary", "secondary", "tertiary", "error", "on_surface"]
            })
    ]
}
