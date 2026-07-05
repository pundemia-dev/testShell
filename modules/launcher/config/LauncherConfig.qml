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
    property OffsetsData offsets: OffsetsData {
        // right: 10
        verticalCenter: 0
        // horizontalCenter: 0
    }
    property PaddingsData paddings: PaddingsData {}
}
