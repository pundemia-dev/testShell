pragma ComponentBehavior: Bound

import qs.services
import Quickshell
import QtQuick

Item {
    id: root

    required property var manager
    required property var content
    required property ShellScreen screen
    required property string moduleName
    required property var trigger
    required property bool moduleVisible
    property bool moduleEnabled: true

    visible: false
    width: 0
    height: 0

    property int _rail: -1

    function _canOpen() {
        return (trigger?.enabled ?? false) && moduleEnabled && !moduleVisible;
    }

    function _open() {
        if (_canOpen())
            VisibilitiesManager.setVisibility(screen, moduleName, true);
    }

    function _unregister() {
        if (_rail < 0)
            return;
        InteractionManager.unregisterHover(_rail, moduleName);
        InteractionManager.unregisterDrop(_rail, moduleName);
        InteractionManager.unregisterSlide(_rail, moduleName);
        _rail = -1;
    }

    function _register() {
        _rail = manager.determineRailIndex(content);
        if (_rail < 0)
            return;
        if (trigger?.hover ?? false)
            InteractionManager.registerHover(_rail, trigger?.layer ?? 0, moduleName, () => root._open());
        if (trigger?.drop ?? false)
            InteractionManager.registerDrop(_rail, moduleName, () => root._open());
        if (trigger?.slide ?? false)
            InteractionManager.registerSlide(_rail, moduleName, () => root._open());
    }

    function sync() {
        _unregister();
        if (!(trigger?.enabled ?? false))
            return;
        _register();
    }

    Component.onCompleted: sync()
    Component.onDestruction: _unregister()

    Connections {
        target: root.trigger
        ignoreUnknownSignals: true
        function onEnabledChanged() { root.sync(); }
        function onHoverChanged() { root.sync(); }
        function onDropChanged() { root.sync(); }
        function onSlideChanged() { root.sync(); }
        function onLayerChanged() { root.sync(); }
    }

    Connections {
        target: root.content
        ignoreUnknownSignals: true
        function onALeftChanged() { root.sync(); }
        function onARightChanged() { root.sync(); }
        function onATopChanged() { root.sync(); }
        function onABottomChanged() { root.sync(); }
        function onAHorizontalCenterChanged() { root.sync(); }
        function onAVerticalCenterChanged() { root.sync(); }
    }
}
