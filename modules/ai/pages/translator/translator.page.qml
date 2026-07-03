import qs.components
import QtQuick
import qs.components.misc

DashboardPage {
    title: qsTr("Translate")
    icon: "" // tabler language
    order: 20

    content: Component {
        TranslatorPage {}
    }
}
