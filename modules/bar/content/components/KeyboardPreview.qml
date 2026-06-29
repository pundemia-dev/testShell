import qs.components
import qs.services
import qs.config
import QtQuick
import Quickshell
import QtQuick.Layouts

FlexboxLayout {
    id: root
    direction: Config.bar.orientation ? FlexboxLayout.Row : FlexboxLayout.Column
    alignItems: FlexboxLayout.AlignCenter
    justifyContent: FlexboxLayout.JustifyCenter
    // visible: Config.bar.kbLayout.show
    property color colour: Colours.role(Config.getCustom("keyboardPreview", "colour", "secondary"))

    gap: Appearance.spacing.small

    StyledIcon {
        id: icon
        visible: Config.getCustom("keyboardPreview", "showIcon", false)
        text: "\uebd6"//"calendar_month"
        color: root.colour

        // anchors.horizontalCenter: parent.horizontalCenter
    }

    StyledText {
        id: text
        visible: Config.getCustom("keyboardPreview", "showLayout", true)
        // anchors.horizontalCenter: parent.horizontalCenter

        // horizontalAlignment: StyledText.AlignHCenter
        text: Niri.capsLock ? Niri.kbLayout.toUpperCase() : Niri.kbLayout.toLowerCase()//"en"//Time.format("hh\nmm")
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: root.colour
        animate: true
        transform: Translate { y: Niri.capsLock ? 1 : 0 }
        // anchors.verticalCenterOffset: -2
    }
}
