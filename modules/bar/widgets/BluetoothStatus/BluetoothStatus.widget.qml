import qs.components.misc

// Manifest for the Bluetooth bar widget. The implementation (BluetoothStatus.qml) is
// loaded by URL (WidgetHost / palette previews); the manifest only carries
// palette metadata and the widget's settings schema.
PluginManifest {
    title: "Bluetooth"
    icon: ""
    order: 60

    settingsSchema: SettingsSchema {
        title: "Bluetooth"
        icon: "" // tabler bluetooth
        key: "bluetoothStatus"
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
