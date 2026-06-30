pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick

// Colour-pick mode: circular magnifier loupe over the frozen grab (the niri
// picker has no zoom). Pixels are sampled synchronously through a 1×1
// Immediate-mode Canvas — no per-move process spawns, so the live chip has
// zero lag. A click opens the inline ColorPanel (result + format toggle +
// HSL quick editor) without leaving the picker; further clicks re-pick.
Item {
    id: root

    required property real outputScale
    required property int physW
    required property int physH
    required property string srcPath
    required property bool srcReady

    anchors.fill: parent
    visible: srcReady

    function handleEscape(): bool {
        if (panel.open) {
            panel.open = false;
            return true;
        }
        return false;
    }

    // Enter/Space guard: don't confirm while typing in the value field.
    readonly property bool textEditing: panel.fieldFocused

    // Geometry of the live-preview chip (editor-local) — the panel grows
    // out of it on first open.
    function chipRect(): var {
        if (!liveChip.visible)
            return { x: cursorX, y: cursorY, w: 1, h: 1 };
        const p = liveChip.mapToItem(root, 0, 0);
        return { x: p.x, y: p.y, w: liveChip.width, h: liveChip.height };
    }

    // Enter/Space: copy with feedback (picked colour if the panel is open,
    // else the live colour under the cursor); the overlay closes after.
    function confirmCopy(): void {
        if (panel.open) {
            Capture.copyTextNotify(panel.valueText, "Color copied");
        } else if (liveColor) {
            const fmt = panel.initialFmt();
            Capture.copyTextNotify(Capture.formatColor(liveColor.r, liveColor.g, liveColor.b, fmt), "Color copied");
        }
    }

    property real cursorX: 0
    property real cursorY: 0
    readonly property bool hovered: hover.hovered || ma.containsMouse || ma.pressed
    readonly property bool interacting: false
    readonly property bool aiming: true

    property var liveColor: null
    property bool samplerReady: false
    readonly property string imgUrl: "file://" + srcPath

    function sampleAt(lx: real, ly: real): var {
        if (!samplerReady)
            return null;
        const px = Math.max(0, Math.min(Math.round(lx * outputScale), physW - 1));
        const py = Math.max(0, Math.min(Math.round(ly * outputScale), physH - 1));
        const ctx = sampler.getContext("2d");
        if (!ctx)
            return null;
        ctx.clearRect(0, 0, 1, 1);
        ctx.drawImage(imgUrl, px, py, 1, 1, 0, 0, 1, 1);
        const d = ctx.getImageData(0, 0, 1, 1).data;
        return { r: d[0], g: d[1], b: d[2] };
    }

    function refreshLive(): void {
        const c = sampleAt(cursorX, cursorY);
        if (c)
            liveColor = c;
    }

    onSrcReadyChanged: {
        if (srcReady)
            sampler.loadImage(imgUrl);
    }

    Component.onCompleted: {
        if (srcReady)
            sampler.loadImage(imgUrl);
    }

    Canvas {
        id: sampler

        width: 1
        height: 1
        opacity: 0
        renderStrategy: Canvas.Immediate
        renderTarget: Canvas.Image
        onImageLoaded: {
            root.samplerReady = true;
            root.refreshLive();
        }
    }

    HoverHandler {
        id: hover

        onPointChanged: {
            root.cursorX = point.position.x;
            root.cursorY = point.position.y;
            root.refreshLive();
        }
    }

    MouseArea {
        id: ma

        anchors.fill: parent
        cursorShape: Qt.BlankCursor
        acceptedButtons: Qt.LeftButton
        // Seed the loupe from the pointer-enter that arrives when the overlay
        // maps under the cursor, before any motion.
        hoverEnabled: true
        onEntered: {
            root.cursorX = mouseX;
            root.cursorY = mouseY;
            root.refreshLive();
        }
        onPressed: mouse => {
            const c = root.sampleAt(mouse.x, mouse.y);
            if (c)
                panel.show(c.r, c.g, c.b);
        }
    }

    // ── Magnifier loupe (circular) ──────────────────────────────────
    Item {
        id: loupe

        visible: root.hovered && !panel.hovering
        width: Config.capture.loupeSize
        height: width
        x: Math.min(root.cursorX + Appearance.spacing.large, root.width - width - Appearance.padding.normal)
        // Sit above the cursor so it doesn't collide with the mode bubble.
        y: Math.max(Appearance.padding.normal, root.cursorY - height - Appearance.spacing.large)

        readonly property int zoom: Config.capture.loupeZoom

        // Zoomed, pixelated view of the grabbed image centred on the cursor.
        StyledClippingRect {
            anchors.fill: parent
            radius: width / 2

            Image {
                source: root.srcReady ? root.imgUrl : ""
                smooth: false
                sourceSize.width: root.physW
                sourceSize.height: root.physH
                width: root.physW * loupe.zoom
                height: root.physH * loupe.zoom
                x: loupe.width / 2 - root.cursorX * root.outputScale * loupe.zoom
                y: loupe.height / 2 - root.cursorY * root.outputScale * loupe.zoom
            }
        }

        // Centre cell = the pixel that will be picked.
        Rectangle {
            width: loupe.zoom
            height: loupe.zoom
            x: (loupe.width - width) / 2
            y: (loupe.height - height) / 2
            color: "transparent"
            border.width: 1
            border.color: Colours.palette.on_surface
        }

        // Ring.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Colours.palette.primary
        }

        // Live value chip under the loupe.
        StyledRect {
            id: liveChip

            anchors.top: parent.bottom
            anchors.topMargin: Appearance.spacing.small
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.liveColor !== null
            implicitWidth: swatchRow.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: swatchRow.implicitHeight + Appearance.padding.smaller * 2
            radius: Appearance.rounding.full
            color: Colours.tPalette.surface_container

            Row {
                id: swatchRow

                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: hexText.implicitHeight
                    height: width
                    radius: width / 2
                    color: root.liveColor ? Qt.rgba(root.liveColor.r / 255, root.liveColor.g / 255, root.liveColor.b / 255, 1) : "transparent"
                    border.width: 1
                    border.color: Colours.palette.outline_variant
                }

                StyledText {
                    id: hexText

                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Appearance.font.family.mono
                    color: Colours.palette.on_surface
                    text: root.liveColor ? Capture.toHex(root.liveColor.r, root.liveColor.g, root.liveColor.b) : ""
                }
            }
        }
    }

    // ── Picked-colour panel (result + format toggle + HSL editor) ───
    ColorPanel {
        id: panel

        picker: root
    }
}
