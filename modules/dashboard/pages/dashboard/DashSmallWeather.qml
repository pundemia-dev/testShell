pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick

// Weather chip: big glyph + temperature + description. 1:1 port of caelestia
// dash/SmallWeather.qml (icon glyph comes from the Weather service, already a
// tabler glyph).
Item {
    id: root

    anchors.centerIn: parent

    implicitWidth: icon.implicitWidth + info.implicitWidth + info.anchors.leftMargin
    implicitHeight: Math.max(icon.implicitHeight, info.implicitHeight) + Appearance.padding.large * 2

    Component.onCompleted: Weather.reload()

    StyledText {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        text: Weather.icon
        font.family: Appearance.font.family.tabler
        font.pointSize: Appearance.font.size.extraLarge * 1.6
        color: Colours.palette.secondary
    }

    Column {
        id: info
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: icon.right
        anchors.leftMargin: Appearance.spacing.largeIncreased
        spacing: Appearance.spacing.extraSmall

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            animate: true
            text: Weather.temp
            color: Colours.palette.primary
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            animate: true
            text: Weather.description
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.on_surface_variant
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.parent.width - icon.implicitWidth - info.anchors.leftMargin - Appearance.padding.large)
        }
    }
}
