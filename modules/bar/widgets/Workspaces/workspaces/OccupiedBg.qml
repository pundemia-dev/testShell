pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property bool isHorizontal
    required property real unitSize
    required property Repeater workspaces
    required property var occupied
    required property int groupOffset

    readonly property var cfg: Config.bar.workspaces.occupied
    readonly property bool isMerge: cfg.show === "merge"
    readonly property real resolvedRounding: cfg.rounding >= 0 ? cfg.rounding : Appearance.rounding.full
    readonly property color resolvedBg: cfg.bg || Colours.layer(Colours.palette.surface_container_high, 2)

    property list<var> pills: []

    onOccupiedChanged: {
        if (!occupied) return;

        if (isMerge) {
            updateMergePills();
        } else {
            updateSeparatePills();
        }
    }

    onIsMergeChanged: {
        // Clear and rebuild when mode changes
        pills.splice(0, pills.length).forEach(p => p.destroy());
        if (occupied)
            isMerge ? updateMergePills() : updateSeparatePills();
    }

    function updateMergePills(): void {
        let count = 0;
        const start = groupOffset;
        const end = start + Config.bar.workspaces.shown;
        for (const [ws, occ] of Object.entries(occupied)) {
            if (ws > start && ws <= end && occ) {
                const isFirstInGroup = Number(ws) === start + 1;
                const isLastInGroup = Number(ws) === end;
                if (isFirstInGroup || !occupied[ws - 1]) {
                    if (pills[count])
                        pills[count].start = ws;
                    else
                        pills.push(pillComp.createObject(root, {
                            start: ws
                        }));
                    count++;
                }
                if ((isLastInGroup || !occupied[ws + 1]) && pills[count - 1])
                    pills[count - 1].end = ws;
            }
        }
        if (pills.length > count)
            pills.splice(count, pills.length - count).forEach(p => p.destroy());
    }

    function updateSeparatePills(): void {
        let count = 0;
        const start = groupOffset;
        const end = start + Config.bar.workspaces.shown;
        for (const [ws, occ] of Object.entries(occupied)) {
            if (ws > start && ws <= end && occ) {
                if (pills[count]) {
                    pills[count].start = ws;
                    pills[count].end = ws;
                } else {
                    pills.push(pillComp.createObject(root, {
                        start: ws,
                        end: ws
                    }));
                }
                count++;
            }
        }
        if (pills.length > count)
            pills.splice(count, pills.length - count).forEach(p => p.destroy());
    }

    Repeater {
        model: ScriptModel {
            values: root.pills.filter(p => p)
        }

        StyledRect {
            id: rect

            required property var modelData

            readonly property Workspace startWs: root.workspaces.count > 0 ? root.workspaces.itemAt(getWsIdx(modelData.start)) ?? null : null
            readonly property Workspace endWs: root.workspaces.count > 0 ? root.workspaces.itemAt(getWsIdx(modelData.end)) ?? null : null

            function getWsIdx(ws: int): int {
                let i = ws - 1;
                while (i < 0)
                    i += Config.bar.workspaces.shown;
                return i % Config.bar.workspaces.shown;
            }

            // Position on primary axis from start workspace
            x: root.isHorizontal
                ? (startWs?.x ?? 0) - 1
                : 0
            y: root.isHorizontal
                ? 0
                : (startWs?.y ?? 0) - 1

            // Primary axis: span from start to end workspace
            // Cross axis: unitSize
            implicitWidth: root.isHorizontal
                ? (startWs && endWs ? endWs.x + endWs.size - startWs.x + 2 : 0)
                : root.unitSize + 2
            implicitHeight: root.isHorizontal
                ? root.unitSize + 2
                : (startWs && endWs ? endWs.y + endWs.size - startWs.y + 2 : 0)

            anchors.verticalCenter: root.isHorizontal ? root.verticalCenter : undefined
            anchors.horizontalCenter: root.isHorizontal ? undefined : root.horizontalCenter

            color: root.resolvedBg
            radius: root.resolvedRounding

            scale: 0
            Component.onCompleted: scale = 1

            Behavior on scale {
                PillAnim {
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            Behavior on x {
                PillAnim {}
            }

            Behavior on y {
                PillAnim {}
            }

            Behavior on implicitWidth {
                PillAnim {}
            }

            Behavior on implicitHeight {
                PillAnim {}
            }
        }
    }

    component Pill: QtObject {
        property int start
        property int end
    }

    Component {
        id: pillComp

        Pill {}
    }

    component PillAnim: NumberAnimation {
        duration: Appearance.anim.durations.normal
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.curves.standard
    }
}
