import qs.config
import qs.components.misc

// Launcher binding of the generic PluginRegistry: scans ../plugins/<id>/ for
// `<id>.plugin.qml` manifests (LauncherManifest) and applies the user's
// Config.launcher.order / .disabled (blocklist semantics — drop a folder in,
// the module appears). `active[0]` is the launcher's default module.
PluginRegistry {
    folder: Qt.resolvedUrl("../plugins")
    suffix: "plugin"
    order: Config.launcher.order ?? []
    disabled: Config.launcher.disabled ?? []
}
