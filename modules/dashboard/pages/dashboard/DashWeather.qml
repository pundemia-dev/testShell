pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

// Compact current-weather chip backed by the Weather service.
RowLayout {
    id: root
    spacing: Appearance.spacing.normal

    StyledText {
        text: Weather.icon
        font.family: Appearance.font.family.tabler
        font.pointSize: Appearance.font.size.extraLarge
        color: Colours.palette.primary
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            text: Weather.temp
            font.pointSize: Appearance.font.size.large
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
        }
        StyledText {
            Layout.fillWidth: true
            text: Weather.description + (Weather.city ? " · " + Weather.city : "")
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.on_surface_variant
            elide: Text.ElideRight
        }
    }
}
