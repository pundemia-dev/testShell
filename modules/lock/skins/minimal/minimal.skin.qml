import QtQuick
import qs.components.misc

PluginManifest {
    title: qsTr("Minimal")
    icon: "" // tabler clock
    order: 10

    content: Component {
        MinimalSkin {}
    }
}
