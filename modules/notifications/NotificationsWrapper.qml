pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.utils
import Quickshell
import QtQuick

Item {
    id: root

    required property var manager
    required property ShellScreen screen

    property bool notificationsVisible: Notifs.popups.length > 0

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
        property var mLeft: Config.notifs.offsets.left ?? Config.notifs.offsets.all
        property var mRight: Config.notifs.offsets.right ?? Config.notifs.offsets.all
        property var mTop: Config.notifs.offsets.top ?? Config.notifs.offsets.all
        property var mBottom: Config.notifs.offsets.bottom ?? Config.notifs.offsets.all
        property var mHorizontalCenter: Config.notifs.offsets.horizontalCenter ?? Config.notifs.offsets.all
        property var mVerticalCenter: Config.notifs.offsets.verticalCenter ?? Config.notifs.offsets.all
        // Paddings
        property var pLeft: Config.notifs.paddings.left ?? Config.notifs.paddings.all
        property var pRight: Config.notifs.paddings.right ?? Config.notifs.paddings.all
        property var pTop: Config.notifs.paddings.top ?? Config.notifs.paddings.all
        property var pBottom: Config.notifs.paddings.bottom ?? Config.notifs.paddings.all
        // Base settings
        property var rounding: Config.notifs.rounding >= 0 ? Config.notifs.rounding : undefined
        property bool invertBaseRounding: Config.notifs.invertBaseRounding ?? false
        // Bar exclusion
        property bool excludeBarArea: Config.notifs.excludeBarArea ?? true
        // Reusability
        property bool reusable: false

        property Component content: NotificationList {}
    }

    Loader {
        id: notifsLoader
        active: root.notificationsVisible

        sourceComponent: Item {
            Component.onCompleted: {
                root.manager.requestBackground(root.content, false, true);
            }

            Component.onDestruction: {
                root.manager.removeBackground(root.content);
            }
        }
    }
}
