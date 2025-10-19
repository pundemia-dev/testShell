import Quickshell.Io

JsonObject {
    property int rounding: 15
    property bool invertBaseRounding: true
    property Margins margins: Margins {}
    property Offsets offsets: Offsets {}

    component Margins: JsonObject {
        property int left: 0
        property int right: 0
        property int top: 0
        property int bottom: 0
    }

    component Offsets: JsonObject {
        property int vCenterOffset: 0
        property int hCenterOffset: 0
    }
}