pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Top-level quicksettings UI: a dashboard-style tab bar over a swipeable page
// area (pages are plugins), then the card stack (cards are plugins), then the
// fixed QuickToggles card. Unlike the dashboard, the page area has a FIXED
// height (Config.quicksettings.pageHeight) so the cards below never jump when
// switching tabs. The outer surface colour is handled by the SDF blob bg
// (WindowSlot), so this Item is transparent.
Item {
    id: root

    // Reliable hover signal for the wrapper's auto-hide.
    property bool panelHovered: hover.hovered

    property int currentTab: registry.currentTab

    // Persistent registries injected by the wrapper (warmed at startup so the
    // async folder scans have finished before the first open).
    required property QsRegistry registry
    required property QsCardRegistry cardRegistry

    readonly property var pages: registry.pages
    readonly property int count: pages.length

    onCountChanged: if (registry.currentTab >= count) registry.currentTab = Math.max(0, count - 1)

    // On open only the current page is built; the others build asynchronously
    // shortly after so opening never hangs (same trick as DashboardContent).
    property bool _othersReady: false
    Timer {
        interval: 450
        running: true
        onTriggered: root._othersReady = true
    }

    // Animate contentX only on explicit tab switches / drag snap-backs.
    property bool _animContentX: false
    onCurrentTabChanged: {
        _animContentX = true;
        Qt.callLater(() => { _animContentX = false; });
    }

    implicitWidth: Config.quicksettings.contentWidth
    implicitHeight: col.implicitHeight

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Appearance.spacing.medium

        QsTabs {
            Layout.fillWidth: true
            visible: root.count > 0
            tabs: root.pages
            currentIndex: root.currentTab
            onTabClicked: index => root.registry.currentTab = index
        }

        // Empty state — no pages discovered or all disabled.
        StyledText {
            Layout.alignment: Qt.AlignCenter
            Layout.margins: Appearance.padding.large
            visible: root.count === 0
            text: qsTr("No quicksettings pages enabled")
            color: Colours.palette.on_surface_variant
        }

        ClippingRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Config.quicksettings.pageHeight
            visible: root.count > 0
            color: "transparent"
            radius: Appearance.rounding.large

            Flickable {
                id: view
                anchors.fill: parent

                flickableDirection: Flickable.HorizontalFlick
                interactive: root.count > 1
                boundsBehavior: Flickable.StopAtBounds

                contentX: root.currentTab * width
                contentWidth: width * root.count
                contentHeight: height

                onDragEnded: {
                    const dx = contentX - root.currentTab * width;
                    if (dx > width / 10)
                        root.registry.currentTab = Math.min(root.currentTab + 1, root.count - 1);
                    else if (dx < -width / 10)
                        root.registry.currentTab = Math.max(root.currentTab - 1, 0);
                    else {
                        root._animContentX = true;
                        contentX = Qt.binding(() => root.currentTab * view.width);
                        Qt.callLater(() => { root._animContentX = false; });
                    }
                }

                Behavior on contentX {
                    enabled: root._animContentX
                    Anim {}
                }

                Row {
                    Repeater {
                        model: root.pages

                        delegate: Loader {
                            required property int index
                            required property var modelData

                            width: view.width
                            height: view.height
                            active: index === root.currentTab || root._othersReady
                            asynchronous: index !== root.currentTab
                            sourceComponent: modelData.content
                            opacity: status === Loader.Ready ? 1 : 0
                        }
                    }
                }
            }
        }

        // Plugin cards, then the fixed toggles card.
        Repeater {
            model: root.cardRegistry.cards

            delegate: Loader {
                required property var modelData

                Layout.fillWidth: true
                sourceComponent: modelData.content
                // Cards with dropdowns (SplitButton) need an overlay host that
                // contains the menu area — pointer events don't reach items
                // outside their ancestors' bounds inside layershell panels.
                onLoaded: {
                    if (item && item.menuHost !== undefined)
                        item.menuHost = dropdownHost;
                }
            }
        }

        QuickToggles {
            Layout.fillWidth: true
        }
    }

    // Dropdown overlay host, above all cards.
    Item {
        id: dropdownHost
        anchors.fill: parent
        z: 100
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
