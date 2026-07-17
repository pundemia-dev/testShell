import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.config

Item {
    id: root

    required property var lock

    Center {
        id: centerCol

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: Math.max(implicitWidth, centerWidth)

        lock: root.lock
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: centerCol.left
        anchors.rightMargin: Appearance.spacing.largeIncreased * 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom

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

    ColumnLayout {
        anchors.left: centerCol.right
        anchors.right: parent.right
        anchors.leftMargin: Appearance.spacing.largeIncreased * 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom

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
