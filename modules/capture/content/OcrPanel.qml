pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Caelestia.Blobs
import QtQuick

// Inline OCR preview: lives INSIDE the region editor, so the selection frame
// stays adjustable while the recognised text is on screen — moving/resizing
// the frame reruns recognition on release, switching the language reruns it
// on the kept crop. Placed into the roomiest side strip around the selection,
// clear of the toolbar ring; fades while the frame is being dragged.
Item {
    id: root

    required property var editor
    required property real clearance
    // Toolbar's OCR button rect — the panel blob grows out of it.
    required property rect buttonRect

    anchors.fill: parent
    visible: editor.ocrOpen

    readonly property real boxW: Appearance.font.size.normal * 34
    readonly property real panelW: boxW + Appearance.padding.large * 2
    readonly property real panelH: col.implicitHeight + Appearance.padding.large * 2

    opacity: editor.interacting ? 0.4 : 1

    Behavior on opacity {
        Anim {}
    }

    readonly property var place: {
        const m = Appearance.spacing.medium;
        const c = clearance + m;
        const e = editor;
        const side = [
            { s: "bottom", v: e.height - (e.selY + e.selH) },
            { s: "top", v: e.selY },
            { s: "right", v: e.width - (e.selX + e.selW) },
            { s: "left", v: e.selX }
        ].sort((a, b) => b.v - a.v)[0].s;
        let x = e.selX + e.selW / 2 - panelW / 2;
        let y = e.selY + e.selH / 2 - panelH / 2;
        if (side === "bottom")
            y = e.selY + e.selH + c;
        else if (side === "top")
            y = e.selY - c - panelH;
        else if (side === "right")
            x = e.selX + e.selW + c;
        else
            x = e.selX - c - panelW;
        x = Math.max(m, Math.min(e.width - panelW - m, x));
        y = Math.max(m, Math.min(e.height - panelH - m, y));
        return { x, y };
    }

    // Animated resting position: relocations (frame adjusted → roomier side)
    // glide, and the liquid blob below stretches with the motion.
    property real px: place.x
    property real py: place.y

    // Grow out of the OCR button on open: the blob's real geometry morphs
    // from the button rect to the panel rect.
    property real growT: 1
    property var fromRect: ({ x: 0, y: 0, w: 1, h: 1 })

    readonly property real vx: fromRect.x + (px - fromRect.x) * growT
    readonly property real vy: fromRect.y + (py - fromRect.y) * growT
    readonly property real vw: fromRect.w + (panelW - fromRect.w) * growT
    readonly property real vh: fromRect.h + (panelH - fromRect.h) * growT

    Connections {
        target: root.editor

        function onOcrOpenChanged(): void {
            if (root.editor.ocrOpen) {
                const b = root.buttonRect;
                root.fromRect = { x: b.x, y: b.y, w: b.width, h: b.height };
                root.growT = 0;
                growAnim.restart();
            }
        }
    }

    Anim {
        id: growAnim

        target: root
        property: "growT"
        from: 0
        to: 1
        duration: Appearance.anim.durations.large
        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
    }

    Behavior on px {
        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on py {
        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    // Liquid blob background — same SDF renderer as the shell panels.
    BlobGroup {
        id: ocrGroup

        color: Colours.tPalette.surface_container
        smoothing: 32
    }

    BlobRect {
        id: ocrBlob

        group: ocrGroup
        x: root.vx
        y: root.vy
        width: Math.max(1, root.vw)
        height: Math.max(1, root.vh)
        radius: Appearance.rounding.large
        deformScale: Liquid.deformScale
        stiffness: Liquid.deformStiffness
        damping: Liquid.deformDamping
        deformAtten: Liquid.deformSizeScale(root.panelW, root.panelH)
    }

    Item {
        id: contentBox

        x: root.vx
        y: root.vy
        width: root.panelW
        height: root.panelH
        scale: root.vw / Math.max(1, root.panelW)
        transformOrigin: Item.TopLeft
        opacity: Math.min(1, root.growT * 2)

        // Mirror the blob's velocity deform onto the content.
        transform: Matrix4x4 {
            matrix: ocrBlob.deformMatrix
        }

        // Swallow clicks so they don't start a selection drag through the panel.
        MouseArea {
            anchors.fill: parent
        }

    Column {
        id: col

        anchors.centerIn: parent
        spacing: Appearance.spacing.medium
        width: root.boxW

        // ── Header: icon chip + title/status + actions ──────────────
        Item {
            width: parent.width
            implicitHeight: iconChip.implicitHeight

            StyledRect {
                id: iconChip

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Appearance.font.size.large + Appearance.padding.large * 2
                implicitHeight: implicitWidth
                radius: Appearance.rounding.full
                color: Colours.palette.primary_container

                StyledIcon {
                    anchors.centerIn: parent
                    text: "" // text-recognition
                    color: Colours.palette.on_primary_container
                }
            }

            Column {
                anchors.left: iconChip.right
                anchors.leftMargin: Appearance.spacing.medium
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: "Text recognition"
                    font.pointSize: Appearance.font.size.larger
                    font.weight: Font.DemiBold
                    color: Colours.palette.on_surface
                }

                StyledText {
                    text: root.editor.ocrRunning ? "Recognizing…" : (root.editor.ocrText !== "" ? "Copied to clipboard" : "No text found")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.on_surface_variant
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.small / 2

                IconButton {
                    type: IconButton.Text
                    icon: "" // copy
                    disabled: root.editor.ocrRunning || root.editor.ocrText === ""
                    onClicked: Capture.copyTextNotify(root.editor.ocrText, "Text copied")
                }

                IconButton {
                    type: IconButton.Text
                    icon: "" // x
                    onClicked: root.editor.ocrOpen = false
                }
            }
        }

        // ── Language quick-toggle: Все / each installed language ────
        Row {
            spacing: Appearance.spacing.small

            Repeater {
                model: [""].concat(Capture.ocrLangsAvailable)

                StyledRect {
                    id: chip

                    required property string modelData

                    readonly property bool active: root.editor.ocrLangsSel === modelData

                    implicitWidth: chipText.implicitWidth + Appearance.padding.medium * 2
                    implicitHeight: chipText.implicitHeight + Appearance.padding.small * 2
                    radius: Appearance.rounding.full
                    color: active ? Colours.palette.primary : Colours.palette.surface_container_high

                    StyledText {
                        id: chipText

                        anchors.centerIn: parent
                        text: chip.modelData === "" ? "All" : chip.modelData
                        color: chip.active ? Colours.palette.on_primary : Colours.palette.on_surface_variant
                    }

                    StateLayer {
                        color: chip.active ? Colours.palette.on_primary : Colours.palette.on_surface

                        function onClicked(): void {
                            root.editor.selectOcrLangs(chip.modelData);
                        }
                    }
                }
            }
        }

        // ── Recognised text (selectable; keeps the old text while a
        //    rerun is in flight so the panel doesn't flicker) ─────────
        StyledRect {
            width: parent.width
            radius: Appearance.rounding.large
            color: Colours.palette.surface_container_low
            implicitHeight: Math.min(root.editor.height * 0.4, flick.contentHeight + Appearance.padding.medium * 2)

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: Appearance.padding.medium
                clip: true
                contentWidth: width
                contentHeight: ocrEdit.height
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: ocrEdit

                    width: flick.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: root.editor.ocrText !== "" ? root.editor.ocrText : (root.editor.ocrRunning ? "…" : "(empty)")
                    color: root.editor.ocrText !== "" ? Colours.palette.on_surface : Colours.palette.on_surface_variant
                    selectionColor: Colours.palette.primary
                    selectedTextColor: Colours.palette.on_primary
                    font.family: Appearance.font.family.sans
                    font.pointSize: Appearance.font.size.normal
                }
            }
        }
    }
    }
}
