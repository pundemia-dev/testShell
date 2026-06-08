pragma ComponentBehavior: Bound

import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import "content"

// Self-contained capture orchestrator (mounted in shell.qml). Owns the single
// IPC handler and routes each action. Region and colour share a per-screen
// overlay (drag select / magnifier loupe); window hands off to niri's
// pick-window (the only thing that knows tiled geometry); screen is a plain grim.
Scope {
    id: root

    // Shared overlay state (region | color). Tab cycles modes inside the overlay.
    property bool overlayOpen: false
    property string overlayMode: "region"

    function focusedScreenName(): string {
        return Niri.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
    }

    function focusedScreen(): var {
        const name = focusedScreenName();
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    // ── Actions ─────────────────────────────────────────────────────
    function openOverlay(m: string): void {
        overlayMode = m;
        overlayOpen = true;
    }

    function region(): void {
        openOverlay("region");
    }

    function color(): void {
        openOverlay("color");
    }

    function dismissOverlay(): void {
        overlayOpen = false;
    }

    function screenshotScreen(): void {
        const name = focusedScreenName();
        if (!name)
            return;
        screenProc.screenName = name;
        screenProc.command = Capture.grabOutputCommand(name);
        screenProc.running = true;
    }

    function window(): void {
        pickWindowProc.running = true;
    }

    // ── Region/colour overlay: one per focused screen ───────────────
    Variants {
        model: Quickshell.screens

        delegate: Loader {
            id: overlayLoader
            required property var modelData
            active: root.overlayOpen && overlayLoader.modelData.name === root.focusedScreenName()

            sourceComponent: CaptureOverlay {
                screen: overlayLoader.modelData
                mode: root.overlayMode
                onDismissed: root.dismissOverlay()
                onRequestWindow: {
                    root.dismissOverlay();
                    root.window();
                }
                onPicked: (r, g, b) => {
                    Capture.addRecent(r, g, b);
                    root.pickedColor = ({ r, g, b });
                }
            }
        }
    }

    // ── Screen capture: grim the focused output, then deliver ───────
    Process {
        id: screenProc
        property string screenName: ""
        onExited: code => {
            if (code === 0)
                Capture.run(Capture.deliverFileCommand(Capture.tempPng(screenName)));
        }
    }

    // ── Window capture: pick-window → screenshot-window --id ────────
    Process {
        id: pickWindowProc
        command: ["niri", "msg", "-j", "pick-window"]
        stdout: StdioCollector {
            id: pickWindowOut
            onStreamFinished: {
                let id = -1;
                try {
                    const data = JSON.parse(pickWindowOut.text);
                    id = data?.id ?? -1;
                } catch (e) {
                    return;
                }
                if (id < 0)
                    return;
                const out = Capture.tempPng(`window-${id}`);
                winShotProc.outPath = out;
                winShotProc.command = ["bash", "-c",
                    `mkdir -p '${Capture.shq(Capture.tempDir)}' && niri msg action screenshot-window --id ${id} -d false --path '${Capture.shq(out)}'`];
                winShotProc.running = true;
            }
        }
    }

    Process {
        id: winShotProc
        property string outPath: ""
        onExited: code => {
            if (code === 0)
                Capture.run(Capture.deliverFileCommand(outPath));
        }
    }

    // ── Colour result chip (fed by the loupe overlay) ───────────────
    property var pickedColor: null  // { r, g, b }

    Loader {
        active: root.pickedColor !== null
        sourceComponent: ColorResult {
            screen: root.focusedScreen()
            colour: root.pickedColor
            onRequestClose: root.pickedColor = null
        }
    }

    // ── IPC ─────────────────────────────────────────────────────────
    IpcHandler {
        target: "capture"

        function region(): void { root.region(); }
        function window(): void { root.window(); }
        function screen(): void { root.screenshotScreen(); }
        function color(): void { root.color(); }
    }
}
