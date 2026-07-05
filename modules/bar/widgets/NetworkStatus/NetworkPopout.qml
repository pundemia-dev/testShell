pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Wi-Fi popout: toggle radio, list nearby networks (sorted active-first then by
// strength), connect/disconnect, rescan. Mirrors the structure of the upstream
// caelestia Network popout but rebuilt on pShell's styled controls + the Tabler
// glyph set.
ColumnLayout {
    id: root

    property string connectingToSsid: ""

    width: Appearance.font.size.normal * 22
    spacing: Appearance.spacing.small

    StyledText {
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("Wireless")
        font.pointSize: Appearance.font.size.normal
        font.weight: Font.Medium
    }

    Toggle {
        label: qsTr("Enabled")
        checked: Nmcli.wifiEnabled
        onToggled: checked => Nmcli.enableWifi(checked, null)
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.small
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("%1 networks available").arg(Nmcli.networks.length)
        color: Colours.palette.on_surface_variant
    }

    Repeater {
        model: ScriptModel {
            values: [...Nmcli.networks].sort((a, b) => {
                if (a.active !== b.active)
                    return b.active - a.active;
                return b.strength - a.strength;
            }).slice(0, 8)
        }

        RowLayout {
            id: net

            required property var modelData
            readonly property bool loading: root.connectingToSsid === modelData.ssid

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
                text: Icons.getNetworkIcon(net.modelData.strength)
                color: net.modelData.active ? Colours.palette.primary : Colours.palette.on_surface_variant
            }

            StyledIcon {
                visible: net.modelData.isSecure
                text: "" // lock
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Appearance.spacing.small
                text: net.modelData.ssid
                elide: Text.ElideRight
                font.weight: net.modelData.active ? Font.Medium : Font.Normal
                color: net.modelData.active ? Colours.palette.primary : Colours.palette.on_surface
            }

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: connectIcon.implicitHeight + Appearance.padding.small
                radius: Appearance.rounding.full
                color: Qt.alpha(Colours.palette.primary, net.modelData.active ? 1 : 0)

                CircularIndicator {
                    anchors.fill: parent
                    running: net.loading
                }

                StateLayer {
                    color: net.modelData.active ? Colours.palette.on_primary : Colours.palette.on_surface
                    disabled: net.loading || !Nmcli.wifiEnabled

                    function onClicked(): void {
                        if (net.modelData.active) {
                            Nmcli.disconnectFromNetwork();
                        } else {
                            root.connectingToSsid = net.modelData.ssid;
                            Nmcli.connectToNetworkWithPasswordCheck(net.modelData.ssid, net.modelData.isSecure, () => {
                                root.connectingToSsid = "";
                            }, net.modelData.bssid);
                        }
                    }
                }

                StyledIcon {
                    id: connectIcon

                    anchors.centerIn: parent
                    text: net.modelData.active ? "" : "" // link-off / link
                    opacity: net.loading ? 0 : 1
                    color: net.modelData.active ? Colours.palette.on_primary : Colours.palette.on_surface

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        type: IconTextButton.Tonal
        icon: "" // refresh
        text: Nmcli.scanning ? qsTr("Scanning…") : qsTr("Rescan networks")
        enabled: !Nmcli.scanning && Nmcli.wifiEnabled
        opacity: enabled ? 1 : 0.6
        onClicked: Nmcli.rescanWifi()
    }

    Connections {
        target: Nmcli
        function onActiveChanged(): void {
            if (Nmcli.active && root.connectingToSsid === Nmcli.active.ssid)
                root.connectingToSsid = "";
        }
        function onConnectionFailed(ssid: string): void {
            if (root.connectingToSsid === ssid)
                root.connectingToSsid = "";
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
