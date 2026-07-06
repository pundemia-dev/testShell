import QtQuick
import qs.components.misc
import qs.modules.launcher.content

// Manifest for the Wallpaper Engine launcher module. Carries the module's
// settings schema (values live in Config.custom.wallpapers); the heavy
// implementation (WallpapersModule + carousel + walltool settings UI) is
// built lazily on activation.
LauncherManifest {
    title: "Wallpaper Engine"
    description: "Manage backgrounds, themes, slideshows and history"
    icon: "" // tabler wallpaper
    trigger: "wp"
    order: 20

    settingsSchema: SettingsSchema {
        title: "Wallpaper Engine"
        icon: "" // tabler wallpaper
        key: "wallpapers"
        fields: [
            ({
                    key: "visibleItems",
                    type: "int",
                    label: "Visible items",
                    description: "Wallpapers visible in the carousel.",
                    "default": 5,
                    min: 3,
                    max: 9,
                    step: 2
                }),
            ({
                    key: "imageScale",
                    type: "real",
                    label: "Image scale",
                    description: "Card size multiplier (1.0 = base).",
                    "default": 2.0,
                    min: 1,
                    max: 4,
                    step: 0.1
                })
        ]
    }

    content: Component {
        WallpapersModule {}
    }
}
