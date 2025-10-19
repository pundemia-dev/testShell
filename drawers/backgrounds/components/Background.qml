import qs.config
import QtQuick
import qs.utils
import QtQuick.Shapes
import Quickshell

Shape {
    id: root

    // Content size
    required property int wrapperWidth
    required property int wrapperHeight

    // Anchors
    required property bool aLeft
    required property bool aRight
    required property bool aTop
    required property bool aBottom
    required property bool aVerticalCenter
    required property bool aHorizontalCenter

    // Margins & offsets
    required property int mLeft
    required property int mRight
    required property int mTop
    required property int mBottom
    required property int vCenterOffset
    required property int hCenterOffset

    // Base settings
    required property int rounding
    required property bool invertBaseRounding

    // Access zone
    required property int zWidth
    required property int zHeight
    
    // Exclusions
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area

    required property bool excludeBarArea

    property int edgeRounding: 20
    
    preferredRendererType: Shape.CurveRenderer
    opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

    function checkAnchors(position) {
        const expectLeft = position.includes("left");
        const expectRight = position.includes("right");
        const expectTop = position.includes("top");
        const expectBottom = position.includes("bottom");

        return (root.aLeft === expectLeft) &&
            (root.aRight === expectRight) &&
            (root.aTop === expectTop) &&
            (root.aBottom === expectBottom);
    }

    ShapePath {
        strokeWidth: -1
        fillColor: wrapperWidth > 0 && wrapperHeight > 0 ? Colours.palette.m3surface : "transparent"
        startX: {
            if (root.aLeft) return root.mLeft + (root.excludeBarArea ? root.left_area : 0);
            if (root.aHorizontalCenter) return (root.zWidth / 2) - (root.wrapperWidth / 2) + root.hCenterOffset;
            if (root.aRight) return root.zWidth - root.wrapperWidth - root.mRight - (root.excludeBarArea ? root.right_area : 0);
            return 0;
        }

        startY: {
            var y;
            if (root.aTop) {
                y = root.mTop + (root.excludeBarArea ? root.top_area : 0);
            } else if (root.aVerticalCenter) {
                y = (root.zHeight / 2) - (root.wrapperHeight / 2) + root.vCenterOffset;
            } else if (root.aBottom) {
                y = root.zHeight - root.wrapperHeight - root.mBottom - (root.excludeBarArea ? root.bottom_area : 0);
            } else {
                y = root.border_area;
            }
            return y + root.rounding * ((root.invertBaseRounding && (checkAnchors("left") || checkAnchors("left&bottom"))) ? -1 : 1);
        }

        // Left top corner
        PathArc {
            relativeX: !root.invertBaseRounding ? root.rounding : (((checkAnchors("top")||checkAnchors("top&right")) ? -1 : 1) * root.rounding)
            relativeY: !root.invertBaseRounding ? -root.rounding : (((checkAnchors("left") || checkAnchors("left&bottom")) ? -1 : 1) * -root.rounding)
            radiusX: Math.min(root.rounding, root.wrapperWidth)
            radiusY: -Math.min(root.rounding, root.wrapperHeight)
            direction: root.invertBaseRounding ? (((root.aTop === true) != (root.aLeft === true)) ? PathArc.Counterclockwise : PathArc.Clockwise) : undefined
        }
        // Top edge
        PathLine {
            relativeX: root.wrapperWidth - root.rounding * (!root.invertBaseRounding ? 2 : (2 - 2 * ((root.aTop === true) + checkAnchors("top"))))
            relativeY: 0
        }
        // Right top corner
        PathArc {
            relativeX: !root.invertBaseRounding ? root.rounding : (((checkAnchors("top") || checkAnchors("left&top")) ? -1 : 1) * root.rounding)
            relativeY: !root.invertBaseRounding ? root.rounding : (((checkAnchors("right") || checkAnchors("right&bottom")) ? -1 : 1) * root.rounding)
            radiusX: Math.min(root.rounding, root.wrapperWidth)
            radiusY: Math.min(root.rounding, root.wrapperHeight)
            direction: root.invertBaseRounding ? (((root.aTop === true) != (root.aRight === true)) ? PathArc.Counterclockwise : PathArc.Clockwise) : undefined
        }
        // Right edge
        PathLine {
            relativeX: 0
            relativeY: root.wrapperHeight - root.rounding * (!root.invertBaseRounding ? 2 : (2 - 2 * ((root.aRight === true) + checkAnchors("right"))))
        }
        // Right Bottom corner
        PathArc {
            relativeX: !root.invertBaseRounding ? -root.rounding : (((checkAnchors("bottom") || checkAnchors("left&bottom")) ? -1 : 1) * -root.rounding)
            relativeY: !root.invertBaseRounding ? root.rounding : (((checkAnchors("right") || checkAnchors("right&top")) ? -1 : 1) * root.rounding)
            radiusX: Math.min(root.rounding, root.wrapperWidth)
            radiusY: Math.min(root.rounding, root.wrapperHeight)
            direction: root.invertBaseRounding ? (((root.aBottom === true) != (root.aRight === true)) ? PathArc.Counterclockwise : PathArc.Clockwise) : undefined
        }
        // Bottom edge
        PathLine {
            relativeX: -(root.wrapperWidth - root.rounding * (!root.invertBaseRounding ? 2 : (2 - 2 * ((root.aBottom === true) + checkAnchors("bottom")))))
            relativeY: 0
        }
        // Left bottom corner
        PathArc {
            relativeX: !root.invertBaseRounding ? -root.rounding : (((checkAnchors("bottom") || checkAnchors("right&bottom")) ? -1 : 1) * -root.rounding)
            relativeY: !root.invertBaseRounding ? -root.rounding : (((checkAnchors("left") || checkAnchors("left&top")) ? -1 : 1) * -root.rounding)
            radiusX: Math.min(root.rounding, root.wrapperWidth)
            radiusY: Math.min(root.rounding, root.wrapperHeight)
            direction: root.invertBaseRounding ? (((root.aBottom === true) != (aLeft === true)) ? PathArc.Counterclockwise : PathArc.Clockwise) : undefined
        }
        // Left edge
        PathLine {
            relativeX: 0
            relativeY: -(root.wrapperHeight - root.rounding * (!root.invertBaseRounding ? 2 : (2 - 2 * ((root.aLeft === true) + checkAnchors("left")))))
        }
        // fillGradient: RadialGradient {
        //         centerX: 100; centerY: 100
        //         // radius: 50
        //         centerRadius: 150
        // focalX: centerX; focalY: centerY
        //         GradientStop { position: 0.0; color: "blue" }
        //         GradientStop { position: 0.2; color: "green" }
        //         GradientStop { position: 0.4; color: "red" }
        //         GradientStop { position: 0.6; color: "yellow" }
        //         GradientStop { position: 1.0; color: "cyan" }
        //     }
        // fillGradient: RadialGradient {
        //     // x1: 0
        //     // y1: 0
        //     // x2: p.fieldWidth
        //     // y2: p.fieldHeight
        //     centerX: 100
        //     centerY: 100
        //     centerRadius: 50

        //     GradientStop {
        //         position: 0.0
        //         color: "#287384"
        //     }
        //     GradientStop {
        //         position: 1.0
        //         color: "#000000"
        //     }
        // }
        Behavior on fillColor {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }

        // Behavior on ibr {
        //     NumberAnimation {
        //         duration: Appearance.anim.durations.normal
        //         easing.type: Easing.BezierSpline
        //         easing.bezierCurve: Appearance.anim.curves.standard
        //     }
        // }
    }
}