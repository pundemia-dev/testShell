import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts
import qs.components.containers

// Generic page for a discovered third-party SettingsSchema. Rendered via
// SchemaForm; values persist in Config.custom[schema.key]. See
// docs/development/settings.md.
Flickable {
    id: root

    property var schema: null

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: root.schema?.title ?? ""
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        StyledText {
            text: qsTr("Third-party module")
            font.pointSize: Appearance.font.size.normal
            color: Colours.palette.on_surface_variant
            Layout.fillWidth: true
            Layout.bottomMargin: Appearance.spacing.small
        }

        SettingSection {
            title: qsTr("Settings")
            icon: root.schema?.icon ?? ""

            SchemaForm {
                Layout.fillWidth: true
                schema: root.schema
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
