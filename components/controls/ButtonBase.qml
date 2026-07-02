import ".."
import qs.services
import qs.config
import QtQuick

// Shared base for the button family (ported from caelestia, adapted to pShell:
// pShell StateLayer with its `function onClicked` override pattern, snake_case
// palette roles, and pShell property names — notably `toggle` rather than
// caelestia's `isToggle`). Provides the M3 colour/radius logic including
// radius-morph on press so subclasses only supply content + colour roles.
StyledRect {
    id: root

    enum Type {
        Filled,
        Tonal,
        Text
    }

    property bool checked
    property bool toggle
    property bool isRound
    property bool disabled

    property bool radiusMorph: true
    property bool fillWidth // for button rows

    property int type: ButtonBase.Filled

    property real padding
    property real horizontalPadding: padding
    property real verticalPadding: padding

    readonly property alias pressed: stateLayer.pressed
    readonly property alias hovered: stateLayer.containsMouse
    property alias stateLayer: stateLayer
    property alias radiusAnim: radiusAnim

    property color activeColour
    property color inactiveColour
    property color activeOnColour
    property color inactiveOnColour
    property color disabledColour: Qt.alpha(Colours.palette.on_surface, 0.1)
    property color disabledOnColour: Qt.alpha(Colours.palette.on_surface, 0.38)

    property bool internalChecked
    readonly property color onColour: disabled ? disabledOnColour : internalChecked ? activeOnColour : inactiveOnColour

    property real pressedRadius: Appearance.rounding.small
    property real checkedRadius: Appearance.rounding.medium
    property real defaultRadius: Appearance.rounding.large

    signal clicked

    onCheckedChanged: internalChecked = checked

    radius: {
        if (radiusMorph && pressed)
            return pressedRadius;
        if (internalChecked)
            return checkedRadius;
        if (isRound)
            return (height || implicitHeight) / 2 * Math.min(1, Appearance.rounding.scale);
        return defaultRadius;
    }
    color: type === ButtonBase.Text ? "transparent" : disabled ? disabledColour : internalChecked ? activeColour : inactiveColour

    StateLayer {
        id: stateLayer

        color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        disabled: root.disabled

        function onClicked(): void {
            if (root.toggle)
                root.internalChecked = !root.internalChecked;
            root.clicked();
        }
    }

    Behavior on radius {
        Anim {
            id: radiusAnim

            type: Anim.DefaultEffects
        }
    }
}
