import qs.components.misc
import QtQuick

// Manifest for the notification-history page.
PluginManifest {
    title: qsTr("Notifications")
    icon: "\uea35" // tabler bell
    order: 0

    content: Component {
        NotifsPage {}
    }
}
