import qs.components
import qs.components.misc

// Per-widget settings for the OS icon. Surfaced inline on the Bar settings page
// (WidgetSettings.qml); values persist in Config.custom["osIcon"] and are read
// by OsIcon.qml via Config.getCustom("osIcon", <field>, <default>).
SettingsSchema {
    title: "OS icon"
    icon: "" // tabler device-desktop
    key: "osIcon"
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
