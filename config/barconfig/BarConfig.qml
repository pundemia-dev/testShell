import Quickshell.Io
import qs.config
// import "components"

JsonObject {
    property bool enabled: true
    property bool autoHide: false
    property bool orientation: false// orientation ([false] - vertical / [true] - horizontal) 
    property bool position: true//  position ([false] - top or [true] - bottom / [false] - left or [true] - right) 
    property int thickness: 50
    property string theme: "panel"// panel(слитная) pills(таблетки) edge(прижатая к краю) caelestia notch(капли)

    property bool equalMargins: true
    property int longSideMargin: 2
    property int shortSideMargin: 2
}