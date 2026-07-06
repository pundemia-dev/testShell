import QtQuick
import qs.components.misc
import qs.modules.launcher.content

// Manifest for the GIF search launcher module. Carries the module's settings
// schema (values live in Config.custom.gif); the implementation (GifModule)
// is built lazily on activation.
LauncherManifest {
    title: "GIF Search"
    description: "Search and copy GIFs from Giphy"
    icon: "" // tabler gif
    trigger: "gif"
    order: 10

    settingsSchema: SettingsSchema {
        title: "GIF Search"
        icon: "" // tabler gif
        key: "gif"
        advanced: true
        fields: [
            ({
                    key: "apiKey",
                    type: "string",
                    label: "Giphy API key",
                    description: "Used by the GIF search module.",
                    "default": ""
                })
        ]
    }

    content: Component {
        GifModule {}
    }
}
