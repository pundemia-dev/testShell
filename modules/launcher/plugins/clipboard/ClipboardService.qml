pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Runtime backend for the clipboard launcher plugin. Non-singleton (only the
// launcher consumes it) — instantiated inside ClipboardModule. Wraps `cliphist`
// (list/decode/copy/delete/wipe), classifies each entry (image/color/url/path/
// text) and pre-decodes image thumbnails into a cache dir so the card's
// `backgroundImage` can point straight at a file.
QtObject {
    id: root

    // Classified + decoded records, newest first. Each: { raw, id, type, ... }.
    property var records: []

    readonly property string binary: "cliphist"
    readonly property int historyLimit: Config.getCustom("clipboard", "historyLimit", 100) ?? 100
    readonly property bool autoPaste: Config.getCustom("clipboard", "autoPaste", false) ?? false
    readonly property string pasteCommand: Config.getCustom("clipboard", "pasteCommand", "wtype -M ctrl v -m ctrl") ?? "wtype -M ctrl v -m ctrl"

    readonly property string cacheDir: {
        const x = Quickshell.env("XDG_CACHE_HOME");
        const base = (x && x.length) ? x : (Quickshell.env("HOME") + "/.cache");
        return base + "/quickshell-pShell/clipboard";
    }

    function shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // ── Classification ────────────────────────────────────────────────
    readonly property var _reImage: /\[\[\s*binary data.*\]\]/i
    readonly property var _reDims: /(\d+)x(\d+)/
    readonly property var _reSize: /binary data\s+([\d.]+\s*\w+)/i
    readonly property var _reHex: /^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
    readonly property var _reRgb: /^rgba?\(\s*[\d.]+\s*,\s*[\d.]+\s*,\s*[\d.]+/i
    readonly property var _reHsl: /^hsla?\(\s*[\d.]+\s*,\s*[\d.]+%?\s*,\s*[\d.]+%/i
    readonly property var _reUrl: /^https?:\/\/\S+$/i
    readonly property var _rePath: /^(file:\/\/|\/)\S/

    function classify(raw) {
        const tab = raw.indexOf("\t");
        const id = tab >= 0 ? raw.slice(0, tab) : raw;
        const preview = tab >= 0 ? raw.slice(tab + 1) : raw;
        const trimmed = preview.trim();

        // image
        if (_reImage.test(preview)) {
            const d = preview.match(_reDims);
            const s = preview.match(_reSize);
            return {
                raw, id, type: "image",
                width: d ? parseInt(d[1]) : 0,
                height: d ? parseInt(d[2]) : 0,
                size: s ? s[1] : "",
                imagePath: cacheDir + "/" + id
            };
        }

        // color
        const hex = colorToHex(trimmed);
        if (hex)
            return { raw, id, type: "color", value: trimmed, hex,
                     label: _reHex.test(trimmed) ? "HEX" : (_reRgb.test(trimmed) ? "RGB" : "HSL") };

        // url
        if (_reUrl.test(trimmed)) {
            let host = trimmed;
            try { host = trimmed.replace(/^https?:\/\//i, "").split("/")[0]; } catch (e) {}
            return { raw, id, type: "url", value: trimmed, host };
        }

        // path / file uri
        if (_rePath.test(trimmed) && trimmed.indexOf("\n") < 0) {
            const clean = trimmed.replace(/^file:\/\//i, "");
            const parts = clean.split("/");
            const base = parts.pop() || clean;
            return { raw, id, type: "path", value: clean, base, dir: parts.join("/") || "/" };
        }

        // plain text
        const lines = preview.split("\n");
        return { raw, id, type: "text", value: trimmed,
                 firstLine: (lines[0] || "").trim() || trimmed,
                 chars: preview.length, lineCount: lines.length };
    }

    // Convert a hex/rgb/hsl CSS string to a Qt-usable "#RRGGBB(AA)" hex, or "".
    function colorToHex(s) {
        s = s.trim();
        if (_reHex.test(s))
            return s;
        let m = s.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$/i);
        if (m)
            return rgbaHex(+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]);
        m = s.match(/^hsla?\(\s*([\d.]+)\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%\s*(?:,\s*([\d.]+)\s*)?\)$/i);
        if (m) {
            const rgb = hslToRgb(+m[1], +m[2] / 100, +m[3] / 100);
            return rgbaHex(rgb[0], rgb[1], rgb[2], m[4] === undefined ? 1 : +m[4]);
        }
        return "";
    }

    function rgbaHex(r, g, b, a) {
        const h = v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0");
        let out = "#" + h(r) + h(g) + h(b);
        if (a < 1)
            out += h(a * 255);
        return out;
    }

    function hslToRgb(h, s, l) {
        h = ((h % 360) + 360) % 360 / 360;
        if (s === 0) {
            const v = l * 255;
            return [v, v, v];
        }
        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        const hue = (t) => {
            if (t < 0) t += 1;
            if (t > 1) t -= 1;
            if (t < 1 / 6) return p + (q - p) * 6 * t;
            if (t < 1 / 2) return q;
            if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
            return p;
        };
        return [hue(h + 1 / 3) * 255, hue(h) * 255, hue(h - 1 / 3) * 255];
    }

    // ── Refresh pipeline ──────────────────────────────────────────────
    property var _pending: []

    function refresh() {
        listProc.buffer = [];
        listProc.running = true;
    }

    function _finalize(lines) {
        const recs = lines.slice(0, historyLimit).map(classify);
        _pending = recs;

        const images = recs.filter(r => r.type === "image");
        if (images.length === 0) {
            records = recs;
            return;
        }

        // Decode any missing image thumbnails in one batched shell call, then
        // publish — so `imagePath` always points at an existing file.
        const cmds = images.map(im => {
            const f = shq(im.imagePath);
            return `[ -f ${f} ] || printf %s ${shq(im.raw)} | ${binary} decode > ${f} 2>/dev/null`;
        });
        decodeProc.command = ["bash", "-c",
            `mkdir -p ${shq(cacheDir)}; ` + cmds.join("; ")];
        decodeProc.running = true;
    }

    // ── Actions ───────────────────────────────────────────────────────
    function copy(raw, paste) {
        let cmd = `printf %s ${shq(raw)} | ${binary} decode | wl-copy`;
        if (paste)
            cmd += `; sleep 0.06; ${pasteCommand}`;
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    // For images: copy the decoded binary back onto the clipboard.
    function copyImage(rec, paste) {
        let cmd = `printf %s ${shq(rec.raw)} | ${binary} decode | wl-copy`;
        if (paste)
            cmd += `; sleep 0.06; ${pasteCommand}`;
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function remove(raw) {
        deleteProc.command = ["bash", "-c", `printf %s ${shq(raw)} | ${binary} delete`];
        deleteProc.running = true;
    }

    function wipe() {
        wipeProc.running = true;
    }

    // ── Processes ─────────────────────────────────────────────────────
    property var _list: Process {
        id: listProc
        property var buffer: []
        command: [root.binary, "list"]
        stdout: SplitParser {
            onRead: line => listProc.buffer.push(line)
        }
        onExited: (code, status) => {
            if (code === 0)
                root._finalize(listProc.buffer);
            else
                console.error("[Clipboard] list failed:", code, status);
        }
    }

    property var _decode: Process {
        id: decodeProc
        onExited: (code, status) => {
            root.records = root._pending;
        }
    }

    property var _delete: Process {
        id: deleteProc
        onExited: (code, status) => root.refresh()
    }

    property var _wipe: Process {
        id: wipeProc
        command: [root.binary, "wipe"]
        onExited: (code, status) => {
            Quickshell.execDetached(["bash", "-c", `rm -rf ${root.shq(root.cacheDir)}`]);
            root.refresh();
        }
    }

    property var _watch: Connections {
        target: Quickshell
        function onClipboardTextChanged() { watchTimer.restart(); }
    }

    property var _watchTimer: Timer {
        id: watchTimer
        interval: 120
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
