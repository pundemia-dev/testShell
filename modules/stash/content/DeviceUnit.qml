pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// One device row in the LocalSend picker. Icon-left, name + badges right.
// Type icon is derived from deviceType (mobile / laptop / desktop / tablet);
// anything else falls back to a CLI/terminal glyph.
StyledRect {
    id: root

    required property string alias
    required property string ip
    required property string deviceType
    required property string deviceModel

    signal picked

    readonly property string typeIcon: {
        switch ((deviceType || "").toLowerCase()) {
            case "mobile":  return "\uea8a"
            case "laptop":  return "\ueb64"
            case "desktop": return "\uea89"
            case "tablet":  return "\uf648"
            default:        return "\uebef"
        }
    }

    readonly property string ipBadge: {
        const m = (ip || "").match(/(\d+)$/)
        return m ? ("#" + m[1]) : ""
    }
    readonly property string osBadge: {
        const v = (deviceModel || "").trim()
        return v.length > 0 ? v : "Unknown"
    }

    radius: Appearance.rounding.small
    color: pressArea.containsMouse
        ? Qt.alpha(Colours.palette.primary, 0.18)
        : Colours.palette.surface_container

    Behavior on color { CAnim {} }

    implicitHeight: rowLayout.implicitHeight + Appearance.padding.small * 2

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.medium
        anchors.rightMargin: Appearance.padding.medium
        anchors.topMargin: Appearance.padding.small
        anchors.bottomMargin: Appearance.padding.small
        spacing: Appearance.spacing.medium

        StyledIcon {
            text: root.typeIcon
            color: Colours.palette.primary
            font.pointSize: Appearance.font.size.extraLarge
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Config.stash.deviceUnitSpacing

            StyledText {
                Layout.fillWidth: true
                text: root.alias
                color: Colours.palette.on_surface
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: Appearance.spacing.small / 2

                // Badge padding intentionally below Appearance.padding.small —
                // these chips are decorative metadata, not pressable, so they
                // sit tighter than buttons. Keep these literals here rather
                // than introducing a project-wide "tiny" token for one place.
                StyledRect {
                    visible: root.ipBadge !== ""
                    radius: Appearance.rounding.small
                    color: Qt.alpha(Colours.palette.primary, 0.18)
                    implicitHeight: ipText.implicitHeight + 2
                    implicitWidth: ipText.implicitWidth + 8

                    StyledText {
                        id: ipText
                        anchors.centerIn: parent
                        text: root.ipBadge
                        color: Colours.palette.primary
                        font.pointSize: Appearance.font.size.small - 1
                    }
                }

                StyledRect {
                    radius: Appearance.rounding.small
                    color: Qt.alpha(Colours.palette.secondary, 0.18)
                    implicitHeight: osText.implicitHeight + 2
                    implicitWidth: osText.implicitWidth + 8

                    StyledText {
                        id: osText
                        anchors.centerIn: parent
                        text: root.osBadge
                        color: Colours.palette.secondary
                        font.pointSize: Appearance.font.size.small - 1
                    }
                }
            }
        }
    }

    MouseArea {
        id: pressArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
