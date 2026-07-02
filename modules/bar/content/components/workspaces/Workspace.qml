pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.utils
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property int index
    required property bool isHorizontal
    required property real unitSize
    required property int activeWsId
    required property var occupied
    required property int groupOffset

    readonly property bool isWorkspace: true
    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool isActive: activeWsId === ws
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    // Per-state config references
    readonly property var activeCfg: Config.bar.workspaces.active
    readonly property var occupiedCfg: Config.bar.workspaces.occupied
    readonly property var unitCfg: Config.bar.workspaces.unit

    // Resolved sizes per state (width/height are absolute pixel values, -1 = auto)
    readonly property real resolvedWidth: {
        const cfg = isActive ? activeCfg : isOccupied ? occupiedCfg : unitCfg;
        return cfg.width >= 0 ? cfg.width : unitSize;
    }
    readonly property real resolvedHeight: {
        const cfg = isActive ? activeCfg : isOccupied ? occupiedCfg : unitCfg;
        return cfg.height >= 0 ? cfg.height : unitSize;
    }
    readonly property real resolvedRounding: {
        const cfg = isActive ? activeCfg : isOccupied ? occupiedCfg : unitCfg;
        return cfg.rounding >= 0 ? cfg.rounding : Appearance.rounding.full;
    }

    readonly property real size: isHorizontal
        ? resolvedWidth + (hasWindows ? Appearance.padding.small : 0)
        : resolvedHeight + (hasWindows ? Appearance.padding.small : 0)

    implicitWidth: isHorizontal ? size : Math.max(resolvedWidth, unitSize)
    implicitHeight: isHorizontal ? Math.max(resolvedHeight, unitSize) : size

    // Per-state background
    Loader {
        id: bgLoader

        active: {
            if (root.isActive) return root.activeCfg.show === "";
            if (root.isOccupied) return root.occupiedCfg.show === "separate";
            return root.unitCfg.show === "show";
        }
        asynchronous: true

        anchors.centerIn: indicator
        width: root.resolvedWidth
        height: root.resolvedHeight

        sourceComponent: StyledRect {
            color: {
                if (root.isActive) return root.activeCfg.bg || Colours.palette.primary;
                if (root.isOccupied) return root.occupiedCfg.bg || Colours.layer(Colours.palette.surface_container_high, 2);
                return root.unitCfg.bg || "transparent";
            }
            radius: root.resolvedRounding

            Behavior on color {
                CAnim {}
            }
        }
    }

    StyledText {
        id: indicator

        x: isHorizontal ? 0 : Math.round((root.implicitWidth - width) / 2)
        y: isHorizontal ? Math.round((root.implicitHeight - height) / 2) : 0
        width: root.resolvedWidth
        height: root.resolvedHeight

        animate: true
        text: {
            // Numerals override everything
            if (Config.bar.workspaces.numerals.length > root.index)
                return Config.bar.workspaces.numerals[root.index];

            // Build display name from workspace name/id
            const ws = Niri.workspaces.values.find(w => w.idx === root.ws);
            const wsName = !ws || !ws.name || ws.name == root.ws ? root.ws : ws.name[0];
            let displayName = wsName.toString();
            if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper")
                displayName = displayName.toUpperCase();
            else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower")
                displayName = displayName.toLowerCase();

            // Per-state label (empty string = use displayName)
            const unitLabel = root.unitCfg.label || displayName;
            const occLabel = root.occupiedCfg.label || unitLabel;
            const actLabel = root.activeCfg.label || (root.isOccupied ? occLabel : unitLabel);
            return root.isActive ? actLabel : root.isOccupied ? occLabel : unitLabel;
        }
        color: {
            if (root.isActive)
                return root.activeCfg.labelColor || Colours.palette.on_primary;
            if (root.isOccupied)
                return root.occupiedCfg.labelColor || Colours.palette.on_surface;
            return root.unitCfg.labelColor || Colours.layer(Colours.palette.outline_variant, 2);
        }
        font.family: {
            if (root.isActive && root.activeCfg.labelFont)
                return root.activeCfg.labelFont;
            if (root.isOccupied && root.occupiedCfg.labelFont)
                return root.occupiedCfg.labelFont;
            return root.unitCfg.labelFont || Appearance.font.family.tabler;
        }
        font.pointSize: {
            const cfg = root.isActive ? root.activeCfg : root.isOccupied ? root.occupiedCfg : root.unitCfg;
            return cfg.fontSize >= 0 ? cfg.fontSize : Appearance.font.size.smaller;
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Loader {
        id: windows

        active: root.hasWindows
        visible: active
        asynchronous: true

        anchors {
            left: root.isHorizontal ? indicator.right : undefined
            top: root.isHorizontal ? undefined : indicator.bottom
            horizontalCenter: root.isHorizontal ? undefined : indicator.horizontalCenter
            verticalCenter: root.isHorizontal ? indicator.verticalCenter : undefined
        }

        sourceComponent: root.isHorizontal ? rowWindowsComp : colWindowsComp
    }

    Component {
        id: colWindowsComp

        Column {
            spacing: 0

            add: Transition {
                WsAnim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            move: Transition {
                WsAnim {
                    properties: "scale"
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                WsAnim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: Niri.toplevels.values.filter(c => {
                        const w = Niri.workspaces.values.find(ww => ww.id === c.workspace_id);
                        return w && w.idx === root.ws;
                    })
                }

                StyledIcon {
                    required property var modelData

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "\uebef")
                    color: Colours.palette.on_surface_variant
                    font.pointSize: Appearance.font.size.small
                }
            }
        }
    }

    Component {
        id: rowWindowsComp

        Row {
            spacing: 0

            add: Transition {
                WsAnim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            move: Transition {
                WsAnim {
                    properties: "scale"
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                WsAnim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: Niri.toplevels.values.filter(c => {
                        const w = Niri.workspaces.values.find(ww => ww.id === c.workspace_id);
                        return w && w.idx === root.ws;
                    })
                }

                StyledIcon {
                    required property var modelData

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "\uebef")
                    color: Colours.palette.on_surface_variant
                    font.pointSize: Appearance.font.size.small
                }
            }
        }
    }

    Behavior on implicitWidth {
        WsAnim {}
    }

    Behavior on implicitHeight {
        WsAnim {}
    }

    component WsAnim: NumberAnimation {
        duration: Appearance.anim.durations.normal
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.curves.standard
    }
}
