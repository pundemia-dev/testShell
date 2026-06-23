// modules/settings/pages/WidgetPalette.qml
//
// Grid of draggable widget tiles for the bar layout editor. Each tile is a drag
// source (icon + label) that drops a fresh widget into the live bar. Dragging
// is a platform drag (Drag.Automatic) so it crosses from the Settings window
// onto the bar's layershell surface; the bar's drop areas record the target and
// the commit happens in Drag.onDragFinished (see WidgetHost / BarEditManager).
//
// A "Preview" toggle morphs every tile: the icon slides from above the label to
// the left of it (a header), and a LIVE instance of the real widget appears
// below — so a user can see their own custom widget.
//
// Tiles are packed masonry-style: fixed-width columns, each tile dropped into
// the currently-shortest column → dense vertical packing with no row-height
// gaps. Position changes animate (Behavior on x/y), so toggling Preview makes
// the tiles slide into their new slots, passing under each other in transit.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.utils
import qs.components

ColumnLayout {
    id: root

    property bool previewMode: false

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal

    // Header: hint + Preview toggle.
    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Drag a widget onto the bar to add it:")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.on_surface_variant
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        StyledRect {
            id: prevBtn
            implicitWidth: prevLabel.implicitWidth + Appearance.padding.large * 2
            implicitHeight: prevLabel.implicitHeight + Appearance.padding.small * 2
            radius: Appearance.rounding.full
            color: root.previewMode ? Colours.palette.primary : Colours.palette.surface_container_highest

            StyledText {
                id: prevLabel
                anchors.centerIn: parent
                text: qsTr("Preview")
                font.pointSize: Appearance.font.size.small
                color: root.previewMode ? Colours.palette.on_primary : Colours.palette.on_surface_variant
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.previewMode = !root.previewMode
            }
        }
    }

    // Masonry board.
    Item {
        id: board

        Layout.fillWidth: true
        implicitHeight: _packH

        readonly property real gap: Appearance.spacing.normal
        readonly property real colW: 150
        readonly property int cols: Math.max(1, Math.floor((width + gap) / (colW + gap)))

        property var _tiles: []
        property real _packH: 0

        function register(t) {
            _tiles.push(t);
            scheduleRelayout();
        }
        function scheduleRelayout() {
            Qt.callLater(relayout);
        }
        function relayout() {
            if (width <= 0 || _tiles.length === 0)
                return;
            const n = cols;
            const heights = new Array(n).fill(0);
            const usedW = n * colW + (n - 1) * gap;
            const offX = Math.max(0, (width - usedW) / 2);
            for (const t of _tiles) {
                if (!t)
                    continue;
                let c = 0;
                for (let i = 1; i < n; i++)
                    if (heights[i] < heights[c] - 0.5)
                        c = i;
                t.targetX = offX + c * (colW + gap);
                t.targetY = heights[c];
                heights[c] += t.implicitHeight + gap;
            }
            let m = 0;
            for (const h of heights)
                m = Math.max(m, h);
            _packH = Math.max(0, m - gap);
        }

        onWidthChanged: scheduleRelayout()
        onColsChanged: scheduleRelayout()
        Component.onCompleted: relayout()

        Repeater {
            model: BarWidgets.widgets

            delegate: Item {
                id: tile
                required property var modelData
                readonly property bool preview: root.previewMode

                property real targetX: 0
                property real targetY: 0

                readonly property real pad: Appearance.padding.large
                readonly property real sp: Appearance.spacing.small
                readonly property real headerH: Math.max(iconT.implicitHeight, labelT.implicitHeight)

                width: board.colW
                height: implicitHeight
                implicitHeight: (preview ? (headerH + sp + previewBox.height) : (iconT.implicitHeight + sp + labelT.implicitHeight)) + pad * 2

                x: targetX
                y: targetY
                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Component.onCompleted: board.register(tile)
                onImplicitHeightChanged: board.scheduleRelayout()

                StyledRect {
                    id: frame
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: ma.containsMouse ? Colours.palette.surface_container_highest : Colours.palette.surface_container_high
                }

                StyledText {
                    id: iconT
                    text: tile.modelData.icon ?? ""
                    font.family: Appearance.font.family.tabler
                    font.pointSize: Appearance.font.size.large
                    color: Colours.palette.on_surface
                    x: tile.preview ? tile.pad : (tile.width - width) / 2
                    y: tile.pad + (tile.preview ? (tile.headerH - height) / 2 : 0)
                    Behavior on x {
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                StyledText {
                    id: labelT
                    text: tile.modelData.label ?? tile.modelData.name
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.on_surface_variant
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, tile.width - (tile.preview ? (tile.pad * 2 + iconT.implicitWidth + tile.sp) : tile.pad * 2))
                    x: tile.preview ? (tile.pad + iconT.implicitWidth + tile.sp) : (tile.width - width) / 2
                    y: tile.preview ? (tile.pad + (tile.headerH - height) / 2) : (tile.pad + iconT.implicitHeight + tile.sp)
                    Behavior on x {
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Live widget preview (only instantiated while previewing).
                StyledRect {
                    id: previewBox
                    clip: true
                    visible: opacity > 0.01
                    opacity: tile.preview ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.durations.small
                        }
                    }
                    radius: Appearance.rounding.small
                    color: Colours.palette.surface_container_lowest

                    readonly property real _avail: tile.width - tile.pad * 2 - tile.sp * 2
                    readonly property real _scale: (previewLoader.item && previewLoader.implicitWidth > 0) ? Math.min(1, _avail / previewLoader.implicitWidth) : 1

                    width: tile.width - tile.pad * 2
                    implicitHeight: (previewLoader.item ? previewLoader.implicitHeight * _scale : 24) + tile.sp * 2
                    height: implicitHeight
                    x: tile.pad
                    y: tile.pad + tile.headerH + tile.sp

                    Loader {
                        id: previewLoader
                        anchors.centerIn: parent
                        active: tile.preview
                        enabled: false // visual only — the tile owns the drag
                        scale: previewBox._scale
                        transformOrigin: Item.Center
                        source: active ? Qt.resolvedUrl("../../bar/content/components/" + tile.modelData.name + ".qml") : ""
                        onLoaded: if (item && item.hasOwnProperty("screen"))
                            item.screen = QsWindow.window ? QsWindow.window.screen : null
                    }
                }

                // Hidden, full-size instance of the real widget, used purely to
                // render the drag-cursor image (so dragging from the palette
                // attaches the actual widget, like an in-bar drag). Parked far
                // off-screen at its natural size so it renders normally (and is
                // grabbable) without ever being seen. Loads on hover so it's
                // ready by the time the drag starts.
                Loader {
                    id: grabLoader
                    x: -100000
                    active: ma.containsMouse || tile.preview
                    source: active ? Qt.resolvedUrl("../../bar/content/components/" + tile.modelData.name + ".qml") : ""
                    onLoaded: if (item && item.hasOwnProperty("screen"))
                        item.screen = QsWindow.window ? QsWindow.window.screen : null
                }

                // Platform-drag carrier.
                Item {
                    id: ghost
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.MoveAction
                    Drag.proposedAction: Qt.MoveAction
                    Drag.mimeData: ({ "application/x-pshell-widget": "1" })
                    Drag.onDragFinished: dropAction => BarEditManager.finishDrag(dropAction === Qt.MoveAction)
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.OpenHandCursor
                    drag.target: ghost
                    readonly property bool _dragArmed: drag.active
                    on_DragArmedChanged: {
                        if (!_dragArmed || ghost.Drag.active)
                            return;
                        const entry = { "type": "widget", "name": tile.modelData.name };
                        const size = Config.bar.thickness.all ?? 44;
                        // Grab the real widget for the cursor image (like an
                        // in-bar drag); fall back to the tile if it isn't loaded.
                        const grabTarget = grabLoader.item ? grabLoader : frame;
                        grabTarget.grabToImage(result => {
                            if (!ma.drag.active)
                                return;
                            ghost.Drag.imageSource = result.url;
                            // State BEFORE Drag.active (which blocks in the
                            // platform DnD loop until the drag ends).
                            BarEditManager.beginPaletteDrag(entry, size);
                            ghost.Drag.active = true;
                        });
                    }
                }
            }
        }
    }
}
