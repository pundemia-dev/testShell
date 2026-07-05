import qs.components.misc

// Manifest for the System tray bar widget. The implementation (Tray.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "System tray"
    icon: ""
    order: 30

    settingsSchema: SettingsSchema {
        title: "System tray"
        icon: "" // tabler apps
        key: "tray"
        fields: [
            ({
                    key: "background",
                    type: "bool",
                    label: "Background",
                    "default": false,
                    description: "Draw a filled background behind the tray icons."
                }),
            ({
                    key: "compact",
                    type: "bool",
                    label: "Compact",
                    "default": false,
                    description: "Collapse icons behind an expand toggle."
                }),
            ({
                    key: "recolour",
                    type: "bool",
                    label: "Recolour icons",
                    "default": false
                })
        ]
    }
}
