import qs.components
import QtQuick
import qs.components.misc

PluginManifest {
    title: qsTr("Chat")
    icon: "" // tabler brain
    order: 10

    content: Component {
        ChatPage {}
    }
}
