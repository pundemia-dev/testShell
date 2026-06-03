pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Coordinates the LocalSend *receive* side. Owns the long-lived receive
// server (scripts/localsend_receive.py) and bridges its line-based event
// protocol into QML state. The server only runs while receiving is enabled
// (Config.stash.localsendReceiveEnabled, persisted in shell.json).
//
// Stash modules listen to `requestArrived` to pop themselves open, read
// `request` / `receiving` / `progress` for the accept card, and call
// `accept(dir)` / `reject()` to resolve the pending transfer.
Singleton {
    id: root

    readonly property string scriptsDir: (Quickshell.env("HOME") || "/home/user")
        + "/.config/quickshell/pShell/scripts"

    readonly property bool enabled: Config.stash.localsendReceiveEnabled
    // True once the server has emitted its "ready" event.
    property bool serverReady: false

    // Current request awaiting a decision OR mid-transfer (null when idle).
    // Shape: { sessionId, alias, fingerprint, files:[{id,name,size,type}], totalSize }
    property var request: null
    readonly property bool hasIncoming: request !== null

    // Transfer progress (valid while `receiving`).
    property bool receiving: false
    property int receivedBytes: 0
    property int totalBytes: 0
    readonly property real progress: totalBytes > 0
        ? Math.min(1, receivedBytes / totalBytes) : 0

    // Requests that arrived while another was still being handled.
    property var _queue: []

    signal requestArrived

    function accept(dir: string): void {
        if (!request)
            return;
        receiving = true;
        receivedBytes = 0;
        totalBytes = request.totalSize;
        _send({ action: "accept", sessionId: request.sessionId, dir: dir });
    }

    function reject(): void {
        if (!request)
            return;
        _send({ action: "reject", sessionId: request.sessionId });
        _advance();
    }

    function _send(obj): void {
        if (server.running)
            server.write(JSON.stringify(obj) + "\n");
    }

    // Move to the next queued request (or idle).
    function _advance(): void {
        receiving = false;
        receivedBytes = 0;
        totalBytes = 0;
        if (_queue.length > 0) {
            const next = _queue.shift();
            _queue = _queue;          // notify
            request = next;
            requestArrived();
        } else {
            request = null;
        }
    }

    function _onEvent(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (ev.event) {
        case "ready":
            serverReady = true;
            break;
        case "request":
            if (request === null) {
                request = ev;
                requestArrived();
            } else {
                _queue.push(ev);
                _queue = _queue;      // notify
            }
            break;
        case "progress":
            if (request && ev.sessionId === request.sessionId) {
                receivedBytes = ev.received;
                totalBytes = ev.total;
            }
            break;
        case "session-done":
            if (request && ev.sessionId === request.sessionId)
                _advance();
            break;
        case "cancelled":
        case "timeout":
        case "session-failed":
            // Sender went away / declined / stalled — drop it and move on so
            // the card never hangs open.
            if (request && ev.sessionId === request.sessionId)
                _advance();
            else
                _queue = _queue.filter(r => r.sessionId !== ev.sessionId);
            break;
        }
    }

    onEnabledChanged: {
        if (!enabled) {
            // Server about to stop — drop any in-flight state.
            serverReady = false;
            receiving = false;
            receivedBytes = 0;
            totalBytes = 0;
            request = null;
            _queue = [];
        }
    }

    Process {
        id: server

        running: root.enabled
        command: [root.scriptsDir + "/localsend_receive.py",
                  "--alias", Config.stash.localsendAlias]
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root._onEvent(line)
        }
        stderr: SplitParser {
            onRead: line => console.log("[localsend-recv]", line)
        }
    }
}
