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
    // Dashed selection border (feeds components/effects/DashedRect.qml).
    property int dashWidth: 2
    property int dashLength: 8
    property int dashGap: 4

    // ── Annotation editor ───────────────────────────────────────────
    // Default stroke thickness; the mouse wheel adjusts it live.
    property int drawThickness: 3
    // Pixelate tool: mosaic cell edge in logical px.
    property int pixelateFactor: 8
    // Use the wallpaper-harmonised hues from Colours (red/yellow/green/cyan/
    // blue/magenta/white + accent) as the editor palette. Off → the static
    // editorPalette list below.
    property bool harmonizedPalette: true
    // Swatches in the editor palette popup (the current accent is appended).
    // Used only when harmonizedPalette is off.
    property list<string> editorPalette: ["#f04438", "#f79009", "#fde047", "#22c55e", "#3b82f6", "#a855f7", "#000000", "#ffffff"]
    // Diameter of the crosshair marker ring drawn instead of the hidden cursor.
    property int markerSize: 16
    // Cursor-bubble spring follow (SpringAnimation spring/damping): the bubble
    // is detached from the pointer and dangles after it.
    property real guideSpring: 7.0
    property real guideDamping: 0.4

    // ── Color picker ────────────────────────────────────────────────
    // Format preselected when a colour is picked: "auto" = last used (kept
    // in colorLastFormat), or explicit "hex" | "rgb" | "rgba" | "hsl".
    property string colorDefaultFormat: "auto"
    // Memory for "auto". Written by the shell when the format toggle changes.
    property string colorLastFormat: "hex"
    // Colour-panel follow behaviour, both in PERCENT of screen height:
    // a pick made farther than colorPanelMoveThreshold away from the panel
    // makes it crawl to the cursor and settle colorPanelFollowRadius away.
    property real colorPanelMoveThreshold: 33
    property real colorPanelFollowRadius: 16.7
    // Magnifier loupe (the niri picker has no zoom, so we draw our own).
    property int loupeSize: 168          // on-screen loupe diameter (logical px)
    property int loupeZoom: 8            // logical px shown per source pixel

    // ── OCR ─────────────────────────────────────────────────────────
    // Default language selection when the OCR panel opens:
    //   "auto"  → remember the last used choice (kept in ocrLastLangs),
    //   "all"   → every installed language joined with '+',
    //   other   → explicit tesseract value, e.g. "eng" / "rus" / "eng+rus".
    property string ocrDefaultLang: "auto"
    // Memory for "auto" ("" = all). Written by the shell whenever the
    // language toggle changes; no need to edit by hand.
    property string ocrLastLangs: ""

    // ── Recording ───────────────────────────────────────────────────
    property string recordDir: "$HOME/Videos"
    // Audio source preselected in the record chooser: "auto" = remember the
    // last choice (kept in recordLastAudio), or an explicit override:
    // "none" | "system" | "mic" | "both".
    property string recordAudioDefault: "auto"
    // Memory for "auto". Written by the shell when the chooser is used.
    property string recordLastAudio: "none"
    // VAAPI hardware encode on this render node (the compositor's GPU; cross-
    // GPU encode is broken in wf-recorder). Falls back to CPU x264 silently
    // while no libva driver is installed (pacman -S intel-media-driver).
    property bool recordHwAccel: true
    property string recordHwDevice: "/dev/dri/renderD128"

    // ── Smart regions (v6, optional) ────────────────────────────────
    // Double-click snaps the selection to a detected content box. Selector
    // works fully without this; missing detector => double-click is a no-op.
    property bool smartRegions: true
}
