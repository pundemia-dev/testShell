import Quickshell.Io

JsonObject {
    property bool enabled: true

    // ── Geometry / anchors (drives the wrapper's rails contract) ──────────
    // Default: right edge, vertically centered — the caelestia OSD look. As in
    // the translator: left/right anchors → the sliders stack vertically (bars
    // vertical); top/bottom or a floating horizontalCenter → they sit side by
    // side (bars horizontal).
    property AnchorsData anchors: AnchorsData {
        right: true
        verticalCenter: true
    }

    // Overlay = covers underlying window; push = displaces siblings on rail.
    property string mode: "push"

    // Margins (perpendicular gap from the adjacent edge/bg).
    property int mTop: 0
    property int mBottom: 0
    property int mLeft: 0
    property int mRight: 0

    // Padding inside the bg around the content.
    property int padding: 16

    // Rounding (falls back to backgrounds.rounding when -1).
    property int rounding: -1

    // Auto-hide delay (ms) after the last volume/brightness change, unless the
    // cursor is hovering the panel or an expansion section is open.
    property int hideDelay: 2000

    // ── Audio ─────────────────────────────────────────────────────────────
    // Max sink/source volume (1.0 = 100%; raise for over-amplification).
    property real maxVolume: 1.0
    // Wheel-scroll / media-key step for volume and mic.
    property real volumeStep: 0.05

    // ── Brightness ─────────────────────────────────────────────────────────
    property real brightnessStep: 0.05
    // Probe external displays via ddcutil (DDC/CI) + Apple displays via asdbctl.
    // OFF by default: poking I2C buses at startup can blank/glitch some internal
    // panels (notably T2 MacBooks). Enable only if you drive an external monitor's
    // backlight through DDC. Internal laptop backlight always uses brightnessctl.
    property bool ddcBrightness: false

    // ── Content toggles ─────────────────────────────────────────────────────
    property bool enableBrightness: true
    property bool enableMicrophone: true
    property bool showPerAppStreams: true

    // ── Slider metrics (the bar's long axis / cross-axis thickness) ──────────
    property int sliderLength: 160
    property int sliderThickness: 40
    // Cross-axis size the expansion drawer grows to when a section is open.
    property int expansionSize: 300

    component AnchorsData: JsonObject {
        property bool left: false
        property bool right: false
        property bool top: false
        property bool bottom: false
        property bool horizontalCenter: false
        property bool verticalCenter: false
    }
}
