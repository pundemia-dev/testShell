import ".."
import qs.services
import qs.config
import QtQuick

ButtonBase {
    id: root

    enum Type {
        Filled,
        Tonal,
        Text
    }

    property alias text: label.text
    property alias font: label.font
    readonly property alias label: label

    horizontalPadding: Appearance.padding.medium
    verticalPadding: Appearance.padding.small

    activeColour: type === TextButton.Filled ? Colours.palette.primary : Colours.palette.secondary
    inactiveColour: {
        if (!toggle && type === TextButton.Filled)
            return Colours.palette.primary;
        return type === TextButton.Filled ? Colours.tPalette.surface_container : Colours.palette.secondary_container;
    }
    activeOnColour: {
        if (type === TextButton.Text)
            return Colours.palette.primary;
        return type === TextButton.Filled ? Colours.palette.on_primary : Colours.palette.on_secondary;
    }
    inactiveOnColour: {
        if (!toggle && type === TextButton.Filled)
            return Colours.palette.on_primary;
        if (type === TextButton.Text)
            return Colours.palette.primary;
        return type === TextButton.Filled ? Colours.palette.on_surface : Colours.palette.on_secondary_container;
    }

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: label.implicitHeight + verticalPadding * 2

    StyledText {
        id: label

        anchors.centerIn: parent
        color: root.onColour
    }
}
