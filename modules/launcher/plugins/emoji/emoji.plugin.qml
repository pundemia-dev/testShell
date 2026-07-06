import QtQuick
import qs.components.misc
import qs.modules.launcher.content

// Manifest for the emoji-picker launcher module. Metadata + settings schema
// (values live in Config.custom.emoji); the implementation (EmojiModule) is a
// panel-only picker built lazily on activation.
LauncherManifest {
    title: "Emoji"
    description: "Search and copy emoji"
    icon: "" // tabler mood-smile
    trigger: "emoji"
    order: 12

    settingsSchema: SettingsSchema {
        title: "Emoji"
        icon: "" // tabler mood-smile
        key: "emoji"
        fields: [
            ({
                    key: "autoPaste",
                    type: "bool",
                    label: "Auto-paste on select",
                    description: "After copying, emulate Ctrl+V to paste into the focused window (needs wtype/ydotool).",
                    "default": false
                }),
            ({
                    key: "recentsLimit",
                    type: "int",
                    label: "Recents limit",
                    description: "How many recently-used emoji to keep.",
                    min: 8,
                    max: 96,
                    "default": 48
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
        EmojiModule {}
    }
}
