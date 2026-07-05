import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    required property bool isHorizontal
    required property real unitSize
    required property int activeWsId
    required property Repeater workspaces
    required property Item mask

    readonly property var cfg: Config.bar.workspaces.active
    readonly property bool isSlider: cfg.show === "slider"
    readonly property bool isTeleport: cfg.show === "teleport"

    // Resolved cross-axis size from config or auto
    readonly property real crossSize: cfg.width >= 0 && cfg.height >= 0
        ? (isHorizontal ? cfg.height : cfg.width)
        : unitSize

    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        while (i < 0)
            i += Config.bar.workspaces.shown;
        return i % Config.bar.workspaces.shown;
    }

    // Primary axis position (x for horizontal, y for vertical)
    property real leading: workspaces.count > 0
        ? (isHorizontal ? workspaces.itemAt(currentWsIdx)?.x ?? 0 : workspaces.itemAt(currentWsIdx)?.y ?? 0)
        : 0
    property real trailing: workspaces.count > 0
        ? (isHorizontal ? workspaces.itemAt(currentWsIdx)?.x ?? 0 : workspaces.itemAt(currentWsIdx)?.y ?? 0)
        : 0
    property real currentSize: workspaces.count > 0
        ? (workspaces.itemAt(currentWsIdx)?.size ?? 0)
        : 0
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (cfg.trail && isSlider && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs);
            if (!ws) return 0;
            const wsEnd = isHorizontal ? ws.x + ws.size : ws.y + ws.size;
            return Math.min(wsEnd - offset, s);
        }
        return s;
    }

    // Resolved main-axis size from config or auto
    readonly property real mainSize: {
        const cfgSize = isHorizontal ? cfg.width : cfg.height;
        return cfgSize >= 0 ? cfgSize : size;
    }

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    clip: true

    // Position on primary axis
    x: isHorizontal ? offset + mask.x : Math.round(mask.x + (mask.implicitWidth - crossSize) / 2)
    y: isHorizontal ? Math.round(mask.y + (mask.implicitHeight - crossSize) / 2) : offset + mask.y

    // Size: primary axis = animated size, cross axis from config or unitSize
    implicitWidth: isHorizontal ? mainSize : crossSize
    implicitHeight: isHorizontal ? crossSize : mainSize

    radius: cfg.rounding >= 0 ? cfg.rounding : Appearance.rounding.full
    color: cfg.bg || Colours.palette.primary

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.on_surface
        colorizationColor: root.cfg.labelColor || Colours.palette.on_primary

        x: root.isHorizontal ? -root.offset : Math.round((root.mask.implicitWidth - root.crossSize) / -2)
        y: root.isHorizontal ? Math.round((root.mask.implicitHeight - root.crossSize) / -2) : -root.offset
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
    }

    Behavior on leading {
        enabled: root.cfg.trail && root.isSlider

        EAnim {}
    }

    Behavior on trailing {
        enabled: root.cfg.trail && root.isSlider

        EAnim {
            duration: Appearance.anim.durations.normal * 2
        }
    }

    Behavior on currentSize {
        enabled: root.cfg.trail && root.isSlider

        EAnim {}
    }

    Behavior on offset {
        enabled: !root.isTeleport && !(root.cfg.trail && root.isSlider)

        EAnim {}
    }

    Behavior on size {
        enabled: !root.isTeleport && !(root.cfg.trail && root.isSlider)

        EAnim {}
    }

    component EAnim: Anim {
        easing.bezierCurve: Appearance.anim.curves.emphasized
    }
}
