import Quickshell.Io
import qs.config

// import "components
//

JsonObject {
    property bool enabled: true
    property bool autoHide: false
    property bool orientation: true// orientation ([false] - vertical / [true] - horizontal)
    property bool position: false//  position ([false] - top or [true] - bottom / [false] - left or [true] - right)
    // property int thickness: 50
    property SeparatedData thickness: SeparatedData {
        all: 50
        center: 70
    }
    property bool separated: true
    property SeparatedData rounding: SeparatedData {
        all: 15
        center: 25
        begin: 15
    }
    property SeparatedData invertBaseRounding: SeparatedData {
        all: false
        center: false
    }
    property SeparatedData reusability: SeparatedData {
        all: false
    }

    property SeparatedData longSideMargin: SeparatedData {
        all: 20
        center: 50
    }

    property SeparatedData shortSideMargin: SeparatedData {
        all: 4
        begin: 100
        end: 100
    }

    // property int longSideMargin: 4
    // property int shortSideMargin: 4

    // component separatedData: JsonObject {
    //     property var all: undefined
    //     property var begin: undefined
    //     property var center: undefined//: null//: undefined
    //     property var end: undefined//: null//: undefined
    // }

    // component IntData: JsonObject {
    //     property var all: undefined
    //     property int begin//: undefined
    //     property int center//: undefined
    //     property int end//: undefined
    // }
}
