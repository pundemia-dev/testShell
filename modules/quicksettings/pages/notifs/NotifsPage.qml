pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.containers
import qs.components.controls
import Quickshell
import QtQuick
import QtQuick.Layouts

// Notification history in the caelestia sidebar style: header (title + DND +
// clear-all) over app-grouped cards (NotifGroup). Groups collapse/expand via
// the count pill (or right-click / vertical drag), swipe sideways to dismiss
// a whole group, rows inside a group swipe individually.
Item {
    id: root

    readonly property var notifs: Notifs.notClosed

    // App names whose groups are currently expanded. Reassigned (not mutated
    // in place) so the NotifGroup `expanded` bindings re-evaluate.
    property list<string> expandedGroups: []

    function setGroupExpanded(app: string, expand: bool): void {
        if (expand && !expandedGroups.includes(app))
            expandedGroups = [...expandedGroups, app];
        else if (!expand && expandedGroups.includes(app))
            expandedGroups = expandedGroups.filter(a => a !== app);
    }

    RowLayout {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Notifications")
            font: Appearance.font.title.small
        }

        IconButton {
            icon: "\uece9" // tabler bell-off
            toggle: true
            isRound: true
            type: IconButton.Text
            checked: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }

        IconButton {
            icon: "\ueb41" // tabler trash
            isRound: true
            type: IconButton.Text
            disabled: root.notifs.length === 0
            onClicked: {
                for (const n of root.notifs.slice())
                    n.close();
            }
        }
    }

    StyledFlickable {
        id: view

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Appearance.spacing.medium

        clip: true
        flickableDirection: Flickable.VerticalFlick
        contentWidth: width
        contentHeight: groupList.implicitHeight

        Column {
            id: groupList

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            Repeater {
                model: ScriptModel {
                    values: {
                        const map = new Map();
                        for (const n of Notifs.notClosed)
                            map.set(n.appName, null);
                        for (const n of Notifs.list)
                            map.set(n.appName, null);
                        return [...map.keys()];
                    }
                }

                delegate: MouseArea {
                    id: group

                    required property int index
                    required property string modelData

                    readonly property bool closed: groupInner.notifCount === 0
                    property int startY

                    function closeAll(): void {
                        clearTimer.start();
                    }

                    width: parent?.width ?? 0
                    implicitHeight: groupInner.implicitHeight

                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : undefined
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    preventStealing: true
                    enabled: !closed

                    drag.target: this
                    drag.axis: Drag.XAxis

                    onPressed: event => {
                        startY = event.y;
                        if (event.button === Qt.RightButton)
                            groupInner.toggleExpand(!groupInner.expanded);
                        else if (event.button === Qt.MiddleButton)
                            closeAll();
                    }
                    onPositionChanged: event => {
                        if (pressed) {
                            const diffY = event.y - startY;
                            if (Math.abs(diffY) > Config.notifs.expandThreshold)
                                groupInner.toggleExpand(diffY > 0);
                        }
                    }
                    onReleased: event => {
                        if (Math.abs(x) < width * Config.notifs.clearThreshold)
                            x = 0;
                        else
                            closeAll();
                    }

                    // Close in batches so dismissing a huge group doesn't
                    // stall a frame (ported from caelestia's dock list).
                    Timer {
                        id: clearTimer

                        interval: 15
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: {
                            const notifs = Notifs.notClosed.filter(n => n.appName === group.modelData);
                            if (notifs.length === 0) {
                                stop();
                                return;
                            }

                            for (const n of notifs.slice(0, 30))
                                n.close();
                        }
                    }

                    // Shrink + fade the card away once every notification in
                    // the group is closed; the delegate is destroyed when the
                    // app leaves the model.
                    ParallelAnimation {
                        running: group.closed

                        Anim {
                            type: Anim.DefaultEffects
                            target: group
                            property: "opacity"
                            to: 0
                        }
                        Anim {
                            target: group
                            property: "scale"
                            to: 0.6
                        }
                        Anim {
                            target: group
                            property: "implicitHeight"
                            to: 0
                        }
                    }

                    NotifGroup {
                        id: groupInner

                        modelData: group.modelData
                        page: root
                    }

                    Behavior on x {
                        Anim {}
                    }
                }
            }
        }
    }

    StyledScrollBar {
        flickable: view
        anchors.right: parent.right
        anchors.top: view.top
        anchors.bottom: view.bottom
    }

    // Empty state.
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.notifs.length === 0
        spacing: Appearance.spacing.small

        StyledIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "\uea35" // tabler bell
            color: Colours.palette.on_surface_variant
            font.pointSize: Appearance.font.size.extraLarge
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No notifications")
            color: Colours.palette.on_surface_variant
        }
    }
}
