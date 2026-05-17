pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var toplevels: ({ "values": [] })
    property var workspaces: ({ "values": [] })
    property var monitors: ({ "values": [] })
    property var _workspacesDict: ({})

    property int activeWsId: 1
    property var focusedMonitor: null
    property var focusedWorkspace: null
    property var activeToplevel: null

    // Keyboard state. niri exposes layout via KeyboardLayoutsChanged events;
    // it does not currently expose capsLock/numLock — left as stubs so callers
    // (KeyboardPreview) keep working.
    property bool capsLock: false
    property bool numLock: false
    property var keyboardLayoutNames: []
    property int keyboardLayoutIndex: 0
    readonly property string kbLayoutFull: keyboardLayoutNames[keyboardLayoutIndex] ?? "Unknown"
    readonly property string kbLayout: {
        const name = kbLayoutFull;
        if (!name || name === "Unknown") return "??";
        // Try to extract a 2-letter code from the layout name (e.g. "English (US)" -> "en").
        const lower = name.toLowerCase();
        if (lower.startsWith("english")) return "en";
        if (lower.startsWith("russian")) return "ru";
        const m = name.match(/\(([a-z]{2,3})\)/i);
        if (m) return m[1].toLowerCase();
        return name.slice(0, 2).toLowerCase();
    }

    signal configReloaded

    function dispatch(action: string) {
        let args = ["niri", "msg", "action"]
        if (action) args = args.concat(action.split(" "))
        dispatchProc.command = args
        dispatchProc.running = true
    }

    function monitorFor(screen) {
        if (!screen) return null;
        return monitors.values.find(m => m.name === screen.name) || monitors.values[0] || null;
    }

    function setWorkspaces(newDict) {
        root._workspacesDict = newDict;
        root.workspaces = { "values": Object.values(newDict).sort((a, b) => a.idx - b.idx) };
    }

    Process {
        id: procWorkspaces
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector { id: stdoutWorkspaces }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const wss = JSON.parse(stdoutWorkspaces.text);
                    const newMap = {};
                    for (const ws of wss) {
                        newMap[ws.id] = ws;
                        if (ws.is_focused) root.activeWsId = ws.idx;
                    }
                    setWorkspaces(newMap);
                } catch (e) {}
            }
        }
    }

    Process {
        id: procWindows
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector { id: stdoutWindows }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    root.toplevels = { "values": JSON.parse(stdoutWindows.text) };
                } catch (e) {}
            }
        }
    }

    Process {
        id: procOutputs
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector { id: stdoutOutputs }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const outs = JSON.parse(stdoutOutputs.text);
                    root.monitors = { "values": Object.values(outs) };
                } catch (e) {}
            }
        }
    }

    function fetchInitialState() {
        procWorkspaces.running = true;
        procWindows.running = true;
        procOutputs.running = true;
    }

    Component.onCompleted: fetchInitialState()

    Process { id: dispatchProc }

    Socket {
        path: Quickshell.env("NIRI_SOCKET"); connected: true

        onConnectedChanged: {
            if (connected) { write('"EventStream"\n'); flush(); }
        }

        parser: SplitParser {
            onRead: data => {
                try {
                    let ev = JSON.parse(data);
                    if (ev.WorkspacesChanged) {
                        const newMap = {};
                        for (const ws of ev.WorkspacesChanged.workspaces) {
                            newMap[ws.id] = ws;
                            if (ws.is_focused) root.activeWsId = ws.idx;
                        }
                        setWorkspaces(newMap);
                    } else if (ev.WindowsChanged) {
                        root.toplevels = { "values": ev.WindowsChanged.windows }
                    } else if (ev.OutputsChanged) {
                        root.monitors = { "values": Object.values(ev.OutputsChanged.outputs) }
                    } else if (ev.WorkspaceActivated) {
                        root.focusedWorkspace = ev.WorkspaceActivated

                        const actWs = root._workspacesDict[ev.WorkspaceActivated.id];
                        if (!actWs) return;
                        const output = actWs.output;

                        const newMap = {};
                        for (const id in root._workspacesDict) {
                            const ws = root._workspacesDict[id];
                            const isAct = ws.id === ev.WorkspaceActivated.id;
                            const updatedWs = Object.assign({}, ws);
                            if (ws.output === output) updatedWs.is_active = isAct;
                            if (ev.WorkspaceActivated.focused) updatedWs.is_focused = isAct;
                            newMap[id] = updatedWs;
                            if (updatedWs.is_focused) root.activeWsId = updatedWs.idx;
                        }
                        setWorkspaces(newMap);

                        // Track focused monitor by name for VisibilitiesManager.getForActive()
                        const newFocusedMon = root.monitors.values.find(m => m.name === output);
                        if (newFocusedMon) root.focusedMonitor = newFocusedMon;
                    } else if (ev.WindowFocusChanged) {
                        const wid = ev.WindowFocusChanged.id;
                        if (wid === null || wid === undefined) {
                            root.activeToplevel = null;
                        } else {
                            const win = root.toplevels.values.find(w => w.id === wid);
                            if (win) root.activeToplevel = win;
                        }
                    } else if (ev.KeyboardLayoutsChanged) {
                        root.keyboardLayoutNames = ev.KeyboardLayoutsChanged.keyboard_layouts.names;
                        root.keyboardLayoutIndex = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
                    } else if (ev.KeyboardLayoutSwitched) {
                        root.keyboardLayoutIndex = ev.KeyboardLayoutSwitched.idx;
                    } else if (ev.ConfigLoaded) {
                        root.configReloaded();
                    }
                } catch (e) {}
            }
        }
    }
}
