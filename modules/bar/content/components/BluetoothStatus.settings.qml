import qs.components

// Per-widget settings for the Bluetooth status indicator. Values persist in
// Config.custom["bluetoothStatus"]; read by BluetoothStatus.qml via getCustom.
SettingsSchema {
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
