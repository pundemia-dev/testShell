import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.config

ColumnLayout {
    id: root

    required property int rootHeight

    spacing: Appearance.spacing.extraSmall

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        animate: true
        text: Weather.description
        color: Colours.palette.on_surface_variant
        font: Appearance.font.body.large
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Appearance.spacing.medium

        StyledText {
            id: temp

            animate: true
            text: Weather.temp
            color: Colours.palette.primary
            font.family: Appearance.font.family.sans
            font.pointSize: Math.round(Appearance.font.headline.large.pointSize * 1.5)
            font.weight: Font.DemiBold
        }

        StyledIcon {
            animate: true
            text: Weather.icon
            color: Colours.palette.secondary
            font.pointSize: Math.round(Appearance.font.headline.large.pointSize * 1.5)
        }
    }

    StyledText {
        visible: root.rootHeight > Config.lock.sizes.showWeatherDetailsHeight
        Layout.alignment: Qt.AlignHCenter
        animate: true
        text: qsTr("Feels like %1").arg(Weather.feelsLike)
        color: Colours.palette.on_surface_variant
        font: Appearance.font.body.large
    }

    StyledText {
        visible: root.rootHeight > Config.lock.sizes.showWeatherDetailsHeight
        Layout.alignment: Qt.AlignHCenter
        animate: true
        text: {
            const today = Weather.forecast[0];
            return qsTr("High %1 • Low %2").arg(Weather.formatTemp(today?.max)).arg(Weather.formatTemp(today?.min));
        }
        color: Colours.palette.on_surface_variant
        font: Appearance.font.body.medium
    }
}
