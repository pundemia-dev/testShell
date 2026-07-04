import qs.config
import qs.components.misc
import QtQuick

// Dashboard binding of the generic PluginRegistry: scans ../pages/<id>/ for
// `<id>.page.qml` manifests (PluginManifest) and applies the user's
// Config.dashboard.order / .disabled. Add a folder → tab appears.
PluginRegistry {
    property int currentTab: 0

    // Host-facing alias kept from the pre-PluginRegistry API.
    readonly property var pages: active

    folder: Qt.resolvedUrl("../pages")
    suffix: "page"
    order: Config.dashboard.order ?? []
    disabled: Config.dashboard.disabled ?? []
}
