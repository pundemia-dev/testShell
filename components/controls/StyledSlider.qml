import ".."
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Templates

// Caelestia-style slider: thin track, narrow handle stick, an end dot, and a
// filled part that can be a flat line or an animated sine wave (`wavy`). Kept as
// a plain Templates.Slider so the standard API (value/from/to/stepSize/
// onValueChanged + built-in drag) still works for existing call sites.
Slider {
    id: root

    // Visuals
    property bool wavy: false
    property bool animateWave: pressed   // wave scrolls while dragging
    property int waveFrequency: 6
    property int radius: Appearance.rounding.full
    property color fgColour: Colours.palette.primary
    property color bgColour: Colours.palette.surface_container_highest

    // Filled length up to the handle centre (drives both the line and the wave).
    readonly property real filledWidth: handle ? handle.x + handle.implicitWidth / 2 : 0

    implicitHeight: 16
    implicitWidth: 200

    handle: StyledRect {
        id: handleRect

        x: root.visualPosition * root.availableWidth
        anchors.verticalCenter: parent?.verticalCenter ?? undefined

        implicitWidth: 4
        implicitHeight: root.pressed ? root.height : root.height * 0.8

        radius: root.radius
        color: root.fgColour

        Behavior on implicitHeight {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }
    }

    background: Item {
        anchors.fill: parent

        // Remaining (un-filled) track from the filled part to the end.
        StyledRect {
            id: remaining

            anchors.left: filled.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Appearance.spacing.small

            implicitHeight: root.height * 0.45
            radius: root.radius
            topLeftRadius: root.radius / 4
            bottomLeftRadius: root.radius / 4
            color: root.bgColour
        }

        // End dot.
        StyledRect {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: implicitWidth / 2

            implicitWidth: root.height * 0.18
            implicitHeight: implicitWidth
            radius: Appearance.rounding.full
            color: root.fgColour
        }

        // Filled part: flat line or animated wave.
        Loader {
            id: filled

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: root.wavy ? waveComp : lineComp
        }

        Component {
            id: lineComp

            StyledRect {
                implicitWidth: root.filledWidth
                implicitHeight: root.height * 0.45
                radius: root.radius
                topRightRadius: root.radius / 4
                bottomRightRadius: root.radius / 4
                color: root.fgColour

                Behavior on implicitWidth {
                    Anim {}
                }
            }
        }

        Component {
            id: waveComp

            WavyLine {
                implicitWidth: root.filledWidth
                implicitHeight: lineWidth * amplitudeMultiplier * 2 + lineWidth

                lineWidth: Math.round(root.height * 0.5)
                amplitudeMultiplier: 0.5
                frequency: root.waveFrequency
                fullLength: root.availableWidth
                color: root.fgColour

                Behavior on implicitWidth {
                    Anim {}
                }

                NumberAnimation on waveProgress {
                    running: true
                    paused: !root.animateWave
                    from: 0
                    to: 1
                    duration: 1000
                    loops: Animation.Infinite
                    easing.type: Easing.Linear
                }
            }
        }
    }
}
