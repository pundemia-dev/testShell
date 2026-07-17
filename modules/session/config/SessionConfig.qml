import Quickshell.Io

JsonObject {
    property bool enabled: true

    // ── Modular action buttons ─────────────────────────────────────────
    // Buttons are folders under modules/session/plugins/ that each ship a
    // *.action.qml manifest declaring their own title/icon/command (see
    // modules/session/content/SessionManifest.qml). These two lists are keyed
    // by the stable button id (= the plugin's folder name) so they survive
    // buttons being added/removed:
    //   order    — display order of the buttons (unknown ids appended by their
    //              manifest `order` hint)
    //   disabled — buttons toggled off (hidden from the menu)
    property list<string> order: []
    property list<string> disabled: []

    // Vim-style Ctrl+J/K (or N/P) navigation between buttons.
    property bool vimKeybinds: false

    // ── Geometry / anchors (drives the wrapper's rails contract) ────────
    // Default: pushes in from the right edge, vertically centered — the bg
    // sits on the right grain.
    property AnchorsData anchors: AnchorsData {
        right: true
        verticalCenter: true
    }

    // Overlay = covers underlying window; push = displaces siblings on rail.
    property string mode: "push"
    property bool sticks: true
    property TriggerData trigger: TriggerData {}

    // Stack orientation override: "auto" derives it from the anchor edge
    // (horizontal when anchored top/bottom or dead-centre, else vertical);
    // "vertical"/"horizontal" force it.
    property string orientation: "auto"

    // ── Background geometry (edited via BackgroundCard) ───────────────
    // Margins / paddings: each side is a number, "all" (inherit the group's
    // `all`), or null ("global" → the rails contract default). Centre offsets
    // shift the panel along the centred axis and may be negative.
    property EdgesData margins: EdgesData {}
    property EdgesData paddings: EdgesData {}
    property int hCenterOffset: 0
    property int vCenterOffset: 0

    // Stacking depth on the anchor rail.
    property int layer: 0
    // For mode "replace": position the borrowed bg INSIDE the reserved edge
    // strip (on the donor's spot, edge-flush like pinned) instead of being
    // inset past it.
    property bool reservesSpace: false

    // Rounding: a number, or null to follow Config.backgrounds.rounding.
    property var rounding: null
    // Size-spring override for the bg open/close/resize animation:
    // numbers, or null to follow the global Liquid defaults.
    property var sizeSpring: null
    property var sizeDamping: null

    // ── Design tokens ───────────────────────────────────────────────────
    property int buttonSize: 80
    property int spacing: 16

    component AnchorsData: JsonObject {
        property bool left: false
        property bool right: false
        property bool top: false
        property bool bottom: false
        property bool horizontalCenter: false
        property bool verticalCenter: false
    }

    component EdgesData: JsonObject {
        property var all: null
        property var left: "all"
        property var right: "all"
        property var top: "all"
        property var bottom: "all"
    }

    component TriggerData: JsonObject {
        property bool enabled: false
        property bool hover: true
        property bool drop: false
        property bool slide: false
        property int layer: 0
    }
}
