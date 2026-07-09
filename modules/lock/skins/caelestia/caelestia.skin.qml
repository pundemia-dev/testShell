import QtQuick
import qs.components.misc

PluginManifest {
    title: qsTr("Caelestia")
    icon: "" // tabler lock
    order: 0

    content: Component {
        CaelestiaSkin {}
    }
}
