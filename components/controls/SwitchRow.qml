import ".."
import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property string label
    required property bool checked
    property bool enabled: true
    property var onToggled: function(checked) {}
    property string icon: ""
    property string tooltip: ""
    property int paddings: Appearance.padding.large
    property bool hovered: hoverHandler.hovered

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + paddings * 2
    radius: Appearance.rounding.large
    color: Colours.layer(Colours.palette.surface_container, 2)

    HoverHandler { id: hoverHandler }

    Behavior on implicitHeight {
        Anim {}
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.paddings
        spacing: Appearance.spacing.medium

        Loader {
            active: root.icon !== ""
            visible: active
            sourceComponent: StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: iconItem.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.full
                color: Colours.palette.surface_variant

                StyledIcon {
                    id: iconItem
                    anchors.centerIn: parent
                    text: root.icon
                    font.pointSize: Appearance.font.size.large
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.label
        }

        StyledSwitch {
            checked: root.checked
            enabled: root.enabled
            onToggled: {
                root.onToggled(checked);
            }
        }

    }
    Loader {
        active: root.tooltip !== ""
        z: 10000
        width: 0
        height: 0
        sourceComponent: Tooltip {
            target: root
            text: root.tooltip
        }
    }
    // Tooltip {
    //     target: root
    //     text: root.tooltip
    //     visible: root.tooltip !== ""
    // }
}
