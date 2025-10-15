import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int rounding: 15
    property string color: "transparent"
    property bool ivertOrientation: false
    property int longSideMargin: 0
    property int shortSideMargin: 0
    readonly property bool orientation: Config.bar.orientation != ivertOrientation 
    // property real padding: 5
    // implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    // implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    default property alias items: gridLayout.children

    StyledRect {
        id: background
        anchors {
            fill: parent
            topMargin: root.orientation ? shortSideMargin : longSideMargin
            bottomMargin: root.orientation ? shortSideMargin : longSideMargin
            leftMargin: root.orientation ? longSideMargin : shortSideMargin
            rightMargin: root.orientation ? longSideMargin : shortSideMargin
        }
        color: root.color
        radius: root.rounding
    }

    GridLayout {
        id: gridLayout
        columns: root.orientation ? 1 : -1
        anchors {
            verticalCenter: root.orientation ? undefined : parent.verticalCenter
            horizontalCenter: root.orientation ? parent.horizontalCenter : undefined
            left: root.orientation ? undefined : parent.left
            right: root.orientation ? undefined : parent.right
            top: root.orientation ? parent.top : undefined
            bottom: root.orientation ? parent.bottom : undefined
            // margins: root.padding
            topMargin: root.orientation ? shortSideMargin : longSideMargin
            bottomMargin: root.orientation ? shortSideMargin : longSideMargin
            leftMargin: root.orientation ? longSideMargin : shortSideMargin
            rightMargin: root.orientation ? longSideMargin : shortSideMargin
        }
        columnSpacing: 4
        rowSpacing: 12
    }
}