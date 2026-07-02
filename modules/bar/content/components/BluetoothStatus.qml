import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick
import Quickshell.Bluetooth
import QtQuick.Layouts
import "../popouts" as BarPopouts


FlexboxLayout {
    id: root
    direction: Config.bar.orientation ? FlexboxLayout.Row : FlexboxLayout.Column
    alignItems: FlexboxLayout.AlignCenter
    justifyContent: FlexboxLayout.JustifyCenter

    property color colour: Colours.role(Config.getCustom("bluetoothStatus", "colour", "secondary"))

    gap: Appearance.spacing.small / 2

    PopoutHandle {
        edge: !Config.bar.orientation ? (Config.bar.position ? "right" : "left") : (Config.bar.position ? "bottom" : "top")
        popoutContent: Component {
            BarPopouts.Bluetooth {}
        }
    }

    property var connectedDevices: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
    property var firstDevice: connectedDevices.length > 0 ? connectedDevices[0] : null
    property var additionalDevices: connectedDevices.slice(1)
    property bool hasConnectedDevices: connectedDevices.length > 0

    RadialSliderIcon {
        id: bluetooth

        implicitHeight: 30
        implicitWidth: 40

        property bool isConnecting: root.firstDevice?.state === BluetoothDeviceState.Connecting
        property real batteryLevel: root.firstDevice?.battery ?? 0
        property real animatedProgress: 0

        label: root.hasConnectedDevices
               ? Icons.getBluetoothIcon(root.firstDevice.icon)
               : (Bluetooth.defaultAdapter?.enabled ? "\uea37" : "\ueceb")

        progress: isConnecting ? animatedProgress : batteryLevel
        animate: !isConnecting

        progressColor: root.hasConnectedDevices && batteryLevel <= 0.2
                       ? Colours.palette.error
                       : Colours.palette.primary

        labelColor: root.colour

        SequentialAnimation on animatedProgress {
            running: bluetooth.isConnecting
            alwaysRunToEnd: true
            loops: Animation.Infinite

            Anim {
                from: 1
                to: 0
                duration: Appearance.anim.durations.large
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
            Anim {
                from: 0
                to: 1
                duration: Appearance.anim.durations.large
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    Repeater {
        id: repeater

        model: ScriptModel {
            values: root.additionalDevices
        }

        RadialSliderIcon {
            id: deviceItem

            required property BluetoothDevice modelData

            property bool isConnecting: modelData.state === BluetoothDeviceState.Connecting
            property real batteryLevel: modelData.battery
            property real animatedProgress: 0

            implicitHeight: 30
            implicitWidth: 40

            label: Icons.getBluetoothIcon(modelData.icon)
            progress: isConnecting ? animatedProgress : batteryLevel
            animate: !isConnecting
            progressColor: batteryLevel > 0.2 ? Colours.palette.primary : Colours.palette.error
            labelColor: root.colour
            opacity: 0

            Component.onCompleted: {
                opacity = 1
            }

            Behavior on opacity {
                Anim {}
            }

            SequentialAnimation on animatedProgress {
                running: deviceItem.isConnecting
                alwaysRunToEnd: true
                loops: Animation.Infinite

                Anim {
                    from: 1
                    to: 0
                    duration: Appearance.anim.durations.large
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
                Anim {
                    from: 0
                    to: 1
                    duration: Appearance.anim.durations.large
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
        }
    }
}
