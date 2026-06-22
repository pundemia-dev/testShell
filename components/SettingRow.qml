import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    default property alias control: controlContainer.data
    property string label: ""
    property string description: ""
    property bool showSeparator: true

    // Optional inline hint shown as an info glyph next to the label.
    property string hintText: ""
    property url hintMedia: ""

    // When true, the row is hidden unless the settings UI is in advanced mode.
    property bool advanced: false

    visible: !advanced || Config.general.advanced

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + (showSeparator ? separator.height + Appearance.spacing.small : 0)

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        RowLayout {
            id: rowLayout

            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            // Label + description column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    visible: root.label !== ""
                    text: root.label
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.on_surface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.description !== ""
                    text: root.description
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.on_surface_variant
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            // Hint glyph: anchored a touch above the bottom of the control so it
            // sits at a stable height instead of drifting with the label line.
            HintIcon {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: Appearance.padding.small
                text: root.hintText
                media: root.hintMedia
            }

            // Control slot
            Item {
                id: controlContainer

                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                Layout.minimumWidth: implicitWidth
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight

                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }

        // Bottom separator
        StyledRect {
            id: separator

            visible: root.showSeparator
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small
            implicitHeight: 1
            color: Colours.palette.outline_variant
            opacity: 0.3
        }
    }
}
