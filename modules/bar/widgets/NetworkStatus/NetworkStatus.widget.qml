import qs.components.misc

// Manifest for the Network bar widget. The implementation (NetworkStatus.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "Network"
    icon: ""
    order: 70

    settingsSchema: SettingsSchema {
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
}
