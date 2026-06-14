import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

FlexboxLayout {
    id: root
    direction: Config.bar.orientation ? FlexboxLayout.Row : FlexboxLayout.Column
    alignItems: FlexboxLayout.AlignCenter
    justifyContent: FlexboxLayout.JustifyCenter

    property color colour: Colours.palette.tertiary

    gap: Appearance.spacing.small

    // ── DEMO: top-edge popout. Shares the same bg as OsIcon's popout in
    // reuse mode — hovering one then the other slides + morphs it across.
    PopoutHandle {
        // Match the bar's current edge (orientation false = vertical).
        edge: !Config.bar.orientation ? (Config.bar.position ? "right" : "left") : (Config.bar.position ? "bottom" : "top")
        popoutContent: Component {
            StyledText {
                text: "Clock popout\n" + Time.format("dddd, dd MMMM\nhh:mm:ss")
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: Appearance.font.size.normal
                color: Colours.palette.primary
            }
        }
    }

    Loader {
        active: !Config.bar.orientation
        visible: active
        asynchronous: true
        width: icon ? icon.implicitWidth : 0
        height: icon ? icon.implicitHeight : 0

        StyledIcon {
            id: icon

            text: "\ufd30"//"calendar_month"
            color: root.colour
            anchors.centerIn: parent
        }
    }

    StyledText {
        id: text

        // horizontalAlignment: StyledText.AlignHCenter
        // verticalAlignment: StyledText.AlignVCenter
        text: Config.bar.orientation ? Time.format("hh:mm") : Time.format("hh\nmm")
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: root.colour

        // transform: Translate { y: 0 }
    }
}
