pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            text: "\ueafc"
            font.family: Appearance.font.family.tabler
            font.pointSize: Appearance.font.size.large
            color: Colours.palette.primary
        }
        StyledText {
            Layout.fillWidth: true
            text: qsTr("Lyrics")
            font: Appearance.font.title.medium
        }
    }

    LyricList {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    SplitButton {
        Layout.alignment: Qt.AlignHCenter

        type: SplitButton.Tonal
        disabled: !Players.list.length
        active: menuItems.find(m => m.modelData === Players.active) ?? menuItems[0] ?? null
        menu.onItemSelected: item => Players.manualActive = (item as PlayerItem).modelData

        menuItems: playerList.instances
        fallbackIcon: "\ueafc"
        fallbackText: qsTr("No players")
        label.elide: Text.ElideRight
        stateLayer.disabled: true
        menuOnTop: true

        Variants {
            id: playerList
            model: Players.list
            PlayerItem {}
        }
    }

    component PlayerItem: MenuItem {
        required property MprisPlayer modelData

        icon: modelData === Players.active ? "\uea5e" : ""
        text: modelData.identity
        activeIcon: "\ueafc"
    }
}
