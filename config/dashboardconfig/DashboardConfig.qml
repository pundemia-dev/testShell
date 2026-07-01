import Quickshell.Io

JsonObject {
    property bool enabled: true

    // IPC / shortcut target: bind in niri with
    //   spawn "qs" "-c" "pShell" "ipc" "call" "dashboard" "activate"
    property string shortcut: "dashboard"

    // Geometry / anchors (drives the wrapper's rails contract). Default: drops
    // from the top edge, horizontally centered — the caelestia dashboard look.
    property AnchorsData anchors: AnchorsData {
        top: true
        horizontalCenter: true
    }

    // Overlay = covers underlying window; push = displaces siblings on rail.
    property string mode: "push"

    // Margins (perpendicular gap from the adjacent edge/bg).
    property int mTop: 0
    property int mBottom: 0
    property int mLeft: 0
    property int mRight: 0

    // Padding inside the bg around the content.
    property int padding: 12

    // Rounding (falls back to backgrounds.rounding when -1).
    property int rounding: -1

    // Auto-hide delay (ms) after the cursor leaves both the trigger strip and
    // the open panel.
    property int autoHideMs: 100

    // ── Modular pages ──────────────────────────────────────────────────
    // Pages are folders under modules/dashboard/pages/ that each ship a
    // *.page.qml manifest declaring their own title + icon (see
    // components/DashboardPage.qml). These two lists are keyed by the stable
    // page id (= the page's folder name) so they survive pages being
    // added/removed:
    //   order    — display order of the tabs (unknown pages appended by their
    //              manifest `order` hint)
    //   disabled — pages toggled off (hidden from the tab bar)
    property list<string> order: []
    property list<string> disabled: []

    // ── Weather service (page-scoped, avoids touching global config) ────
    // "" = auto-detect via IP; otherwise "City name" or "lat,lon".
    property string weatherLocation: ""
    property bool useFahrenheit: false

    // ── Design tokens, one section per page ────────────────────────────
    // Ported 1:1 from caelestia DashboardTokens so the layout metrics match,
    // but live here (editable in Settings → Dashboard) instead of the caelestia
    // C++ config. Shared tab-bar metrics first, then a sub-object per page.
    property int tabIndicatorHeight: 3
    property int tabIndicatorSpacing: 5

    property DashTokens dash: DashTokens {}
    property MediaTokens media: MediaTokens {}
    property PerfTokens performance: PerfTokens {}
    property WeatherTokens weather: WeatherTokens {}

    // Dashboard tab (User / DateTime / Calendar / Resources / SmallWeather / Media).
    component DashTokens: JsonObject {
        property int userWidth: 340
        property int logoSize: 30
        property int uptimeSize: 30
        property int dateTimeWidth: 110
        property int mediaWidth: 200
        property int mediaProgressThickness: 6
        property int resourceProgressThickness: 6
        property int weatherWidth: 275
    }

    // Media tab (cover + details + lyrics + visualiser).
    component MediaTokens: JsonObject {
        property int coverArtSize: 200
        property int tabWidth: 1000
        property int tabHeight: 320
        property int sectionWidth: 300
        property int progressSweep: 180
        property int progressThickness: 6
        property int visualiserBars: 44
    }

    // Performance tab (hero / usage shapes / storage / network / battery).
    component PerfTokens: JsonObject {
        // Per-widget visibility.
        property bool showCpu: true
        property bool showGpu: true
        property bool showMemory: true
        property bool showStorage: true
        property bool showNetwork: true
        property bool showBattery: true
        property bool useFahrenheit: false

        property int heroCardWidth: 400
        property int usageShapeSize: 100
        property int storageTextWidth: 160
        property int networkCardWidth: 390
        property int networkCardHeight: 220
        property int battWidth: 150
        property int battWidthSingle: 400
        property int battHeight: 160
        property int placeholderWidth: 700
    }

    // Weather tab.
    component WeatherTokens: JsonObject {
        property int forecastItemWidth: 51
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
