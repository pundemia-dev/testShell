import qs.components
import QtQuick

DashboardPage {
    title: qsTr("Chat")
    icon: "" // tabler brain
    order: 10

    content: Component {
        ChatPage {}
    }
}
