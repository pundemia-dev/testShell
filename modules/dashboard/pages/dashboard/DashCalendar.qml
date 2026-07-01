pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import M3Shapes
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Month calendar with prev/next/today navigation. Port of caelestia
// dash/Calendar.qml minus the M3Shapes "sunny" today indicator (replaced by a
// simple filled circle behind today).
ColumnLayout {
    id: root

    property date currentDate: new Date()
    readonly property int currMonth: currentDate.getMonth()
    readonly property int currYear: currentDate.getFullYear()

    spacing: Appearance.spacing.small

    // Month navigation header
    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        IconButton {
            type: IconButton.Text
            icon: "\uea60" // tabler chevron-left
            onClicked: root.currentDate = new Date(root.currYear, root.currMonth - 1, 1)
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: grid.title
            color: Colours.palette.primary
            font.pointSize: Appearance.font.size.normal
            font.weight: Font.DemiBold

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentDate = new Date()
            }
        }

        IconButton {
            type: IconButton.Text
            icon: "\uea61" // tabler chevron-right
            onClicked: root.currentDate = new Date(root.currYear, root.currMonth + 1, 1)
        }
    }

    DayOfWeekRow {
        id: daysRow
        Layout.fillWidth: true
        locale: grid.locale

        delegate: StyledText {
            required property var model
            horizontalAlignment: Text.AlignHCenter
            text: model.shortName
            font.pointSize: Appearance.font.size.small
            font.weight: Font.Medium
            color: (model.day === 0 || model.day === 6) ? Colours.palette.tertiary : Colours.palette.on_surface
        }
    }

    MonthGrid {
        id: grid
        Layout.fillWidth: true
        month: root.currMonth
        year: root.currYear
        spacing: 2
        locale: Qt.locale()

        delegate: Item {
            id: dayItem
            required property var model

            implicitWidth: implicitHeight
            implicitHeight: dayText.implicitHeight + Appearance.padding.small

            // Today gets the signature rotating "Sunny" M3 shape behind it.
            MaterialShape {
                anchors.centerIn: parent
                implicitSize: (Math.max(parent.width, parent.height) + Appearance.padding.small) / 1.5
                visible: dayItem.model.today
                shape: MaterialShape.Sunny
                color: Colours.palette.primary
            }

            StyledText {
                id: dayText
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: grid.locale.toString(dayItem.model.day)
                font.pointSize: Appearance.font.size.small
                opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                color: {
                    if (dayItem.model.today)
                        return Colours.palette.on_primary;
                    const dow = dayItem.model.date.getDay();
                    if (dow === 0 || dow === 6)
                        return Colours.palette.tertiary;
                    return Colours.palette.on_surface_variant;
                }
            }
        }
    }
}
