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

    property QtObject content: QtObject {
        property int wrapperWidth: 0
        property int wrapperHeight: 0

        property bool aLeft: Config.toasts.anchors.left ?? false
        property bool aRight: Config.toasts.anchors.right ?? false
        property bool aTop: Config.toasts.anchors.top ?? false
        property bool aBottom: Config.toasts.anchors.bottom ?? false
        property bool aHorizontalCenter: Config.toasts.anchors.horizontalCenter ?? false
        property bool aVerticalCenter: Config.toasts.anchors.verticalCenter ?? false

        property int mLeft: Config.toasts.mLeft
        property int mRight: Config.toasts.mRight
        property int mTop: Config.toasts.mTop
        property int mBottom: Config.toasts.mBottom
        property int vCenterOffset: 0
        property int hCenterOffset: 0

        property int pLeft: Config.toasts.padding
        property int pRight: Config.toasts.padding
        property int pTop: Config.toasts.padding
        property int pBottom: Config.toasts.padding

        property string mode: Config.toasts.mode
        property bool pinned: false
        property bool reservesSpace: false
        readonly property int layer: 0
        property int windowRounding: Config.toasts.rounding >= 0 ? Config.toasts.rounding : (Config.backgrounds.rounding ?? 0)

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
