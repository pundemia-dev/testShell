import Quickshell.Io
import qs.config

import "structures"

JsonObject {
    // property bool direction: false
    property int gap: 10
    // property int rounding: 10
    property bool excludeBareArea: true
    // Плагины (modules/launcher/plugins/<id>/) — blocklist-семантика:
    // всё найденное активно, если id не в disabled; order задаёт порядок
    // (order[0] = дефолтный модуль). Пер-модульные настройки живут в
    // Config.custom[<id>] через settingsSchema манифеста.
    property var order: []
    property var disabled: []
    property int itemHeight: 50      // высота одного элемента делегата
    property int maxShown: 7         // максимум видимых элементов
    property string magicSymbol: "!" // символ вызова модулей
    property AnchorsData anchors: AnchorsData {
        // top: true
        // bottom: true
        // right: true
        // left: true
        // verticalCenter: true
        // horizontalCenter: true
    }
    // Overlay = covers underlying window; push = displaces siblings on rail.
    property string mode: "push"
    property bool sticks: true
    property TriggerData trigger: TriggerData {}

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
