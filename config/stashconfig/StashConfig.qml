import Quickshell.Io

JsonObject {
    property bool enabled: true

    // Filesystem dir where dropped files live (symlinks or copies).
    // Resolved with $HOME at runtime if it starts with ~ or $HOME.
    property string stashDir: "$HOME/Downloads/qs_stash"

    // Drop mode for incoming files: "copy" duplicates the file into stashDir,
    // "symlink" creates a symlink (no extra disk usage, original must stay put).
    property string dropMode: "copy"

    // Hyprland shortcut name → bind with: bind = SUPER, X, global, pShell:stash
    property string shortcut: "stash"

    // Hover trigger: a thin strip at the chosen edge spawns the stash overlay
    // on mouse enter / drag enter. 0 = disabled.
    property int hoverStripPx: 4

    // Grid sizing.
    // `columns` controls the column count in vertical layout (side panel);
    // keep it low for a narrow, tall drawer — 2 by default. `rowsMax` caps
    // how tall the vertical grid grows. In horizontal layout there's a
    // single row and `colsMax` caps how many tiles are visible before the
    // ListView scrolls. `cellSize` drives both dimensions.
    property int columns: 2
    property int rowsMax: 6
    property int colsMax: 8
    property int cellSize: 96

    // Drop-zone tile dimensions (drag-into-stash chooser). Two values that
    // swap roles with orientation: when isVertical=true, width=x, height=y;
    // when isVertical=false, width=y, height=x. Lets one config describe
    // both panel orientations without separate H/V variables.
    property int dropZoneX: 160
    property int dropZoneY: 96

    // Dashed border around the FilesTray drop zone (only visible during drag).
    property int dashedBorderWidth: 2
    property int dashedBorderDashLength: 10
    property int dashedBorderGapLength: 6
    property int dashedBorderRadius: 4

    // LocalSend integration
    property bool localsendEnabled: true
    // Max devices visible at once in the picker before the list scrolls.
    // Indirectly caps panel height in picker mode.
    property int visibleDevicesMax: 5
    // Vertical spacing (px) between alias and badges row inside a DeviceUnit.
    // Smaller → tighter row. The picker's row-height estimate (~60 px) is
    // tuned assuming this stays under ~8 px.
    property int deviceUnitSpacing: 2

    // Layout direction override: "auto" | "horizontal" | "vertical".
    // "auto" rule: top/bottom anchor → horizontal (takes priority over left/right);
    // left/right anchor → vertical; only-center fallback → vertical.
    property string direction: "auto"

    // Geometry / anchors (drives the wrapper's rails contract).
    // Defaults: right edge, vertically centered (side drawer style).
    property AnchorsData anchors: AnchorsData {
        right: true
        verticalCenter: true
    }

    // Auto-hide delay (ms). After mouse leaves both the trigger strip and
    // the open panel, wait this long before closing. 0 = stay open until
    // toggled off via shortcut.
    property int autoHideMs: 400

    // Overlay = covers underlying window; push = displaces siblings on rail.
    property string mode: "overlay"

    // Margins (relative to screen edge for layer 1, see plan).
    property int mTop: 0
    property int mBottom: 0
    property int mLeft: 0
    property int mRight: 0

    // Padding around content inside the bg.
    property int padding: 12

    // Rounding (falls back to backgrounds.rounding if -1).
    property int rounding: -1
    property int invertedJoinRounding: -1

    component AnchorsData: JsonObject {
        property bool left: false
        property bool right: false
        property bool top: false
        property bool bottom: false
        property bool horizontalCenter: false
        property bool verticalCenter: false
    }
}
