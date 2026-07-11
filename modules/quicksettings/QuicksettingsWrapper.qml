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

    // Persistent registries, built once at startup (the wrapper is always
    // alive) so the async folder-scan discovery finishes well before the
    // first open (mirrors DashboardWrapper).
    property QsRegistry registry: QsRegistry {}
    property QsCardRegistry cardRegistry: QsCardRegistry {}

    // ── Visibility ──────────────────────────────────────────────────
    property bool qsVisible: false

    // ── Focus-driven auto-hide (mirrors DashboardWrapper) ───────────
    property int _interactionRail: -1
    property int _arrivalSeq: -1
    readonly property bool _stripHovered: _interactionRail >= 0
        ? (InteractionManager.stripHovered[_interactionRail] ?? false)
        : false
    readonly property bool _slotHovered: _arrivalSeq >= 0
        ? (manager.slotHover[_arrivalSeq] ?? false)
        : false

    property bool _panelHovered: false
    function notePanelHover(hovered) { _panelHovered = hovered; }

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

    onQsVisibleChanged: {
        if (!qsVisible && _interactionRail >= 0)
            InteractionManager.resetCounter(_interactionRail);
    }
    on_AnyHoveredChanged: {
        if (!qsVisible) return;
        if (_anyHovered) {
            transitGraceTimer.stop();
            return;
        }
        transitGraceTimer.restart();
    }

    Timer {
        id: transitGraceTimer
        interval: Config.quicksettings.autoHideMs
        repeat: false
        onTriggered: {
            if (root.qsVisible && !root._anyHovered)
                VisibilitiesManager.setVisibility(root.screen, "quicksettings", false);
        }
    }

    Component.onCompleted: {
        // Shortcut пустой — таргет "quicksettings" держит IpcManager (toggle/open/list).
        VisibilitiesManager.addVisibility(root.screen, "quicksettings", "",
                                          false, false, "Toggle Quicksettings");
        IpcManager.register("quicksettings", root.registry.active);

        _interactionRail = manager.determineRailIndex(content);
        if (_interactionRail >= 0) {
            InteractionManager.registerHover(_interactionRail, 0, "quicksettings", () => {
                if (Config.quicksettings.enabled)
                    VisibilitiesManager.setVisibility(root.screen, "quicksettings", true);
            });
        }
    }

    Component.onDestruction: {
        if (_interactionRail >= 0)
            InteractionManager.unregisterHover(_interactionRail, "quicksettings");
    }

    Connections {
        target: VisibilitiesManager
        function onVisibilityChanged(screen: ShellScreen, name: string, state: bool) {
            if (screen === root.screen && name === "quicksettings")
                root.qsVisible = state && Config.quicksettings.enabled;
        }
    }

    // Держим список страниц в менеджере свежим (реестр грузится асинхронно).
    Connections {
        target: root.registry
        function onActiveChanged() {
            IpcManager.setManifests("quicksettings", root.registry.active);
        }
    }

    // IPC `open <id>` → выбрать вкладку на видимом (активном) экране.
    Connections {
        target: IpcManager
        function onOpenRequested(name: string, id: string, query: string) {
            if (name !== "quicksettings" || !root.qsVisible || !id)
                return;
            const arr = root.registry.active ?? [];
            const i = arr.findIndex(m => m.id === id);
            if (i >= 0)
                root.registry.currentTab = i;
        }
    }

    // ── QtObject contract for the rails system ─────────────────────
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
        // Anchors from config
        property bool aLeft: Config.quicksettings.anchors.left ?? undefined
        property bool aRight: Config.quicksettings.anchors.right ?? undefined
        property bool aTop: Config.quicksettings.anchors.top ?? undefined
        property bool aBottom: Config.quicksettings.anchors.bottom ?? undefined
        property bool aHorizontalCenter: Config.quicksettings.anchors.horizontalCenter ?? undefined
        property bool aVerticalCenter: Config.quicksettings.anchors.verticalCenter ?? undefined
        // Margins
        property var mLeft: root._edge(Config.quicksettings.margins, "left")
        property var mRight: root._edge(Config.quicksettings.margins, "right")
        property var mTop: root._edge(Config.quicksettings.margins, "top")
        property var mBottom: root._edge(Config.quicksettings.margins, "bottom")
        property int vCenterOffset: Config.quicksettings.vCenterOffset
        property int hCenterOffset: Config.quicksettings.hCenterOffset
        // Padding
        property var pLeft: root._edge(Config.quicksettings.paddings, "left")
        property var pRight: root._edge(Config.quicksettings.paddings, "right")
        property var pTop: root._edge(Config.quicksettings.paddings, "top")
        property var pBottom: root._edge(Config.quicksettings.paddings, "bottom")
        // Rails semantics
        property string mode: Config.quicksettings.mode
        property bool sticks: Config.quicksettings.sticks
        property bool pinned: false
        property bool reservesSpace: Config.quicksettings.reservesSpace
        property int layer: Config.quicksettings.layer
        property var windowRounding: Config.quicksettings.rounding
        property var sizeSpring: Config.quicksettings.sizeSpring
        property var sizeDamping: Config.quicksettings.sizeDamping
        // Content
        property Component content: QuicksettingsContent {
            registry: root.registry
            cardRegistry: root.cardRegistry
            onPanelHoveredChanged: root.notePanelHover(panelHovered)
        }
    }

    // ── Backend Loader: registers/unregisters the bg via manager ───
    Loader {
        active: root.qsVisible
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
