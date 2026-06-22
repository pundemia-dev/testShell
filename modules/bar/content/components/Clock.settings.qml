import qs.components

// DEMO of the third-party settings contract: a lightweight schema sibling to a
// bar widget. SettingsDiscovery picks it up and renders a "Clock" page; values
// persist in Config.custom["clock"]. A real widget would read them via
// Config.getCustom("clock", "<field>", <default>). Safe to delete.
SettingsSchema {
    title: "Clock"
    icon: "\uea70" // tabler clock
    key: "clock"
    fields: [
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
            }),
        ({
                key: "showDate",
                type: "bool",
                label: "Show date",
                "default": true
            })
    ]
}
