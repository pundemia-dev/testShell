import qs.components.misc
import QtQuick

// AI binding of the generic PluginRegistry: scans ../pages/<id>/ for
// `<id>.page.qml` manifests (PluginManifest). No user ordering config —
// pages sort by their manifest `order` hint, then title.
PluginRegistry {
    property int currentTab: 0

    // Host-facing alias kept from the pre-PluginRegistry API.
    readonly property var pages: active

    folder: Qt.resolvedUrl("../pages")
    suffix: "page"
}
