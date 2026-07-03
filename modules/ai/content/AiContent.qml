pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Top-level AI panel UI: discovers pages (AiRegistry), renders a tab bar
// (AiTabs) and a horizontally-swipeable page area that slides + resizes
// between tabs. Structural port of modules/dashboard/content/
// DashboardContent.qml. The outer surface colour is handled by the SDF blob
// bg (WindowSlot), so this Item is transparent.
Item {
    id: root

    // Reliable hover signal for the wrapper's auto-hide.
    property bool panelHovered: hover.hovered

    // True while the current page holds keyboard focus (pages may expose an
    // optional `inputFocused` property); keeps the panel alive while typing.
    readonly property bool inputFocused: {
        repeater.count;
        const pane = repeater.itemAt(currentTab);
        return pane?.item?.inputFocused ?? false;
    }

    property int currentTab: registry.currentTab

    // Persistent registry injected by the wrapper. It's warmed at shell
    // startup so its async FolderListModel page discovery has long finished
    // before the first open.
    required property AiRegistry registry

    readonly property var pages: registry.pages
    readonly property int count: pages.length

    readonly property Item currentItem: {
        repeater.count; // re-eval when delegates (dis)appear
        return repeater.itemAt(currentTab);
    }

    onCountChanged: if (registry.currentTab >= count) registry.currentTab = Math.max(0, count - 1)

    // On open only the current page is built (fast, single-frame); the other
    // pages are deferred until just after the open settles so their async
    // incubation doesn't steal frames from the first open.
    property bool _othersReady: false
    Timer {
        interval: 450
        running: true
        onTriggered: root._othersReady = true
    }

    // Animate contentX only on explicit tab switches / drag snap-backs, not on
    // layout shifts caused by async page builds.
    property bool _animContentX: false
    onCurrentTabChanged: {
        _animContentX = true;
        Qt.callLater(() => { _animContentX = false; });
    }

    implicitWidth: Math.max(320, view.implicitWidth + viewWrapper.anchors.margins * 2)
    implicitHeight: col.implicitHeight

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Appearance.spacing.medium

        AiTabs {
            id: tabs
            Layout.fillWidth: true
            visible: root.count > 0
            tabs: root.pages
            currentIndex: root.currentTab
            onTabClicked: index => registry.currentTab = index
        }

        // Empty state — no pages discovered.
        StyledText {
            Layout.alignment: Qt.AlignCenter
            Layout.margins: Appearance.padding.large
            visible: root.count === 0
            text: qsTr("No AI pages found")
            color: Colours.palette.on_surface_variant
        }

        ClippingRectangle {
            id: viewWrapper
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.count > 0
            color: "transparent"
            radius: Appearance.rounding.large
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
                        registry.currentTab = Math.min(registry.currentTab + 1, root.count - 1);
                    else if (dx < -root.currentItem.implicitWidth / 2)
                        registry.currentTab = Math.max(registry.currentTab - 1, 0);
                }

                onDragEnded: {
                    if (!root.currentItem)
                        return;
                    const dx = contentX - root.currentItem.x;
                    if (dx > root.currentItem.implicitWidth / 10)
                        registry.currentTab = Math.min(registry.currentTab + 1, root.count - 1);
                    else if (dx < -root.currentItem.implicitWidth / 10)
                        registry.currentTab = Math.max(registry.currentTab - 1, 0);
                    else {
                        root._animContentX = true;
                        contentX = Qt.binding(() => root.currentItem?.x ?? 0);
                        Qt.callLater(() => { root._animContentX = false; });
                    }
                }

                Behavior on contentX {
                    enabled: root._animContentX
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

                            // The CURRENT page builds synchronously so it shows
                            // in one frame at the right size; the others build
                            // asynchronously in the background so opening never
                            // hangs. Torn down on close.
                            Layout.alignment: Qt.AlignTop
                            active: index === root.currentTab || root._othersReady
                            asynchronous: index !== root.currentTab
                            sourceComponent: modelData.content
                            // Hide during async incubation: the item briefly
                            // exists at x=0 before RowLayout repositions it.
                            opacity: status === Loader.Ready ? 1 : 0
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
