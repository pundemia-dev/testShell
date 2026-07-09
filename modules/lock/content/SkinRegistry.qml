import QtQuick
import qs.config
import qs.components.misc

// Lock-skin discovery: scans ../skins/<id>/ for `<id>.skin.qml` manifests
// (PluginManifest whose `content` is the full-surface visual). The active skin
// is picked by Config.lock.skin; unknown/missing ids fall back to the first
// discovered skin so the session can always lock.
PluginRegistry {
    id: root

    readonly property var activeSkin: all.find(s => s.id === Config.lock.skin) ?? active[0] ?? null

    folder: Qt.resolvedUrl("../skins")
    suffix: "skin"
}
