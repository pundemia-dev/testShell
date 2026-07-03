import qs.components
import qs.components.misc

// Per-widget settings for the Network status indicator. Values persist in
// Config.custom["networkStatus"]; read by NetworkStatus.qml via getCustom.
SettingsSchema {
    title: "Network"
    icon: "" // tabler wifi
    key: "networkStatus"
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
