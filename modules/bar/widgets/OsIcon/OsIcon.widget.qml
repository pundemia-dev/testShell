import qs.components.misc

// Manifest for the OS icon bar widget. The implementation (OsIcon.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "OS icon"
    icon: ""
    order: 0

    settingsSchema: SettingsSchema {
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
}
