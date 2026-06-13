pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Fullscreen capture shell for the focused output. Freezes the screen
// (ScreencopyView immediately, exact grim pixels once grabbed) and hosts the
// current mode, cycled with Tab and shown in the cursor bubble:
//   region — flameshot-style editor (RegionEditor): select → all tools at once.
//   color  — magnifier loupe (ColorLoupe) → click → pick.
//   window — instant handoff to niri's pick-window (it knows tiled geometry).
// The hardware cursor is hidden while aiming (it lives on the compositor's
// zero-latency cursor plane and would drift ahead of scene-graph visuals);
// the crosshair marker below is the pointer instead.
PanelWindow {
    id: root

    signal dismissed()
    signal requestWindow()
    // Recording: this output + local logical selection rect (the audio
    // chooser lives in the top rails panel; recording starts there).
    signal requestRecord(string screenName, real x, real y, real w, real h)
    // Lens: physical-px crop request + the grab to crop from.
    signal requestLens(string src, real x, real y, real w, real h)

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

    // grim -o writes physical pixels; our coords are logical. The grab path is
    // stamped per open so Qt's image caches can never serve a stale frame.
    readonly property real outputScale: Niri.monitorFor(root.screen)?.logical?.scale ?? 1
    readonly property int physW: Math.round(width * outputScale)
    readonly property int physH: Math.round(height * outputScale)
    readonly property string grabStamp: Date.now().toString()
    // PPM: lossless like PNG, but grim skips the encode that dominates open latency.
    readonly property string srcPath: `${Capture.tempDir}/src-${root.screen.name}-${grabStamp}.ppm`

    // Visuals appear only once grim has captured the clean output.
    property bool ready: false

    readonly property Item modeItem: mode === "region" ? regionLoader.item : mode === "color" ? colorLoader.item : null

    function modeGlyph(m: string): string {
        return m === "region" ? ""   // scissors
             : m === "color" ? ""    // color-picker
             : "";                   // app-window
    }

    function modeLabel(m: string): string {
        return m === "region" ? "Region"
             : m === "color" ? "Color"
             : "Window";
    }

    // Enter/Space: confirm the current mode's result and close. Guarded
    // against text entry (annotation TextEdit holds focus and consumes keys
    // itself; the colour value field reports textEditing).
    function confirmAction(): void {
        if (mode === "color") {
            const c = colorLoader.item;
            if (!c || c.textEditing)
                return;
            c.confirmCopy();
            dismissed();
        } else if (mode === "region") {
            const ed = regionLoader.item;
            if (!ed || ed.editingObj >= 0)
                return;
            if (ed.ocrOpen) {
                if (ed.ocrText !== "")
                    Capture.copyTextNotify(ed.ocrText, "Text copied");
                dismissed();
            } else {
                ed.commit(true);
            }
        }
    }

    function cycleMode(): void {
        const i = modes.indexOf(mode);
        const next = modes[(i + 1) % modes.length];
        if (next === "window") {
            // Window pick is an instant handoff to niri, not an overlay state.
            root.requestWindow();
            return;
        }
        mode = next;
    }

    Process {
        id: grabProc

        running: true
        command: Capture.grabOutputCommand(root.screen.name, root.srcPath)
        onExited: root.ready = true
    }

    Component.onCompleted: {
        // niri doesn't send wl_pointer.enter to a freshly mapped layer until
        // the pointer moves, so the crosshair/loupe/bubble would stay hidden
        // until the user wiggles the mouse. A ±1px virtual-pointer nudge
        // forces a focus recompute and delivers the position immediately.
        Quickshell.execDetached([`${Quickshell.configDir}/scripts/capture_nudge.py`]);
    }

    Item {
        id: keyRoot

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const ed = root.mode === "region" ? regionLoader.item : null;
            if (event.key === Qt.Key_Escape) {
                // Both modes expose handleEscape (panel → palette → tool → …).
                const mi = root.modeItem;
                if (!mi || !mi.handleEscape())
                    root.dismissed();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                // Don't drop an existing selection by accident.
                if (!(ed && ed.hasSelection))
                    root.cycleMode();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.confirmAction();
                event.accepted = true;
            } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                ed?.commit(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                ed?.commit(false);
                event.accepted = true;
            } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
                if (event.modifiers & Qt.ShiftModifier)
                    ed?.redo();
                else
                    ed?.undo();
                event.accepted = true;
            } else if (event.key === Qt.Key_Y && (event.modifiers & Qt.ControlModifier)) {
                ed?.redo();
                event.accepted = true;
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                ed?.deleteSelected();
                event.accepted = true;
            }
        }

        // Frozen screen: instant compositor copy, then the exact grab pixels.
        ScreencopyView {
            anchors.fill: parent
            live: false
            captureSource: root.screen
        }

        // Exact grab pixels over the (identical) ScreencopyView. Async decode:
        // the copy view covers any not-yet-decoded frames, and the stamped
        // srcPath makes Qt's image cache safe, so loupe/composite reuse this
        // decode for free.
        Image {
            id: base

            anchors.fill: parent
            source: root.ready ? "file://" + root.srcPath : ""
            asynchronous: true
        }

        Loader {
            id: regionLoader

            anchors.fill: parent
            active: root.mode === "region"

            sourceComponent: RegionEditor {
                outputScale: root.outputScale
                physW: root.physW
                physH: root.physH
                srcPath: root.srcPath
                srcReady: root.ready
                baseItem: base
                keyTarget: keyRoot
                outPath: Capture.annotatedPng(root.screen.name)
                ocrPath: Capture.ocrPng(root.screen.name)
                onDismissed: root.dismissed()
                onRecordRequested: (x, y, w, h) => root.requestRecord(root.screen.name, x, y, w, h)
                onLensRequested: (x, y, w, h) => root.requestLens(root.srcPath, x, y, w, h)
            }
        }

        Loader {
            id: colorLoader

            anchors.fill: parent
            active: root.mode === "color"

            sourceComponent: ColorLoupe {
                outputScale: root.outputScale
                physW: root.physW
                physH: root.physH
                srcPath: root.srcPath
                srcReady: root.ready
            }
        }

        // ── Crosshair marker: the visible pointer while aiming ──────
        Item {
            readonly property Item m: root.modeItem

            visible: root.ready && m !== null && m.hovered && m.aiming
            x: m ? m.cursorX : 0
            y: m ? m.cursorY : 0

            Rectangle {
                readonly property int d: Config.capture.markerSize

                x: -d / 2
                y: -d / 2
                width: d
                height: d
                radius: d / 2
                color: "transparent"
                border.width: 1
                border.color: Colours.palette.primary
            }

            Rectangle {
                x: -1
                y: -1
                width: 2
                height: 2
                color: Colours.palette.on_surface
            }
        }

        // ── Cursor bubble (current mode) ────────────────────────────
        // Detached from the pointer: the position binding is the target and a
        // loose spring chases it, so the drop dangles around the cursor
        // instead of being glued to it.
        CursorGuide {
            id: guide

            readonly property Item m: root.modeItem

            // The spring goes live one tick AFTER the bubble is shown: on the
            // very event that reveals it (pointer enter) both the position and
            // visibility bindings update in unspecified order, so an
            // enabled-while-visible Behavior could still animate from the
            // stale spot. With the tick delay the bubble always materialises
            // at the cursor, then starts dangling.
            property bool springLive: false

            onVisibleChanged: {
                if (visible)
                    Qt.callLater(() => guide.springLive = true);
                else
                    springLive = false;
            }

            visible: root.ready && m !== null && m.hovered && !m.interacting && (root.mode !== "region" || !(regionLoader.item?.hasSelection ?? false))
            glyph: root.modeGlyph(root.mode)
            description: root.modeLabel(root.mode)
            x: Math.min((m ? m.cursorX : 0) + Appearance.spacing.large, root.width - width - Appearance.padding.normal)
            y: Math.min((m ? m.cursorY : 0) + Appearance.spacing.large, root.height - height - Appearance.padding.normal)

            Behavior on x {
                enabled: guide.springLive

                SpringAnimation {
                    spring: Config.capture.guideSpring
                    damping: Config.capture.guideDamping
                }
            }

            Behavior on y {
                enabled: guide.springLive

                SpringAnimation {
                    spring: Config.capture.guideSpring
                    damping: Config.capture.guideDamping
                }
            }
        }
    }
}
