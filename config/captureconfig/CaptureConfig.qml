import Quickshell.Io

JsonObject {
    property bool enabled: true

    // IPC target name. Drive from niri: spawn "qs" "-c" "pShell" "ipc" "call" "capture" "region"
    property string shortcut: "capture"

    // Where saved screenshots land. Resolved with $HOME/~ at runtime. Empty
    // string ("") means "don't save to disk, clipboard only".
    property string saveDir: "$HOME/Pictures/Screenshots"

    // Whether a capture is always copied to the clipboard (in addition to any save).
    property bool copyOnCapture: true

    // Scratch dir for the full-output PNG grabbed at open (source for crop / OCR
    // / lens / annotation). Cleared opportunistically.
    property string tempDir: "/tmp/pShell_capture"

    // ── Region selector visual ──────────────────────────────────────
    // Thin aim/crosshair lines from the cursor to the screen edges.
    property bool showAimLines: true
    // Dim strength of the area outside the selection (0..1 alpha over black).
    property real dimStrength: 0.45
    // Dashed selection border (feeds components/DashedRect.qml).
    property int dashWidth: 2
    property int dashLength: 8
    property int dashGap: 4

    // ── Color picker ────────────────────────────────────────────────
    // Default copy format: "hex" | "rgb" | "rgba" | "hsl".
    property string defaultColorFormat: "hex"
    // Magnifier loupe (the niri picker has no zoom, so we draw our own).
    property int loupeSize: 168          // on-screen loupe diameter (logical px)
    property int loupeZoom: 8            // logical px shown per source pixel

    // ── OCR (v3) ────────────────────────────────────────────────────
    // tesseract -l value. Empty ("") => use every installed language joined
    // with '+' (recognise everything). Otherwise e.g. "rus+eng".
    property string ocrLangs: ""

    // ── Recording (v4) ──────────────────────────────────────────────
    property string recordDir: "$HOME/Videos"
    property bool recordAudio: false

    // ── Smart regions (v6, optional) ────────────────────────────────
    // Double-click snaps the selection to a detected content box. Selector
    // works fully without this; missing detector => double-click is a no-op.
    property bool smartRegions: false
}
