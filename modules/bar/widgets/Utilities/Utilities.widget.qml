import qs.components.misc

// Manifest for the Utilities bar widget. The implementation (Utilities.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "Utilities"
    icon: ""
    order: 20

    settingsSchema: SettingsSchema {
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
}
