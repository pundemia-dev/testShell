pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "pages"
// Feature-sliced modules own their settings page (modules/<name>/settings/);
// pages/ keeps the core/chrome pages that belong to the settings module itself.
import qs.modules.bar.settings
import qs.modules.dashboard.settings
import qs.modules.launcher.settings
import qs.modules.ai.settings
import qs.modules.osd.settings
import qs.modules.quicksettings.settings
import qs.modules.toasts.settings
import qs.modules.lock.settings
import qs.modules.session.settings

Item {
    id: root

    signal closeRequested

    property int currentPage: 0
    property bool navExpanded: true

    // Shared sidebar button metrics. A fixed-width icon box (centered glyph)
    // keeps every icon on one vertical axis and stops icons shifting while the
    // rail animates; railPadH adds end-4-style breathing room left and right.
    readonly property int railPadH: Appearance.padding.large
    readonly property int railIconBox: 26
    readonly property int railIconSize: Appearance.font.size.large
    readonly property int railBtnH: railIconBox + Appearance.padding.medium * 2
    readonly property int railCollapsedW: railIconBox + railPadH * 2

    // Third-party pages discovered from *.settings.qml schemas.
    SettingsDiscovery {
        id: discovery
    }

    // Official pages + discovered schema pages (appended after the built-ins).
    readonly property var allPages: root.pages.concat((discovery.schemas ?? []).map(s => ({
                    name: s.title,
                    icon: s.icon,
                    advanced: s.advanced,
                    schema: s
                })))

    function _componentFor(i: int): var {
        const e = root.allPages[i];
        if (!e)
            return null;
        return e.schema ? schemaPage : e.component;
    }

    // `scope` is the preset scope the sidebar's Presets button targets on each
    // page ("full" = whole-config snapshot, otherwise that config section).
    property var pages: [
        {
            name: qsTr("General"),
            icon: "\ueb20", // tabler settings
            scope: "full",
            component: generalPage
        },
        {
            name: qsTr("Themes"),
            icon: "\ueb01", // tabler palette
            scope: "full",
            component: themesPage
        },
        {
            name: qsTr("Bar"),
            icon: "\uead7", // tabler layout-navbar
            scope: "bar",
            component: barPage
        },
        {
            name: qsTr("Backgrounds"),
            icon: "\uf51b", // tabler texture
            scope: "backgrounds",
            component: backgroundsPage
        },
        {
            name: qsTr("Borders"),
            icon: "\uea3b", // tabler border-all
            scope: "border",
            component: bordersPage
        },
        {
            name: qsTr("Corners"),
            icon: "\ufd63", // tabler border-corner-rounded
            scope: "corners",
            component: cornersPage
        },
        {
            name: qsTr("Launcher"),
            icon: "\uec45", // tabler rocket
            scope: "launcher",
            component: launcherPage
        },
        {
            name: qsTr("Dashboard"),
            icon: "\uea87", // tabler dashboard
            scope: "dashboard",
            component: dashboardPage
        },
        {
            name: qsTr("AI"),
            icon: "\uf59f", // tabler brain
            scope: "ai",
            component: aiPage
        },
        {
            name: qsTr("OSD"),
            icon: "\ueb51", // tabler volume
            scope: "osd",
            component: osdPage
        },
        {
            name: qsTr("Quicksettings"),
            icon: "\ueb3f", // tabler toggle-right
            scope: "quicksettings",
            component: quicksettingsPage
        },
        {
            name: qsTr("Toasts"),
            icon: "\uea35", // tabler bell
            scope: "toasts",
            component: toastsPage
        },
        {
            name: qsTr("Lock"),
            icon: "\ueae2", // tabler lock
            scope: "lock",
            component: lockPage
        },
        {
            name: qsTr("Session"),
            icon: "\ueb0d", // tabler power
            scope: "session",
            component: sessionPage
        },
        {
            name: qsTr("About"),
            icon: "\ueac5", // tabler info-circle
            scope: "full",
            component: aboutPage
        }
    ]

    // Page components — bound to Config.* (see modules/settings/pages/).
    Component {
        id: generalPage
        GeneralPage {}
    }
    Component {
        id: themesPage
        ThemesPage {}
    }
    Component {
        id: barPage
        BarPage {}
    }
    Component {
        id: backgroundsPage
        BackgroundsPage {}
    }
    Component {
        id: bordersPage
        BordersPage {}
    }
    Component {
        id: cornersPage
        CornersPage {}
    }
    Component {
        id: launcherPage
        LauncherPage {}
    }
    Component {
        id: dashboardPage
        DashboardSettingsPage {}
    }
    Component {
        id: aiPage
        AiPage {}
    }
    Component {
        id: osdPage
        OsdPage {}
    }
    Component {
        id: quicksettingsPage
        QuicksettingsSettingsPage {}
    }
    Component {
        id: toastsPage
        ToastsPage {}
    }
    Component {
        id: lockPage
        LockPage {}
    }
    Component {
        id: sessionPage
        SessionPage {}
    }
    Component {
        id: aboutPage
        PlaceholderPage {
            title: qsTr("About")
            description: qsTr("About pShell")
        }
    }
    Component {
        id: schemaPage
        SchemaPage {}
    }

    implicitWidth: 900
    implicitHeight: 600

    // Keyboard navigation
    Keys.onPressed: event => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab) {
                root.currentPage = (root.currentPage + 1) % root.allPages.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Backtab) {
                root.currentPage = (root.currentPage - 1 + root.allPages.length) % root.allPages.length;
                event.accepted = true;
            }
        }
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // === Titlebar (spans the full window width) ===
        // Title is centered across the whole strip; close sits at the right
        // edge. The sidebar collapse toggle now lives at the top of the rail.
        Item {
            Layout.fillWidth: true
            implicitHeight: closeButton.implicitHeight

            // Drag anywhere on the titlebar strip to move the window. Declared
            // first so the close button (later child) stays on top and keeps
            // its own clicks. Niri honours xdg-toplevel interactive move.
            MouseArea {
                anchors.fill: parent
                onPressed: root.Window.window?.startSystemMove()
            }

            StyledText {
                anchors.centerIn: parent
                text: qsTr("Settings")
                font.pointSize: Appearance.font.size.large
                font.weight: Font.DemiBold
                color: Colours.palette.on_surface
            }

            IconButton {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                type: IconButton.Text
                icon: "\ueb55" // tabler x
                onClicked: root.closeRequested()
            }
        }

        // === Body: navigation rail | content pane ===
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // === Navigation Rail ===
            // Wrapped in a plain Item driven by implicitWidth (dots-hyprland
            // pattern): a nested ColumnLayout with Layout.preferredWidth as a
            // direct RowLayout child mis-sizes, so the rail lives inside an Item.
            Item {
                id: navRailWrapper

                Layout.fillHeight: true
                implicitWidth: root.navExpanded ? 170 : root.railCollapsedW

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Appearance.anim.durations.small
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                ColumnLayout {
                    id: navRail

                    anchors.fill: parent
                    spacing: 4

                    // Sidebar collapse/expand toggle — icon shares the same
                    // leading slot as every other rail icon (common axis).
                    StyledRect {
                        Layout.alignment: Qt.AlignLeft
                        implicitWidth: root.railCollapsedW
                        implicitHeight: root.railBtnH
                        radius: Appearance.rounding.large
                        color: collapseMouse.containsMouse ? Qt.alpha(Colours.palette.on_surface, 0.08) : "transparent"

                        StyledText {
                            anchors.left: parent.left
                            anchors.leftMargin: root.railPadH
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.railIconBox
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Appearance.font.family.tabler
                            font.pointSize: root.railIconSize
                            color: Colours.palette.on_surface_variant
                            text: root.navExpanded ? "\uf004" : "\uf005" // tabler layout-sidebar-left-collapse / -expand
                        }

                        MouseArea {
                            id: collapseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.navExpanded = !root.navExpanded
                        }
                    }

                    // Presets: apply / save presets for the current page's scope.
                    PresetButton {
                        Layout.alignment: Qt.AlignLeft
                        Layout.bottomMargin: Appearance.spacing.medium
                        expanded: root.navExpanded
                        scope: root.pages[root.currentPage].scope ?? "full"
                        padH: root.railPadH
                        iconBox: root.railIconBox
                        iconSize: root.railIconSize
                        buttonHeight: root.railBtnH
                    }

                    // Nav items
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: navColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: navColumn
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: root.allPages

                                delegate: StyledRect {
                                    id: navItem

                                    required property int index
                                    required property var modelData

                                    property bool isActive: root.currentPage === index

                                    // Advanced-only pages drop out of the rail in basic mode.
                                    visible: !navItem.modelData.advanced || Config.general.advanced

                                    // Hug content: pill = padH + icon box (+ gap + label when
                                    // expanded) + padH. Height matches the Presets button.
                                    Layout.alignment: Qt.AlignLeft
                                    implicitWidth: root.navExpanded ? (root.railPadH + root.railIconBox + Appearance.spacing.small + navLabel.implicitWidth + root.railPadH) : root.railCollapsedW
                                    implicitHeight: root.railBtnH
                                    clip: true

                                    Behavior on implicitWidth {
                                        Anim {}
                                    }

                                    radius: Appearance.rounding.large
                                    color: isActive ? Colours.palette.secondary_container : navMouse.containsMouse ? Qt.alpha(Colours.palette.on_surface, 0.08) : "transparent"

                                    // Icon pinned to a fixed leading slot: its x never moves while the
                                    // rail width animates, so icons don't jitter and stay on one axis.
                                    StyledText {
                                        id: navIcon
                                        anchors.left: parent.left
                                        anchors.leftMargin: root.railPadH
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: root.railIconBox
                                        horizontalAlignment: Text.AlignHCenter
                                        text: navItem.modelData.icon
                                        font.family: Appearance.font.family.tabler
                                        font.pointSize: root.railIconSize
                                        color: navItem.isActive ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                                    }

                                    StyledText {
                                        id: navLabel
                                        anchors.left: navIcon.right
                                        anchors.leftMargin: Appearance.spacing.small
                                        anchors.right: parent.right
                                        anchors.rightMargin: root.railPadH
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: navItem.modelData.name
                                        font.pointSize: Appearance.font.size.smaller
                                        font.weight: navItem.isActive ? Font.DemiBold : Font.Normal
                                        color: navItem.isActive ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                                        elide: Text.ElideRight
                                        opacity: root.navExpanded ? 1 : 0
                                        visible: opacity > 0

                                        Behavior on opacity {
                                            Anim {}
                                        }
                                    }

                                    MouseArea {
                                        id: navMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.currentPage = navItem.index
                                    }
                                }
                            }
                        }
                    }

                    // Bottom spacer
                    Item {
                        Layout.preferredHeight: 4
                    }
                }
            }

            // === Content Area ===
            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true

                radius: Appearance.rounding.large
                color: Colours.tPalette.surface_container_low
                clip: true

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large

                    opacity: 1.0

                    // No live binding on sourceComponent: the page is set once
                    // here and afterwards ONLY from switchAnim's PropertyAction,
                    // so the swap always happens mid-fade (opacity 0). Binding it
                    // to currentPage would swap instantly and defeat the fade-out.
                    Component.onCompleted: sourceComponent = root._componentFor(root.currentPage)

                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            switchAnim.complete();
                            switchAnim.start();
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: pageLoader
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: 100
                            easing.type: Easing.InQuad
                        }

                        PropertyAction {
                            target: pageLoader
                            property: "sourceComponent"
                            value: root._componentFor(root.currentPage)
                        }

                        ScriptAction {
                            // schema pages share one component, so a swap may not
                            // reload — assign the active schema explicitly.
                            script: {
                                const e = root.allPages[root.currentPage];
                                if (pageLoader.item && e && e.schema)
                                    pageLoader.item.schema = e.schema;
                            }
                        }

                        PropertyAction {
                            target: pageLoader
                            property: "anchors.topMargin"
                            value: Appearance.padding.large + 15
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: pageLoader
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: pageLoader
                                property: "anchors.topMargin"
                                to: Appearance.padding.large
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
