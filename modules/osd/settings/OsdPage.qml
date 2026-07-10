pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.modules.settings.components
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

        BackgroundCard {
            cfg: Config.osd
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
