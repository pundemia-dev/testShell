import qs.services
import qs.config
import qs.components
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real progress: 0
    property int progressSweepAngle: 270
    property int progressWidth: 3
    property int progressSpacing: 3
    property string progressColor
    property string label
    property int labelSize: 12
    property string labelColor
    property bool labelVisibility: true
    property bool animate: true

    Shape {
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colours.palette.surface_container_high
            strokeWidth: progressWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: center_icon.x + center_icon.width / 2
                centerY: center_icon.y + center_icon.height / 2
                radiusX: (center_icon.width + progressWidth) / 2 + progressSpacing
                radiusY: (center_icon.height + progressWidth) / 2 + progressSpacing
                startAngle: -90 - progressSweepAngle / 2
                sweepAngle: progressSweepAngle
            }
            Behavior on strokeColor {
                CAnim {

                }
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: progressColor
            strokeWidth: progressWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: center_icon.x + center_icon.width / 2
                centerY: center_icon.y + center_icon.height / 2
                radiusX: (center_icon.width + progressWidth) / 2 + progressSpacing
                radiusY: (center_icon.height + progressWidth) / 2 + progressSpacing
                startAngle: -90 - progressSweepAngle / 2
                sweepAngle: progressSweepAngle * progress
                Behavior on sweepAngle {
                    enabled: root.animate
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }
            }
            Behavior on strokeColor {
                CAnim {

                }
            }
        }
    }

    StyledIcon {
        id: center_icon

        anchors.centerIn: parent
        text: label
        color: labelColor
        font.pointSize: labelSize
        visible: labelVisibility
        fill: 1
        animate: true
    }
}
