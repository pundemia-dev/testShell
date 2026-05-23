import Quickshell.Io
import qs.config

import "components"
import "structures"

JsonObject {
    // property bool direction: false
    property int gap: 10
    property string giphyApiKey: ""
    // property int rounding: 10
    property int invertBaseRounding: 0
    property bool excludeBareArea: true
    property bool reusability: false
    property var modules: ["AppListModule", "GifListModule", "WallListModule"]
    property int itemHeight: 50      // высота одного элемента делегата
        property int maxShown: 7         // максимум видимых элементов
        property string magicSymbol: "!" // символ вызова модулей
    property int carouselVisibleItems: 5  // 5 или 7 — кол-во видимых обоев в карусели
    property real carouselImageScale: 2.0 // множитель размера карточек (1.0 = базовый, 2.0 = удвоенный)
    property AnchorsData anchors: AnchorsData {
        // top: true
        bottom: true
        right: true
        // left: true
        // verticalCenter: true
        // horizontalCenter: true
    }
    property OffsetsData offsets: OffsetsData {
        right: 10
        // verticalCenter: 0
        // horizontalCenter: 0
    }
    property PaddingsData paddings: PaddingsData {

    }
}
