pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.containers
import qs.components.controls
import QtQuick
import QtQuick.Layouts

// Notification history: header (title + DND + clear-all) over a scrolling
// list of the Notifs service history (the same store the popups feed).
Item {
    id: root

    readonly property var notifs: Notifs.notClosed

    RowLayout {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Notifications")
            font: Appearance.font.title.small
        }

        IconButton {
            icon: "\uece9" // tabler bell-off
            toggle: true
            isRound: true
            type: IconButton.Text
            checked: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }

        IconButton {
            icon: "\ueb41" // tabler trash
            isRound: true
            type: IconButton.Text
            disabled: root.notifs.length === 0
            onClicked: {
                for (const n of root.notifs.slice())
                    n.close();
            }
        }
    }

    StyledListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Appearance.spacing.medium

        clip: true
        spacing: Appearance.spacing.small
        model: root.notifs

        delegate: HistoryNotif {}
    }

    StyledScrollBar {
        flickable: list
        anchors.right: parent.right
        anchors.top: list.top
        anchors.bottom: list.bottom
    }

    // Empty state.
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.notifs.length === 0
        spacing: Appearance.spacing.small

        StyledIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "\uea35" // tabler bell
            color: Colours.palette.on_surface_variant
            font.pointSize: Appearance.font.size.extraLarge
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No notifications")
            color: Colours.palette.on_surface_variant
        }
    }
}
