pragma ComponentBehavior: Bound

import qs.services
import qs.config
import qs.components
import qs.components.effects
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

StyledClippingRect {
    id: root

    property ShellScreen screen

    readonly property bool isHorizontal: Config.bar.orientation
    readonly property bool onSpecial: false
    readonly property int activeWsId: {
        if (!Config.bar.workspaces.perMonitorWorkspaces) { const focused = Niri.workspaces.values.find(w => w.is_focused); return focused ? focused.idx : 1; }
        const mon = Niri.monitorFor(screen);
        if (!mon) return 1;
        const ws = Niri.workspaces.values.find(w => w.output === mon.name && w.is_active);
        return ws ? ws.idx : 1;
    }

    readonly property var occupied: Niri.workspaces.values.reduce((acc, curr) => {
        // Niri workspace is occupied if it has windows
        acc[curr.idx] = true; 
        return acc;
    }, {})
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown
    readonly property real unitSize: Config.bar.group.thickness - Appearance.padding.small * 2
    readonly property real wsSpacing: Config.bar.workspaces.spacing >= 0
        ? Config.bar.workspaces.spacing
        : Math.round(Appearance.spacing.small / 2)

    // Deterministic main-axis size: doesn't depend on layout engine timing
    readonly property real totalMainSize: Config.bar.workspaces.shown * unitSize
        + Math.max(0, Config.bar.workspaces.shown - 1) * wsSpacing

    property real blur: onSpecial ? 1 : 0

    implicitWidth: isHorizontal
        ? Math.ceil((Math.max(layout.childrenRect.width, totalMainSize) + Appearance.padding.small * 2) / 2) * 2
        : Math.ceil((unitSize + Appearance.padding.small * 2) / 2) * 2
    implicitHeight: isHorizontal
        ? Math.ceil((unitSize + Appearance.padding.small * 2) / 2) * 2
        : Math.ceil((Math.max(layout.childrenRect.height, totalMainSize) + Appearance.padding.small * 2) / 2) * 2

    color: Colours.tPalette.surface_container
    radius: Config.bar.workspaces.rounding >= 0 ? Config.bar.workspaces.rounding : Appearance.rounding.full

    Item {
        id: normalContent

        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            active: Config.bar.workspaces.occupied.show !== ""

            anchors.fill: parent
            anchors.margins: Appearance.padding.small

            sourceComponent: OccupiedBg {
                isHorizontal: root.isHorizontal
                unitSize: root.unitSize
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: root.groupOffset
            }
        }

        FlexboxLayout {
            id: layout

            x: Appearance.padding.small
            y: Appearance.padding.small
            direction: root.isHorizontal ? FlexboxLayout.Row : FlexboxLayout.Column
            alignItems: FlexboxLayout.AlignCenter
            gap: root.wsSpacing



            Repeater {
                id: workspaces

                model: Config.bar.workspaces.shown

                Workspace {
                    isHorizontal: root.isHorizontal
                    unitSize: root.unitSize
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    groupOffset: root.groupOffset
                }
            }
        }

        Loader {
            active: Config.bar.workspaces.active.show !== ""

            sourceComponent: ActiveIndicator {
                isHorizontal: root.isHorizontal
                unitSize: root.unitSize
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
            }
        }

        MouseArea {
            anchors.fill: layout

            onClicked: event => {
                const child = layout.childAt(event.x, event.y);
                if (!child || child.ws === undefined)
                    return;
                if (1 !== child.ws)
                    Niri.dispatch(`focus-workspace ${child.ws}`);
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Loader {
        id: specialWs

        anchors.fill: parent
        anchors.margins: Appearance.padding.small

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
            isHorizontal: root.isHorizontal
            unitSize: root.unitSize
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Behavior on blur {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
