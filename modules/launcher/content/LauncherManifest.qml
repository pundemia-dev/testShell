import qs.components.misc

// Slot contract for launcher plugin units (modules/launcher/plugins/<id>/):
// the generic PluginManifest (id/title/icon/order/settingsSchema + lazy
// `content`) plus the launcher-specific metadata the host needs without
// instantiating the module. `content` must build a LauncherModule.
PluginManifest {
    // Secondary line in the module-selection list (magic-symbol mode).
    property string description: ""

    // Строка-триггер (БЕЗ магического символа), например "gif", "wp".
    // Reserved for CLI/shortcut activation flows.
    property string trigger: ""
}
