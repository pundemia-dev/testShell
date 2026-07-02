import ".."
import qs.services
import qs.config
import QtQuick

ButtonBase {
    id: root

    // Redeclared so call sites keep resolving `IconButton.Filled/Tonal/Text`
    // (values match ButtonBase.Type).
    enum Type {
        Filled,
        Tonal,
        Text
    }

    property alias icon: label.text
    property alias font: label.font
    readonly property alias label: label

    // caelestia parity: rounded-rect by default (defaultRadius); set `isRound: true`
    // at the call site for a circular button.
    padding: type === IconButton.Text ? Appearance.padding.small / 2 : Appearance.padding.small

    activeColour: type === IconButton.Filled ? Colours.palette.primary : Colours.palette.secondary
    inactiveColour: {
        if (!toggle && type === IconButton.Filled)
            return Colours.palette.primary;
        return type === IconButton.Filled ? Colours.tPalette.surface_container : Colours.palette.secondary_container;
    }
    activeOnColour: type === IconButton.Filled ? Colours.palette.on_primary : type === IconButton.Tonal ? Colours.palette.on_secondary : Colours.palette.primary
    inactiveOnColour: {
        if (!toggle && type === IconButton.Filled)
            return Colours.palette.on_primary;
        return type === IconButton.Tonal ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant;
    }

    implicitWidth: implicitHeight
    implicitHeight: label.implicitHeight + padding * 2

    StyledIcon {
        id: label

        anchors.centerIn: parent
        color: root.onColour
        fill: !root.toggle || root.internalChecked ? 1 : 0

        Behavior on fill {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
