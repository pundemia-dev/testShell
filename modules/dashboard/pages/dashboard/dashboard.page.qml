import qs.components
import QtQuick
import qs.components.misc

// Manifest for the primary Dashboard page. Declares its own title + icon (the
// modular contract) and lazily builds Dash on demand.
DashboardPage {
    title: qsTr("Dashboard")
    icon: "\uea87" // tabler dashboard
    order: 0

    content: Component {
        Dash {}
    }
}
