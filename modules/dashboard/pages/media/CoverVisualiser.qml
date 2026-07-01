pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Caelestia.Services
import M3Shapes
import QtQuick
import QtQuick.Shapes

// Radial spectrum visualiser: one bar per cava band, drawn outward from the
// rotating CoverArt shape's edge. 1:1 port of caelestia media/CoverVisualiser.
Item {
    id: root

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real spacing: Appearance.spacing.normal
    readonly property real maxMagnitude: (implicitWidth - cover.implicitWidth) / 2 - spacing
    readonly property int bars: Config.dashboard.media.visualiserBars

    ServiceRef { service: Audio.cava }

    Shape {
        anchors.fill: parent
        asynchronous: true
        preferredRendererType: Shape.CurveRenderer
        data: bars.instances
    }

    Variants {
        id: bars
        model: Array.from({ length: root.bars }, (_, i) => i)

        ShapePath {
            id: bar

            required property int modelData
            readonly property real value: Math.max(1e-2, Math.min(1, Audio.cava.values[modelData] ?? 0))
            readonly property real angle: modelData * 2 * Math.PI / root.bars
            readonly property real shapeEdgeDist: {
                cover.shape.rotation; // re-eval when the shape rotates
                const sDist = cover.shape.distanceAtAngle(modelData * 360 / root.bars + 90);
                return sDist + root.spacing + strokeWidth / 2;
            }
            readonly property real dist: shapeEdgeDist + value * root.maxMagnitude
            readonly property real cos: Math.cos(angle)
            readonly property real sin: Math.sin(angle)

            asynchronous: true
            capStyle: Appearance.rounding.scale === 0 ? ShapePath.SquareCap : ShapePath.RoundCap
            strokeWidth: 360 / root.bars - Appearance.spacing.small / 4
            strokeColor: Colours.palette.primary

            startX: root.centerX + shapeEdgeDist * cos
            startY: root.centerY + shapeEdgeDist * sin

            PathLine {
                x: root.centerX + bar.dist * bar.cos
                y: root.centerY + bar.dist * bar.sin
            }

            Behavior on strokeColor {
                CAnim {}
            }
        }
    }

    CoverArt {
        id: cover
        anchors.centerIn: parent
        shape.shape: MaterialShape.Cookie9Sided
        implicitWidth: Config.dashboard.media.coverArtSize
        implicitHeight: Config.dashboard.media.coverArtSize
    }
}
