pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

// The fixed bottom card: a row of round toggle buttons (caelestia's
// Toggles card). Deliberately NOT a card plugin — the set is hardcoded and
// individual buttons are switched via Config.quicksettings.toggles.
QsCard {
    id: root

    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Quick Toggles")
            font: Appearance.font.body.medium
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Toggle {
                visible: Config.quicksettings.toggles.wifi
                icon: "\ueb52" // tabler wifi
                checked: Nmcli.wifiEnabled
                onClicked: Nmcli.toggleWifi(null)
            }

            Toggle {
                visible: Config.quicksettings.toggles.bluetooth
                icon: "\uea37" // tabler bluetooth
                checked: Bluetooth.defaultAdapter?.enabled ?? false
                onClicked: {
                    const adapter = Bluetooth.defaultAdapter;
                    if (adapter)
                        adapter.enabled = !adapter.enabled;
                }
            }

            Toggle {
                visible: Config.quicksettings.toggles.mic
                icon: "\ueaf0" // tabler microphone
                checked: !Audio.sourceMuted
                onClicked: Audio.toggleSourceMute()
            }

            Toggle {
                visible: Config.quicksettings.toggles.dnd
                icon: "\uece9" // tabler bell-off
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            Toggle {
                visible: Config.quicksettings.toggles.settings
                toggle: false
                icon: "\ueb20" // tabler settings
                inactiveOnColour: Colours.palette.on_surface_variant
                onClicked: {
                    IpcManager.show("quicksettings", false);
                    Quickshell.execDetached(["qs", "-c", "pShell", "ipc", "call", "settings", "activate"]);
                }
            }
        }
    }

    component Toggle: IconButton {
        Layout.fillWidth: true
        toggle: true
        isRound: true
        padding: Appearance.padding.medium
        inactiveColour: Colours.layer(Colours.palette.surface_container_highest, 2)
    }
}
