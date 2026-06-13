import ".."
import qs.services
import qs.config
import QtQuick

// Minimal tabler-glyph button: just the icon with a ripple, optionally on a
// tinted rounded-square container (set `color`). The glyph is centred with
// fill+alignment — anchors.centerIn drifts sideways on tabler glyphs whose
// advance width differs from the ink box.
StyledRect {
    id: root

    property alias icon: ic.text
    property color fg: Colours.palette.on_surface
    property real iconSize: Appearance.font.size.larger
    property real padding: Appearance.padding.small
    property bool disabled: false

    signal clicked()

    implicitWidth: implicitHeight
    implicitHeight: Math.ceil(ic.implicitHeight) + padding * 2
    radius: Appearance.rounding.small / 2
    color: "transparent"

    StateLayer {
        color: root.fg
        disabled: root.disabled

        function onClicked(): void {
            root.clicked();
        }
    }

    StyledIcon {
        id: ic

        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pointSize: root.iconSize
        color: root.disabled ? Qt.alpha(Colours.palette.on_surface, 0.38) : root.fg
    }
}
