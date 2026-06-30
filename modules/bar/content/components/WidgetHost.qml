// modules/bar/content/components/WidgetHost.qml
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.utils
import qs.components
import Quickshell

Item {
    id: host
    required property ShellScreen screen

    // Segment id ("begin" | "center" | "end") and this entry's top-level index,
    // threaded down from the owning segment so edit affordances can address the
    // entry in Config.bar.<seg>Layout. (index supplied by the Repeater.)
    property string seg: ""
    required property int index

    readonly property bool isHorizontal: Config.bar.orientation
    readonly property real groupPadding: Config.bar.group.padding
    readonly property real thickness: Config.bar.group.thickness

    readonly property bool editing: BarEditManager.editing
    readonly property bool dragActive: !!BarEditManager.dragPayload
    // This widget is the phone-folder merge target the cursor is hovering.
    readonly property bool _groupFocus: editing && dragActive && BarEditManager.dropSeg === host.seg && BarEditManager.dropOnto === host.index
    readonly property bool isWidget: host.modelData && host.modelData.type === "widget"
    readonly property bool isGroup: host.modelData && host.modelData.type === "group"

    readonly property int _segCount: BarEditManager.layoutFor(host.seg).length

    // The bar's true outer edges (begin's first slot, end's last slot) extend
    // their drop hit-area outward into the surrounding padding — purely the
    // DropArea geometry (negative margins), never the layout — so dropping at
    // the very start/end of the bar is easy even when that slot is a group.
    readonly property real _edgeExtend: Appearance.padding.large + (Config.bar.paddings.all ?? 8)
    readonly property bool _extendLeading: host.seg === "begin" && host.index === 0
    readonly property bool _extendTrailing: host.seg === "end" && host.index === host._segCount - 1

    // Intrinsic content size (no drop gap).
    readonly property real _contentW: {
        if (mainLoader.active) return mainLoader.width
        if (isGroup) return isHorizontal ? (groupLayout.childrenRect.width + groupPadding * 2) : thickness
        return 0
    }
    readonly property real _contentH: {
        if (mainLoader.active) return mainLoader.height
        if (isGroup) return isHorizontal ? thickness : (groupLayout.childrenRect.height + groupPadding * 2)
        return 0
    }

    // Drop gap: a slot opens space on its leading edge when the drop target is
    // its own index, or on its trailing edge when it's the last slot and the
    // target is "past the end". The gap grows the slot along the bar's long
    // axis and offsets the content, so neighbours slide apart — no placeholder
    // entry, so the model (and the in-flight drag source) stays stable.
    readonly property bool _dropHere: host.editing && host.dragActive && BarEditManager.dropSeg === host.seg && BarEditManager.dropPath.length === 1
    property real _gapBefore: (_dropHere && BarEditManager.dropPath[0] === host.index) ? BarEditManager.dropSize : 0
    property real _gapAfter: (_dropHere && host.index === _segCount - 1 && BarEditManager.dropPath[0] === _segCount) ? BarEditManager.dropSize : 0
    Behavior on _gapBefore {
        NumberAnimation {
            duration: Appearance.anim.durations.small
            easing.type: Easing.OutCubic
        }
    }
    Behavior on _gapAfter {
        NumberAnimation {
            duration: Appearance.anim.durations.small
            easing.type: Easing.OutCubic
        }
    }

    readonly property real _contentX: isHorizontal ? _gapBefore : (width - _contentW) / 2
    readonly property real _contentY: isHorizontal ? (height - _contentH) / 2 : _gapBefore

    implicitWidth: isHorizontal ? (_gapBefore + _contentW + _gapAfter) : _contentW
    implicitHeight: isHorizontal ? _contentH : (_gapBefore + _contentH + _gapAfter)

    // Reveal edit badges only while hovering this host — keeps the bar uncluttered.
    HoverHandler {
        id: hostHover
        enabled: host.editing
    }

    // Incoming-drag target: top-level insertion before/after this slot. Covered
    // by the per-child drop areas inside a group, so the group's own children
    // claim the cursor first and this only fires over the group's padding /
    // outside a child — that's the group-end "seam" handling.
    DropArea {
        id: slotDrop
        anchors.fill: parent
        // Extend the bar's outer edges outward (geometry only, not layout).
        anchors.leftMargin: (host.isHorizontal && host._extendLeading) ? -host._edgeExtend : 0
        anchors.topMargin: (!host.isHorizontal && host._extendLeading) ? -host._edgeExtend : 0
        anchors.rightMargin: (host.isHorizontal && host._extendTrailing) ? -host._edgeExtend : 0
        anchors.bottomMargin: (!host.isHorizontal && host._extendTrailing) ? -host._edgeExtend : 0
        enabled: host.editing && host.dragActive
        keys: ["application/x-pshell-widget"]

        // Dwell gate for the group gesture: the cursor must linger in a widget's
        // centre this long before the merge is proposed (else a slow drag-through
        // would group accidentally). Until it fires, the centre behaves as a
        // normal before/after insert.
        property bool _dwellArmed: false
        function _cancelDwell() {
            _dwellArmed = false;
            dwellTimer.stop();
        }
        Timer {
            id: dwellTimer
            interval: Config.bar.groupDwellMs ?? 1000
            onTriggered: BarEditManager.markGroupReady()
        }

        onPositionChanged: drag => {
            const E = host._edgeExtend;
            const lead = host._extendLeading ? E : 0;
            const mainPos = host.isHorizontal ? drag.x : drag.y;
            const mainSize = host.isHorizontal ? width : height;

            // Outward extension zones → top-level segment ends (works even when
            // the edge slot is a group).
            if (host._extendLeading && mainPos < lead) {
                slotDrop._cancelDwell();
                BarEditManager.setDropTarget(host.seg, [0]);
                return;
            }
            if (host._extendTrailing && mainPos > mainSize - E) {
                slotDrop._cancelDwell();
                BarEditManager.setDropTarget(host.seg, [host._segCount]);
                return;
            }

            // Content region. For a WIDGET target, the middle third is the
            // "drop onto → group" zone (phone-folder gesture, gated by the dwell
            // timer); the outer thirds insert before/after. For a GROUP this
            // fires over its padding (children claim the cursor via their own
            // drop areas), so left padding → before group, right padding → after
            // group. Insert INTO a group is the per-child drop areas.
            const hostMain = host.isHorizontal ? host.width : host.height;
            const rel = (mainPos - lead) / Math.max(1, hostMain);
            const draggedIsWidget = BarEditManager.dragPayload && BarEditManager.dragPayload.entry && BarEditManager.dragPayload.entry.type === "widget";
            const self = BarEditManager.isDragging(host.seg, [host.index]);
            // Generous centre band so the target is easy to settle on.
            const inCentre = host.isWidget && draggedIsWidget && !self && rel > 0.25 && rel < 0.75;

            if (inCentre) {
                // Focus the target IMMEDIATELY (no insert gap → layout holds
                // still, target stays under the cursor and scales up). The dwell
                // timer only flips it to "ready" (ring + mergeable).
                if (!slotDrop._dwellArmed) {
                    slotDrop._dwellArmed = true;
                    BarEditManager.setGroupTarget(host.seg, host.index);
                    dwellTimer.restart();
                }
            } else {
                slotDrop._cancelDwell();
                BarEditManager.setDropTarget(host.seg, [rel < 0.5 ? host.index : host.index + 1]);
            }
        }
        onExited: {
            slotDrop._cancelDwell();
            // Drop our focus if we still own it (so a lingering ring can't cause
            // an accidental merge once the cursor has left).
            if (BarEditManager.dropSeg === host.seg && BarEditManager.dropOnto === host.index)
                BarEditManager.clearDrop();
        }
        // Accept only — the actual commit runs in Drag.onDragFinished (post-loop).
        onDropped: drag => drag.acceptProposedAction()
    }

    // Group drag handle — sits below the group's children (declared before
    // bgRect) so child presses reach the per-child handles; group padding
    // presses fall through the background here and drag the whole group.
    MouseArea {
        id: groupDrag
        x: host._contentX
        y: host._contentY
        width: host._contentW
        height: host._contentH
        enabled: host.editing && host.isGroup
        cursorShape: enabled ? Qt.OpenHandCursor : Qt.ArrowCursor
        drag.target: dragGhost
        readonly property bool _dragArmed: drag.active
        on_DragArmedChanged: {
            if (!_dragArmed || dragGhost.Drag.active)
                return;
            // Capture identity SYNCHRONOUSLY at press — reading host.index in the
            // async grab callback can see -1 if a prior commit is recycling the
            // delegate.
            const seg = host.seg;
            const idx = host.index;
            const md = host.modelData;
            const size = host.isHorizontal ? host._contentW : host._contentH;
            if (idx < 0 || !seg)
                return; // stale/recycling delegate
            bgRect.grabToImage(result => {
                if (!groupDrag.drag.active)
                    return;
                dragGhost.Drag.imageSource = result.url;
                // State BEFORE Drag.active — setting active starts a BLOCKING
                // platform drag (QDrag::exec), so anything after it runs only
                // once the drag ends.
                BarEditManager.beginEntryDrag(seg, [idx], md, size);
                dragGhost.Drag.active = true;
            });
        }
    }

    // 1. Single widget
    EditJiggle {
        id: widgetJiggle
        x: host._contentX
        y: host._contentY
        active: host.editing && host.isWidget
        seed: host.index
        opacity: BarEditManager.isDragging(host.seg, [host.index]) ? 0.35 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.small
            }
        }
        // Spring up when it's the merge target (Android-style folder hover).
        scale: host._groupFocus ? 1.18 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.durations.small
                easing.type: Easing.OutBack
            }
        }

        Loader {
            id: mainLoader
            active: host.isWidget && !!host.modelData.name
            source: active ? Qt.resolvedUrl("../components/" + host.modelData.name + ".qml") : ""
            onLoaded: if (item && item.hasOwnProperty("screen")) item.screen = host.screen
        }
    }

    // 2. Group
    StyledRect {
        id: bgRect
        visible: host.isGroup
        x: host._contentX
        y: host._contentY
        width: host._contentW
        height: host._contentH
        color: Colours.tPalette.surface_container
        radius: Config.bar.group.rounding

        // index of the group child currently hovered (-1 = none); used to
        // suppress the group badge while a child badge is up.
        property int hoveredChild: -1

        FlexboxLayout {
            id: groupLayout
            // Cross-axis centred via anchors, main-axis offset by a constant
            // padding — reading parent.width/height here would loop, since the
            // group's size is itself derived from this layout's childrenRect.
            anchors.verticalCenter: host.isHorizontal ? parent.verticalCenter : undefined
            anchors.horizontalCenter: host.isHorizontal ? undefined : parent.horizontalCenter
            anchors.left: host.isHorizontal ? parent.left : undefined
            anchors.leftMargin: host.isHorizontal ? host.groupPadding : 0
            anchors.top: host.isHorizontal ? undefined : parent.top
            anchors.topMargin: host.isHorizontal ? 0 : host.groupPadding

            direction: host.isHorizontal ? FlexboxLayout.Row : FlexboxLayout.Column
            alignItems: FlexboxLayout.AlignCenter
            gap: Appearance.spacing.normal

            Repeater {
                model: host.isGroup ? host.modelData.children : []
                delegate: Item {
                    id: childHost
                    required property var modelData
                    required property int index

                    readonly property int _childCount: (host.modelData && host.modelData.children) ? host.modelData.children.length : 0

                    // Into-group drop gap (mirrors the top-level slot gap).
                    readonly property bool _cDropHere: host.editing && host.dragActive && BarEditManager.dropSeg === host.seg && BarEditManager.dropPath.length === 2 && BarEditManager.dropPath[0] === host.index
                    property real _cGapBefore: (_cDropHere && BarEditManager.dropPath[1] === childHost.index) ? BarEditManager.dropSize : 0
                    property real _cGapAfter: (_cDropHere && childHost.index === _childCount - 1 && BarEditManager.dropPath[1] === _childCount) ? BarEditManager.dropSize : 0
                    Behavior on _cGapBefore {
                        NumberAnimation {
                            duration: Appearance.anim.durations.small
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on _cGapAfter {
                        NumberAnimation {
                            duration: Appearance.anim.durations.small
                            easing.type: Easing.OutCubic
                        }
                    }

                    implicitWidth: host.isHorizontal ? (_cGapBefore + childJiggle.implicitWidth + _cGapAfter) : childJiggle.implicitWidth
                    implicitHeight: host.isHorizontal ? childJiggle.implicitHeight : (_cGapBefore + childJiggle.implicitHeight + _cGapAfter)

                    HoverHandler {
                        id: childHover
                        enabled: host.editing
                        onHoveredChanged: {
                            if (hovered)
                                bgRect.hoveredChild = childHost.index;
                            else if (bgRect.hoveredChild === childHost.index)
                                bgRect.hoveredChild = -1;
                        }
                    }

                    // Into-group insertion target (before/after this child).
                    DropArea {
                        anchors.fill: parent
                        enabled: host.editing && host.dragActive
                        keys: ["application/x-pshell-widget"]
                        onPositionChanged: drag => {
                            const before = host.isHorizontal ? (drag.x < width / 2) : (drag.y < height / 2);
                            BarEditManager.setDropTarget(host.seg, [host.index, before ? childHost.index : childHost.index + 1]);
                        }
                        onDropped: drag => drag.acceptProposedAction()
                    }

                    EditJiggle {
                        id: childJiggle
                        x: host.isHorizontal ? childHost._cGapBefore : (childHost.width - childJiggle.implicitWidth) / 2
                        y: host.isHorizontal ? (childHost.height - childJiggle.implicitHeight) / 2 : childHost._cGapBefore
                        active: host.editing && !!childHost.modelData && childHost.modelData.type === "widget"
                        seed: childHost.index + 3
                        opacity: BarEditManager.isDragging(host.seg, [host.index, childHost.index]) ? 0.35 : 1
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.durations.small
                            }
                        }

                        Loader {
                            id: childLoader
                            active: !!childHost.modelData && !!childHost.modelData.name
                            source: active ? Qt.resolvedUrl("../components/" + childHost.modelData.name + ".qml") : ""
                            onLoaded: if (item && item.hasOwnProperty("screen")) item.screen = host.screen
                        }
                    }

                    // Drag a single child out of the group (on top of content).
                    MouseArea {
                        id: childDrag
                        anchors.fill: childJiggle
                        enabled: host.editing
                        cursorShape: enabled ? Qt.OpenHandCursor : Qt.ArrowCursor
                        drag.target: childDragGhost
                        readonly property bool _dragArmed: drag.active
                        on_DragArmedChanged: {
                            if (!_dragArmed || childDragGhost.Drag.active)
                                return;
                            const seg = host.seg;
                            const gi = host.index;
                            const ci = childHost.index;
                            const md = childHost.modelData;
                            const size = host.isHorizontal ? childJiggle.implicitWidth : childJiggle.implicitHeight;
                            if (gi < 0 || ci < 0 || !seg)
                                return; // stale/recycling delegate
                            childLoader.grabToImage(result => {
                                if (!childDrag.drag.active)
                                    return;
                                childDragGhost.Drag.imageSource = result.url;
                                BarEditManager.beginEntryDrag(seg, [gi, ci], md, size);
                                childDragGhost.Drag.active = true;
                            });
                        }
                    }

                    Item {
                        id: childDragGhost
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.MoveAction
                        Drag.proposedAction: Qt.MoveAction
                        Drag.mimeData: ({ "application/x-pshell-widget": "1" })
                        Drag.onDragFinished: dropAction => BarEditManager.finishDrag(dropAction === Qt.MoveAction)
                    }

                    // Per-child delete badge (revealed on child hover)
                    EditBadge {
                        visible: host.editing && childHover.hovered
                        anchors.horizontalCenter: childJiggle.right
                        anchors.verticalCenter: childJiggle.top
                        z: 10
                        onClicked: BarEditManager.removeEntry(host.seg, [host.index, childHost.index])
                    }
                }
            }
        }
    }

    // Shared drag ghost for the top-level entry (widget or whole group).
    Item {
        id: dragGhost
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.mimeData: ({ "application/x-pshell-widget": "1" })
        Drag.onDragFinished: dropAction => BarEditManager.finishDrag(dropAction === Qt.MoveAction)
    }

    // Single-widget drag handle (on top of the widget content).
    MouseArea {
        id: widgetDrag
        anchors.fill: widgetJiggle
        enabled: host.editing && host.isWidget
        cursorShape: enabled ? Qt.OpenHandCursor : Qt.ArrowCursor
        drag.target: dragGhost
        readonly property bool _dragArmed: drag.active
        on_DragArmedChanged: {
            if (!_dragArmed || dragGhost.Drag.active)
                return;
            const seg = host.seg;
            const idx = host.index;
            const md = host.modelData;
            const size = host.isHorizontal ? host._contentW : host._contentH;
            if (idx < 0 || !seg)
                return; // stale/recycling delegate
            mainLoader.grabToImage(result => {
                if (!widgetDrag.drag.active)
                    return;
                dragGhost.Drag.imageSource = result.url;
                BarEditManager.beginEntryDrag(seg, [idx], md, size);
                dragGhost.Drag.active = true;
            });
        }
    }

    // Group-with highlight: ring around this widget when a dragged widget is
    // hovering its centre (it will fold into a new group on drop).
    StyledRect {
        visible: host._groupFocus && BarEditManager.dropOntoReady
        x: host._contentX - 3
        y: host._contentY - 3
        width: host._contentW + 6
        height: host._contentH + 6
        radius: Appearance.rounding.normal
        color: Colours.palette.primary
        opacity: 0.18
        z: 5

        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: Colours.palette.primary
        }
    }

    // 3. Delete badge for the top-level entry (widget or whole group).
    //    For a group it only shows while hovering the group but not a child,
    //    so it never collides with the per-child badges.
    EditBadge {
        visible: host.editing && hostHover.hovered && (host.isWidget || (host.isGroup && bgRect.hoveredChild === -1))
        anchors.horizontalCenter: host.isWidget ? widgetJiggle.right : bgRect.right
        anchors.verticalCenter: host.isWidget ? widgetJiggle.top : bgRect.top
        z: 20
        onClicked: BarEditManager.removeEntry(host.seg, [host.index])
    }
}
