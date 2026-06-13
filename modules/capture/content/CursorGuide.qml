pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick

// Action bubble that follows the cursor (port of end-4's CursorGuide): a pill
// with one squared corner showing the current mode's icon + label. The label
// collapses to just the icon after a moment; it re-expands whenever the mode
// (description) changes.
Item {
    id: root

    property string glyph: ""
    property string description: ""

    property bool showDescription: true
    function flash(): void {
        showDescription = true;
        descTimeout.restart();
    }
    onDescriptionChanged: flash()

    Timer {
        id: descTimeout
        interval: Appearance.anim.durations.extraLarge
        running: true
        onTriggered: root.showDescription = false
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    StyledRect {
        id: pill

        readonly property real pad: Appearance.padding.normal
        implicitHeight: contentRow.implicitHeight + pad
        implicitWidth: root.showDescription ? contentRow.implicitWidth + pad * 2 : implicitHeight
        clip: true

        topLeftRadius: Appearance.rounding.small / 2
        bottomLeftRadius: implicitHeight / 2
        topRightRadius: implicitHeight / 2
        bottomRightRadius: implicitHeight / 2

        color: Colours.palette.primary

        Behavior on implicitWidth {
            Anim {}
        }

        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.smaller
            spacing: Appearance.spacing.normal

            StyledIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyph
                color: Colours.palette.on_primary
                font.pointSize: Appearance.font.size.larger
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showDescription
                text: root.description
                color: Colours.palette.on_primary
            }
        }
    }
}
