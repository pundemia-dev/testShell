import qs.config
import qs.components.misc
import QtQuick

// Session binding of the generic PluginRegistry: scans ../plugins/<id>/ for
// `<id>.action.qml` manifests (SessionManifest) and applies the user's
// Config.session.order / .disabled. Drop a folder in → a button appears.
PluginRegistry {
    folder: Qt.resolvedUrl("../plugins")
    suffix: "action"
    order: Config.session.order ?? []
    disabled: Config.session.disabled ?? []
}
