import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import qs.components.controls

StyledRect {
    id: root

    required property string stateText
    required property var    devices
    required property bool   sending

    signal picked(string ip)
    signal closed()

    color: Colours.palette.surface
    radius: Appearance.rounding.normal
    opacity: 0.97

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.small

        // Header row
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledIcon {
                text: root.sending ? "" : ""
                color: Colours.palette.primary
            }
            StyledText {
                Layout.fillWidth: true
                text: root.stateText
                color: Colours.palette.on_surface
                font.pointSize: Appearance.font.size.normal
                font.bold: true
            }
            IconButton {
                icon: ""
                type: IconButton.Text
                implicitHeight: 24
                onClicked: root.closed()
            }
        }

        // Indeterminate progress bar (shown while sending)
        Item {
            Layout.fillWidth: true
            height: 4
            clip: true
            visible: root.sending

            StyledRect {
                anchors.fill: parent
                radius: 2
                color: Qt.alpha(Colours.palette.primary, 0.22)
            }

            StyledRect {
                id: progressChunk
                width: parent.width * 0.38
                height: parent.height
                radius: 2
                color: Colours.palette.primary

                SequentialAnimation on x {
                    running: root.sending
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -progressChunk.width
                        to: progressChunk.parent.width
                        duration: 1300
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // Device list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.devices
            clip: true
            spacing: 4
            visible: !root.sending

            delegate: StyledRect {
                required property string alias
                required property string ip

                width: ListView.view.width
                height: 36
                radius: Appearance.rounding.small
                color: deviceMouse.containsMouse
                    ? Qt.alpha(Colours.palette.primary, 0.16)
                    : Colours.palette.surface_container

                Behavior on color { CAnim {} }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.small
                    spacing: Appearance.spacing.normal

                    IconImage {
                        source: Quickshell.iconPath("computer", "network-wired")
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        asynchronous: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: alias
                            color: Colours.palette.on_surface
                            font.pointSize: Appearance.font.size.normal
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: ip
                            color: Colours.palette.on_surface_variant
                            font.pointSize: Appearance.font.size.smaller
                        }
                    }
                }

                MouseArea {
                    id: deviceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.picked(ip)
                }
            }
        }

        // Sending status message
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.sending
            spacing: Appearance.spacing.small

            Item { Layout.fillHeight: true }

            StyledText {
                text: "Uploading file…"
                color: Colours.palette.on_surface_variant
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }
        }
    }
}
