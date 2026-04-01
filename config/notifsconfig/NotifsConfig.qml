import Quickshell.Io

import "structures"

JsonObject {
    property bool expire: true
    property int defaultExpireTimeout: 5000
    property real clearThreshold: 0.3
    property int expandThreshold: 20
    property bool actionOnClick: false
    property bool openExpanded: false
    property Sizes sizes: Sizes {}
    property int rounding: -1
    property bool invertBaseRounding: false
    property bool excludeBarArea: true
    property AnchorsData anchors: AnchorsData {
        right: true
        top: true
    }
    property OffsetsData offsets: OffsetsData {
        top: 10
        right: 10
    }
    property PaddingsData paddings: PaddingsData {
        left: 10
        right: 10
        top: 10
        bottom: 10
    }

    component Sizes: JsonObject {
        property int width: 400
        property int image: 41
        property int badge: 20
    }
}
