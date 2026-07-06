import QtQuick
import qs.components.misc
import qs.modules.launcher.content

// Manifest for the notes launcher module. Metadata + settings schema (values
// live in Config.custom.notes); the implementation (NotesModule) is built
// lazily on activation. Browses an Obsidian vault: fuzzy note search, full-text
// (rg/grep), quick-capture into the daily note, and an editable daily preview.
LauncherManifest {
    title: "Notes"
    description: "Search your Obsidian vault, capture to the daily note"
    icon: "" // tabler notes
    trigger: "notes"
    order: 13

    settingsSchema: SettingsSchema {
        title: "Notes"
        icon: "" // tabler notes
        key: "notes"
        fields: [
            ({
                    key: "vaultPath",
                    type: "string",
                    label: "Vault path",
                    description: "Absolute path to your Obsidian vault folder (e.g. /home/you/Obsidian/Knowledge). Required.",
                    "default": ""
                }),
            ({
                    key: "vaultName",
                    type: "string",
                    label: "Vault name",
                    description: "Vault name used in obsidian:// links. Leave empty to use the vault folder's name.",
                    "default": ""
                }),
            ({
                    key: "dailyNoteFolder",
                    type: "string",
                    label: "Daily note folder",
                    description: "Folder (relative to the vault) where daily notes live. Empty = vault root.",
                    "default": ""
                }),
            ({
                    key: "dailyNoteFormat",
                    type: "string",
                    label: "Daily note format",
                    description: "moment.js-style date format for the daily-note filename (subset: YYYY MM DD MMMM MMM dddd ddd HH mm).",
                    "default": "YYYY-MM-DD"
                }),
            ({
                    key: "templatePath",
                    type: "string",
                    label: "Daily note template",
                    description: "Absolute path to a Templates file used when creating a new daily note. Supports {{date}}, {{time}}, {{title}} (and {{date:FMT}}). Optional.",
                    advanced: true,
                    "default": ""
                })
        ]
    }

    content: Component {
        NotesModule {}
    }
}
