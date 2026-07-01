pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

// Dashboard tab — 1:1 layout of caelestia dash/Dash.qml on pShell tokens/colours.
// Cards sit on the SDF blob panel surface (nested-card colour rule).
GridLayout {
    id: root

    readonly property color cardColour: Colours.transparency.enabled
        ? Colours.layer(Colours.palette.surface_container, 2)
        : Colours.palette.surface_container

    rowSpacing: Appearance.spacing.normal
    columnSpacing: Appearance.spacing.normal

    // User
    Card {
        Layout.column: 2
        Layout.columnSpan: 3
        Layout.preferredWidth: Config.dashboard.dash.userWidth
        Layout.fillHeight: true
        radius: Appearance.rounding.large

        DashUser {}
    }

    // Weather
    Card {
        Layout.row: 0
        Layout.columnSpan: 2
        Layout.preferredWidth: Config.dashboard.dash.weatherWidth
        Layout.preferredHeight: weather.implicitHeight
        radius: Appearance.rounding.large

        DashSmallWeather { id: weather }
    }

    // Date/time
    Card {
        Layout.row: 1
        Layout.preferredWidth: dateTime.implicitWidth
        Layout.fillHeight: true
        radius: Appearance.rounding.large

        DashDateTime { id: dateTime }
    }

    // Calendar
    Card {
        Layout.row: 1
        Layout.column: 1
        Layout.columnSpan: 3
        Layout.fillWidth: true
        Layout.preferredHeight: calendar.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.large

        DashCalendar {
            id: calendar
            anchors.centerIn: parent
            width: parent.width - Appearance.padding.large * 2
        }
    }

    // Resources
    Card {
        Layout.row: 1
        Layout.column: 4
        Layout.preferredWidth: resources.implicitWidth
        Layout.fillHeight: true
        radius: Appearance.rounding.large

        DashResources { id: resources }
    }

    // Media
    Card {
        Layout.row: 0
        Layout.column: 5
        Layout.rowSpan: 2
        Layout.preferredWidth: media.implicitWidth
        Layout.fillHeight: true
        radius: Appearance.rounding.large

        DashMedia { id: media; anchors.fill: parent; anchors.margins: Appearance.padding.large }
    }

    component Card: StyledRect {
        color: root.cardColour
    }
}
