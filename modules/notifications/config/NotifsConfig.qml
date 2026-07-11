import Quickshell.Io

import "structures"

JsonObject {
    property bool expire: true
    property int defaultExpireTimeout: 5000
    // Max notifications kept in history (persisted to notifs.json and loaded
    // at startup). Unbounded history was the dominant shell-startup cost:
    // every entry is a live Notif QObject (Timer + Connections + LazyLoader),
    // and the derived `notClosed`/`popups` filters recompute per insert → O(n²).
    // 0 = unlimited (not recommended).
    property int historyLimit: 100
    property real clearThreshold: 0.3
    property int expandThreshold: 20
    // Collapsed app groups in the history page show this many notifications.
    property int groupPreviewNum: 3
    property bool actionOnClick: false
    property bool openExpanded: false
    property Sizes sizes: Sizes {}
    property bool excludeBarArea: true
    property AnchorsData anchors: AnchorsData {
        right: true
        top: true
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

    component Sizes: JsonObject {
        property int width: 400
        property int image: 41
        property int badge: 20
    }

    component EdgesData: JsonObject {
        property var all: null
        property var left: "all"
        property var right: "all"
        property var top: "all"
        property var bottom: "all"
    }
}
