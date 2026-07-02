pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.utils
import QtQuick
import QtQuick.Layouts

// Weather tab — 1:1 port of caelestia WeatherTab on pShell tokens/colours/tabler
// glyphs, driven by the Weather service. Header (city + sunrise/sunset), a big
// current block, humidity/feels-like/wind cards, and a 7-day forecast row.
Item {
    id: root

    readonly property color cardColour: Colours.transparency.enabled
        ? Colours.layer(Colours.palette.surface_container, 2)
        : Colours.palette.surface_container

    implicitWidth: Math.max(840, layout.implicitWidth)
    implicitHeight: layout.implicitHeight

    Component.onCompleted: Weather.reload()

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: Appearance.spacing.medium

        // Header.
        RowLayout {
            Layout.leftMargin: Appearance.padding.large
            Layout.rightMargin: Appearance.padding.large
            Layout.fillWidth: true

            Column {
                spacing: Appearance.spacing.small

                StyledText {
                    text: Weather.city || qsTr("Loading...")
                    font.pointSize: 28
                    font.weight: Font.DemiBold
                    color: Colours.palette.on_surface
                }
                StyledText {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.on_surface_variant
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: Appearance.spacing.large

                WeatherStat {
                    glyph: "\uef1c" // tabler sunrise
                    label: qsTr("Sunrise")
                    value: Weather.sunrise
                    colour: Colours.palette.tertiary
                }
                WeatherStat {
                    glyph: "\uec31" // tabler sunset
                    label: qsTr("Sunset")
                    value: Weather.sunset
                    colour: Colours.palette.tertiary
                }
            }
        }

        // Big current block.
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: bigInfoRow.implicitHeight + Appearance.padding.small
            radius: Appearance.rounding.large
            color: root.cardColour

            RowLayout {
                id: bigInfoRow
                anchors.centerIn: parent
                spacing: Appearance.spacing.large

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: Weather.icon
                    font.family: Appearance.font.family.tabler
                    font.pointSize: Appearance.font.size.extraLarge * 3
                    color: Colours.palette.secondary
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -Appearance.spacing.small

                    StyledText {
                        text: Weather.temp
                        font.pointSize: 56
                        font.weight: Font.Medium
                        color: Colours.palette.primary
                    }
                    StyledText {
                        Layout.leftMargin: Appearance.padding.small
                        text: Weather.description
                        font.pointSize: Appearance.font.size.normal
                        color: Colours.palette.on_surface_variant
                    }
                }
            }
        }

        // Detail cards.
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.medium

            DetailCard {
                glyph: "\uea97" // tabler droplet
                label: qsTr("Humidity")
                value: Weather.humidity + "%"
                colour: Colours.palette.secondary
            }
            DetailCard {
                glyph: "\ueb38" // tabler temperature
                label: qsTr("Feels Like")
                value: Weather.feelsLike
                colour: Colours.palette.primary
            }
            DetailCard {
                glyph: "\uec34" // tabler wind
                label: qsTr("Wind")
                value: Weather.windSpeed ? Math.round(Weather.windSpeed) + " km/h" : "--"
                colour: Colours.palette.tertiary
            }
        }

        // Forecast heading.
        StyledText {
            Layout.topMargin: Appearance.spacing.medium
            Layout.leftMargin: Appearance.padding.medium
            visible: forecastRepeater.count > 0
            text: qsTr("7-Day Forecast")
            font.pointSize: Appearance.font.size.normal
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
        }

        // Forecast row.
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.medium

            Repeater {
                id: forecastRepeater
                model: Weather.forecast

                StyledRect {
                    id: fc
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: fcCol.implicitHeight + Appearance.padding.medium * 2
                    radius: Appearance.rounding.large
                    color: root.cardColour

                    ColumnLayout {
                        id: fcCol
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: fc.index === 0 ? qsTr("Today") : new Date(fc.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: Font.DemiBold
                            color: Colours.palette.primary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: new Date(fc.modelData.date).toLocaleDateString(Qt.locale(), "MMM d")
                            font.pointSize: Appearance.font.size.small
                            opacity: 0.7
                            color: Colours.palette.on_surface_variant
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Icons.getWeatherIconWmo(fc.modelData.code)
                            font.family: Appearance.font.family.tabler
                            font.pointSize: Appearance.font.size.extraLarge
                            color: Colours.palette.secondary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: `${fc.modelData.min}° / ${fc.modelData.max}°`
                            font.pointSize: Appearance.font.size.small
                            font.weight: Font.DemiBold
                            color: Colours.palette.tertiary
                        }
                    }
                }
            }
        }
    }

    component DetailCard: StyledRect {
        id: dc
        property string glyph
        property string label
        property string value
        property color colour

        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: Appearance.rounding.large
        color: root.cardColour

        Row {
            anchors.centerIn: parent
            spacing: Appearance.spacing.medium

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: dc.glyph
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.large
                color: dc.colour
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                StyledText {
                    text: dc.label
                    font.pointSize: Appearance.font.size.small
                    opacity: 0.7
                }
                StyledText {
                    text: dc.value
                    font.pointSize: Appearance.font.size.small
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    component WeatherStat: Row {
        id: ws
        property string glyph
        property string label
        property string value
        property color colour

        spacing: Appearance.spacing.small

        StyledText {
            text: ws.glyph
            font.family: Appearance.font.family.tabler
            font.pointSize: Appearance.font.size.extraLarge
            color: ws.colour
        }
        Column {
            StyledText {
                text: ws.label
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
            }
            StyledText {
                text: ws.value
                font.pointSize: Appearance.font.size.small
                font.weight: Font.DemiBold
                color: Colours.palette.on_surface
            }
        }
    }
}
