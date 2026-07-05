import qs.components.misc

// Manifest for the Power menu bar widget. The implementation (Power.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "Power menu"
    icon: ""
    order: 90

    settingsSchema: SettingsSchema {
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
}
