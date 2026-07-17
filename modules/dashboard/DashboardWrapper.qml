pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components.misc
import Quickshell
import QtQuick
import "content"

Item {
    id: root

    required property var manager
    required property ShellScreen screen

    // Persistent page registry, built once at startup (the wrapper is always
    // alive) so its async folder-scan discovery finishes well before the first
    // open. DashboardContent — recreated on every open — reads this instead of
    // scanning afresh, so the main page renders in the first frame. Declared as
    // a property (not a bare child id) so it's reachable via `root.registry`.
    property DashboardRegistry registry: DashboardRegistry {}

    // ── Visibility ──────────────────────────────────────────────────
    property bool dashVisible: false

    // ── Focus-driven auto-hide (mirrors StashWrapper) ───────────────
    readonly property int _interactionRail: manager.determineRailIndex(content)
    property int _arrivalSeq: -1
    readonly property bool _stripHovered: _interactionRail >= 0
        ? (InteractionManager.stripHovered[_interactionRail] ?? false)
        : false
    readonly property bool _slotHovered: _arrivalSeq >= 0
        ? (manager.slotHover[_arrivalSeq] ?? false)
        : false

    // Reliable hover signal from inside DashboardContent (not blocked by Qt's
    // topmost-only hover delivery through the strip).
    property bool _panelHovered: false
    function notePanelHover(hovered) { _panelHovered = hovered; }

    // Sticky strip engagement: hold a brief "still engaged" flag after the
    // strip hover drops so the cursor can land on the panel itself.
    property bool _stickyStripEngaged: false
    on_StripHoveredChanged: {
        if (_stripHovered) {
            _stickyStripEngaged = true;
            stickyExitTimer.stop();
        } else {
            stickyExitTimer.restart();
        }
    }
    Timer {
        id: stickyExitTimer
        interval: 300
        repeat: false
        onTriggered: root._stickyStripEngaged = false
    }

    readonly property bool _anyHovered: _stickyStripEngaged || _slotHovered || _panelHovered

    onDashVisibleChanged: {
        if (!dashVisible && _interactionRail >= 0)
            InteractionManager.resetCounter(_interactionRail);
    }
    on_AnyHoveredChanged: {
        if (!dashVisible) return;
        if (_anyHovered) {
            transitGraceTimer.stop();
            return;
        }
        transitGraceTimer.restart();
    }

    Timer {
        id: transitGraceTimer
        interval: Config.dashboard.autoHideMs
        repeat: false
        onTriggered: {
            if (root.dashVisible && !root._anyHovered)
                VisibilitiesManager.setVisibility(root.screen, "dashboard", false);
        }
    }

    Component.onCompleted: {
        // Shortcut пустой — таргет "dashboard" держит IpcManager (toggle/open/list).
        VisibilitiesManager.addVisibility(root.screen, "dashboard", "",
                                          false, false, "Toggle Dashboard");
        IpcManager.register("dashboard", root.registry.active);
    }

    Connections {
        target: VisibilitiesManager
        function onVisibilityChanged(screen: ShellScreen, name: string, state: bool) {
            if (screen === root.screen && name === "dashboard")
                root.dashVisible = state && Config.dashboard.enabled;
        }
    }

    // Держим список страниц в менеджере свежим (реестр грузится асинхронно).
    Connections {
        target: root.registry
        function onActiveChanged() {
            IpcManager.setManifests("dashboard", root.registry.active);
        }
    }

    BorderTriggerBinding {
        manager: root.manager
        content: root.content
        screen: root.screen
        moduleName: "dashboard"
        trigger: Config.dashboard.trigger
        moduleVisible: root.dashVisible
        moduleEnabled: Config.dashboard.enabled
    }

    // IPC `open <id>` → выбрать вкладку на видимом (активном) экране.
    Connections {
        target: IpcManager
        function onOpenRequested(name: string, id: string, query: string) {
            if (name !== "dashboard" || !root.dashVisible || !id)
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

    // ── QtObject contract for the rails system ─────────────────────
    property QtObject content: QtObject {
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        // Anchors from config
        property bool aLeft: Config.dashboard.anchors.left ?? undefined
        property bool aRight: Config.dashboard.anchors.right ?? undefined
        property bool aTop: Config.dashboard.anchors.top ?? undefined
        property bool aBottom: Config.dashboard.anchors.bottom ?? undefined
        property bool aHorizontalCenter: Config.dashboard.anchors.horizontalCenter ?? undefined
        property bool aVerticalCenter: Config.dashboard.anchors.verticalCenter ?? undefined
        // Margins
        property var mLeft: root._edge(Config.dashboard.margins, "left")
        property var mRight: root._edge(Config.dashboard.margins, "right")
        property var mTop: root._edge(Config.dashboard.margins, "top")
        property var mBottom: root._edge(Config.dashboard.margins, "bottom")
        property int vCenterOffset: Config.dashboard.vCenterOffset
        property int hCenterOffset: Config.dashboard.hCenterOffset
        // Padding
        property var pLeft: root._edge(Config.dashboard.paddings, "left")
        property var pRight: root._edge(Config.dashboard.paddings, "right")
        property var pTop: root._edge(Config.dashboard.paddings, "top")
        property var pBottom: root._edge(Config.dashboard.paddings, "bottom")
        // Rails semantics
        property string mode: Config.dashboard.mode
        property bool sticks: Config.dashboard.sticks
        property bool pinned: false
        property bool reservesSpace: Config.dashboard.reservesSpace
        property int layer: Config.dashboard.layer
        property var windowRounding: Config.dashboard.rounding
        property var sizeSpring: Config.dashboard.sizeSpring
        property var sizeDamping: Config.dashboard.sizeDamping
        // Content
        property Component content: DashboardContent {
            registry: root.registry
            onPanelHoveredChanged: root.notePanelHover(panelHovered)
        }
    }

    // ── Backend Loader: registers/unregisters the bg via manager ───
    Loader {
        active: root.dashVisible
        sourceComponent: Item {
            Component.onCompleted: {
                root._arrivalSeq = root.manager.requestBackground(root.content);
            }
            Component.onDestruction: {
                root.manager.removeBackground(root.content);
                root._arrivalSeq = -1;
            }
        }
    }
}
