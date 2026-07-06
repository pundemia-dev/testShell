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

    // ── Rails contract ────────────────────────────────────────────────
    property QtObject content: QtObject {
        // 0 = auto-sized from the content's implicit size (dashboard-style).
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        property bool aLeft: true
        property bool aRight: false
        property bool aTop: false
        property bool aBottom: false
        property bool aHorizontalCenter: false
        property bool aVerticalCenter: true
        property int mLeft: 0
        property int mRight: 0
        property int mTop: 0
        property int mBottom: 0
        property int vCenterOffset: 0
        property int hCenterOffset: 0
        property int pLeft: Appearance.padding.medium
        property int pRight: Appearance.padding.medium
        property int pTop: Appearance.padding.medium
        property int pBottom: Appearance.padding.medium
        property string mode: "push"
        property bool pinned: false
        property bool reservesSpace: false
        readonly property int layer: 0
        // property int windowRounding: Appearance.rounding.extraLarge

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
