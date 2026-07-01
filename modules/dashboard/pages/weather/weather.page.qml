import qs.components
import QtQuick

DashboardPage {
    title: qsTr("Weather")
    icon: "\uea76" // tabler cloud
    order: 30

    content: Component {
        WeatherContent {}
    }
}
