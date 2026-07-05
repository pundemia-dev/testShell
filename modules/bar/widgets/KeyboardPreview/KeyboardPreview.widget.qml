import qs.components.misc

// Manifest for the Keyboard layout bar widget. The implementation (KeyboardPreview.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "Keyboard layout"
    icon: ""
    order: 50

    settingsSchema: SettingsSchema {
        title: "Keyboard layout"
        icon: "" // tabler keyboard
        key: "keyboardPreview"
        fields: [
            ({
                    key: "colour",
                    type: "enum",
                    label: "Colour",
                    "default": "secondary",
                    options: ["primary", "secondary", "tertiary", "error", "on_surface"]
                }),
            ({
                    key: "showIcon",
                    type: "bool",
                    label: "Show icon",
                    "default": false
                }),
            ({
                    key: "showLayout",
                    type: "bool",
                    label: "Show layout name",
                    "default": true
                })
        ]
    }
}
