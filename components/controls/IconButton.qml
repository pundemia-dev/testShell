import ".."
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    enum Type {
        Filled,
        Tonal,
        Text
    }

    property alias icon: label.text
    property bool checked
    property bool toggle
    property real padding: type === IconButton.Text ? Appearance.padding.small / 2 : Appearance.padding.smaller
    property alias font: label.font
    property int type: IconButton.Filled
    property bool disabled

    property alias stateLayer: stateLayer
    property alias label: label
    property alias radiusAnim: radiusAnim

    property bool internalChecked
    property color activeColour: type === IconButton.Filled ? Colours.palette.primary : Colours.palette.secondary
    property color inactiveColour: {
        if (!toggle && type === IconButton.Filled)
            return Colours.palette.primary;
        return type === IconButton.Filled ? Colours.tPalette.surface_container : Colours.palette.secondary_container;
    }
    property color activeOnColour: type === IconButton.Filled ? Colours.palette.on_primary : type === IconButton.Tonal ? Colours.palette.on_secondary : Colours.palette.primary
    property color inactiveOnColour: {
        if (!toggle && type === IconButton.Filled)
            return Colours.palette.on_primary;
        return type === IconButton.Tonal ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant;
    }
    property color disabledColour: Qt.alpha(Colours.palette.on_surface, 0.1)
    property color disabledOnColour: Qt.alpha(Colours.palette.on_surface, 0.38)

    signal clicked

    onCheckedChanged: internalChecked = checked

    radius: internalChecked ? Appearance.rounding.small : implicitHeight / 2 * Math.min(1, Appearance.rounding.scale)
    color: type === IconButton.Text ? "transparent" : disabled ? disabledColour : internalChecked ? activeColour : inactiveColour

    implicitWidth: implicitHeight
    implicitHeight: label.implicitHeight + padding * 2

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

    StyledIcon {
        id: label

        anchors.centerIn: parent
        color: root.disabled ? root.disabledOnColour : root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        fill: !root.toggle || root.internalChecked ? 1 : 0

        Behavior on fill {
            Anim {}
        }
    }

    Behavior on radius {
        Anim {
            id: radiusAnim
        }
    }
}
