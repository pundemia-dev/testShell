pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import QtQuick
import QtQuick.Layouts

// Config.osd → modules/osd/config/OsdConfig.qml
// OSD panel enable/position/behaviour + which extra controls the hover
// sections expose.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // ── Anchor helpers (same contract as the translator) ────────────────────
    readonly property string currentEdge: {
        const a = Config.osd.anchors;
        if (a.top) return "top";
        if (a.bottom) return "bottom";
        if (a.left) return "left";
        if (a.right) return "right";
        if (a.horizontalCenter && a.verticalCenter) return "center";
        return "right";
    }
    function setEdge(edge: string): void {
        const a = Config.osd.anchors;
        a.left = edge === "left";
        a.right = edge === "right";
        a.top = edge === "top";
        a.bottom = edge === "bottom";
        a.horizontalCenter = edge === "top" || edge === "bottom" || edge === "center";
        a.verticalCenter = edge === "left" || edge === "right" || edge === "center";
    }

    component PillRow: Flow {
        id: pillRow
        property var model: []
        property string current: ""
        signal picked(string key)

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Repeater {
            model: pillRow.model

            delegate: StyledRect {
                id: pill
                required property var modelData
                readonly property bool active: pillRow.current === modelData.key

                implicitWidth: pillLabel.implicitWidth + Appearance.padding.medium * 2
                implicitHeight: pillLabel.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.small
                color: active ? Colours.palette.secondary_container : Colours.palette.surface_container_high

                StyledText {
                    id: pillLabel
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    font.pointSize: Appearance.font.size.small
                    color: pill.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pillRow.picked(pill.modelData.key)
                }
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("OSD")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        // ── Panel ───────────────────────────────────────────────────────────
        SettingSection {
            title: qsTr("Panel")
            icon: "\ueb51" // volume

            SwitchRow {
                label: qsTr("Enabled")
                checked: Config.osd.enabled
                onToggled: checked => Config.osd.enabled = checked
            }

            SpinBoxRow {
                label: qsTr("Auto-hide delay (ms)")
                value: Config.osd.hideDelay
                min: 500
                max: 10000
                step: 250
                onValueModified: v => Config.osd.hideDelay = v
            }

            SpinBoxRow {
                label: qsTr("Slider length")
                value: Config.osd.sliderLength
                min: 80
                max: 400
                step: 10
                visible: Config.general.advanced
                onValueModified: v => Config.osd.sliderLength = v
            }

            SpinBoxRow {
                label: qsTr("Slider thickness")
                value: Config.osd.sliderThickness
                min: 24
                max: 80
                step: 4
                visible: Config.general.advanced
                onValueModified: v => Config.osd.sliderThickness = v
            }

            SpinBoxRow {
                label: qsTr("Expansion size")
                value: Config.osd.expansionSize
                min: 180
                max: 500
                step: 10
                visible: Config.general.advanced
                onValueModified: v => Config.osd.expansionSize = v
            }
        }

        // ── Position ─────────────────────────────────────────────────────────
        SettingSection {
            title: qsTr("Position")
            icon: "\uea03" // adjustments

            SettingRow {
                label: qsTr("Anchor")
                description: qsTr("Left/Right stack the sliders vertically; Top/Bottom/Center lay them out horizontally.")
                showSeparator: false

                PillRow {
                    model: [
                        { key: "left", label: qsTr("Left") },
                        { key: "right", label: qsTr("Right") },
                        { key: "top", label: qsTr("Top") },
                        { key: "bottom", label: qsTr("Bottom") },
                        { key: "center", label: qsTr("Center") }
                    ]
                    current: root.currentEdge
                    onPicked: key => root.setEdge(key)
                }
            }
        }

        // ── Audio ─────────────────────────────────────────────────────────────
        SettingSection {
            title: qsTr("Audio")
            icon: "\uea8b" // speaker

            SpinBoxRow {
                label: qsTr("Max volume (%)")
                value: Math.round(Config.osd.maxVolume * 100)
                min: 100
                max: 150
                step: 5
                onValueModified: v => Config.osd.maxVolume = v / 100
            }

            SpinBoxRow {
                label: qsTr("Volume step (%)")
                value: Math.round(Config.osd.volumeStep * 100)
                min: 1
                max: 25
                step: 1
                visible: Config.general.advanced
                onValueModified: v => Config.osd.volumeStep = v / 100
            }

            SwitchRow {
                label: qsTr("Microphone slider")
                checked: Config.osd.enableMicrophone
                onToggled: checked => Config.osd.enableMicrophone = checked
            }

            SwitchRow {
                label: qsTr("Per-app volume")
                checked: Config.osd.showPerAppStreams
                onToggled: checked => Config.osd.showPerAppStreams = checked
            }
        }

        // ── Display ────────────────────────────────────────────────────────────
        SettingSection {
            title: qsTr("Display")
            icon: "\ueb30" // sun

            SwitchRow {
                label: qsTr("Brightness slider")
                checked: Config.osd.enableBrightness
                onToggled: checked => Config.osd.enableBrightness = checked
            }

            SpinBoxRow {
                label: qsTr("Brightness step (%)")
                value: Math.round(Config.osd.brightnessStep * 100)
                min: 1
                max: 25
                step: 1
                visible: Config.general.advanced
                onValueModified: v => Config.osd.brightnessStep = v / 100
            }
        }
    }
}
