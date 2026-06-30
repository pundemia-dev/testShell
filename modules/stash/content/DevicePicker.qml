import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.components.controls

StyledRect {
    id: root

    required property string stateText
    required property var devices
    required property bool sending
    property bool scanning: false

    signal picked(string ip)
    signal rescan

    color: Colours.tPalette.surface
    radius: Appearance.rounding.normal
    opacity: 0.97

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.small

        // Header: state label + lone rescan button.
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
                id: rescanBtn
                icon: "\ueb13"
                type: IconButton.Tonal
                implicitHeight: 28
                disabled: root.sending
                onClicked: {
                    if (!root.sending)
                        root.rescan();
                }

                // While scanning, the icon spins one full turn on a bezier
                // ease (accelerate \u2192 settle), pauses, then repeats \u2014 a
                // "thinking" indicator. Resets upright when scanning stops.
                SequentialAnimation {
                    running: root.scanning
                    loops: Animation.Infinite
                    NumberAnimation {
                        target: rescanBtn.label
                        property: "rotation"
                        from: 360
                        to: 0
                        duration: Appearance.anim.durations.extraLarge
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.bubblyHeight
                    }
                    PauseAnimation {
                        duration: Appearance.anim.durations.small
                    }
                    onStopped: rescanBtn.label.rotation = 0
                }
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

        // Device list — height capped at visibleDevicesMax rows. If more
        // devices are discovered, the user scrolls within the cap.
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Hard ceiling. Each row ≈ deviceRowH (kept in sync with
            // StashContent._deviceRowH). +spacing for the gap.
            Layout.maximumHeight: Config.stash.visibleDevicesMax * 60 + (Config.stash.visibleDevicesMax - 1) * Appearance.spacing.smaller
            model: root.devices
            clip: true
            spacing: Appearance.spacing.smaller
            visible: !root.sending

            delegate: Item {
                id: wrap
                required property int index
                required property string alias
                required property string ip
                required property string deviceType
                required property string deviceModel

                width: ListView.view.width
                implicitHeight: unit.implicitHeight

                DeviceUnit {
                    id: unit
                    anchors.fill: parent
                    alias: wrap.alias
                    ip: wrap.ip
                    deviceType: wrap.deviceType
                    deviceModel: wrap.deviceModel
                    onPicked: root.picked(wrap.ip)
                }
            }
        }

        // Sending status message
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.sending
            spacing: Appearance.spacing.small

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                text: "Uploading file…"
                color: Colours.palette.on_surface_variant
                Layout.alignment: Qt.AlignHCenter
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
