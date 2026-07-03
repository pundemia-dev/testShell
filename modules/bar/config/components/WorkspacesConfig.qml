import Quickshell.Io

JsonObject {
    property int shown: 10
    property bool showWindows: false
    property bool showWindowsOnSpecialWorkspaces: showWindows
    property bool perMonitorWorkspaces: true
    property int rounding: -1 // -1 = auto (Appearance.rounding.full)
    property int spacing: -1 // -1 = auto (Appearance.spacing.small / 2)
    property list<var> numerals: [] // unique label per workspace index, e.g. ["一", "二", "三"]
    property string capitalisation: "preserve" // "upper", "lower", "preserve" — only when label is empty
    property list<var> specialWorkspaceIcons: [] // [{ "name": "music", "icon": "󰎆" }]
    property bool activeIndicator: true // show active indicator in special workspaces

    property ActiveWsConfig active: ActiveWsConfig {}
    property OccupiedWsConfig occupied: OccupiedWsConfig {}
    property UnitWsConfig unit: UnitWsConfig {}
}
