pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Caelestia.Services
import Quickshell
import QtQuick
import QtQuick.Layouts

// Storage card: 270° radial gauge + used/total + a SplitButton disk picker that
// auto-updates as disks are (un)mounted (Variants over Storage.disks — no shell
// reload). 1:1 port of caelestia performance/StorageCard.qml.
StyledRect {
    id: root

    readonly property color accent: Colours.palette.secondary
    readonly property real percentage: Storage.primaryDisk?.perc ?? 0
    readonly property color cardColour: Colours.transparency.enabled
        ? Colours.layer(Colours.palette.surface_container, 2)
        : Colours.palette.surface_container

    color: cardColour
    radius: Appearance.rounding.extraExtraLarge

    implicitWidth: layout.implicitWidth + Appearance.padding.extraLarge * 2
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    ServiceRef { service: Storage }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.extraLarge
        spacing: 0

        RowLayout {
            id: row
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.large

            DashProgress {
                implicitSize: usageColumn.implicitHeight + thickness + Appearance.padding.large * 2
                startAngle: -225
                sweepAngle: 270
                fgColour: root.accent
                value: root.percentage

                Behavior on clampedVal { Anim {} }

                ColumnLayout {
                    id: usageColumn
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\uea88" // tabler database
                        font.family: Appearance.font.family.tabler
                        font.pointSize: Appearance.font.size.large
                        color: root.accent
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(root.percentage * 100) + "%"
                        font.pointSize: Appearance.font.size.large
                        font.weight: Font.DemiBold
                        color: root.accent
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Used")
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.on_surface_variant
                    }
                }
            }

            ColumnLayout {
                Layout.minimumWidth: Config.dashboard.performance.storageTextWidth
                spacing: Appearance.spacing.extraSmall

                StyledText {
                    text: qsTr("Storage")
                    font.pointSize: Appearance.font.size.large
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: {
                        if (!Storage.primaryDisk)
                            return qsTr("No disks detected");
                        const fmt = UsageFmt.formatKib(Storage.primaryDisk.used, Storage.primaryDisk.total);
                        return `${fmt.value.toFixed(1)} / ${Math.floor(fmt.total)} ${fmt.unit}`;
                    }
                    font.pointSize: Appearance.font.size.normal
                    color: root.accent
                }
            }
        }

        // Disk picker — auto-updates as disks appear/disappear.
        SplitButton {
            Layout.alignment: Qt.AlignHCenter
            type: SplitButton.Tonal
            disabled: !Storage.disks.length
            fallbackIcon: "\uea88"
            fallbackText: qsTr("No disks")
            menuOnTop: true

            menuItems: disks.instances
            active: menuItems.find(m => m.modelData === Storage.primaryDisk) ?? menuItems[0] ?? null
            menu.onItemSelected: item => Storage.manualPrimaryDisk = (item as DiskItem).modelData

            Variants {
                id: disks
                model: Storage.disks

                DiskItem {}
            }
        }
    }

    component DiskItem: MenuItem {
        required property var modelData
        icon: modelData === Storage.primaryDisk ? "\uea5e" : "" // tabler check / none
        text: modelData.mount
        activeIcon: "\uea88" // tabler database
    }
}
