pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components.misc
import QtQuick
import Quickshell
import Quickshell.Io

// Per-monitor brightness. Each screen becomes a Monitor that drives the right
// backend — internal panels via `brightnessctl`, external displays via
// `ddcutil` (DDC/CI), Apple Studio/Pro displays via `asdbctl`. Ported from
// caelestia; the "active monitor" query is adapted from Hypr to Niri.
Singleton {
    id: root

    property list<var> ddcMonitors: []
    readonly property var ddcMonitorMap: {
        const map = {};
        for (const m of ddcMonitors)
            map[m.connector] = m;
        return map;
    }
    readonly property list<Monitor> monitors: variants.instances
    property bool appleDisplayPresent: false

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.modelData === screen);
    }

    function getMonitor(query: string): var {
        if (query === "active")
            return monitors.find(m => m.modelData.name === Niri.focusedMonitor?.name) ?? monitors[0];

        if (query.startsWith("model:")) {
            const model = query.slice(6);
            return monitors.find(m => m.modelData.model === model);
        }

        if (query.startsWith("serial:")) {
            const serial = query.slice(7);
            return monitors.find(m => m.modelData.serialNumber === serial);
        }

        return monitors.find(m => m.modelData.name === query);
    }

    function increaseBrightness(): void {
        const monitor = getMonitor("active");
        if (monitor)
            monitor.setBrightness(monitor.brightness + Config.osd.brightnessStep);
    }

    function decreaseBrightness(): void {
        const monitor = getMonitor("active");
        if (monitor)
            monitor.setBrightness(monitor.brightness - Config.osd.brightnessStep);
    }

    onMonitorsChanged: {
        if (!Config.osd.ddcBrightness)
            return;
        ddcMonitors = [];
        ddcProc.running = true;
    }

    Variants {
        id: variants

        model: Quickshell.screens

        Monitor {}
    }

    Process {
        // Only probe Apple displays when DDC is opted in — asdbctl talks to the
        // display over I2C, which we keep off internal panels by default.
        running: Config.osd.ddcBrightness
        command: ["sh", "-c", "asdbctl get"] // avoid warnings if asdbctl is missing
        stdout: StdioCollector {
            onStreamFinished: root.appleDisplayPresent = text.trim().length > 0
        }
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: root.ddcMonitors = text.trim().split("\n\n").filter(d => d.startsWith("Display ")).map(d => ({
                        busNum: d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/)[1],
                        connector: d.match(/DRM connector:\s+(.*)/)[1].replace(/^card\d+-/, "") // strip "card1-"
                    }))
        }
    }

    CustomShortcut {
        name: "brightnessUp"
        description: "Increase brightness"
        onActivated: () => root.increaseBrightness()
    }

    CustomShortcut {
        name: "brightnessDown"
        description: "Decrease brightness"
        onActivated: () => root.decreaseBrightness()
    }

    IpcHandler {
        function get(): real {
            return getFor("active");
        }

        // Allows searching by active/model/serial/name
        function getFor(query: string): real {
            return root.getMonitor(query)?.brightness ?? -1;
        }

        function set(value: string): string {
            return setFor("active", value);
        }

        // Handles brightness value like brightnessctl: 0.1, +0.1, 0.1-, 10%, +10%, 10%-
        function setFor(query: string, value: string): string {
            const monitor = root.getMonitor(query);
            if (!monitor)
                return "Invalid monitor: " + query;

            let targetBrightness;
            if (value.endsWith("%-")) {
                const percent = parseFloat(value.slice(0, -2));
                targetBrightness = monitor.brightness - (percent / 100);
            } else if (value.startsWith("+") && value.endsWith("%")) {
                const percent = parseFloat(value.slice(1, -1));
                targetBrightness = monitor.brightness + (percent / 100);
            } else if (value.endsWith("%")) {
                const percent = parseFloat(value.slice(0, -1));
                targetBrightness = percent / 100;
            } else if (value.startsWith("+")) {
                const increment = parseFloat(value.slice(1));
                targetBrightness = monitor.brightness + increment;
            } else if (value.endsWith("-")) {
                const decrement = parseFloat(value.slice(0, -1));
                targetBrightness = monitor.brightness - decrement;
            } else if (value.includes("%") || value.includes("-") || value.includes("+")) {
                return `Invalid brightness format: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;
            } else {
                targetBrightness = parseFloat(value);
            }

            if (isNaN(targetBrightness))
                return `Failed to parse value: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;

            monitor.setBrightness(targetBrightness);

            return `Set monitor ${monitor.modelData.name} brightness to ${+monitor.brightness.toFixed(2)}`;
        }

        target: "brightness"
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property var ddcInfo: root.ddcMonitorMap[modelData.name] ?? null
        readonly property bool isDdc: ddcInfo !== null
        readonly property string busNum: ddcInfo?.busNum ?? ""
        readonly property bool isAppleDisplay: root.appleDisplayPresent && modelData.model.startsWith("StudioDisplay")
        property real brightness
        property real queuedBrightness: NaN
        // Guards against writing hardware before the current level has been read
        // — otherwise an early "brightness - step" would send `0%` and black the
        // screen.
        property bool initialized: false

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    if (monitor.isAppleDisplay) {
                        const val = parseInt(text.trim());
                        monitor.brightness = val / 101;
                    } else {
                        const [, , , cur, max] = text.split(" ");
                        monitor.brightness = parseInt(cur) / parseInt(max);
                    }
                    monitor.initialized = true;
                }
            }
        }

        readonly property Timer timer: Timer {
            interval: 500
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    monitor.setBrightness(monitor.queuedBrightness);
                    monitor.queuedBrightness = NaN;
                }
            }
        }

        function setBrightness(value: real): void {
            if (!initialized)
                return;
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;

            if (isDdc && timer.running) {
                queuedBrightness = value;
                return;
            }

            brightness = value;

            if (isAppleDisplay)
                Quickshell.execDetached(["asdbctl", "set", rounded]);
            else if (isDdc)
                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", rounded]);
            else
                // Floor the internal backlight at 1% so the OSD can never drive
                // the panel fully dark (which, with no bound key to recover, is a
                // dead end).
                Quickshell.execDetached(["brightnessctl", "s", `${Math.max(1, rounded)}%`]);

            if (isDdc)
                timer.restart();
        }

        function initBrightness(): void {
            if (isAppleDisplay)
                initProc.command = ["asdbctl", "get"];
            else if (isDdc)
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
            else
                initProc.command = ["sh", "-c", "echo a b c $(brightnessctl g) $(brightnessctl m)"];

            initProc.running = true;
        }

        onBusNumChanged: initBrightness()
        Component.onCompleted: initBrightness()
    }
}
