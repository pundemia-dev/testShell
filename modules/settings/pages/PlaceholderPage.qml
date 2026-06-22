import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

Flickable {
    id: root

    required property string title
    property string description: ""

    contentHeight: contentColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: Appearance.spacing.normal

        // Page title
        StyledText {
            text: root.title
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        // Page description
        StyledText {
            visible: root.description !== ""
            text: root.description
            font.pointSize: Appearance.font.size.normal
            color: Colours.palette.on_surface_variant
            Layout.fillWidth: true
            Layout.bottomMargin: Appearance.spacing.small
        }

        // Separator
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.outline_variant
            Layout.bottomMargin: Appearance.spacing.normal
        }

        // Placeholder content
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: placeholderColumn.implicitHeight + Appearance.padding.large * 2
            radius: Appearance.rounding.normal
            color: Colours.palette.surface_container

            ColumnLayout {
                id: placeholderColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "\ueb20" // tabler settings icon
                    font.family: Appearance.font.family.tabler
                    font.pointSize: 36
                    color: Colours.palette.outline
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("This section is under construction")
                    font.pointSize: Appearance.font.size.larger
                    font.weight: Font.Medium
                    color: Colours.palette.on_surface_variant
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Settings for \"%1\" will appear here.").arg(root.title)
                    font.pointSize: Appearance.font.size.smaller
                    color: Colours.palette.outline
                }
            }
        }

        // Spacer at bottom
        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
