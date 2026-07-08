import qs.components.misc
import QtQuick

// Manifest for the idle-inhibit ("keep awake") card.
PluginManifest {
    title: qsTr("Keep Awake")
    icon: "\uef0e" // tabler coffee
    order: 0

    content: Component {
        CoffeeCard {}
    }
}
