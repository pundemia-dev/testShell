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

    property bool notificationsVisible: Notifs.popups.length > 0

    // Resolve one side of an EdgesData group for the rails contract: "all"
    // inherits the group's `all`; a number is literal; null falls through so
    // WindowSlot applies its automatic default (0 for margins, the global
    // Config.backgrounds.paddings for paddings).
    function _edge(g, side) {
        const v = g[side];
        return v === "all" ? g.all : v;
    }

    property QtObject content: QtObject {
        // Content size
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        // Anchors
        property bool aLeft: Config.notifs.anchors.left ?? false
        property bool aRight: Config.notifs.anchors.right ?? false
        property bool aTop: Config.notifs.anchors.top ?? false
        property bool aBottom: Config.notifs.anchors.bottom ?? false
        property bool aHorizontalCenter: Config.notifs.anchors.horizontalCenter ?? false
        property bool aVerticalCenter: Config.notifs.anchors.verticalCenter ?? false
        // Margins & offsets
        property var mLeft: root._edge(Config.notifs.margins, "left")
        property var mRight: root._edge(Config.notifs.margins, "right")
        property var mTop: root._edge(Config.notifs.margins, "top")
        property var mBottom: root._edge(Config.notifs.margins, "bottom")
        property int vCenterOffset: Config.notifs.vCenterOffset
        property int hCenterOffset: Config.notifs.hCenterOffset
        // Paddings
        property var pLeft: root._edge(Config.notifs.paddings, "left")
        property var pRight: root._edge(Config.notifs.paddings, "right")
        property var pTop: root._edge(Config.notifs.paddings, "top")
        property var pBottom: root._edge(Config.notifs.paddings, "bottom")
        // Rails contract
        property string mode: Config.notifs.mode
        property bool sticks: Config.notifs.sticks
        property bool pinned: false
        property bool reservesSpace: false
        property int layer: Config.notifs.layer
        property var windowRounding: Config.notifs.rounding

        property Component content: NotificationList {}
    }

    Loader {
        id: notifsLoader
        active: root.notificationsVisible

        sourceComponent: Item {
            Component.onCompleted: {
                root.manager.requestBackground(root.content);
            }

            Component.onDestruction: {
                root.manager.removeBackground(root.content);
            }
        }
    }
}
