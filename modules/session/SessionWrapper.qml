pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.modules.session.content
import Quickshell
import QtQuick

Item {
    id: root

    required property var manager
    required property ShellScreen screen

    // Persistent action registry, built once at startup (the wrapper is always
    // alive) so the async folder-scan discovery finishes before the first open
    // (mirrors DashboardWrapper). Declared as a property so it's reachable via
    // `root.registry` from the content Component.
    property SessionRegistry registry: SessionRegistry {}

    // ── Visibility ──────────────────────────────────────────────────
    property bool sessionVisible: false

    onSessionVisibleChanged: {
        if (sessionVisible)
            FocusManager.requestFocus("session");
        else
            FocusManager.releaseFocus("session");
    }

    // Click-outside (scrim) / focus loss closes the menu.
    Connections {
        target: FocusManager
        function onFocusCleared() {
            if (root.sessionVisible)
                VisibilitiesManager.setVisibility(root.screen, "session", false);
        }
    }

    Component.onCompleted: {
        // Shortcut пустой — таргет "session" держит IpcManager (toggle/open/list).
        VisibilitiesManager.addVisibility(root.screen, "session", "",
                                          false, false, "Toggle Session menu");
        IpcManager.register("session", root.registry.active);
    }

    Connections {
        target: VisibilitiesManager
        function onVisibilityChanged(screen: ShellScreen, name: string, state: bool) {
            if (screen === root.screen && name === "session")
                root.sessionVisible = state && Config.session.enabled;
        }
    }

    // Держим список действий в менеджере свежим (реестр грузится асинхронно).
    Connections {
        target: root.registry
        function onActiveChanged() {
            IpcManager.setManifests("session", root.registry.active);
        }
    }

    // IPC `open <id>` → сразу выполнить действие по id на активном экране.
    Connections {
        target: IpcManager
        function onOpenRequested(name: string, id: string, query: string) {
            if (name !== "session" || !id)
                return;
            const a = (root.registry.active ?? []).find(m => m.id === id);
            if (a && a.command && a.command.length > 0)
                Quickshell.execDetached(a.command);
            VisibilitiesManager.setVisibility(root.screen, "session", false);
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
        property bool aLeft: Config.session.anchors.left ?? undefined
        property bool aRight: Config.session.anchors.right ?? undefined
        property bool aTop: Config.session.anchors.top ?? undefined
        property bool aBottom: Config.session.anchors.bottom ?? undefined
        property bool aHorizontalCenter: Config.session.anchors.horizontalCenter ?? undefined
        property bool aVerticalCenter: Config.session.anchors.verticalCenter ?? undefined
        // Margins
        property var mLeft: root._edge(Config.session.margins, "left")
        property var mRight: root._edge(Config.session.margins, "right")
        property var mTop: root._edge(Config.session.margins, "top")
        property var mBottom: root._edge(Config.session.margins, "bottom")
        property int vCenterOffset: Config.session.vCenterOffset
        property int hCenterOffset: Config.session.hCenterOffset
        // Padding
        property var pLeft: root._edge(Config.session.paddings, "left")
        property var pRight: root._edge(Config.session.paddings, "right")
        property var pTop: root._edge(Config.session.paddings, "top")
        property var pBottom: root._edge(Config.session.paddings, "bottom")
        // Rails semantics
        property string mode: Config.session.mode
        property bool sticks: Config.session.sticks
        property bool pinned: false
        property bool reservesSpace: Config.session.reservesSpace
        property int layer: Config.session.layer
        property var windowRounding: Config.session.rounding
        property var sizeSpring: Config.session.sizeSpring
        property var sizeDamping: Config.session.sizeDamping
        // Content
        property Component content: SessionContent {
            registry: root.registry
            onActionTriggered: VisibilitiesManager.setVisibility(root.screen, "session", false)
            onCloseRequested: VisibilitiesManager.setVisibility(root.screen, "session", false)
        }
    }

    // ── Backend Loader: registers/unregisters the bg via manager ───
    Loader {
        active: root.sessionVisible
        sourceComponent: Item {
            Component.onCompleted: root.manager.requestBackground(root.content)
            Component.onDestruction: root.manager.removeBackground(root.content)
        }
    }
}
