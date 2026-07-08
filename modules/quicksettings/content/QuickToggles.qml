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
// Toggles card). Deliberately NOT a card plugin — the set is hardcoded;
// individual buttons are switched via Config.quicksettings.toggles and
// ordered via Config.quicksettings.togglesOrder.
QsCard {
    id: root

    readonly property list<string> defaultOrder: ["wifi", "bluetooth", "mic", "dnd", "settings"]

    // Known keys in user order, keys missing from config appended by default.
    readonly property var orderedKeys: {
        const o = (Config.quicksettings.togglesOrder ?? []).filter(k => defaultOrder.includes(k));
        return o.concat(defaultOrder.filter(k => !o.includes(k)));
    }

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

            Repeater {
                model: root.orderedKeys

                delegate: Toggle {
                    id: button

                    required property string modelData

                    visible: Config.quicksettings.toggles[modelData] ?? false
                    toggle: modelData !== "settings"
                    inactiveOnColour: Colours.palette.on_surface_variant
                    icon: ({
                        wifi: "",       // tabler wifi
                        bluetooth: "",  // tabler bluetooth
                        mic: "",        // tabler microphone
                        dnd: "",        // tabler bell-off
                        settings: ""    // tabler settings
                    })[modelData] ?? ""

                    checked: {
                        switch (button.modelData) {
                        case "wifi":
                            return Nmcli.wifiEnabled;
                        case "bluetooth":
                            return Bluetooth.defaultAdapter?.enabled ?? false;
                        case "mic":
                            return !Audio.sourceMuted;
                        case "dnd":
                            return Notifs.dnd;
                        default:
                            return false;
                        }
                    }

                    onClicked: {
                        switch (modelData) {
                        case "wifi":
                            Nmcli.toggleWifi(null);
                            break;
                        case "bluetooth": {
                            const adapter = Bluetooth.defaultAdapter;
                            if (adapter)
                                adapter.enabled = !adapter.enabled;
                            break;
                        }
                        case "mic":
                            Audio.toggleSourceMute();
                            break;
                        case "dnd":
                            Notifs.dnd = !Notifs.dnd;
                            break;
                        case "settings":
                            IpcManager.show("quicksettings", false);
                            Quickshell.execDetached(["qs", "-c", "pShell", "ipc", "call", "settings", "activate"]);
                            break;
                        }
                    }
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
