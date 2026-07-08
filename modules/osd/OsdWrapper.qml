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
    property QtObject content: QtObject {
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        property bool aLeft: Config.osd.anchors.left ?? undefined
        property bool aRight: Config.osd.anchors.right ?? undefined
        property bool aTop: Config.osd.anchors.top ?? undefined
        property bool aBottom: Config.osd.anchors.bottom ?? undefined
        property bool aHorizontalCenter: Config.osd.anchors.horizontalCenter ?? undefined
        property bool aVerticalCenter: Config.osd.anchors.verticalCenter ?? undefined
        property int mLeft: Config.osd.mLeft
        property int mRight: Config.osd.mRight
        property int mTop: Config.osd.mTop
        property int mBottom: Config.osd.mBottom
        property int vCenterOffset: 0
        property int hCenterOffset: 0
        property int pLeft: Config.osd.padding
        property int pRight: Config.osd.padding
        property int pTop: Config.osd.padding
        property int pBottom: Config.osd.padding
        property string mode: Config.osd.mode
        property bool pinned: false
        property bool reservesSpace: false
        readonly property int layer: 0

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
