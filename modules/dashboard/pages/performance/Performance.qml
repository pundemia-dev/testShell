pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Caelestia.Services
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Performance tab — 1:1 port of caelestia Performance.qml (NetworkCard deferred
// until a NetworkUsage service lands). Cards toggle via Config.dashboard.performance.
Item {
    id: root

    readonly property bool hasBattery: (UPower.displayDevice?.isLaptopBattery ?? false) && Config.dashboard.performance.showBattery

    implicitWidth: placeholder.active ? Config.dashboard.performance.placeholderWidth : content.implicitWidth
    implicitHeight: placeholder.active ? placeholder.implicitHeight + Appearance.padding.large * 2 : content.implicitHeight

    Loader {
        id: placeholder
        anchors.centerIn: parent
        active: !Config.dashboard.performance.showCpu
            && !(Config.dashboard.performance.showGpu && Gpu.type !== Gpu.None)
            && !Config.dashboard.performance.showMemory
            && !Config.dashboard.performance.showStorage
            && !Config.dashboard.performance.showNetwork
            && !root.hasBattery
        asynchronous: true

        sourceComponent: ColumnLayout {
            spacing: Appearance.spacing.medium

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "\uea03" // tabler adjustments
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.extraLarge * 1.6
                color: Colours.palette.on_surface_variant
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No widgets enabled")
                font.pointSize: Appearance.font.size.large
                font.weight: Font.DemiBold
                color: Colours.palette.on_surface
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Enable widgets in the dashboard settings")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
            }
        }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.spacing.medium
        visible: !placeholder.active

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.medium

            RowLayout {
                spacing: Appearance.spacing.medium
                visible: cpuCard.active || gpuCard.active

                Loader {
                    id: cpuCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: active
                    active: Config.dashboard.performance.showCpu
                    sourceComponent: HeroCard {
                        glyph: "\uef8e" // tabler cpu
                        label: qsTr("CPU")
                        subLabel: Cpu.name
                        usage: Cpu.percentage
                        temperature: Cpu.temperature
                        accent: Colours.palette.primary
                        ServiceRef { service: Cpu }
                    }
                }

                Loader {
                    id: gpuCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: active
                    active: Config.dashboard.performance.showGpu && Gpu.type !== Gpu.None
                    sourceComponent: HeroCard {
                        glyph: "\uea89" // tabler device-desktop
                        label: qsTr("GPU")
                        subLabel: Gpu.name
                        usage: Gpu.percentage
                        temperature: Gpu.temperature
                        accent: Colours.palette.secondary
                        ServiceRef { service: Gpu }
                    }
                }
            }

            RowLayout {
                spacing: Appearance.spacing.medium
                visible: storageCard.active || networkCard.active || memoryCard.active

                Loader {
                    id: storageCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: active
                    active: Config.dashboard.performance.showStorage
                    sourceComponent: StorageCard {}
                }
                Loader {
                    id: networkCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: active
                    active: Config.dashboard.performance.showNetwork
                    sourceComponent: NetworkCard {}
                }
                Loader {
                    id: memoryCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: active
                    active: Config.dashboard.performance.showMemory
                    sourceComponent: MemoryCard {}
                }
            }
        }

        Loader {
            Layout.fillHeight: true
            visible: active
            active: root.hasBattery
            sourceComponent: BatteryTank {}
        }
    }
}
