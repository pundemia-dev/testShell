import Quickshell.Io

JsonObject {
    property bool enabled: true

    // Geometry / anchors (drives the wrapper's rails contract). Default: a
    // control-center side drawer on the right edge, vertically centered.
    property AnchorsData anchors: AnchorsData {
        right: true
        verticalCenter: true
    }

    // Overlay = covers underlying window; push = displaces siblings on rail.
    property string mode: "push"
    property bool sticks: true

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

    // Auto-hide delay (ms) after the cursor leaves both the trigger strip and
    // the open panel.
    property int autoHideMs: 100

    // Content width of the panel and fixed height of the tab-page area. The
    // page area must NOT be content-driven: the cards below it would jump on
    // every tab switch.
    property int contentWidth: 420
    property int pageHeight: 460

    // ── Modular pages (tabs) ───────────────────────────────────────────
    // Folders under modules/quicksettings/pages/ shipping *.page.qml
    // manifests; keyed by the page's folder name.
    property list<string> order: []
    property list<string> disabled: []

    // ── Modular cards (below the tabs, above quick toggles) ────────────
    // Folders under modules/quicksettings/cards/ shipping *.card.qml.
    property list<string> cardsOrder: []
    property list<string> cardsDisabled: []

    // ── Quick toggles (the fixed bottom card) ──────────────────────────
    property Toggles toggles: Toggles {}

    // Display order of the quick-toggle buttons (keys of Toggles); keys
    // missing here are appended in the default order.
    property list<string> togglesOrder: []

    component Toggles: JsonObject {
        property bool wifi: true
        property bool bluetooth: true
        property bool mic: true
        property bool dnd: true
        property bool settings: true
    }

    // Last-used recording mode of the record card's split button
    // ("fullscreen" | "region").
    property string recordMode: "fullscreen"

    // ── News page ──────────────────────────────────────────────────────
    property list<string> newsFeeds: [
        "https://archlinux.org/feeds/news/",
        "https://www.phoronix.com/rss.php"
    ]
    property int newsLimit: 40
    property int newsRefreshMinutes: 60
    // Collapsed source groups on the news page show this many articles.
    property int newsPreviewNum: 3

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
}
