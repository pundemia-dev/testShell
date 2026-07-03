import qs.components
import QtQuick
import qs.components.misc

DashboardPage {
    title: qsTr("Chat")
    icon: "" // tabler brain
    order: 10

    content: Component {
        ChatPage {}
    }
}
