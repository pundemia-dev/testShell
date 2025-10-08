import QtQuick
import QtQuick.Shapes
import "components"
import qs.utils

Shape {
    id: root

    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area

    anchors.fill: parent
    anchors.leftMargin: left_area
    anchors.topMargin: top_area
    anchors.rightMargin: right_area
    anchors.bottomMargin: bottom_area

    preferredRendererType: Shape.CurveRenderer
    opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

    // fillColor: "transparent"
    // fillGradient: LinearGradient {
    //     GradientStop { position: 0.0; color: "red" }
    //     GradientStop { position: 0.33; color: "yellow" }
    //     GradientStop { position: 1.0; color: "green" }
    // }

    Background {
        zWidth: root.width
        zHeight: root.height
        aLeft: true
        aTop: true
        aRight: false
        aBottom: false
        verticalCenter: false
        horizontalCenter: false
        vCenterOffset: 300
        hCenterOffset: 700
        rounding: 20
        invertBaseRounding: false
        wrapper: Wrapper {
            height: 200
            width: 200
        }
    }
}
