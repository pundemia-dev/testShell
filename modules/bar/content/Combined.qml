// modules/bar/content/Combined.qml
//
// Non-separated bar: begin / center / end share a single background slot
// (`position`). begin pins to the leading edge, end to the trailing edge, and
// center anchors to the true centre — so center stays geometrically centred
// regardless of how wide begin/end grow (no spacers, no SpaceBetween).
//
// Sizing mirrors the separated Begin/Center/End flexboxes: tight on the SHORT
// axis (hug the tallest segment), full along the LONG axis. The slot's content
// host centres the loaded content by its childrenRect, so the short axis must
// be tight — otherwise the host double-centres and the whole bar drifts off the
// bg's centre line.
//
// Symmetric, so every placement works: `horizontal` picks the axis and the
// top/bottom/left/right position needs no special case.
import QtQuick
import Quickshell
import qs.config

Item {
    id: root
    required property ShellScreen screen

    // true → horizontal bar (begin↔end run left→right), false → vertical
    readonly property bool horizontal: Config.bar.orientation
    readonly property int shortMargin: Config.bar.shortSideMargin.all ?? 0
    readonly property int pad: Config.bar.paddings.all ?? 0

    // Long axis = full bar extent (screen minus short-side margins and a
    // symmetric edge pad). Short axis = tallest/widest segment, so the host
    // centres a tight box inside the bar thickness.
    implicitWidth: horizontal ? (root.screen.width - 2 * shortMargin - 2 * pad) : Math.max(begin.implicitWidth, center.implicitWidth, end.implicitWidth)
    implicitHeight: horizontal ? Math.max(begin.implicitHeight, center.implicitHeight, end.implicitHeight) : (root.screen.height - 2 * shortMargin - 2 * pad)

    Begin {
        id: begin
        screen: root.screen
        anchors.left: root.horizontal ? parent.left : undefined
        anchors.top: root.horizontal ? undefined : parent.top
        anchors.verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
    }

    Center {
        id: center
        screen: root.screen
        anchors.centerIn: parent
    }

    End {
        id: end
        screen: root.screen
        anchors.right: root.horizontal ? parent.right : undefined
        anchors.bottom: root.horizontal ? undefined : parent.bottom
        anchors.verticalCenter: root.horizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
    }
}
