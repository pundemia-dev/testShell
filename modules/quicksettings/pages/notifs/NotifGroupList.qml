pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick

// Ported from caelestia sidebar/NotifGroupList, with the C++ LazyListView
// swapped for a Column + Repeater on a ScriptModel (history is capped at
// Config.notifs.historyLimit, so lazy delegate management buys nothing here).
// Collapsed groups show the first groupPreviewNum active notifications;
// expanded groups show everything. Rows swipe horizontally to dismiss.
Column {
    id: root

    required property list<var> notifs
    required property bool expanded

    signal requestToggleExpand(bool expand)

    anchors.left: parent.left
    anchors.right: parent.right

    spacing: Appearance.spacing.extraSmall

    Repeater {
        model: ScriptModel {
            values: {
                if (root.expanded)
                    return root.notifs;

                let count = 0;
                let i = 0;
                const previewNum = Config.notifs.groupPreviewNum;
                while (i < root.notifs.length && count < previewNum) {
                    if (!(root.notifs[i]?.closed ?? true))
                        count++;
                    i++;
                }

                return root.notifs.slice(0, i);
            }
        }

        delegate: MouseArea {
            id: notif

            required property int index
            required property var modelData

            property int startY

            Component.onCompleted: modelData?.lock(this)
            Component.onDestruction: modelData?.unlock(this)

            width: parent?.width ?? 0
            implicitHeight: notifInner.implicitHeight

            hoverEnabled: true
            cursorShape: notifInner.body?.hoveredLink ? Qt.PointingHandCursor : pressed ? Qt.ClosedHandCursor : undefined
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            preventStealing: !root.expanded
            enabled: !(modelData?.closed ?? true)

            drag.target: this
            drag.axis: Drag.XAxis

            onPressed: event => {
                startY = event.y;
                if (event.button === Qt.RightButton)
                    root.requestToggleExpand(!root.expanded);
                else if (event.button === Qt.MiddleButton)
                    modelData?.close();
            }
            onPositionChanged: event => {
                if (pressed && !root.expanded) {
                    const diffY = event.y - startY;
                    if (Math.abs(diffY) > Config.notifs.expandThreshold)
                        root.requestToggleExpand(diffY > 0);
                }
            }
            onReleased: event => {
                if (Math.abs(x) < width * Config.notifs.clearThreshold)
                    x = 0;
                else
                    modelData?.close();
            }

            // Slide out + collapse when the notification is closed, then
            // release the lock so the service drops it from the list.
            ParallelAnimation {
                running: notif.modelData?.closed ?? false
                onFinished: notif.modelData?.unlock(notif)

                Anim {
                    type: Anim.DefaultEffects
                    target: notif
                    property: "opacity"
                    to: 0
                }
                Anim {
                    target: notif
                    property: "x"
                    to: notif.x >= 0 ? notif.width : -notif.width
                }
                Anim {
                    target: notif
                    property: "implicitHeight"
                    to: 0
                }
            }

            Notif {
                id: notifInner

                anchors.left: parent.left
                anchors.right: parent.right
                modelData: notif.modelData
                expanded: root.expanded
            }

            Behavior on x {
                Anim {}
            }
        }
    }
}
