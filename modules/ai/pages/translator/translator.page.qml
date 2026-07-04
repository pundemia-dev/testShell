import qs.components
import QtQuick
import qs.components.misc

PluginManifest {
    title: qsTr("Translate")
    icon: "" // tabler language
    order: 20

    content: Component {
        TranslatorPage {}
    }
}
