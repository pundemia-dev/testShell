import qs.components.misc

// Manifest for the Battery bar widget. The implementation (PowerStatus.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "Battery"
    icon: ""
    order: 80

    settingsSchema: SettingsSchema {
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
}
