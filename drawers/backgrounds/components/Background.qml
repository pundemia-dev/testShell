import qs.config
import QtQuick
import QtQuick.Shapes
import Quickshell

ShapePath {
    id: root

    required property Wrapper wrapper

    required property int zWidth
    required property int zHeight

    property bool aLeft: false
    property bool aRight: false
    property bool aTop: false
    property bool aBottom: false
    property bool verticalCenter: false
    property bool horizontalCenter: false

    property int mLeft: 0
    property int mRight: 0
    property int mTop: 0
    property int mBottom: 0
    property int vCenterOffset: 0
    property int hCenterOffset: 0

    property bool invertBaseRounding: false
    property int rounding: 0
    property int edgeRounding: 0
    strokeWidth: -1
    // fillColor: wrapper.width > 0 && wrapper.height > 0 ? Colours.palette.m3surface : "transparent"
    startX: {
        if (aLeft) return mLeft;
        if (horizontalCenter) return (zWidth / 2) - (wrapper.width / 2) + hCenterOffset;
        if (aRight) return zWidth - wrapper.width - mRight;
        return 0;
    }

    startY: {
        var y;
        if (aTop) {
            y = mTop;
        } else if (verticalCenter) {
            y = (zHeight / 2) - (wrapper.height / 2) + vCenterOffset;
        } else if (aBottom) {
            y = zHeight - wrapper.height - mBottom;
        } else {
            y = 0;
        }
        return y + rounding * ((invertBaseRounding && (checkAnchors("left") || checkAnchors("left&bottom"))) ? -1 : 1);
    }

    function checkAnchors(position) {
        const expectLeft = position.includes("left");
        const expectRight = position.includes("right");
        const expectTop = position.includes("top");
        const expectBottom = position.includes("bottom");

        return (aLeft === expectLeft) &&
               (aRight === expectRight) &&
               (aTop === expectTop) &&
               (aBottom === expectBottom);
    }

    // Left top corner
    PathArc {
        relativeX: !invertBaseRounding ? root.rounding : (((checkAnchors("top")||checkAnchors("top&right")) ? -1 : 1) * root.rounding)
        relativeY: !invertBaseRounding ? -root.rounding : (((checkAnchors("left") || checkAnchors("left&bottom")) ? -1 : 1) * -root.rounding)
        radiusX: Math.min(root.rounding, root.wrapper.width)
        radiusY: -Math.min(root.rounding, root.wrapper.height)
        direction: invertBaseRounding ? (((aTop === true) != (aLeft === true)) ? PathArc.Counterclockwise : PathArc.Clockwise) : undefined
    }
    // Top edge
    PathLine {
        relativeX: root.wrapper.width - root.rounding * (!invertBaseRounding ? 2 : (2 - 2 * ((aTop === true) + checkAnchors("top"))))
        relativeY: 0
    }
    // Right top corner
    PathArc {
        relativeX: !invertBaseRounding ? root.rounding : (((checkAnchors("top") || checkAnchors("left&top")) ? -1 : 1) * root.rounding)
        relativeY: !invertBaseRounding ? root.rounding : (((checkAnchors("right") || checkAnchors("right&bottom")) ? -1 : 1) * root.rounding)
        radiusX: Math.min(root.rounding, root.wrapper.width)
        radiusY: Math.min(root.rounding, root.wrapper.height)
        direction: invertBaseRounding ? (((aTop === true) != (aRight === true)) ? PathArc.Counterclockwise : PathArc.Clockwise) : undefined
    }
    // Right edge
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.rounding * (!invertBaseRounding ? 2 : (2 - 2 * ((aRight === true) + checkAnchors("right"))))
    }
    // Right Bottom corner
    PathArc {
        relativeX: !invertBaseRounding ? -root.rounding : (((checkAnchors("bottom") || checkAnchors("left&bottom")) ? -1 : 1) * -root.rounding)
        relativeY: !invertBaseRounding ? root.rounding : (((checkAnchors("right") || checkAnchors("right&top")) ? -1 : 1) * root.rounding)
        radiusX: Math.min(root.rounding, root.wrapper.width)
        radiusY: Math.min(root.rounding, root.wrapper.height)
        direction: invertBaseRounding ? (((aBottom === true) != (aRight === true)) ? PathArc.Counterclockwise : PathArc.Clockwise) : undefined
    }
    // Bottom edge
    PathLine {
        relativeX: -(root.wrapper.width - root.rounding * (!invertBaseRounding ? 2 : (2 - 2 * ((aBottom === true) + checkAnchors("bottom")))))
        relativeY: 0
    }
    // Left bottom corner
    PathArc {
        relativeX: !invertBaseRounding ? -root.rounding : (((checkAnchors("bottom") || checkAnchors("right&bottom")) ? -1 : 1) * -root.rounding)
        relativeY: !invertBaseRounding ? -root.rounding : (((checkAnchors("left") || checkAnchors("left&top")) ? -1 : 1) * -root.rounding)
        radiusX: Math.min(root.rounding, root.wrapper.width)
        radiusY: Math.min(root.rounding, root.wrapper.height)
        direction: invertBaseRounding ? (((aBottom === true) != (aLeft === true)) ? PathArc.Counterclockwise : PathArc.Clockwise) : undefined
    }
    // Left edge
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.rounding * (!invertBaseRounding ? 2 : (2 - 2 * ((aLeft === true) + checkAnchors("left")))))
    }
    fillGradient: RadialGradient {
            centerX: 100; centerY: 100
            // radius: 50
            centerRadius: 150
    focalX: centerX; focalY: centerY
            GradientStop { position: 0.0; color: "blue" }
            GradientStop { position: 0.2; color: "green" }
            GradientStop { position: 0.4; color: "red" }
            GradientStop { position: 0.6; color: "yellow" }
            GradientStop { position: 1.0; color: "cyan" }
        }
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
