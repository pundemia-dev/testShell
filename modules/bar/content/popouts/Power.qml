pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Performance-manager popout: battery summary (when present) + a segmented
// power-profile selector (saver / balanced / performance) with an animated
// indicator, plus a warning card when the profile is degraded.
ColumnLayout {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev.isLaptopBattery

    function formatSeconds(s: int, fallback: string): string {
        const hr = Math.floor(s / 3600);
        const min = Math.floor(s / 60) % 60;
        let comps = [];
        if (hr > 0)
            comps.push(qsTr("%1 h").arg(hr));
        if (min > 0)
            comps.push(qsTr("%1 min").arg(min));
        return comps.join(", ") || fallback;
    }

    width: Appearance.font.size.normal * 20
    spacing: Appearance.spacing.medium

    StyledText {
        Layout.fillWidth: true
        text: root.hasBattery ? qsTr("Remaining: %1%").arg(Math.round(root.dev.percentage * 100)) : qsTr("No battery detected")
        font.pointSize: Appearance.font.size.normal
        font.weight: Font.Medium
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.hasBattery
        text: UPower.onBattery ? qsTr("Time remaining: %1").arg(root.formatSeconds(root.dev.timeToEmpty, qsTr("Calculating…"))) : qsTr("Until charged: %1").arg(root.formatSeconds(root.dev.timeToFull, qsTr("Fully charged")))
        color: Colours.palette.on_surface_variant
    }

    // Degraded-performance warning.
    StyledRect {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
        implicitHeight: visible ? warn.implicitHeight + Appearance.padding.medium * 2 : 0
        radius: Appearance.rounding.large
        color: Colours.palette.error

        ColumnLayout {
            id: warn
            anchors.centerIn: parent
            width: parent.width - Appearance.padding.medium * 2
            spacing: Appearance.spacing.small

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Performance degraded")
                color: Colours.palette.on_error
                font.weight: Font.Medium
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Reason: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
                color: Colours.palette.on_error
            }
        }
    }

    // Segmented profile selector.
    StyledRect {
        id: selector

        readonly property var profiles: [
            {profile: PowerProfile.PowerSaver, icon: ""},  // leaf
            {profile: PowerProfile.Balanced, icon: ""},    // scale
            {profile: PowerProfile.Performance, icon: ""}  // rocket
        ]
        readonly property int activeIndex: {
            const p = PowerProfiles.profile;
            if (p === PowerProfile.PowerSaver)
                return 0;
            if (p === PowerProfile.Performance)
                return 2;
            return 1;
        }
        readonly property real cellWidth: width / 3

        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        implicitHeight: Appearance.font.size.larger + Appearance.padding.large * 2
        radius: Appearance.rounding.full
        color: Colours.palette.surface_container

        StyledRect {
            id: indicator
            x: selector.activeIndex * selector.cellWidth + Appearance.padding.small
            y: Appearance.padding.small
            width: selector.cellWidth - Appearance.padding.small * 2
            height: parent.height - Appearance.padding.small * 2
            radius: Appearance.rounding.full
            color: Colours.palette.primary

            Behavior on x {
                Anim {}
            }
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: selector.profiles

                Item {
                    id: cell

                    required property int index
                    required property var modelData
                    readonly property bool active: selector.activeIndex === index

                    width: selector.cellWidth
                    height: selector.height

                    StateLayer {
                        radius: Appearance.rounding.full
                        color: cell.active ? Colours.palette.on_primary : Colours.palette.on_surface
                        function onClicked(): void {
                            PowerProfiles.profile = cell.modelData.profile;
                        }
                    }

                    StyledIcon {
                        anchors.centerIn: parent
                        text: cell.modelData.icon
                        fill: cell.active ? 1 : 0
                        color: cell.active ? Colours.palette.on_primary : Colours.palette.on_surface_variant
                    }
                }
            }
        }
    }
}
