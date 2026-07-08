pragma ComponentBehavior: Bound

import ".."
import "../effects"
import qs.components
import qs.config
import qs.services
import QtQuick
import QtQuick.Templates as T

// M3 filled slider used by the OSD. Ported from caelestia and generalized to
// both orientations: the fill grows from the low end along the active axis, a
// round handle carries a Tabler glyph that flips to the live value (0–100)
// while dragging. Uncontrolled — bind `value` and react to `onMoved`.
T.Slider {
    id: root

    required property string icon
    // Optional: tapping (not dragging) the handle invokes this — used to mute.
    property var onIconTapped: null

    readonly property bool isVertical: orientation === Qt.Vertical
    readonly property real thickness: isVertical ? width : height

    property real oldValue
    property bool initialized

    background: StyledRect {
        color: Colours.transparency.enabled ? Colours.layer(Colours.palette.surface_container, 2) : Colours.palette.surface_container
        radius: Appearance.rounding.full

        StyledRect {
            id: fill

            x: root.isVertical ? 0 : 0
            y: root.isVertical ? handle.y + handle.height / 2 : 0
            width: root.isVertical ? parent.width : handle.x + handle.width / 2
            height: root.isVertical ? parent.height - y : parent.height

            color: Colours.palette.secondary
            radius: parent.radius
        }
    }

    handle: Item {
        id: handle

        property alias moving: label.moving

        x: root.isVertical ? 0 : root.visualPosition * (root.availableWidth - width)
        y: root.isVertical ? root.visualPosition * (root.availableHeight - height) : 0
        implicitWidth: root.thickness
        implicitHeight: root.thickness

        Elevation {
            anchors.fill: parent
            radius: rect.radius
            level: handleInteraction.containsMouse ? 2 : 1
        }

        StyledRect {
            id: rect

            anchors.fill: parent

            color: Colours.palette.inverse_surface
            radius: Appearance.rounding.full

            MouseArea {
                id: handleInteraction

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.NoButton
            }

            // Tap (not drag) → mute toggle, when wired.
            TapHandler {
                enabled: root.onIconTapped
                onTapped: if (root.onIconTapped) root.onIconTapped()
            }

            StyledIcon {
                id: label

                property bool moving

                anchors.centerIn: parent
                text: moving ? Math.round(root.value * 100) : root.icon
                color: Colours.palette.inverse_on_surface
                font.family: moving ? Appearance.font.family.sans : Appearance.font.family.tabler
                font.pointSize: moving ? Appearance.font.size.small : Appearance.font.icon.medium.pointSize

                Behavior on moving {
                    SequentialAnimation {
                        Anim {
                            target: label
                            property: "scale"
                            to: 0.3
                            duration: Appearance.anim.durations.small / 2
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.standardAccel
                        }
                        PropertyAction {}
                        Anim {
                            target: label
                            property: "scale"
                            to: 1
                            duration: Appearance.anim.durations.normal / 2
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.standardDecel
                        }
                    }
                }
            }
        }
    }

    onPressedChanged: handle.moving = pressed

    onValueChanged: {
        if (!initialized) {
            initialized = true;
            return;
        }
        if (Math.abs(value - oldValue) < 0.01)
            return;
        oldValue = value;
        handle.moving = true;
        stateChangeDelay.restart();
    }

    Timer {
        id: stateChangeDelay

        interval: 500
        onTriggered: {
            if (!root.pressed)
                handle.moving = false;
        }
    }

    Behavior on value {
        Anim {
            type: Anim.StandardLarge
        }
    }
}
