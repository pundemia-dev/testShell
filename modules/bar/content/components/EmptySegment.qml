// modules/bar/content/components/EmptySegment.qml
//
// Placeholder drop target shown in a segment that has no widgets while the
// layout editor is active. Without it an empty segment collapses to its
// paddings and exposes no DropArea, so a palette widget has nowhere to land.
import QtQuick
import qs.config
import qs.services
import qs.components
import qs.components.effects

Item {
    id: root
    property string seg: ""

    readonly property bool isHorizontal: Config.bar.orientation
    readonly property bool shown: BarEditManager.editing && BarEditManager.layoutFor(seg).length === 0
    // A "widget-sized" landing strip: group thickness on the short axis,
    // doubled along the bar so it reads as a drop zone.
    readonly property real side: Config.bar.group.thickness

    visible: shown
    implicitWidth: shown ? (isHorizontal ? side * 2 : side) : 0
    implicitHeight: shown ? (isHorizontal ? side : side * 2) : 0

    DropArea {
        id: drop
        anchors.fill: parent
        enabled: root.shown && !!BarEditManager.dragPayload
        keys: ["application/x-pshell-widget"]
        onEntered: BarEditManager.setDropTarget(root.seg, [0])
        // Accept only — the commit runs in the source's Drag.onDragFinished.
        onDropped: drag => drag.acceptProposedAction()
    }

    DashedRect {
        anchors.fill: parent
        cornerRadius: Config.bar.group.rounding
        strokeColor: drop.containsDrag ? Colours.palette.primary : Colours.palette.outline
        opacity: drop.containsDrag ? 1 : 0.6

        Behavior on opacity {
            Anim {}
        }
    }
}
