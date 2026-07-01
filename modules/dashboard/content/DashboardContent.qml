pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Top-level dashboard UI: discovers pages (DashboardRegistry), renders a tab bar
// (DashboardTabs) and a horizontally-swipeable page area that slides + resizes
// between tabs. Port of caelestia Content.qml onto pShell idioms. The outer
// surface colour is handled by the SDF blob bg (WindowSlot), so this Item is
// transparent.
Item {
    id: root

    // Reliable hover signal for the wrapper's auto-hide.
    property bool panelHovered: hover.hovered

    property int currentTab: 0

    // Persistent registry injected by the wrapper. It's warmed at shell startup
    // so its async FolderListModel page discovery has long finished before the
    // first open — the main page is thus present in the very first frame instead
    // of popping in a few frames later once the scan completes.
    required property DashboardRegistry registry

    readonly property var pages: registry.pages
    readonly property int count: pages.length

    readonly property Item currentItem: {
        repeater.count; // re-eval when delegates (dis)appear
        return repeater.itemAt(currentTab);
    }

    onCountChanged: if (currentTab >= count) currentTab = Math.max(0, count - 1)

    // On open only the current page is built (fast, single-frame); the other
    // (heavy) pages are deferred until just after the open settles so their
    // async incubation doesn't steal frames from the first open. Once ready
    // they build in the background so swipe geometry is complete.
    property bool _othersReady: false
    Timer {
        interval: 450
        running: true
        onTriggered: root._othersReady = true
    }

    implicitWidth: Math.max(320, view.implicitWidth + viewWrapper.anchors.margins * 2)
    implicitHeight: col.implicitHeight

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Appearance.spacing.normal

        DashboardTabs {
            id: tabs
            Layout.fillWidth: true
            visible: root.count > 0
            tabs: root.pages
            currentIndex: root.currentTab
            onTabClicked: index => root.currentTab = index
        }

        // Empty state — no pages discovered or all disabled.
        StyledText {
            Layout.alignment: Qt.AlignCenter
            Layout.margins: Appearance.padding.large
            visible: root.count === 0
            text: qsTr("No dashboard pages enabled")
            color: Colours.palette.on_surface_variant
        }

        ClippingRectangle {
            id: viewWrapper
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.count > 0
            color: "transparent"
            radius: Appearance.rounding.normal
            anchors.margins: 0

            implicitWidth: view.implicitWidth
            implicitHeight: view.implicitHeight

            Flickable {
                id: view
                anchors.fill: parent

                flickableDirection: Flickable.HorizontalFlick
                interactive: root.count > 1
                boundsBehavior: Flickable.StopAtBounds

                implicitWidth: root.currentItem?.implicitWidth ?? 0
                implicitHeight: root.currentItem?.implicitHeight ?? 0

                contentX: root.currentItem?.x ?? 0
                contentWidth: row.implicitWidth
                contentHeight: row.implicitHeight

                // While dragging past the half-way point of the current page,
                // commit to the neighbour so the resize animation starts early.
                onContentXChanged: {
                    if (!moving || !root.currentItem)
                        return;
                    const dx = contentX - root.currentItem.x;
                    if (dx > root.currentItem.implicitWidth / 2)
                        root.currentTab = Math.min(root.currentTab + 1, root.count - 1);
                    else if (dx < -root.currentItem.implicitWidth / 2)
                        root.currentTab = Math.max(root.currentTab - 1, 0);
                }

                onDragEnded: {
                    if (!root.currentItem)
                        return;
                    const dx = contentX - root.currentItem.x;
                    if (dx > root.currentItem.implicitWidth / 10)
                        root.currentTab = Math.min(root.currentTab + 1, root.count - 1);
                    else if (dx < -root.currentItem.implicitWidth / 10)
                        root.currentTab = Math.max(root.currentTab - 1, 0);
                    else
                        contentX = Qt.binding(() => root.currentItem?.x ?? 0);
                }

                Behavior on contentX {
                    Anim {}
                }

                RowLayout {
                    id: row

                    Repeater {
                        id: repeater
                        model: root.pages

                        delegate: Loader {
                            id: pane
                            required property int index
                            required property var modelData

                            // All pages are built while the dashboard is open (so
                            // the Row's x positions used for swipe geometry are
                            // correct). The CURRENT page builds synchronously so it
                            // shows in one frame at the right size (no tabs-then-
                            // content flash); the other (heavy) pages build
                            // asynchronously in the background so opening never
                            // hangs. Torn down on close.
                            Layout.alignment: Qt.AlignTop
                            active: index === root.currentTab || root._othersReady
                            asynchronous: index !== root.currentTab
                            sourceComponent: modelData.content
                        }
                    }
                }
            }
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }
    Behavior on implicitHeight {
        Anim {}
    }
}
