pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Fullscreen capture surface for the focused output. Freezes the screen with a
// ScreencopyView and runs one of three modes, shown in the cursor bubble and
// cycled with Tab:
//   region — drag a rectangle (dim + aim lines + dashed border + W×H) → crop.
//   color  — magnifier loupe (the niri picker has no zoom) → click → pick.
//   window — hand off to niri's pick-window (it knows tiled geometry).
PanelWindow {
    id: root

    signal dismissed()
    signal requestWindow()
    signal picked(int r, int g, int b)

    property string mode: "region"
    readonly property var modes: ["region", "color", "window"]

    color: "transparent"
    WlrLayershell.namespace: "pShell-capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // grim -o writes physical pixels; our coords are logical.
    readonly property real outputScale: Niri.monitorFor(root.screen)?.logical?.scale ?? 1
    readonly property int physW: Math.round(width * outputScale)
    readonly property int physH: Math.round(height * outputScale)
    readonly property string srcPath: Capture.tempPng(root.screen.name)

    // Visuals appear only once grim has captured the clean output.
    property bool ready: false
    readonly property int dimBorder: Math.max(width, height)

    function modeGlyph(m: string): string {
        return m === "region" ? ""   // scissors
             : m === "color" ? ""     // color-picker
             : "";                    // app-window
    }
    function modeLabel(m: string): string {
        return m === "region" ? "Область"
             : m === "color" ? "Цвет"
             : "Окно";
    }
    function cycleMode(): void {
        const i = modes.indexOf(mode);
        mode = modes[(i + 1) % modes.length];
    }

    // ── Region state (logical, window-local px) ─────────────────────
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property bool dragging: false
    readonly property real regionX: Math.min(dragStartX, draggingX)
    readonly property real regionY: Math.min(dragStartY, draggingY)
    readonly property real regionWidth: Math.abs(draggingX - dragStartX)
    readonly property real regionHeight: Math.abs(draggingY - dragStartY)
    readonly property bool hasSelection: mode === "region" && dragging && regionWidth > 0 && regionHeight > 0

    Process {
        id: grabProc
        running: true
        command: Capture.grabOutputCommand(root.screen.name)
        onExited: root.ready = true
    }

    function commitRegion(): void {
        if (regionWidth < 2 || regionHeight < 2) {
            root.dismissed();
            return;
        }
        const x = Math.max(0, regionX);
        const y = Math.max(0, regionY);
        const w = Math.min(regionWidth, root.width - x);
        const h = Math.min(regionHeight, root.height - y);
        const s = root.outputScale;
        Capture.run(Capture.cropCommand(root.srcPath,
            Math.round(x * s), Math.round(y * s), Math.round(w * s), Math.round(h * s)));
        root.dismissed();
    }

    // ── Colour sampling (magick reads a single pixel from the grab) ──
    property var liveColor: null  // { r, g, b }

    function pixelCmd(px: int, py: int): var {
        const cx = Math.max(0, Math.min(px, physW - 1));
        const cy = Math.max(0, Math.min(py, physH - 1));
        return ["bash", "-c", `magick '${Capture.shq(srcPath)}' -depth 8 -crop 1x1+${cx}+${cy} +repage txt:-`];
    }
    function parseHex(text: string): var {
        const m = String(text).match(/#([0-9A-Fa-f]{6})/);
        if (!m)
            return null;
        const h = m[1];
        return { r: parseInt(h.slice(0, 2), 16), g: parseInt(h.slice(2, 4), 16), b: parseInt(h.slice(4, 6), 16) };
    }

    Timer {
        id: liveSampleTimer
        interval: Appearance.anim.durations.smaller
        onTriggered: {
            liveSampleProc.command = root.pixelCmd(Math.round(mouseArea.mouseX * root.outputScale), Math.round(mouseArea.mouseY * root.outputScale));
            liveSampleProc.running = true;
        }
    }
    Process {
        id: liveSampleProc
        stdout: StdioCollector {
            id: liveOut
            onStreamFinished: {
                const c = root.parseHex(liveOut.text);
                if (c)
                    root.liveColor = c;
            }
        }
    }
    Process {
        id: clickSampleProc
        stdout: StdioCollector {
            id: clickOut
            onStreamFinished: {
                const c = root.parseHex(clickOut.text);
                if (c)
                    root.picked(c.r, c.g, c.b);
                root.dismissed();
            }
        }
    }

    // ── Frozen screen + keys ────────────────────────────────────────
    ScreencopyView {
        id: frozen
        anchors.fill: parent
        live: false
        captureSource: root.screen

        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.dismissed();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                root.cycleMode();
                event.accepted = true;
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        // Hide the hardware cursor in region/color: it lives on the compositor's
        // cursor plane (zero-latency) while our aim lines / loupe update through
        // the scene graph, so a visible system cursor appears to drift ahead of
        // them on fast moves. The crosshair / loupe centre IS the pointer.
        cursorShape: root.mode === "window" ? Qt.ArrowCursor : Qt.BlankCursor
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        enabled: root.ready

        onPressed: mouse => {
            if (root.mode === "region") {
                root.dragStartX = mouse.x;
                root.dragStartY = mouse.y;
                root.draggingX = mouse.x;
                root.draggingY = mouse.y;
                root.dragging = true;
            } else if (root.mode === "window") {
                root.requestWindow();
                root.dismissed();
            } else if (root.mode === "color") {
                clickSampleProc.command = root.pixelCmd(Math.round(mouse.x * root.outputScale), Math.round(mouse.y * root.outputScale));
                clickSampleProc.running = true;
            }
        }
        onPositionChanged: mouse => {
            if (root.mode === "region" && root.dragging) {
                root.draggingX = mouse.x;
                root.draggingY = mouse.y;
            } else if (root.mode === "color") {
                liveSampleTimer.restart();
            }
        }
        onReleased: {
            if (root.mode === "region" && root.dragging) {
                root.dragging = false;
                root.commitRegion();
            }
        }

        // ── Region: dim outside the selection ───────────────────────
        StyledRect {
            anchors.fill: parent
            visible: root.ready && root.mode === "region" && !root.hasSelection
            color: Colours.palette.scrim
            opacity: Config.capture.dimStrength
        }
        StyledRect {
            visible: root.ready && root.hasSelection
            x: root.regionX - root.dimBorder
            y: root.regionY - root.dimBorder
            width: root.regionWidth + root.dimBorder * 2
            height: root.regionHeight + root.dimBorder * 2
            color: "transparent"
            border.color: Qt.alpha(Colours.palette.scrim, Config.capture.dimStrength)
            border.width: root.dimBorder
        }

        // ── Region: aim lines ───────────────────────────────────────
        Rectangle {
            visible: root.ready && root.mode === "region" && Config.capture.showAimLines && mouseArea.containsMouse
            x: Math.round(mouseArea.mouseX)
            y: 0
            width: 1
            height: parent.height
            color: Colours.palette.primary
            opacity: 0.4
        }
        Rectangle {
            visible: root.ready && root.mode === "region" && Config.capture.showAimLines && mouseArea.containsMouse
            x: 0
            y: Math.round(mouseArea.mouseY)
            width: parent.width
            height: 1
            color: Colours.palette.primary
            opacity: 0.4
        }

        // ── Region: selection border ────────────────────────────────
        DashedRect {
            visible: root.ready && root.hasSelection
            x: root.regionX
            y: root.regionY
            width: root.regionWidth
            height: root.regionHeight
            strokeColor: Colours.palette.primary
            strokeWidth: Config.capture.dashWidth
            dashLength: Config.capture.dashLength
            gapLength: Config.capture.dashGap
            cornerRadius: Appearance.rounding.small
        }

        // ── Region: W×H readout ─────────────────────────────────────
        StyledRect {
            visible: root.ready && root.hasSelection
            x: Math.min(root.regionX + root.regionWidth - width, root.width - width)
            y: root.regionY + root.regionHeight + Appearance.spacing.small
            implicitWidth: dimsText.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: dimsText.implicitHeight + Appearance.padding.smaller * 2
            radius: Appearance.rounding.small
            color: Colours.palette.surface_container

            StyledText {
                id: dimsText
                anchors.centerIn: parent
                color: Colours.palette.on_surface
                text: `${Math.round(root.regionWidth * root.outputScale)} × ${Math.round(root.regionHeight * root.outputScale)}`
            }
        }

        // ── Colour: magnifier loupe ─────────────────────────────────
        Item {
            id: loupe
            visible: root.ready && root.mode === "color" && mouseArea.containsMouse
            width: Config.capture.loupeSize
            height: width
            x: Math.min(mouseArea.mouseX + Appearance.spacing.large, root.width - width - Appearance.padding.normal)
            // Sit above the cursor so it doesn't collide with the mode bubble.
            y: Math.max(Appearance.padding.normal, mouseArea.mouseY - height - Appearance.spacing.large)

            readonly property int zoom: Config.capture.loupeZoom

            // Zoomed, pixelated view of the grabbed image centred on the cursor.
            Item {
                anchors.fill: parent
                clip: true

                Image {
                    source: root.ready ? "file://" + root.srcPath : ""
                    smooth: false
                    sourceSize.width: root.physW
                    sourceSize.height: root.physH
                    width: root.physW * loupe.zoom
                    height: root.physH * loupe.zoom
                    x: loupe.width / 2 - mouseArea.mouseX * root.outputScale * loupe.zoom
                    y: loupe.height / 2 - mouseArea.mouseY * root.outputScale * loupe.zoom
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
                radius: Appearance.rounding.normal
                color: "transparent"
                border.width: 2
                border.color: Colours.palette.primary
            }

            // Live value chip under the loupe.
            StyledRect {
                id: swatch
                anchors.top: parent.bottom
                anchors.topMargin: Appearance.spacing.small
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.liveColor !== null
                implicitWidth: swatchRow.implicitWidth + Appearance.padding.normal * 2
                implicitHeight: swatchRow.implicitHeight + Appearance.padding.smaller * 2
                radius: Appearance.rounding.full
                color: Colours.palette.surface_container

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

        // ── Cursor bubble (current mode) ────────────────────────────
        CursorGuide {
            id: cursorGuide
            visible: root.ready && mouseArea.containsMouse
            glyph: root.modeGlyph(root.mode)
            description: root.modeLabel(root.mode)
            x: Math.min(mouseArea.mouseX + Appearance.spacing.large, root.width - width - Appearance.padding.normal)
            y: Math.min(mouseArea.mouseY + Appearance.spacing.large, root.height - height - Appearance.padding.normal)
        }
    }
}
