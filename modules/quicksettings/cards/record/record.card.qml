import qs.components.misc
import QtQuick

// Manifest for the screen-recorder card.
PluginManifest {
    title: qsTr("Screen Recorder")
    icon: "\ued22" // tabler video
    order: 10

    content: Component {
        RecordCard {}
    }
}
