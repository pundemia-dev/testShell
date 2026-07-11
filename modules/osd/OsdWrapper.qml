pragma ComponentBehavior: Bound

import qs.config
import qs.services
import Quickshell
import QtQuick
import "content"

// OSD wrapper. Unlike the hover/IPC drawers this one is EVENT-driven: it pops
// up when volume/brightness change (media keys or the sliders themselves) and
// auto-hides on a timer. Hovering the panel — or opening an expansion section —
// blocks the hide. Positioning + background come from the rails contract
// (mode: push), same as the other wrappers.
Item {
    id: root

    required property var manager
    required property ShellScreen screen

    // Bound to Brightness.monitors directly (not via the helper) so it tracks
    // the list populating asynchronously at startup.
    readonly property var monitor: Brightness.monitors.find(m => m.modelData === screen) ?? null

    // ── Visibility ────────────────────────────────────────────────────
    property bool osdVisible: false
    property bool _panelHovered: false
    property bool _expanded: false
    // Suppress the very first change signals fired while services settle at
    // startup, so the OSD doesn't flash on login.
    property bool _armed: false

    function show(): void {
        if (!Config.osd.enabled || !_armed)
            return;
        osdVisible = true;
        hideTimer.restart();
    }

    function notePanelHover(h: bool): void {
        _panelHovered = h;
        if (h)
            hideTimer.stop();
        else if (osdVisible && !_expanded)
            hideTimer.restart();
    }

    function noteExpanded(e: bool): void {
        _expanded = e;
        if (e)
            hideTimer.stop();
        else if (osdVisible && !_panelHovered)
            hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: Config.osd.hideDelay
        onTriggered: {
            if (!root._panelHovered && !root._expanded)
                root.osdVisible = false;
        }
    }

    // Arm after the first event loop turn so startup settling doesn't show it.
    Component.onCompleted: armTimer.start()
    Timer {
        id: armTimer
        interval: 1000
        onTriggered: root._armed = true
    }

    // ── Event sources ─────────────────────────────────────────────────
    Connections {
        target: Audio
        function onVolumeChanged(): void { root.show(); }
        function onMutedChanged(): void { root.show(); }
        function onSourceVolumeChanged(): void { root.show(); }
        function onSourceMutedChanged(): void { root.show(); }
    }

    Connections {
        target: root.monitor
        enabled: root.monitor
        // The init read (0 → real level) fires before `initialized` flips true,
        // so this stays quiet on startup and only shows on genuine changes.
        function onBrightnessChanged(): void {
            if (root.monitor?.initialized)
                root.show();
        }
    }

    // ── Rails contract ────────────────────────────────────────────────
    // Resolve one side of an EdgesData group for the rails contract: "all"
    // inherits the group's `all`; a number is literal; null falls through so
    // WindowSlot applies its automatic default (0 for margins, the global
    // Config.backgrounds.paddings for paddings).
    function _edge(g, side) {
        const v = g[side];
        return v === "all" ? g.all : v;
    }

    property QtObject content: QtObject {
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        property bool aLeft: Config.osd.anchors.left ?? undefined
        property bool aRight: Config.osd.anchors.right ?? undefined
        property bool aTop: Config.osd.anchors.top ?? undefined
        property bool aBottom: Config.osd.anchors.bottom ?? undefined
        property bool aHorizontalCenter: Config.osd.anchors.horizontalCenter ?? undefined
        property bool aVerticalCenter: Config.osd.anchors.verticalCenter ?? undefined
        property var mLeft: root._edge(Config.osd.margins, "left")
        property var mRight: root._edge(Config.osd.margins, "right")
        property var mTop: root._edge(Config.osd.margins, "top")
        property var mBottom: root._edge(Config.osd.margins, "bottom")
        property int vCenterOffset: Config.osd.vCenterOffset
        property int hCenterOffset: Config.osd.hCenterOffset
        property var pLeft: root._edge(Config.osd.paddings, "left")
        property var pRight: root._edge(Config.osd.paddings, "right")
        property var pTop: root._edge(Config.osd.paddings, "top")
        property var pBottom: root._edge(Config.osd.paddings, "bottom")
        property string mode: Config.osd.mode
        property bool sticks: Config.osd.sticks
        property bool pinned: false
        property bool reservesSpace: Config.osd.reservesSpace
        property int layer: Config.osd.layer
        property var windowRounding: Config.osd.rounding
        property var sizeSpring: Config.osd.sizeSpring
        property var sizeDamping: Config.osd.sizeDamping

        property Component content: OsdContent {
            monitor: root.monitor
            onPanelHoveredChanged: root.notePanelHover(panelHovered)
            onExpandedChanged: root.noteExpanded(expanded)
        }
    }

    // ── Background registration ───────────────────────────────────────
    Loader {
        active: root.osdVisible
        sourceComponent: Item {
            Component.onCompleted: root.manager.requestBackground(root.content)
            Component.onDestruction: root.manager.removeBackground(root.content)
        }
    }
}
