import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ButtonBase {
    id: root

    enum Type {
        Filled,
        Tonal,
        Text
    }

    property alias icon: iconLabel.text
    property alias text: label.text
    property alias font: label.font
    readonly property alias iconLabel: iconLabel
    readonly property alias label: label

    horizontalPadding: Appearance.padding.medium
    verticalPadding: Appearance.padding.small

    activeColour: type === IconTextButton.Filled ? Colours.palette.primary : Colours.palette.secondary
    inactiveColour: type === IconTextButton.Filled ? Colours.tPalette.surface_container : Colours.palette.secondary_container
    activeOnColour: type === IconTextButton.Filled ? Colours.palette.on_primary : Colours.palette.on_secondary
    inactiveOnColour: type === IconTextButton.Filled ? Colours.palette.on_surface : Colours.palette.on_secondary_container

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: row.implicitHeight + verticalPadding * 2

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        StyledIcon {
            id: iconLabel

            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: Math.round(fontInfo.pointSize * 0.0575)
            color: root.onColour
            fill: root.internalChecked ? 1 : 0

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        StyledText {
            id: label

            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: -Math.round(iconLabel.fontInfo.pointSize * 0.0575)
            color: root.onColour
        }
    }
}
