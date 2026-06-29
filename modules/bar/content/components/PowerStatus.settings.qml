import qs.components

// Per-widget settings for the Battery / power status indicator. Values persist
// in Config.custom["powerStatus"]; read by PowerStatus.qml via getCustom.
SettingsSchema {
    title: "Battery"
    icon: "" // tabler battery
    key: "powerStatus"
    fields: [
        ({
                key: "colour",
                type: "enum",
                label: "Icon colour",
                "default": "secondary",
                options: ["primary", "secondary", "tertiary", "error", "on_surface"]
            })
    ]
}
