import qs.components
import qs.components.misc

// Per-widget settings for the Clock. Values persist in Config.custom["clock"]
// and are read by Clock.qml via Config.getCustom("clock", <field>, <default>).
SettingsSchema {
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
