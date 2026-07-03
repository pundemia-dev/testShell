pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Capture helpers: path resolution, shell-command builders for crop/copy/save,
// and colour formatting/history for the picker. Stateless orchestration lives in
// modules/capture/CaptureScope.qml; this singleton is the "ScreenshotAction"
// analogue from end-4 — it only builds commands and holds the colour history.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/home/user"

    function resolvePath(p: string): string {
        if (!p)
            return "";
        if (p.startsWith("~"))
            return home + p.slice(1);
        if (p.startsWith("$HOME"))
            return home + p.slice(5);
        return p;
    }

    readonly property string tempDir: resolvePath(Config.capture.tempDir)
    readonly property string saveDir: resolvePath(Config.capture.saveDir)

    function timestamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss");
    }

    // Full-output PNG grabbed at overlay open; per-screen so multi-monitor is safe.
    function tempPng(screenName: string): string {
        return `${tempDir}/src-${screenName}.png`;
    }

    function shq(s: string): string {
        // Single-quote escape for embedding in a bash single-quoted string.
        return String(s).replace(/'/g, "'\\''");
    }

    // Output PNG for the annotated composite (grabToImage result).
    function annotatedPng(screenName: string): string {
        return `${tempDir}/out-${screenName}.png`;
    }

    // ── Command builders ────────────────────────────────────────────
    // grim the whole output into the temp source image (shown frozen + cropped
    // later). outPath may be "" → default per-screen temp path. Stale stamped
    // grabs of this output are removed first. Both formats are lossless: a
    // .ppm outPath skips PNG encoding entirely (the encode dominates overlay
    // open latency; the raw write goes to tmpfs), .png outputs use fast
    // compression (-l only trades CPU for file size, never quality).
    function grabOutputCommand(screenName: string, outPath: string): var {
        const out = outPath ? outPath : tempPng(screenName);
        const fmt = out.endsWith(".ppm") ? "-t ppm" : "-l 1";
        return ["bash", "-c", `mkdir -p '${shq(tempDir)}' && rm -f '${shq(tempDir)}/src-${shq(screenName)}-'* && grim ${fmt} -o '${shq(screenName)}' '${shq(out)}'`];
    }

    // Clipboard only (the editor's Copy button / Enter), with feedback.
    function copyFileCommand(file: string): var {
        return ["bash", "-c", `wl-copy -t image/png < '${shq(file)}' && notify-send -a pShell 'Screenshot copied'`];
    }

    // File only (the editor's Save button / Ctrl+S).
    function saveFileCommand(file: string): var {
        const dir = saveDir !== "" ? saveDir : `${home}/Pictures`;
        const path = `${dir}/screenshot-${timestamp()}.png`;
        return ["bash", "-c", `mkdir -p '${shq(dir)}' && cp '${shq(file)}' '${shq(path)}' && notify-send -a pShell 'Screenshot saved' '${shq(path)}'`];
    }

    // Crop the source PNG to the selection (physical px) → clipboard, and save if
    // saveDir is set + copyOnCapture controls clipboard. Returns a command array.
    function cropCommand(src: string, x: int, y: int, w: int, h: int): var {
        const crop = `magick '${shq(src)}' -crop ${w}x${h}+${x}+${y} +repage`;
        const save = Config.capture.saveDir !== "";
        const copy = Config.capture.copyOnCapture;
        let sinks = [];
        if (copy)
            sinks.push("wl-copy");
        if (save) {
            const dir = saveDir;
            const path = `${dir}/screenshot-${timestamp()}.png`;
            // tee to clipboard (if copying) and to the file.
            if (copy)
                return ["bash", "-c", `mkdir -p '${shq(dir)}' && ${crop} png:- | tee >(wl-copy) > '${shq(path)}' && notify-send -a pShell 'Screenshot saved' '${shq(path)}'`];
            return ["bash", "-c", `mkdir -p '${shq(dir)}' && ${crop} '${shq(path)}' && notify-send -a pShell 'Screenshot saved' '${shq(path)}'`];
        }
        // Clipboard only.
        return ["bash", "-c", `${crop} png:- | wl-copy`];
    }

    // For full PNGs already produced by niri (window) or grim (screen): copy to
    // clipboard and optionally save a dated copy.
    function deliverFileCommand(file: string): var {
        const save = Config.capture.saveDir !== "";
        const copy = Config.capture.copyOnCapture;
        let parts = [];
        if (copy)
            parts.push(`wl-copy -t image/png < '${shq(file)}'`);
        if (save) {
            const dir = saveDir;
            const path = `${dir}/screenshot-${timestamp()}.png`;
            parts.push(`mkdir -p '${shq(dir)}'`);
            parts.push(`cp '${shq(file)}' '${shq(path)}'`);
            parts.push(`notify-send -a pShell 'Screenshot saved' '${shq(path)}'`);
        }
        if (parts.length === 0)
            parts.push(`wl-copy -t image/png < '${shq(file)}'`);
        return ["bash", "-c", parts.join(" && ")];
    }

    function run(cmd: var): void {
        if (cmd)
            Quickshell.execDetached(cmd);
    }

    // ── OCR ─────────────────────────────────────────────────────────
    // Tesseract languages installed on this system ("osd" is a script
    // detector, not a language). Filled once at startup; empty
    // Config.capture.ocrLangs means "all of these joined with +".
    property var ocrLangsAvailable: []

    Process {
        running: true
        command: ["bash", "-c", "tesseract --list-langs 2>/dev/null | tail -n +2"]
        stdout: StdioCollector {
            id: langsOut
            onStreamFinished: root.ocrLangsAvailable = langsOut.text.trim().split("\n").filter(l => l && l !== "osd")
        }
    }

    function ocrPng(screenName: string): string {
        return `${tempDir}/ocr-${screenName}.png`;
    }

    // Crop the pure source grab (no annotations) into a PNG for tesseract.
    function ocrCropCommand(src: string, x: int, y: int, w: int, h: int, out: string): var {
        return ["bash", "-c", `magick '${shq(src)}' -crop ${w}x${h}+${x}+${y} +repage '${shq(out)}'`];
    }

    // ── Google Lens ─────────────────────────────────────────────────
    // Crop the pure source → upload to uguu.se (temp host, ~3h retention,
    // end-4's approach) → open Lens with the URL in the browser.
    function lensSearch(src: string, x: int, y: int, w: int, h: int, screenName: string): void {
        const file = `${tempDir}/lens-${screenName}.png`;
        const cmd = `magick '${shq(src)}' -crop ${w}x${h}+${x}+${y} +repage '${shq(file)}'` + ` && url="$(curl -sf -F 'files[]=@${shq(file)}' https://uguu.se/upload | jq -r '.files[0].url')"` + ` && [ -n "$url" ] && [ "$url" != null ]` + ` && xdg-open "https://lens.google.com/uploadbyurl?url=$url"` + ` || notify-send -a pShell 'Google Lens' 'Upload failed'`;
        Quickshell.execDetached(["bash", "-c", cmd]);
        Quickshell.execDetached(["notify-send", "-a", "pShell", "Google Lens", "Uploading the crop…"]);
    }

    // ── Recording (wf-recorder via scripts/capture_record.sh) ───────
    // State lives here (not in CaptureScope) so the rails RecordWrapper in
    // Drawers can gate the indicator panel on it.
    //
    // Flow: a record request (editor region / IPC) only opens the top rails
    // panel in PENDING state with the audio chooser; recording starts when
    // an audio chip is clicked there. Pause is segment-based (see the script).
    property bool recording: false
    property bool recordPaused: false
    property bool recordPending: false
    property string recordScreen: ""
    property string recordFile: ""
    property string recordAudio: "none"    // current audio source (live-switchable)
    property double recordStartedAt: 0
    property double recordPausedAccum: 0   // ms recorded before the current segment
    property string pendingGeom: ""
    property string pendingOutput: ""
    property bool discardRequested: false

    function recordPath(): string {
        const dir = resolvePath(Config.capture.recordDir) || `${home}/Videos`;
        return `${dir}/recording_${timestamp()}.mp4`;
    }

    // Audio mode for a new recording: "auto" default resolves to the last
    // used choice, an explicit config value overrides.
    function resolveRecordAudio(): string {
        const def = Config.capture.recordAudioDefault;
        if (def === "auto")
            return Config.capture.recordLastAudio || "none";
        return def;
    }

    // Region from the editor: output-local logical → global logical, then
    // open the pending chooser in the top panel (no recording yet).
    function requestRecordRegion(screenName: string, x: real, y: real, w: real, h: real): void {
        if (recording)
            return;
        const scr = Quickshell.screens.find(s => s.name === screenName) ?? null;
        const mon = Niri.monitorFor(scr);
        const gx = Math.round((mon?.logical?.x ?? 0) + x);
        const gy = Math.round((mon?.logical?.y ?? 0) + y);
        pendingGeom = `${gx},${gy} ${Math.max(1, Math.round(w))}x${Math.max(1, Math.round(h))}`;
        pendingOutput = "";
        recordScreen = screenName;
        recordPending = true;
    }

    function requestRecordOutput(name: string): void {
        if (recording)
            return;
        pendingGeom = "";
        pendingOutput = name;
        recordScreen = name;
        recordPending = true;
    }

    function cancelPending(): void {
        recordPending = false;
    }

    // Audio chip clicked in the top panel → actually start.
    function startPending(audio: string): void {
        if (!recordPending || recording)
            return;
        recordPending = false;
        Config.capture.recordLastAudio = audio;
        recordAudio = audio;
        discardRequested = false;
        recordFile = recordPath();
        const cmd = [`${Quickshell.shellDir}/scripts/capture_record.sh`, audio, recordFile];
        if (pendingGeom)
            cmd.push("--geometry", pendingGeom);
        else if (pendingOutput)
            cmd.push("-o", pendingOutput);
        if (Config.capture.recordHwAccel && Config.capture.recordHwDevice)
            cmd.push("--hw", Config.capture.recordHwDevice);
        recProc.command = cmd;
        recProc.running = true;
        recording = true;
        recordPaused = false;
        recordPausedAccum = 0;
        recordStartedAt = Date.now();
    }

    function stopRecord(): void {
        if (!recording)
            return;
        // SIGINT → the script finalizes the segment and concats (Ctrl+C path).
        recProc.signal(2);
    }

    // Live audio switch: the script re-reads "<file>.audioctl" on SIGUSR2 and
    // restarts the current segment with the new source.
    function setRecordAudio(audio: string): void {
        if (audio === recordAudio)
            return;
        recordAudio = audio;
        Config.capture.recordLastAudio = audio;
        if (recording) {
            const ctl = recordFile + ".audioctl";
            Quickshell.execDetached(["bash", "-c", `printf '%s' '${shq(audio)}' > '${shq(ctl)}' && kill -USR2 ${recProc.processId}`]);
        }
    }

    // Stop AND delete the result instead of saving it.
    function discardRecord(): void {
        if (!recording)
            return;
        discardRequested = true;
        recProc.signal(2);
    }

    // SIGUSR1 → the script closes the current segment / starts the next one.
    function togglePause(): void {
        if (!recording)
            return;
        if (recordPaused)
            recordStartedAt = Date.now();
        else
            recordPausedAccum += Date.now() - recordStartedAt;
        recordPaused = !recordPaused;
        recProc.signal(10);
    }

    // IPC toggle: stop if recording; quick-start with the resolved default
    // if the chooser is already pending; otherwise open the chooser for the
    // focused output.
    function toggleRecord(): void {
        if (recording) {
            stopRecord();
            return;
        }
        if (recordPending) {
            startPending(resolveRecordAudio());
            return;
        }
        const name = Niri.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
        requestRecordOutput(name);
    }

    Process {
        id: recProc

        onExited: (code, status) => {
            const file = root.recordFile;
            const discard = root.discardRequested;
            root.recording = false;
            root.recordPaused = false;
            root.discardRequested = false;
            if (discard)
                Quickshell.execDetached(["bash", "-c", `rm -f '${root.shq(file)}' && notify-send -a pShell 'Recording discarded'`]);
            else
                Quickshell.execDetached(["bash", "-c", `[ -s '${root.shq(file)}' ] && notify-send -a pShell 'Recording saved' '${root.shq(file)}' || notify-send -a pShell 'Recording failed' 'wf-recorder exited without a file'`]);
        }
    }

    // ── Colour picker ───────────────────────────────────────────────
    // history of recent {hex, r, g, b} entries, newest first.
    property var recentColors: []

    function clamp255(v: real): int {
        return Math.max(0, Math.min(255, Math.round(v)));
    }

    function toHex(r: int, g: int, b: int): string {
        const h = n => clamp255(n).toString(16).padStart(2, "0");
        return `#${h(r)}${h(g)}${h(b)}`;
    }

    function rgbToHsl(r: int, g: int, b: int): var {
        r /= 255; g /= 255; b /= 255;
        const max = Math.max(r, g, b), min = Math.min(r, g, b);
        let h = 0, s = 0;
        const l = (max + min) / 2;
        const d = max - min;
        if (d !== 0) {
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max === r)
                h = (g - b) / d + (g < b ? 6 : 0);
            else if (max === g)
                h = (b - r) / d + 2;
            else
                h = (r - g) / d + 4;
            h /= 6;
        }
        return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
    }

    function formatColor(r: int, g: int, b: int, fmt: string): string {
        switch (fmt) {
        case "rgb":
            return `rgb(${clamp255(r)}, ${clamp255(g)}, ${clamp255(b)})`;
        case "rgba":
            return `rgba(${clamp255(r)}, ${clamp255(g)}, ${clamp255(b)}, 1)`;
        case "hsl": {
            const c = rgbToHsl(r, g, b);
            return `hsl(${c.h}, ${c.s}%, ${c.l}%)`;
        }
        case "hex":
        default:
            return toHex(r, g, b);
        }
    }

    function addRecent(r: int, g: int, b: int): void {
        const hex = toHex(r, g, b);
        let list = recentColors.filter(c => c.hex !== hex);
        list.unshift({ hex, r: clamp255(r), g: clamp255(g), b: clamp255(b) });
        recentColors = list.slice(0, 12);
    }

    function copyText(text: string): void {
        Quickshell.execDetached(["bash", "-c", `printf '%s' '${shq(text)}' | wl-copy`]);
    }

    // Manual copy actions: same, plus a notification so the click has feedback.
    function copyTextNotify(text: string, summary: string): void {
        Quickshell.execDetached(["bash", "-c", `printf '%s' '${shq(text)}' | wl-copy && notify-send -a pShell '${shq(summary)}'`]);
    }
}
