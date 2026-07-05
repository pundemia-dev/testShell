import qs.components.misc

// Manifest for the Clock bar widget. The implementation (Clock.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "Clock"
    icon: ""
    order: 40

    settingsSchema: SettingsSchema {
        title: "Clock"
        icon: "" // tabler clock
        key: "clock"
        fields: [
            ({
                    key: "colour",
                    type: "enum",
                    label: "Colour",
                    "default": "tertiary",
                    options: ["primary", "secondary", "tertiary", "error", "on_surface"]
                }),
            ({
                    key: "format24h",
                    type: "bool",
                    label: "24-hour clock",
                    "default": true,
                    hint: ({
                            text: "Off shows a 12-hour AM/PM time."
                        })
                }),
            ({
                    key: "showSeconds",
                    type: "bool",
                    label: "Show seconds",
                    "default": false
                })
        ]
    }
}
