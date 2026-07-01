pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Caelestia.Components as CComp
import QtQuick
import QtQuick.Shapes

// Rich circular progress ported from caelestia (adds sweepAngle gauges + a wavy
// active arc via Caelestia.Components.WavyLine). Kept separate from the simple
// components/controls/CircularProgress.qml so existing callers are untouched.
Item {
    id: root

    property real value
    property int startAngle: -90
    property int sweepAngle: 360
    property int strokeWidth: Appearance.padding.small
    property int padding: 0
    property int spacing: Appearance.spacing.small
    property color fgColour: Colours.palette.primary
    property color bgColour: Colours.palette.secondary_container
    property alias hasEndIndicator: dot.active

    property bool wavy: false
    property alias waveFrequency: wave.frequency
    property alias waveAmplitude: wave.amplitudeMultiplier
    property bool wavePaused
    property alias waveDuration: waveProgAnim.duration

    readonly property real size: Math.min(width, height)
    readonly property real arcRadius: (size - padding - strokeWidth * (1 + waveAmplitude * 2)) / 2
    property real clampedVal: Math.max(1 / 360, Math.min(1, isNaN(value) ? 0 : value))
    readonly property real gapAngle: ((spacing + strokeWidth) / (arcRadius || 1)) * (180 / Math.PI)
    readonly property real dotAngleRad: (startAngle + sweepAngle - gapAngle * (sweepAngle < 360 ? 0 : 1)) * Math.PI / 180

    readonly property real thickness: strokeWidth * (1 + waveAmplitude) * 2
    property real implicitSize

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Shape {
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        opacity: Math.min(1, remainingArc.sweepAngle)

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.bgColour
            strokeWidth: Math.min(1, remainingArc.sweepAngle) * root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                id: remainingArc
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                centerX: root.size / 2
                centerY: root.size / 2
                startAngle: root.startAngle + root.clampedVal * root.sweepAngle + root.gapAngle
                sweepAngle: Math.max(1 / 360, root.sweepAngle * (1 - root.clampedVal) - root.gapAngle * (root.sweepAngle < 360 ? 1 : 2))
            }

            Behavior on strokeColor {
                CAnim {}
            }
        }
    }

    CComp.WavyLine {
        id: wave

        anchors.fill: parent
        anchors.margins: -lineWidth * amplitudeMultiplier

        lineWidth: root.strokeWidth
        color: root.fgColour
        pathType: CComp.WavyLine.Arc
        radius: root.arcRadius
        startAngle: root.startAngle
        fullAngle: root.sweepAngle
        value: root.clampedVal
        frequency: 8
        amplitudeMultiplier: root.wavy ? 0.5 : 0

        Anim on waveProgress {
            id: waveProgAnim
            running: true
            paused: root.wavePaused || wave.amplitudeMultiplier === 0
            from: 0
            to: 1
            duration: 2000
            easing.type: Easing.Linear
            loops: Animation.Infinite
        }

        Behavior on color {
            CAnim {}
        }

        Behavior on amplitudeMultiplier {
            Anim {}
        }
    }

    Loader {
        id: dot
        x: root.size / 2 + root.arcRadius * Math.cos(root.dotAngleRad) - width / 2
        y: root.size / 2 + root.arcRadius * Math.sin(root.dotAngleRad) - height / 2

        sourceComponent: StyledRect {
            radius: Appearance.rounding.full
            color: root.fgColour
            opacity: Math.min(1, remainingArc.sweepAngle)
            implicitWidth: Math.min(1, remainingArc.sweepAngle) * Math.min(4, root.strokeWidth)
            implicitHeight: Math.min(1, remainingArc.sweepAngle) * Math.min(4, root.strokeWidth)
        }
    }
}
