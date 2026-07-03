import qs.components
import QtQuick

DashboardPage {
    title: qsTr("Translate")
    icon: "" // tabler language
    order: 20

    content: Component {
        TranslatorPage {}
    }
}
