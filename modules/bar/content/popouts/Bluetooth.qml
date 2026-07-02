pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

// Bluetooth popout: enable/discover toggles + a list of devices (connected
// first), each with connect/disconnect and a forget action for bonded ones.
ColumnLayout {
    id: root

    function batteryGlyph(level: real): string {
        if (level >= 0.875)
            return ""; // battery-4
        if (level >= 0.625)
            return ""; // battery-3
        if (level >= 0.375)
            return ""; // battery-2
        if (level >= 0.125)
            return ""; // battery-1
        return ""; // battery
    }

    width: Appearance.font.size.normal * 22
    spacing: Appearance.spacing.small

    StyledText {
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("Bluetooth")
        font.pointSize: Appearance.font.size.normal
        font.weight: Font.Medium
    }

    Toggle {
        label: qsTr("Enabled")
        checked: Bluetooth.defaultAdapter?.enabled ?? false
        onToggled: checked => {
            const a = Bluetooth.defaultAdapter;
            if (a)
                a.enabled = checked;
        }
    }

    Toggle {
        label: qsTr("Discovering")
        checked: Bluetooth.defaultAdapter?.discovering ?? false
        onToggled: checked => {
            const a = Bluetooth.defaultAdapter;
            if (a)
                a.discovering = checked;
        }
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.small
        Layout.rightMargin: Appearance.padding.small
        text: {
            const devices = Bluetooth.devices.values;
            let s = qsTr("%1 device(s) available").arg(devices.length);
            const connected = devices.filter(d => d.connected).length;
            if (connected > 0)
                s += qsTr(" (%1 connected)").arg(connected);
            return s;
        }
        color: Colours.palette.on_surface_variant
    }

    Repeater {
        model: ScriptModel {
            values: [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)).slice(0, 5)
        }

        RowLayout {
            id: dev

            required property BluetoothDevice modelData
            readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

            Layout.fillWidth: true
            Layout.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.small

            opacity: 0
            scale: 0.7
            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }
            Behavior on opacity {
                Anim {}
            }
            Behavior on scale {
                Anim {}
            }

            StyledIcon {
                text: Icons.getBluetoothIcon(dev.modelData.icon)
                color: dev.modelData.connected ? Colours.palette.primary : Colours.palette.on_surface_variant
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Appearance.spacing.small
                text: dev.modelData.name
                elide: Text.ElideRight
                color: dev.modelData.connected ? Colours.palette.primary : Colours.palette.on_surface
            }

            StyledIcon {
                visible: dev.modelData.connected && dev.modelData.batteryAvailable
                text: root.batteryGlyph(dev.modelData.battery)
                font.pointSize: Appearance.font.size.small
                color: dev.modelData.battery < 0.2 ? Colours.palette.error : Colours.palette.on_surface_variant
            }

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: connectIcon.implicitHeight + Appearance.padding.small
                radius: Appearance.rounding.full
                color: Qt.alpha(Colours.palette.primary, dev.modelData.connected ? 1 : 0)

                CircularIndicator {
                    anchors.fill: parent
                    running: dev.loading
                }

                StateLayer {
                    color: dev.modelData.connected ? Colours.palette.on_primary : Colours.palette.on_surface
                    disabled: dev.loading

                    function onClicked(): void {
                        dev.modelData.connected = !dev.modelData.connected;
                    }
                }

                StyledIcon {
                    id: connectIcon

                    anchors.centerIn: parent
                    text: dev.modelData.connected ? "" : "" // link-off / link
                    opacity: dev.loading ? 0 : 1
                    color: dev.modelData.connected ? Colours.palette.on_primary : Colours.palette.on_surface

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }

            StyledRect {
                visible: dev.modelData.bonded
                implicitWidth: implicitHeight
                implicitHeight: forgetIcon.implicitHeight + Appearance.padding.small
                radius: Appearance.rounding.full

                StateLayer {
                    function onClicked(): void {
                        dev.modelData.forget();
                    }
                }

                StyledIcon {
                    id: forgetIcon
                    anchors.centerIn: parent
                    text: "" // trash
                    color: Colours.palette.on_surface
                }
            }
        }
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: sw.checked
        signal toggled(bool checked)

        Layout.fillWidth: true
        Layout.rightMargin: Appearance.padding.small
        spacing: Appearance.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: parent.label
        }

        StyledSwitch {
            id: sw
            onToggled: parent.toggled(checked)
        }
    }
}
