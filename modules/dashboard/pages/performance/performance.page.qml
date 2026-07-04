import qs.components
import QtQuick
import qs.components.misc

PluginManifest {
    title: qsTr("Performance")
    icon: "\ueab1" // tabler gauge
    order: 20

    content: Component {
        Performance {}
    }
}
