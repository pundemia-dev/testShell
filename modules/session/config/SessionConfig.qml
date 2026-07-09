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

    // Stack orientation override: "auto" derives it from the anchor edge
    // (horizontal when anchored top/bottom or dead-centre, else vertical);
    // "vertical"/"horizontal" force it.
    property string orientation: "auto"

    // Margins (perpendicular gap from the adjacent edge/bg).
    property int mLeft: 0
    property int mRight: 0
    property int mTop: 0
    property int mBottom: 0

    // Padding inside the bg around the content.
    property int padding: 16

    // Rounding (falls back to backgrounds.rounding when -1).
    property int rounding: -1

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
}
