pragma ComponentBehavior: Bound

import qs.config
import qs.services
import Quickshell
import QtQuick

import "content"

// Toast overlay wrapper. Event-driven like NotificationsWrapper: it requests a
// background whenever Toaster has active toasts and drops it when the queue
// empties. Geometry/anchors come from Config.toasts via the rails contract
// (mode: push), same as the OSD/notification wrappers. The individual toasts'
// timers live in the content delegates; this only gates the surface's presence.
Item {
    id: root

    required property var manager
    required property ShellScreen screen

    readonly property bool toastsVisible: Toaster.toasts.length > 0

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

        property bool aLeft: Config.toasts.anchors.left ?? false
        property bool aRight: Config.toasts.anchors.right ?? false
        property bool aTop: Config.toasts.anchors.top ?? false
        property bool aBottom: Config.toasts.anchors.bottom ?? false
        property bool aHorizontalCenter: Config.toasts.anchors.horizontalCenter ?? false
        property bool aVerticalCenter: Config.toasts.anchors.verticalCenter ?? false

        property var mLeft: root._edge(Config.toasts.margins, "left")
        property var mRight: root._edge(Config.toasts.margins, "right")
        property var mTop: root._edge(Config.toasts.margins, "top")
        property var mBottom: root._edge(Config.toasts.margins, "bottom")
        property int vCenterOffset: Config.toasts.vCenterOffset
        property int hCenterOffset: Config.toasts.hCenterOffset

        property var pLeft: root._edge(Config.toasts.paddings, "left")
        property var pRight: root._edge(Config.toasts.paddings, "right")
        property var pTop: root._edge(Config.toasts.paddings, "top")
        property var pBottom: root._edge(Config.toasts.paddings, "bottom")

        property string mode: Config.toasts.mode
        property bool sticks: Config.toasts.sticks
        property bool pinned: false
        property bool reservesSpace: false
        property int layer: Config.toasts.layer
        property var windowRounding: Config.toasts.rounding

        property Component content: ToastsContent {}
    }

    Loader {
        active: root.toastsVisible

        sourceComponent: Item {
            Component.onCompleted: root.manager.requestBackground(root.content)
            Component.onDestruction: root.manager.removeBackground(root.content)
        }
    }
}
