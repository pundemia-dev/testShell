pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Save / apply / delete / rename config presets. Two granularities:
//   - "full"  → a snapshot of the whole shell.json (a "theme")
//   - <scope> → just one adapter section (bar, launcher, border, ...)
//
// Everything goes through the FILE: apply = build a new shell.json object and
// write it once; Config's own FileView (watchChanges) picks it up via
// onFileChanged → reload() and repopulates the adapter. This is atomic and
// avoids per-leaf binding churn from the auto-writer.
//
// Storage:  ${Paths.config}/presets/<scope>/<name>.json
//
// Headless test over IPC (target "presets"):
//   qs -c pShell ipc call presets save  bar    mytheme
//   qs -c pShell ipc call presets apply bar    mytheme
//   qs -c pShell ipc call presets save  full   dark
//   qs -c pShell ipc call presets apply full   dark
//   qs -c pShell ipc call presets remove bar   mytheme
//   qs -c pShell ipc call presets rename bar   old new
//
// See docs/development/settings.md.
Singleton {
    id: root

    readonly property string configFile: `${Paths.config}/shell.json`
    readonly property string presetsDir: `${Paths.config}/presets`

    // Adapter section names (the per-module preset scopes).
    readonly property var moduleScopes: [
        "bar", "launcher", "border", "corners", "backgrounds",
        "notifs", "stash", "capture", "popouts", "general", "custom"
    ]
    // All scopes including the whole-config snapshot.
    readonly property var scopes: ["full"].concat(moduleScopes)

    Component.onCompleted: {
        // Ensure the preset directory tree exists so writes never race a mkdir.
        Quickshell.execDetached(["mkdir", "-p", `${presetsDir}/full`]);
        for (let i = 0; i < moduleScopes.length; i++)
            Quickshell.execDetached(["mkdir", "-p", `${presetsDir}/${moduleScopes[i]}`]);
    }

    // ── Path helpers ─────────────────────────────────────────────────────
    function _sanitize(name: string): string {
        return String(name).replace(/[\/\0]/g, "_").trim();
    }
    function presetPath(scope: string, name: string): string {
        return `${presetsDir}/${scope}/${_sanitize(name)}.json`;
    }

    // ── Public API ───────────────────────────────────────────────────────
    function savePreset(scope: string, name: string): bool {
        if (scopes.indexOf(scope) < 0) { console.warn("[Presets] unknown scope:", scope); return false; }
        if (!_sanitize(name)) { console.warn("[Presets] empty preset name"); return false; }

        const obj = _readJson(configFile);
        if (!obj) { console.warn("[Presets] cannot read config:", configFile); return false; }

        const data = (scope === "full") ? obj : (obj[scope] ?? {});
        _write(presetPath(scope, name), JSON.stringify(data, null, 2));
        console.log("[Presets] saved", scope, "/", name);
        return true;
    }

    function applyPreset(scope: string, name: string): bool {
        if (scopes.indexOf(scope) < 0) { console.warn("[Presets] unknown scope:", scope); return false; }

        const preset = _readJson(presetPath(scope, name));
        if (preset === null) { console.warn("[Presets] preset not found:", scope, "/", name); return false; }

        let out;
        if (scope === "full") {
            out = preset;
        } else {
            out = _readJson(configFile) ?? {};
            out[scope] = preset;
        }
        // Single write → Config's FileView.onFileChanged → reload() repopulates.
        _write(configFile, JSON.stringify(out, null, 2));
        console.log("[Presets] applied", scope, "/", name);
        return true;
    }

    function deletePreset(scope: string, name: string): void {
        Quickshell.execDetached(["rm", "-f", presetPath(scope, name)]);
        console.log("[Presets] deleted", scope, "/", name);
    }

    function renamePreset(scope: string, from: string, to: string): void {
        if (!_sanitize(to)) { console.warn("[Presets] empty target name"); return; }
        Quickshell.execDetached(["mv", "-f", presetPath(scope, from), presetPath(scope, to)]);
        console.log("[Presets] renamed", scope, "/", from, "→", to);
    }

    // listPresets() is provided in the UI phase via a FolderListModel (async
    // directory enumeration); for now inspect ${presetsDir}/<scope> directly.

    // ── File I/O ─────────────────────────────────────────────────────────
    // Returns parsed object, or null on missing/invalid file.
    function _readJson(path: string): var {
        const txt = _read(path);
        if (!txt || !txt.trim()) return null;
        try {
            return JSON.parse(txt);
        } catch (e) {
            console.warn("[Presets] JSON parse error for", path, ":", e);
            return null;
        }
    }

    function _read(path: string): string {
        const fv = _fileComp.createObject(root, { path: path, blockLoading: true, printErrors: false });
        if (!fv) return "";
        let txt = "";
        try { txt = fv.text() || ""; } catch (e) { txt = ""; }
        fv.destroy();
        return txt;
    }

    function _write(path: string, content: string): void {
        const fv = _fileComp.createObject(root, { path: path, atomicWrites: true, printErrors: true });
        if (!fv) return;
        fv.setText(content);
        // Defer destroy a tick so the synchronous write fully flushes first.
        Qt.callLater(() => fv.destroy());
    }

    Component {
        id: _fileComp
        FileView {}
    }

    // ── Headless IPC entry point ─────────────────────────────────────────
    IpcHandler {
        target: "presets"
        function save(scope: string, name: string): void { root.savePreset(scope, name); }
        function apply(scope: string, name: string): void { root.applyPreset(scope, name); }
        function remove(scope: string, name: string): void { root.deletePreset(scope, name); }
        function rename(scope: string, from: string, to: string): void { root.renamePreset(scope, from, to); }
    }
}
