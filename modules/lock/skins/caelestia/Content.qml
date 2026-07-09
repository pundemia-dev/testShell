import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.config

RowLayout {
    id: root

    required property var lock

    spacing: Appearance.spacing.largeIncreased * 2

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.medium

        WeatherInfo {
            Layout.fillWidth: true
            rootHeight: root.height
        }

        Fetch {
            Layout.fillWidth: true
            rootHeight: root.height
        }

        Media {
            Layout.fillWidth: true
            Layout.fillHeight: true
            lock: root.lock
        }
    }

    Center {
        lock: root.lock
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.medium

        Resources {
            Layout.fillWidth: true
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            bottomRightRadius: Appearance.rounding.extraLarge
            radius: Appearance.rounding.medium
            color: Colours.tPalette.surface_container

            NotifDock {
                lock: root.lock
            }
        }
    }
}
