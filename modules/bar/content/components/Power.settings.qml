import qs.components

// Per-widget settings for the Power menu button. Values persist in
// Config.custom["power"]; read by Power.qml via Config.getCustom.
SettingsSchema {
    title: "Power menu"
    icon: "" // tabler power
    key: "power"
    fields: [
        ({
                key: "colour",
                type: "enum",
                label: "Colour",
                "default": "error",
                options: ["primary", "secondary", "tertiary", "error", "on_surface"]
            })
    ]
}
