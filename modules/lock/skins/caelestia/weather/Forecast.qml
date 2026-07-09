import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia
import qs.components
import qs.services
import qs.config

StyledRect {
    id: root

    color: Colours.layer(Colours.palette.surface_container_high, 2)
    radius: Appearance.rounding.extraLargeIncreased
    implicitHeight: header.anchors.margins + header.implicitHeight + Appearance.spacing.medium + layout.implicitHeight + layout.anchors.bottomMargin

    RowLayout {
        id: header

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Appearance.padding.largeIncreased

        spacing: Appearance.spacing.small

        StyledIcon {
            Layout.topMargin: Math.round(fontInfo.pointSize * 0.12)
            text: "" // tabler clock
            font.pointSize: Appearance.font.icon.medium.pointSize
            font.weight: title.font.weight
        }

        StyledText {
            id: title

            text: qsTr("Hourly forecast")
            font: Appearance.font.title.medium
        }
    }

    RowLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.largeIncreased
        anchors.margins: Appearance.padding.large

        spacing: Appearance.spacing.small

        Repeater {
            model: CUtils.clamp(Math.floor((layout.width + layout.spacing) / (Config.lock.sizes.forecastItemWidth + layout.spacing)), 0, Weather.hourly.length)

            ColumnLayout {
                id: hour

                required property int index
                readonly property var cond: Weather.hourly[index]

                Layout.fillWidth: true
                spacing: Appearance.spacing.extraSmall

                MaterialShape {
                    Layout.alignment: Qt.AlignHCenter
                    implicitSize: temp.implicitHeight + Appearance.padding.medium * 2
                    shape: MaterialShape.Cookie4Sided
                    color: Qt.alpha(Colours.palette.primary, hour.index === 0 ? 1 : 0)

                    Behavior on color {
                        CAnim {}
                    }

                    StyledText {
                        id: temp

                        anchors.centerIn: parent
                        text: Weather.formatTemp(hour.cond?.tempC).slice(0, -1) // Remove C/F
                        color: hour.index === 0 ? Colours.palette.on_primary : Colours.palette.on_surface
                        font: Appearance.font.title.medium
                    }
                }

                StyledIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Icons.getWeatherIconWmo(hour.cond?.code)
                    color: Colours.palette.secondary
                    font.pointSize: Appearance.font.icon.large.pointSize
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: (hour.cond?.precip ?? 0) + "%"
                    color: Colours.palette.primary
                }

                StyledText {
                    Layout.topMargin: Appearance.spacing.extraSmall
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        if (hour.index === 0)
                            return qsTr("Now");
                        const h = hour.cond?.hour ?? 0;
                        if (Config.services?.useTwelveHourClock ?? false)
                            return `${h % 12 || 12}${h < 12 ? "am" : "pm"}`;
                        return `${String(h).padStart(2, "0")}:00`;
                    }
                    color: Colours.palette.on_surface_variant
                    font: Appearance.font.body.medium
                }
            }
        }
    }
}
