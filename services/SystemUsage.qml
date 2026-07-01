pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Lightweight system resource monitor (replaces caelestia's C++ Cpu/Memory/
// Storage services). CPU from /proc/stat jiffy deltas, RAM from /proc/meminfo,
// root-filesystem usage from df. All values are fractions in 0..1 plus raw byte
// counts where useful. Polled every ~2s while anything reads them.
Singleton {
    id: root

    // Fractions 0..1
    property real cpuPerc: 0
    property real memPerc: 0
    property real storagePerc: 0

    // Raw bytes
    property real memUsed: 0
    property real memTotal: 0
    property real storageUsed: 0
    property real storageTotal: 0

    // Previous CPU sample for delta computation.
    property var _prevCpu: null

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFv.reload();
            memFv.reload();
            dfProc.running = true;
        }
    }

    FileView {
        id: statFv
        path: "/proc/stat"
        onLoaded: root._parseCpu(text())
    }

    FileView {
        id: memFv
        path: "/proc/meminfo"
        onLoaded: root._parseMem(text())
    }

    function _parseCpu(t: string): void {
        const line = t.split("\n")[0];
        if (!line || !line.startsWith("cpu"))
            return;
        const p = line.trim().split(/\s+/).slice(1).map(Number);
        const idle = (p[3] || 0) + (p[4] || 0); // idle + iowait
        const total = p.reduce((a, b) => a + b, 0);
        if (_prevCpu) {
            const dt = total - _prevCpu.total;
            const di = idle - _prevCpu.idle;
            if (dt > 0)
                cpuPerc = Math.max(0, Math.min(1, 1 - di / dt));
        }
        _prevCpu = { total, idle };
    }

    function _parseMem(t: string): void {
        const get = k => {
            const m = t.match(new RegExp(k + ":\\s+(\\d+)"));
            return m ? Number(m[1]) * 1024 : 0;
        };
        const total = get("MemTotal");
        const avail = get("MemAvailable");
        if (total <= 0)
            return;
        memTotal = total;
        memUsed = Math.max(0, total - avail);
        memPerc = memUsed / total;
    }

    Process {
        id: dfProc
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector {
            id: dfOut
            onStreamFinished: root._parseDf(dfOut.text)
        }
    }

    function _parseDf(t: string): void {
        const lines = t.trim().split("\n");
        if (lines.length < 2)
            return;
        const parts = lines[1].trim().split(/\s+/).map(Number);
        if (!(parts[0] > 0))
            return;
        storageTotal = parts[0];
        storageUsed = parts[1];
        storagePerc = storageUsed / storageTotal;
    }
}
