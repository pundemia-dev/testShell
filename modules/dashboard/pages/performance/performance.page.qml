import qs.components
import QtQuick

DashboardPage {
    title: qsTr("Performance")
    icon: "\ueab1" // tabler gauge
    order: 20

    content: Component {
        Performance {}
    }
}
