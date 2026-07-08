import qs.components.misc
import QtQuick

// Manifest for the RSS news page.
PluginManifest {
    title: qsTr("News")
    icon: "\ueafd" // tabler news
    order: 1

    content: Component {
        NewsPage {}
    }
}
