pragma Singleton

import qs.config
import Quickshell
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

    // ── Command builders ────────────────────────────────────────────
    // grim the whole output into the temp source PNG (shown frozen + cropped later).
    function grabOutputCommand(screenName: string): var {
        const out = tempPng(screenName);
        return ["bash", "-c", `mkdir -p '${shq(tempDir)}' && grim -o '${shq(screenName)}' '${shq(out)}'`];
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
}
