import Quickshell.Io
import qs.config
// import "components"

JsonObject {
    property bool enabled: true
    property bool autoHide: false
    property bool orientation: true// orientation ([false] - vertical / [true] - horizontal) 
    property bool position: false//  position ([false] - top or [true] - bottom / [false] - left or [true] - right) 
    property int thickness: 50
    property bool separated: true
    property IntData rounding: IntData {
        all: 15
        center: 30
    }
    property BoolData invertBaseRounding: BoolData {
        all: false
        center: true
    }
    property BoolData reusability: BoolData {
        all: false
    }

    property bool equalMargins: true
    property int longSideMargin: 4
    property int shortSideMargin: 4

    component BoolData: JsonObject {
        property var all: undefined
        property var begin: undefined
        property var center: undefined//: null//: undefined
        property var end: undefined//: null//: undefined
    }

    component IntData: JsonObject {
        property int all//: undefined
        property int begin//: undefined
        property int center//: undefined
        property int end//: undefined
    }
}