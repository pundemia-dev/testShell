import QtQuick
import qs.components.misc
import qs.modules.launcher.content

// Manifest for the clipboard-history launcher module. Metadata + settings
// schema (values live in Config.custom.clipboard); the implementation
// (ClipboardModule) is built lazily on activation.
LauncherManifest {
    title: "Clipboard"
    description: "Browse and paste clipboard history (cliphist)"
    icon: "" // tabler clipboard
    trigger: "clip"
    order: 15

    settingsSchema: SettingsSchema {
        title: "Clipboard"
        icon: "" // tabler clipboard
        key: "clipboard"
        fields: [
            ({
                    key: "historyLimit",
                    type: "int",
                    label: "History limit",
                    description: "Maximum number of clipboard entries to load.",
                    min: 10,
                    max: 500,
                    "default": 100
                }),
            ({
                    key: "autoPaste",
                    type: "bool",
                    label: "Auto-paste on select",
                    description: "After copying, emulate Ctrl+V to paste into the focused window (needs wtype/ydotool).",
                    "default": false
                }),
            ({
                    key: "pasteCommand",
                    type: "string",
                    label: "Paste command",
                    description: "Key-emulation command used for auto-paste.",
                    advanced: true,
                    "default": "wtype -M ctrl v -m ctrl"
                })
        ]
    }

    content: Component {
        ClipboardModule {}
    }
}
