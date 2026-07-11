pragma ComponentBehavior: Bound

import qs.config
import qs.services
import Quickshell
import QtQuick
import "content"

Item {
    id: root

    required property var manager
    required property ShellScreen screen

    // Persistent page registry, built once at startup (the wrapper is always
    // alive) so its async folder-scan discovery finishes well before the
    // first open — mirrors DashboardWrapper.
    property AiRegistry registry: AiRegistry {}

    // ── Visibility ────────────────────────────────────────────────────
    property bool aiVisible: false

    // Touch the Ai singleton at startup: singletons are lazy, and without
    // this reference the backend server only starts the first time the
    // panel opens (first message would wait for "Starting AI server…").
    readonly property bool serverWarm: Ai.serverReady

    // ── Hover state (mirrors DashboardWrapper) ────────────────────────
    property int _interactionRail: -1
    property int _arrivalSeq: -1

    readonly property bool _stripHovered: _interactionRail >= 0 ? (InteractionManager.stripHovered[_interactionRail] ?? false) : false
    readonly property bool _slotHovered: _arrivalSeq >= 0 ? (manager.slotHover[_arrivalSeq] ?? false) : false
    property bool _panelHovered: false
    function notePanelHover(h: bool) {
        _panelHovered = h;
    }

    property bool _inputFocused: false
    function notePanelFocus(f: bool) {
        _inputFocused = f;
    }

    property bool _stickyStrip: false
    on_StripHoveredChanged: {
        if (_stripHovered) {
            _stickyStrip = true;
            stickyTimer.stop();
        } else
            stickyTimer.restart();
    }
    Timer {
        id: stickyTimer
        interval: 300
        onTriggered: root._stickyStrip = false
    }

    // _inputFocused keeps the panel alive while the user is actively typing.
    readonly property bool _anyHovered: _stickyStrip || _slotHovered || _panelHovered || _inputFocused

    on_AnyHoveredChanged: {
        if (!aiVisible)
            return;
        if (_anyHovered) {
            transitTimer.stop();
            return;
        }
        transitTimer.restart();
    }
    Timer {
        id: transitTimer
        interval: 150
        onTriggered: {
            if (root.aiVisible && !root._anyHovered)
                VisibilitiesManager.setVisibility(root.screen, "ai", false);
        }
    }

    onAiVisibleChanged: {
        if (aiVisible)
            FocusManager.requestFocus("ai");
        else
            FocusManager.releaseFocus("ai");
    }

    Connections {
        target: FocusManager
        function onFocusCleared() {
            if (root.aiVisible)
                VisibilitiesManager.setVisibility(root.screen, "ai", false);
        }
    }

    Component.onCompleted: {
        // Shortcut пустой — таргет "ai" держит IpcManager (toggle/open/list).
        VisibilitiesManager.addVisibility(root.screen, "ai", "", false, false, "Toggle AI");
        IpcManager.register("ai", root.registry.active);
        _interactionRail = manager.determineRailIndex(content);
        if (_interactionRail >= 0) {
            InteractionManager.registerHover(_interactionRail, 0, "ai", () => {
                VisibilitiesManager.setVisibility(root.screen, "ai", true);
            });
        }
    }

    Component.onDestruction: {
        if (_interactionRail >= 0)
            InteractionManager.unregisterHover(_interactionRail, "ai");
    }

    Connections {
        target: VisibilitiesManager
        function onVisibilityChanged(screen: ShellScreen, name: string, state: bool) {
            if (screen === root.screen && name === "ai")
                root.aiVisible = state;
        }
    }

    // Держим список страниц в менеджере свежим (реестр грузится асинхронно).
    Connections {
        target: root.registry
        function onActiveChanged() {
            IpcManager.setManifests("ai", root.registry.active);
        }
    }

    // IPC `open <id>` → выбрать вкладку на видимом (активном) экране.
    Connections {
        target: IpcManager
        function onOpenRequested(name: string, id: string, query: string) {
            if (name !== "ai" || !root.aiVisible || !id)
                return;
            const arr = root.registry.active ?? [];
            const i = arr.findIndex(m => m.id === id);
            if (i >= 0)
                root.registry.currentTab = i;
        }
    }

    // Resolve one side of an EdgesData group for the rails contract: "all"
    // inherits the group's `all`; a number is literal; null falls through so
    // WindowSlot applies its automatic default (0 for margins, the global
    // Config.backgrounds.paddings for paddings).
    function _edge(g, side) {
        const v = g[side];
        return v === "all" ? g.all : v;
    }

    // ── Rails contract ────────────────────────────────────────────────
    property QtObject content: QtObject {
        // 0 = auto-sized from the content's implicit size (dashboard-style).
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        property bool aLeft: Config.ai.anchors.left ?? undefined
        property bool aRight: Config.ai.anchors.right ?? undefined
        property bool aTop: Config.ai.anchors.top ?? undefined
        property bool aBottom: Config.ai.anchors.bottom ?? undefined
        property bool aHorizontalCenter: Config.ai.anchors.horizontalCenter ?? undefined
        property bool aVerticalCenter: Config.ai.anchors.verticalCenter ?? undefined
        property var mLeft: root._edge(Config.ai.margins, "left")
        property var mRight: root._edge(Config.ai.margins, "right")
        property var mTop: root._edge(Config.ai.margins, "top")
        property var mBottom: root._edge(Config.ai.margins, "bottom")
        property int vCenterOffset: Config.ai.vCenterOffset
        property int hCenterOffset: Config.ai.hCenterOffset
        property var pLeft: root._edge(Config.ai.paddings, "left")
        property var pRight: root._edge(Config.ai.paddings, "right")
        property var pTop: root._edge(Config.ai.paddings, "top")
        property var pBottom: root._edge(Config.ai.paddings, "bottom")
        property string mode: Config.ai.mode
        property bool sticks: Config.ai.sticks
        property bool pinned: false
        property bool reservesSpace: Config.ai.reservesSpace
        property int layer: Config.ai.layer
        property var windowRounding: Config.ai.rounding
        property var sizeSpring: Config.ai.sizeSpring
        property var sizeDamping: Config.ai.sizeDamping

        property Component content: AiContent {
            registry: root.registry
            onPanelHoveredChanged: root.notePanelHover(panelHovered)
            onInputFocusedChanged: root.notePanelFocus(inputFocused)
        }
    }

    // ── Background registration ───────────────────────────────────────
    Loader {
        active: root.aiVisible
        sourceComponent: Item {
            Component.onCompleted: root._arrivalSeq = root.manager.requestBackground(root.content)
            Component.onDestruction: {
                root.manager.removeBackground(root.content);
                root._arrivalSeq = -1;
            }
        }
    }
}
