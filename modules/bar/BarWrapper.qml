pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    Loader {
        id: content

        anchors.left: !Config.bar.orientation && !Config.bar.position ? parent.left : undefined;
        anchors.top: Config.bar.orientation && !Config.bar.position ? parent.top : undefined;
        anchors.right: !Config.bar.orientation && Config.bar.position ? parent.right : undefined;
        anchors.bottom: Config.bar.orientation && Config.bar.position ? parent.bottom : undefined;

        anchors.leftMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
        anchors.topMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin
        anchors.rightMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
        anchors.bottomMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin

        sourceComponent : Bar {

        }
    }
}