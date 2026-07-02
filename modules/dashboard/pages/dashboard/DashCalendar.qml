pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.effects
import M3Shapes
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    property date currentDate: new Date()
    readonly property int currMonth: currentDate.getMonth()
    readonly property int currYear: currentDate.getFullYear()

    spacing: Appearance.spacing.extraSmall

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.currentDate = new Date(root.currYear, root.currMonth - 1, 1);
            else if (event.angleDelta.y < 0)
                root.currentDate = new Date(root.currYear, root.currMonth + 1, 1);
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.extraSmall

        IconButton {
            type: IconButton.Text
            icon: ""
            onClicked: root.currentDate = new Date(root.currYear, root.currMonth - 1, 1)
        }

        Item {
            Layout.fillWidth: true
            implicitWidth: monthYearDisplay.implicitWidth + Appearance.padding.large * 2
            implicitHeight: monthYearDisplay.implicitHeight + Appearance.spacing.extraSmall * 2

            readonly property bool _todayMonth: {
                const now = new Date();
                return root.currMonth === now.getMonth() && root.currYear === now.getFullYear();
            }

            StateLayer {
                color: Colours.palette.primary
                radius: pressed ? Appearance.rounding.small : Appearance.rounding.large
                disabled: parent._todayMonth
                function onClicked(): void { root.currentDate = new Date(); }

                Behavior on radius { Anim { type: Anim.DefaultEffects } }
            }

            StyledText {
                id: monthYearDisplay
                anchors.centerIn: parent
                text: grid.title
                color: Colours.palette.primary
                font: Appearance.font.title.small
            }
        }

        IconButton {
            type: IconButton.Text
            icon: ""
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

    Item {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight

        MonthGrid {
            id: grid

            anchors.fill: parent
            month: root.currMonth
            year: root.currYear
            spacing: 3
            locale: Qt.locale()

            delegate: Item {
                id: dayItem
                required property var model

                implicitWidth: implicitHeight
                implicitHeight: dayText.implicitHeight + Appearance.padding.small

                StyledText {
                    id: dayText
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: grid.locale.toString(dayItem.model.day)
                    font: Appearance.font.body.small
                    opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                    color: {
                        const dow = dayItem.model.date.getDay();
                        if (dow === 0 || dow === 6)
                            return Colours.palette.tertiary;
                        return Colours.palette.on_surface_variant;
                    }
                }
            }
        }

        MaterialShape {
            id: todayIndicator

            readonly property Item todayItem: grid.contentItem.children.find(c => c.model?.today) ?? null
            property Item today: null

            onTodayItemChanged: {
                if (todayItem)
                    today = todayItem;
            }

            x: today ? today.x + (today.width - implicitWidth) / 2 : 0
            y: today ? today.y - Appearance.padding.extraSmall - 1 : 0
            implicitSize: today ? Math.max(today.implicitWidth, today.implicitHeight) + Appearance.padding.extraSmall * 2 : 0
            shape: MaterialShape.Sunny
            clip: true
            color: Colours.palette.primary

            opacity: todayItem ? 1 : 0
            scale: todayItem ? 1 : 0.7

            Colouriser {
                x: -todayIndicator.x
                y: -todayIndicator.y
                implicitWidth: grid.width
                implicitHeight: grid.height
                source: grid
                sourceColor: Colours.palette.on_surface
                colorizationColor: Colours.palette.on_primary
            }

            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
            Behavior on scale { Anim { type: Anim.FastSpatial } }
            Behavior on x { Anim {} }
            Behavior on y { Anim {} }
        }
    }
}
