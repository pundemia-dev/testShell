import Quickshell.Io

JsonObject {
    property string show: "slider" // "slider", "teleport", ""
    property bool trail: false
    property int width: -1 // -1 = auto (unitSize)
    property int height: -1 // -1 = auto (unitSize)
    property int rounding: -1 // -1 = auto (Appearance.rounding.full)
    property string bg: "" // empty = Colours.palette.primary
    property string labelColor: "" // empty = Colours.palette.on_primary
    property string labelFont: "" // empty = Appearance.font.family.tabler
    property int fontSize: -1 // -1 = auto (Appearance.font.size.smaller)
    property string label: "\ueebc"
}
