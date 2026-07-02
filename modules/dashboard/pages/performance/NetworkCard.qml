pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Caelestia.Internal
import QtQuick
import QtQuick.Layouts

// Network card: up/down sparkline + live speeds + session totals. 1:1 port of
// caelestia performance/NetworkCard.qml (SparklineItem from Caelestia.Internal,
// data from the ported NetworkUsage service).
StyledRect {
    id: root

    readonly property color cardColour: Colours.transparency.enabled
        ? Colours.layer(Colours.palette.surface_container, 2)
        : Colours.palette.surface_container

    color: cardColour
    radius: Appearance.rounding.extraLarge

    implicitWidth: Config.dashboard.performance.networkCardWidth
    implicitHeight: Config.dashboard.performance.networkCardHeight

    // Hold a poll ref while visible.
    Component.onCompleted: NetworkUsage.refCount++
    Component.onDestruction: NetworkUsage.refCount--

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        anchors.bottomMargin: Appearance.padding.medium
        spacing: 0

        RowLayout {
            spacing: Appearance.spacing.small

            StyledText {
                text: "\uedb6" // tabler arrows-up-down
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.large
                color: Colours.palette.primary
            }
            StyledText {
                text: qsTr("Network")
                font.pointSize: Appearance.font.size.large
                font.weight: Font.DemiBold
            }
        }

        // Sparkline graph.
        Item {
            Layout.topMargin: Appearance.spacing.medium
            Layout.bottomMargin: Appearance.spacing.small
            Layout.fillWidth: true
            Layout.fillHeight: true

            SparklineItem {
                id: sparkline
                property real targetMax: 1024
                property real smoothMax: targetMax

                anchors.fill: parent
                line1: NetworkUsage.uploadBuffer
                line1Color: Colours.palette.secondary
                line1FillAlpha: 0.15
                line2: NetworkUsage.downloadBuffer
                line2Color: Colours.palette.tertiary
                line2FillAlpha: 0.2
                maxValue: smoothMax
                historyLength: NetworkUsage.historyLength

                Connections {
                    target: NetworkUsage.downloadBuffer
                    function onValuesChanged(): void {
                        sparkline.targetMax = Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024);
                        slideAnim.restart();
                    }
                }

                NumberAnimation {
                    id: slideAnim
                    target: sparkline
                    property: "slideProgress"
                    from: 0
                    to: 1
                    easing.type: Easing.Linear
                    duration: 1000
                }

                Behavior on smoothMax { Anim {} }
            }

            StyledText {
                anchors.centerIn: parent
                text: qsTr("Collecting data...")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.outline
                visible: NetworkUsage.downloadBuffer.count < 2
            }
        }

        // Rows.
        SpeedRow {
            glyph: "\uea96" // tabler download
            label: qsTr("Download")
            accent: Colours.palette.tertiary
            value: {
                const fmt = NetworkUsage.formatBytes(NetworkUsage.downloadSpeed ?? 0);
                return `${fmt.value.toFixed(1)} ${fmt.unit}`;
            }
        }
        SpeedRow {
            glyph: "\ueb47" // tabler upload
            label: qsTr("Upload")
            accent: Colours.palette.secondary
            value: {
                const fmt = NetworkUsage.formatBytes(NetworkUsage.uploadSpeed ?? 0);
                return `${fmt.value.toFixed(1)} ${fmt.unit}`;
            }
        }
        SpeedRow {
            glyph: "\uebea" // tabler history
            label: qsTr("Total")
            accent: Colours.palette.on_surface_variant
            value: {
                const down = NetworkUsage.formatBytesTotal(NetworkUsage.downloadTotal ?? 0);
                const up = NetworkUsage.formatBytesTotal(NetworkUsage.uploadTotal ?? 0);
                return `↓${down.value.toFixed(1)}${down.unit} ↑${up.value.toFixed(1)}${up.unit}`;
            }
        }
    }

    component SpeedRow: RowLayout {
        id: srow
        property string glyph
        property string label
        property string value
        property color accent

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            text: srow.glyph
            font.family: Appearance.font.family.tabler
            font.pointSize: Appearance.font.size.normal
            color: srow.accent
        }
        StyledText {
            text: srow.label
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.on_surface_variant
        }
        Item { Layout.fillWidth: true }
        StyledText {
            text: srow.value
            font.pointSize: Appearance.font.size.small
            font.weight: Font.Medium
            color: srow.accent
        }
    }
}
