import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    default property alias content: contentColumn.data
    property string title: ""
    property string description: ""
    property string icon: ""
    property real contentSpacing: Appearance.spacing.small

    // When true, the whole section is hidden unless the UI is in advanced mode.
    property bool advanced: false

    visible: !advanced || Config.general.advanced

    Layout.fillWidth: true
    implicitHeight: outerColumn.implicitHeight + Appearance.padding.large * 2

    radius: Appearance.rounding.large
    // Nested card inside the settings window surface — layered like caelestia's
    // SectionContainer (layer 2 when translucent; opaque role otherwise).
    color: Colours.transparency.enabled ? Colours.layer(Colours.palette.surface_container, 2) : Colours.palette.surface_container

    ColumnLayout {
        id: outerColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.small

        // Section title (optional leading icon)
        RowLayout {
            visible: root.title !== "" || root.icon !== ""
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                visible: root.icon !== ""
                text: root.icon
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.larger
                color: Colours.palette.on_surface
            }

            StyledText {
                visible: root.title !== ""
                text: root.title
                font.pointSize: Appearance.font.size.larger
                font.weight: Font.DemiBold
                color: Colours.palette.on_surface
                Layout.fillWidth: true
            }
        }

        // Section description
        StyledText {
            visible: root.description !== ""
            text: root.description
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.on_surface_variant
            Layout.fillWidth: true
            Layout.bottomMargin: root.title !== "" || root.description !== "" ? Appearance.spacing.small : 0
        }

        // Separator after header (only if title or description exists)
        StyledRect {
            visible: root.title !== "" || root.description !== ""
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.outline_variant
            opacity: 0.5
            Layout.bottomMargin: Appearance.spacing.small / 2
        }

        // Content column for child items
        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            spacing: root.contentSpacing
        }
    }
}
