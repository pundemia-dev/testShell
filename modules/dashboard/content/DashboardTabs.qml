pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

// Tab bar for the dashboard: one uniform-width button per page (tabler icon +
// title) with an animated underline indicator. Port of caelestia Tabs.qml onto
// pShell idioms (Appearance tokens, tabler glyphs, tPalette).
Item {
    id: root

    // Array of DashboardPage manifests (id/title/icon).
    property var tabs: []
    property int currentIndex: 0
    readonly property int count: tabs.length

    // Emitted on click; the parent owns currentIndex (kept a one-way input so
    // the external binding is never broken by an internal write).
    signal tabClicked(int index)

    implicitHeight: bar.implicitHeight + Appearance.spacing.small + 3 + separator.implicitHeight

    RowLayout {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Repeater {
            model: root.tabs

            delegate: Item {
                id: tab

                required property int index
                required property var modelData
                readonly property bool current: root.currentIndex === index

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: tabCol.implicitHeight + Appearance.padding.small * 2

                StateLayer {
                    radius: Appearance.rounding.normal
                    color: tab.current ? Colours.palette.primary : Colours.palette.on_surface
                    function onClicked(): void {
                        root.tabClicked(tab.index);
                    }
                }

                ColumnLayout {
                    id: tabCol
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tab.modelData.icon
                        font.family: Appearance.font.family.tabler
                        font.pointSize: Appearance.font.size.large
                        color: tab.current ? Colours.palette.primary : Colours.palette.on_surface_variant

                        Behavior on color {
                            CAnim {}
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tab.modelData.title
                        font.pointSize: Appearance.font.size.small
                        color: tab.current ? Colours.palette.primary : Colours.palette.on_surface_variant

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }
            }
        }
    }

    // Moving underline indicator.
    StyledRect {
        id: indicator
        anchors.top: bar.bottom
        anchors.topMargin: Appearance.spacing.small

        readonly property real tabWidth: root.count > 0 ? bar.width / root.count : 0

        implicitWidth: tabWidth * 0.5
        implicitHeight: 3
        radius: Appearance.rounding.full
        color: Colours.palette.primary

        x: tabWidth * root.currentIndex + (tabWidth - width) / 2

        Behavior on x {
            Anim {}
        }
    }

    StyledRect {
        id: separator
        anchors.top: indicator.bottom
        anchors.topMargin: Appearance.spacing.small
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: 1
        color: Colours.palette.outline_variant
    }
}
