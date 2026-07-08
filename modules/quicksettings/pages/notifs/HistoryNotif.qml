pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.effects
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// One history row: app icon circle, summary + relative time, body preview,
// close button. Deliberately lighter than the popup Notification component
// (no drag/expand machinery) — history lists can hold ~100 of these.
StyledRect {
    id: root

    required property var modelData
    readonly property bool hasAppIcon: modelData.appIcon.length > 0

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: row.implicitHeight + Appearance.padding.medium * 2

    radius: Appearance.rounding.medium
    color: modelData.urgency === NotificationUrgency.Critical ? Colours.tPalette.secondary_container : Colours.tPalette.surface_container

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.medium
        spacing: Appearance.spacing.medium

        StyledRect {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            radius: Appearance.rounding.full
            color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.error : Colours.palette.secondary_container

            Loader {
                active: root.hasAppIcon
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.6)
                height: Math.round(parent.width * 0.6)

                sourceComponent: ColouredIcon {
                    anchors.fill: parent
                    source: Quickshell.iconPath(root.modelData.appIcon)
                    colour: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.on_error : Colours.palette.on_secondary_container
                    layer.enabled: root.modelData.appIcon.endsWith("symbolic")
                }
            }

            Loader {
                active: !root.hasAppIcon
                anchors.centerIn: parent

                sourceComponent: StyledIcon {
                    text: Icons.getNotifIcon(root.modelData.summary, root.modelData.urgency)
                    color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.on_error : Colours.palette.on_secondary_container
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.modelData.summary
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    text: root.modelData.timeStr
                    color: Colours.palette.on_surface_variant
                    font: Appearance.font.label.small
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.modelData.body
                textFormat: Text.MarkdownText
                color: Colours.palette.on_surface_variant
                font: Appearance.font.body.small
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                elide: Text.ElideRight
                maximumLineCount: 2

                onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
            }
        }

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: closeIcon.implicitHeight + Appearance.padding.extraSmall * 2
            implicitHeight: implicitWidth

            StateLayer {
                radius: Appearance.rounding.full
                function onClicked(): void {
                    root.modelData.close();
                }
            }

            StyledIcon {
                id: closeIcon
                anchors.centerIn: parent
                text: "\ueb55" // tabler x
                color: Colours.palette.on_surface_variant
                font.pointSize: Appearance.font.size.small
            }
        }
    }
}
