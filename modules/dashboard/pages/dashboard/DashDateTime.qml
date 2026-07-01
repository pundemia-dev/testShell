pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

// Vertical clock (hour / ••• / minute / am-pm). 1:1 port of caelestia
// dash/DateTime.qml on pShell tokens.
Item {
    id: root

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: Config.dashboard.dash.dateTimeWidth

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StyledText {
            Layout.bottomMargin: -(font.pointSize * 0.4)
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            color: Colours.palette.secondary
            font.pointSize: 35
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "•••"
            color: Colours.palette.primary
            font.pointSize: 35 * 0.9
        }
        StyledText {
            Layout.topMargin: -(font.pointSize * 0.4)
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            color: Colours.palette.secondary
            font.pointSize: 35
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: Time.amPmStr !== ""
            text: Time.amPmStr
            color: Colours.palette.primary
            font.pointSize: 22
            font.weight: Font.DemiBold
        }
    }
}
