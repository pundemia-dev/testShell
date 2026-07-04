import qs.components
import QtQuick
import qs.components.misc

PluginManifest {
    title: qsTr("Weather")
    icon: "\uea76" // tabler cloud
    order: 30

    content: Component {
        WeatherContent {}
    }
}
