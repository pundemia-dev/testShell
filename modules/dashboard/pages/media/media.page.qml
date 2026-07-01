import qs.components
import QtQuick

DashboardPage {
    title: qsTr("Media")
    icon: "\ueafc" // tabler music
    order: 10

    content: Component {
        MediaContent {}
    }
}
