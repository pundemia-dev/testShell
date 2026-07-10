pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.modules.settings.components
import QtQuick
import QtQuick.Layouts

// Config.notifs → modules/notifications/config/NotifsConfig.qml
// Popup behaviour + the shared background geometry card.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Notifications")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("Behaviour")
            icon: "" // tabler bell

            SwitchRow {
                label: qsTr("Auto-expire")
                checked: Config.notifs.expire
                onToggled: c => Config.notifs.expire = c
            }

            SpinBoxRow {
                label: qsTr("Default timeout (ms)")
                value: Config.notifs.defaultExpireTimeout
                min: 1000
                max: 30000
                step: 500
                onValueModified: v => Config.notifs.defaultExpireTimeout = v
            }

            SwitchRow {
                label: qsTr("Action on click")
                checked: Config.notifs.actionOnClick
                onToggled: c => Config.notifs.actionOnClick = c
            }

            SwitchRow {
                label: qsTr("Open expanded")
                checked: Config.notifs.openExpanded
                onToggled: c => Config.notifs.openExpanded = c
            }

            SwitchRow {
                label: qsTr("Exclude bar area")
                checked: Config.notifs.excludeBarArea
                onToggled: c => Config.notifs.excludeBarArea = c
            }

            SpinBoxRow {
                label: qsTr("Group preview count")
                value: Config.notifs.groupPreviewNum
                min: 1
                max: 10
                step: 1
                onValueModified: v => Config.notifs.groupPreviewNum = v
            }

            SpinBoxRow {
                label: qsTr("History limit")
                value: Config.notifs.historyLimit
                min: 0
                max: 1000
                step: 50
                onValueModified: v => Config.notifs.historyLimit = v
            }

            SpinBoxRow {
                label: qsTr("Width")
                value: Config.notifs.sizes.width
                min: 240
                max: 640
                step: 10
                onValueModified: v => Config.notifs.sizes.width = v
            }
        }

        BackgroundCard {
            cfg: Config.notifs
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
