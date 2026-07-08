import qs.config
import qs.components.misc
import QtQuick

// Quicksettings binding of the generic PluginRegistry: scans ../pages/<id>/
// for `<id>.page.qml` manifests (PluginManifest) and applies the user's
// Config.quicksettings.order / .disabled. Add a folder → tab appears.
PluginRegistry {
    property int currentTab: 0

    readonly property var pages: active

    folder: Qt.resolvedUrl("../pages")
    suffix: "page"
    order: Config.quicksettings.order ?? []
    disabled: Config.quicksettings.disabled ?? []
}
