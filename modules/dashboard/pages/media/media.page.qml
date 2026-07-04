import qs.components
import QtQuick
import qs.components.misc

PluginManifest {
    title: qsTr("Media")
    icon: "\ueafc" // tabler music
    order: 10

    content: Component {
        MediaContent {}
    }
}
