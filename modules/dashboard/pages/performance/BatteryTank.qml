pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Battery "tank": a liquid fill that rises with charge, with the label drawn
// twice (dim on the empty part, bright on the filled part). 1:1 port of
// caelestia performance/BatteryTank.qml.
StyledClippingRect {
    id: root

    property real animPerc: UPower.displayDevice?.percentage ?? 0

    color: Colours.palette.secondary_container
    radius: Appearance.rounding.large

    implicitWidth: Config.dashboard.performance.showCpu
        || (Config.dashboard.performance.showGpu && Gpu.type !== Gpu.None)
        || Config.dashboard.performance.showStorage
        || Config.dashboard.performance.showMemory
        || Config.dashboard.performance.showNetwork
        ? Config.dashboard.performance.battWidth
        : Config.dashboard.performance.battWidthSingle
    implicitHeight: Config.dashboard.performance.battHeight

    Behavior on animPerc { Anim {} }

    Contents {
        id: layout
        anchors.fill: parent
        anchors.margins: Appearance.padding.medium
        accentColour: Colours.palette.primary
        textColour: Colours.palette.on_surface
        subTextColour: Colours.palette.on_surface_variant
    }

    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: parent.height * root.animPerc
        color: Colours.palette.secondary
        radius: Appearance.rounding.small
        clip: true

        Contents {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: layout.anchors.margins
            height: layout.height
            accentColour: Colours.palette.primary_container
            textColour: Colours.palette.on_secondary
            subTextColour: Colours.palette.secondary_container
        }
    }

    component Contents: ColumnLayout {
        id: contents

        required property color accentColour
        required property color textColour
        required property color subTextColour
        readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice?.state ?? UPowerDeviceState.Unknown)

        spacing: 0

        StyledText {
            text: "\uea34" // tabler battery
            font.family: Appearance.font.family.tabler
            font.pointSize: Appearance.font.size.large
            color: contents.accentColour
        }
        StyledText {
            Layout.fillWidth: true
            text: qsTr("Battery")
            color: contents.textColour
            font.pointSize: Appearance.font.size.normal
        }

        Item { Layout.fillHeight: true }

        StyledText {
            Layout.alignment: Qt.AlignRight
            text: {
                const dev = UPower.displayDevice;
                if (!dev)
                    return qsTr("...");
                if (dev.state === UPowerDeviceState.FullyCharged)
                    return qsTr("Full");
                if (contents.charging)
                    return qsTr("Charging");
                const s = dev.timeToEmpty;
                if (s === 0)
                    return qsTr("...");
                const hr = Math.floor(s / 3600);
                const min = Math.floor((s % 3600) / 60);
                return hr > 0 ? `${hr}h ${min}m` : `${min}m`;
            }
            color: contents.subTextColour
            font.pointSize: Appearance.font.size.small
            animate: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Appearance.spacing.small

            StyledText {
                text: "\uea38" // tabler bolt
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.large
                color: contents.accentColour
                scale: contents.charging ? 1 : 0
                opacity: contents.charging ? 1 : 0
                Behavior on scale { Anim {} }
                Behavior on opacity { Anim {} }
            }
            StyledText {
                text: `${Math.round((UPower.displayDevice?.percentage ?? 0) * 100)}%`
                color: contents.accentColour
                font.pointSize: Appearance.font.size.large
                font.weight: Font.DemiBold
            }
        }
    }
}
