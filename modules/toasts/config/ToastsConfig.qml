import Quickshell.Io

// Config for the ephemeral toast overlay (services/Toaster.qml + the toasts
// module wrapper). The geometry / anchors block mirrors OsdConfig — it drives
// the same rails contract.
//
// Muting is DYNAMIC, not a hardcoded category list: emitters self-register a
// ToastSource with ToastRegistry, and per-source / per-group / per-notification
// mute state lives in the open map `overrides` below (keyed by source id, same
// idea as Config.custom). See services/Toaster.qml for the shape and the
// setOverride/flag helpers the settings page uses.
JsonObject {
    property bool enabled: true

    // ── Global severity switches ──────────────────────────────────────────
    // Mute every toast of a given severity, regardless of source. The "info"
    // bucket also covers Success-type toasts. Checked first in Toaster.
    property SeverityData severity: SeverityData {}

    // ── Geometry / anchors (drives the wrapper's rails contract) ──────────
    // Default: top-right — the conventional toast corner.
    property AnchorsData anchors: AnchorsData {
        right: true
        top: true
    }

    // overlay = covers the underlying window; push = displaces siblings on rail.
    property string mode: "push"

    // Perpendicular margins from the adjacent edge / bg.
    property int mTop: 0
    property int mBottom: 0
    property int mLeft: 0
    property int mRight: 0

    // Inner padding inside the bg around the toast stack.
    property int padding: 16

    // Rounding (falls back to backgrounds.rounding when -1).
    property int rounding: -1

    // Default auto-dismiss timeout (ms) when a caller passes none / <=0.
    property int defaultTimeout: 5000

    // Hard cap on concurrently shown toasts; enqueuing past it drops the oldest.
    property int maxVisible: 4

    // Fixed width of a toast card (the stack's cross-axis size).
    property int toastWidth: 360

    // ── Per-source mute state (open map, self-populating) ─────────────────
    // overrides["<sourceId>"] = { enabled, errors, others, ids: {"<notifId>": bool} }
    // Anything undefined = shown. Written wholesale via Toaster.setOverride(...).
    property var overrides: ({})

    // NOTE: keystroke / screenkey display (evdev listener + HUD) is deferred to
    // a separate session; its `keystrokes` sub-object lands then.

    component SeverityData: JsonObject {
        property bool info: true
        property bool warning: true
        property bool error: true
    }

    component AnchorsData: JsonObject {
        property bool left: false
        property bool right: false
        property bool top: false
        property bool bottom: false
        property bool horizontalCenter: false
        property bool verticalCenter: false
    }
}
