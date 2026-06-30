pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import qs.components.controls

Item {
    id: del

    required property Item stash
    required property Item sender

    required property int index
    required property string fileURL
    required property string filePath
    required property string fileName
    required property bool isFav

    readonly property string _ext: fileName.includes('.') ? fileName.split('.').pop().toLowerCase() : ""

    readonly property bool isImage:   ["png","jpg","jpeg","gif","webp","bmp","svg"].includes(_ext)
    readonly property bool isPdf:     _ext === "pdf"
    readonly property bool isVideo:   ["mp4","mkv","avi","mov","webm"].includes(_ext)
    readonly property bool isAudio:   ["mp3","wav","flac","ogg","aac","m4a"].includes(_ext)
    readonly property bool isText:    ["txt","md","log","csv","json","xml","toml","yaml","yml","sh","py","js","ts","rs","go","cpp","c","h"].includes(_ext)
    readonly property bool isArchive: ["zip","tar","gz","bz2","xz","rar","7z"].includes(_ext)

    // Thumb cache: stable name based on sanitised filename
    readonly property string _thumbBase: "/tmp/qs_stash_" + fileName.replace(/[^a-zA-Z0-9-]/g, "_")
    readonly property string _thumbPath: _thumbBase + ".png"

    property string _genThumbPath: ""
    readonly property bool hasThumb: isImage || _genThumbPath !== ""
    readonly property string thumbSource: isImage ? fileURL : (_genThumbPath !== "" ? "file://" + _genThumbPath : "")

    readonly property string themeIcon: {
        if (isImage)   return "image-x-generic"
        if (isPdf)     return "application-pdf"
        if (isVideo)   return "video-x-generic"
        if (isAudio)   return "audio-x-generic"
        if (isText)    return "text-x-generic"
        if (isArchive) return "application-x-archive"
        return "application-x-generic"
    }

    Component.onCompleted: {
        if (isPdf || isVideo) checkThumb.running = true
    }

    Process {
        id: checkThumb
        command: ["test", "-f", del._thumbPath]
        onExited: (code, status) => {
            if (code === 0) del._genThumbPath = del._thumbPath
            else if (del.isPdf)   pdfThumb.running = true
            else if (del.isVideo) vidThumb.running = true
        }
    }

    Process {
        id: pdfThumb
        command: ["bash", "-c", "pdftoppm -r 80 -singlefile -png -l 1 '" + del.filePath + "' '" + del._thumbBase + "'"]
        onExited: (code, status) => { if (code === 0) del._genThumbPath = del._thumbPath }
    }

    Process {
        id: vidThumb
        command: ["bash", "-c", "ffmpegthumbnailer -i '" + del.filePath + "' -o '" + del._thumbPath + "' -s 200 -q 8 2>/dev/null"]
        onExited: (code, status) => { if (code === 0) del._genThumbPath = del._thumbPath }
    }

    MouseArea {
        id: tile
        anchors.fill: parent
        anchors.margins: 4
        drag.target: dragItem
        hoverEnabled: true

        // Native (file-manager-style) drag-out. We deliberately do NOT bind
        // dragItem's Drag.active to drag.active: with Drag.Automatic that
        // binding is re-entrant — starting the native drag drops the
        // MouseArea grab, so drag.active flips back and the binding re-runs
        // *inside* QDrag::exec, churning and freeing the QMimeData mid-drag
        // (the segfault was in QMimeData::hasImage()). Instead we start the
        // drag imperatively, exactly once, when the threshold is crossed.
        readonly property bool _dragArmed: drag.active
        on_DragArmedChanged: {
            if (!_dragArmed || dragItem.Drag.active)
                return;
            // Grab the tile (thumbnail/icon + name) into an image so the drag
            // carries a file preview under the cursor, then flip Drag.active
            // — the order Qt's Drag.Automatic recipe prescribes.
            surface.grabToImage(result => {
                if (!tile.drag.active)
                    return;   // released before the grab landed
                dragItem.Drag.imageSource = result.url;
                dragItem.Drag.active = true;
            });
        }

        // Outer clipped surface — rounded corners actually clip the image
        // and the gradient overlay (Rectangle's `clip: true` is rectangular;
        // ClippingRectangle masks to its rounded shape).
        StyledClippingRect {
            id: surface
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Colours.tPalette.surface_container

            // System theme icon underneath — always present, gets faded out
            // when the thumbnail becomes ready.
            IconImage {
                id: sysIcon
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // Nudge up so the rendered icon leaves room at the bottom
                // for the filename label without crowding it.
                anchors.verticalCenterOffset: -Appearance.padding.normal
                width: Math.min(parent.width, parent.height) * 0.66
                height: width
                source: Quickshell.iconPath(del.themeIcon, "application-x-generic")
                asynchronous: true
                opacity: thumb.opacity < 1 ? 1 : 0
                Behavior on opacity { Anim {} }
            }

            // Thumbnail (images / generated PDF+video thumbs).
            Image {
                id: thumb
                anchors.fill: parent
                source: del.thumbSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: del.hasThumb && status === Image.Ready ? 1 : 0
                Behavior on opacity { Anim {} }
            }

            // Gradient overlay — fades transparent → dark from top to bottom.
            // Only painted while a thumb exists; opacity tied to hover so it
            // animates in/out as the cursor moves between files (Anim = the
            // project's standard 400 ms fade).
            Rectangle {
                anchors.fill: parent
                visible: del.hasThumb
                opacity: tile.containsMouse ? 1 : 0
                Behavior on opacity { Anim {} }
                gradient: Gradient {
                    GradientStop { position: 0.2; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                }
            }

            // Filename label.
            // - With thumb: shown only on hover, white text over the gradient.
            // - Without thumb: always visible, low-contrast text on the
            //   icon-only background.
            StyledText {
                id: nameLabel
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: Appearance.padding.small
                    rightMargin: Appearance.padding.small
                    bottomMargin: Appearance.padding.small
                }
                text: del.fileName
                color: del.hasThumb ? "white" : Colours.palette.on_surface_variant
                font.pointSize: Appearance.font.size.smaller
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                opacity: del.hasThumb ? (tile.containsMouse ? 1 : 0) : 1
                Behavior on opacity { Anim {} }
            }
        }

        Item {
            id: dragItem
            anchors.fill: parent
            // Drag.active is set imperatively from tile.on_DragArmedChanged —
            // see the comment there for why it must NOT be a live binding.
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.proposedAction: Qt.CopyAction
            Drag.mimeData: { "text/uri-list": del.fileURL }

            // Pin the panel open for the whole native drag. Without this the
            // cursor leaving the tray trips the hover auto-hide, which
            // unloads this delegate (and its QMimeData) mid-drag — the
            // compositor then asks the freed source for the data and the
            // shell segfaults in QMimeData::hasImage().
            Drag.onDragStarted:  del.stash.noteOutgoingDrag(true)
            Drag.onDragFinished: del.stash.noteOutgoingDrag(false)
        }

        // ── Action buttons ─────────────────────────────────────────
        // A single MouseArea owns hover + clicks for the whole strip.
        // Nested MouseAreas inside IconButton/StateLayer were eating the
        // hover events we needed (the trash-hover trigger never fired),
        // so the three "buttons" are now pure visuals (StyledRect + glyph)
        // and the wrapper MouseArea dispatches the click based on
        // `mouseX` against the trash / send / bookmark sub-zones.
        Item {
            id: actions
            anchors.top: surface.top
            anchors.right: surface.right
            width: actions.btnSize +
                   (actions.trashHovered
                        ? (actions.btnSize + actions.btnSize + actions.spacing * 2)
                        : 0)
            height: actions.btnSize

            property int spacing: Appearance.spacing.small
            property int btnRadius: Appearance.rounding.small
            property int btnSize: 26

            property bool fileHovered: tile.containsMouse
            // Hysteresis: entering the trash zone (rightmost `btnSize` px)
            // latches `_expanded` true, and it stays true until the cursor
            // leaves the actions strip entirely. Lets the user move freely
            // across the gap between buttons without the strip collapsing.
            property bool _expanded: false
            property bool trashHovered: actions.fileHovered && actions._expanded

            // Trash visual (rightmost) — scales 0.5 → 1.0 on trash-hover.
            StyledRect {
                id: trashBtn
                width: actions.btnSize
                height: actions.btnSize
                anchors.right: parent.right
                anchors.top: parent.top
                radius: actions.btnRadius
                color: Colours.palette.secondary_container
                transformOrigin: Item.Center

                opacity: actions.fileHovered ? 1 : 0
                scale: actions.trashHovered ? 1 : 0.5

                Behavior on opacity { Anim {} }
                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.durations.small
                        easing.type: Easing.OutCubic
                    }
                }

                StyledIcon {
                    anchors.centerIn: parent
                    text: "\ueb41"
                    color: Colours.palette.on_secondary_container
                    font.pointSize: Appearance.font.size.smaller
                }
            }

            // Send visual — slides in from behind trash with a small delay.
            StyledRect {
                id: sendBtn
                visible: Config.stash.localsendEnabled
                width: actions.btnSize
                height: actions.btnSize
                anchors.right: trashBtn.left
                anchors.rightMargin: actions.spacing
                anchors.top: parent.top
                radius: actions.btnRadius
                color: Colours.palette.primary

                // slideOffset is driven imperatively by `slideInAnim` below
                // so that the slide only happens on expansion (from behind
                // trash → 0). On collapse the button stays put while opacity
                // + scale fade it out, instead of zipping back behind trash.
                property real slideOffset: 0
                transform: Translate { x: sendBtn.slideOffset }

                opacity: actions.trashHovered ? 1 : 0
                scale: actions.trashHovered ? 1 : 0.5
                transformOrigin: Item.Center

                SequentialAnimation {
                    id: sendBtnSlideIn
                    PauseAnimation { duration: Appearance.anim.durations.smaller }
                    NumberAnimation {
                        target: sendBtn
                        property: "slideOffset"
                        from: actions.btnSize + actions.spacing
                        to: 0
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.bubblyMove
                    }
                }
                Connections {
                    target: actions
                    function onTrashHoveredChanged() {
                        if (actions.trashHovered) sendBtnSlideIn.restart()
                        else                     sendBtnSlideIn.stop()
                    }
                }
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: actions.trashHovered
                                ? Appearance.anim.durations.smaller
                                : 0
                        }
                        NumberAnimation { duration: Appearance.anim.durations.small }
                    }
                }
                Behavior on scale {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: actions.trashHovered
                                ? Appearance.anim.durations.smaller
                                : 0
                        }
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.bubblyMove
                        }
                    }
                }

                StyledIcon {
                    anchors.centerIn: parent
                    text: "\ueb21"
                    color: Colours.palette.on_primary
                    font.pointSize: Appearance.font.size.smaller
                }
            }

            // Bookmark visual — leftmost, longer delay.
            StyledRect {
                id: bookmarkBtn
                width: actions.btnSize
                height: actions.btnSize
                anchors.right: sendBtn.left
                anchors.rightMargin: actions.spacing
                anchors.top: parent.top
                radius: actions.btnRadius
                color: Colours.palette.secondary_container

                // Same imperative slide-in story as sendBtn — keeps it in
                // place on collapse so it doesn't tunnel back behind trash.
                property real slideOffset: 0
                transform: Translate { x: bookmarkBtn.slideOffset }

                opacity: actions.trashHovered ? 1 : 0
                scale: actions.trashHovered ? 1 : 0.5
                transformOrigin: Item.Center

                SequentialAnimation {
                    id: bookmarkBtnSlideIn
                    PauseAnimation { duration: Appearance.anim.durations.small }
                    NumberAnimation {
                        target: bookmarkBtn
                        property: "slideOffset"
                        from: actions.btnSize * 2 + actions.spacing * 2
                        to: 0
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.bubblyMove
                    }
                }
                Connections {
                    target: actions
                    function onTrashHoveredChanged() {
                        if (actions.trashHovered) bookmarkBtnSlideIn.restart()
                        else                     bookmarkBtnSlideIn.stop()
                    }
                }
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: actions.trashHovered
                                ? Appearance.anim.durations.small
                                : 0
                        }
                        NumberAnimation { duration: Appearance.anim.durations.small }
                    }
                }
                Behavior on scale {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: actions.trashHovered
                                ? Appearance.anim.durations.small
                                : 0
                        }
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.bubblyMove
                        }
                    }
                }

                StyledIcon {
                    anchors.centerIn: parent
                    text: del.isFav ? "\ueced" : "\uea3a"
                    color: Colours.palette.on_secondary_container
                    font.pointSize: Appearance.font.size.smaller
                }
            }

            // Single hover + click sink. Latches `_expanded` once the
            // cursor enters the trash zone; clears it on exit. Click is
            // dispatched by mouseX against the trash / send / bookmark
            // sub-bands. The gap between bands is absorbed into the
            // closest button so a click in a gap still does something.
            MouseArea {
                id: actionsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function inTrashZone() {
                    return containsMouse && mouseX >= actions.width - actions.btnSize
                }

                onPositionChanged: { if (inTrashZone()) actions._expanded = true }
                onEntered:         { if (inTrashZone()) actions._expanded = true }
                onExited:          actions._expanded = false

                onClicked: {
                    if (!actions._expanded) {
                        // Trash-only view — actions.width === btnSize, any
                        // click in the strip means trash.
                        deleteProc.running = true
                        return
                    }
                    // Expanded view: three bands right→left.
                    // Split each gap in half so clicks always land somewhere.
                    const halfGap   = actions.spacing / 2
                    const trashLeft = actions.width - actions.btnSize - halfGap
                    const sendLeft  = actions.width - actions.btnSize * 2 - actions.spacing - halfGap
                    if (mouseX >= trashLeft) {
                        deleteProc.running = true
                    } else if (mouseX >= sendLeft) {
                        if (Config.stash.localsendEnabled)
                            del.sender.openSendPicker(del.filePath)
                    } else {
                        const f = !del.isFav
                        del.stash.model.setProperty(del.index, "isFav", f)
                        del.stash.model.move(del.index, f ? 0 : del.stash.model.count - 1, 1)
                    }
                }
            }
        }

        Process {
            id: deleteProc
            command: ["bash", "-c", "rm -rf '" + del.filePath + "'"]
            onExited: del.stash.refreshStash()
        }
    }
}
