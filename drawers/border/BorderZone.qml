pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.utils

// One of 8 logical zones around the screen perimeter. Renders 1 (side) or 2
// (corner) blocking debug MouseArea strips along its edge(s), with geometry
// derived from the edge-nearest bgs (layer-1 + overlays) on the zone's rail.
//
// Zone indexing (clockwise from top-left):
//   0 topLeft     1 top         2 topRight
//   7 left                      3 right
//   6 bottomLeft  5 bottom      4 bottomRight
Item {
    id: root

    required property var manager
    required property int zoneIdx
    required property int zWidth
    required property int zHeight
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area

    anchors.fill: parent

    // Rail this zone fires events to (1:1 mapping, see BackgroundsManager).
    readonly property int rail: manager.railForZone(zoneIdx)

    // Strip-hover dedup: cursor entering ANY of the 1-2 strips of this zone
    // counts as a single rail hover. Transitions from 0 → 1 strip hovered
    // fires the InteractionManager.fireHover; 1 → 0 just decrements.
    property int _stripsHovered: 0

    function _stripEnter() {
        _stripsHovered++;
        if (_stripsHovered === 1) InteractionManager.fireHover(rail);
    }

    function _stripExit() {
        if (_stripsHovered > 0) _stripsHovered--;
    }

    // ── Side flags (which screen edges this zone touches) ────────────
    readonly property var _sides: manager.zoneSides(zoneIdx)
    readonly property bool touchTop: _sides.top ?? false
    readonly property bool touchRight: _sides.right ?? false
    readonly property bool touchBottom: _sides.bottom ?? false
    readonly property bool touchLeft: _sides.left ?? false

    // ── Edge-nearest bgs in this zone's rail ─────────────────────────
    // Explicit dependencies on manager.rails AND manager.slotRects so QML
    // re-evaluates whenever either changes (functions don't auto-track
    // their property reads — we anchor them here).
    readonly property var _railsRef: manager.rails
    readonly property var _slotRectsRef: manager.slotRects
    readonly property var _entries: {
        void _railsRef;
        return manager.zoneEdgeNearestEntries(zoneIdx);
    }
    readonly property var _topmost: {
        void _railsRef;
        return manager.zoneTopmostEntry(zoneIdx);
    }
    readonly property bool _hasEntries: _entries.length > 0

    // ── Per-entry painted rect ───────────────────────────────────────
    // Primary source: manager.slotRects[arrivalSeq] (live painted geometry
    // published by WindowSlot). Fallback (for the brief window before
    // WindowSlot runs its first frame): synthesized from wrapper data the
    // same way WindowSlot computes ownX/ownY.
    function _entryRect(entry) {
        if (!entry) return null;
        const live = manager.slotRectByArrivalSeq(entry.arrivalSeq);
        if (live && live.w > 0 && live.h > 0)
            return { x: live.x, y: live.y, w: live.w, h: live.h };

        const wrapper = entry.wrapper;
        if (!wrapper) return null;
        const w = wrapper.wrapperWidth || 0;
        const h = wrapper.wrapperHeight || 0;
        if (w <= 0 || h <= 0) return null;

        const isPinned = wrapper.pinned ?? false;
        const isOverlay = (wrapper.mode ?? "push") === "overlay";
        const noEdge = isPinned || isOverlay;

        const eL = noEdge ? 0 : root.left_area;
        const eR = noEdge ? 0 : root.right_area;
        const eT = noEdge ? 0 : root.top_area;
        const eB = noEdge ? 0 : root.bottom_area;

        const aLeft = wrapper.aLeft ?? false;
        const aRight = wrapper.aRight ?? false;
        const aTop = wrapper.aTop ?? false;
        const aBottom = wrapper.aBottom ?? false;
        const aHC = wrapper.aHorizontalCenter ?? false;
        const aVC = wrapper.aVerticalCenter ?? false;
        const mL = wrapper.mLeft ?? 0;
        const mR = wrapper.mRight ?? 0;
        const mT = wrapper.mTop ?? 0;
        const mB = wrapper.mBottom ?? 0;
        const hCO = wrapper.hCenterOffset ?? 0;
        const vCO = wrapper.vCenterOffset ?? 0;

        let x, y;
        if (aHC && !aLeft && !aRight) x = (root.zWidth / 2) - (w / 2) + hCO;
        else if (aLeft) x = mL + eL;
        else if (aRight) x = root.zWidth - w - mR - eR;
        else x = 0;

        if (aVC && !aTop && !aBottom) y = (root.zHeight / 2) - (h / 2) + vCO;
        else if (aTop) y = mT + eT;
        else if (aBottom) y = root.zHeight - h - mB - eB;
        else y = 0;

        return { x: x, y: y, w: w, h: h };
    }

    // ── Projection extents (union of edge-nearest bg rects) ──────────
    readonly property var _proj: {
        void _slotRectsRef;
        void _railsRef;
        let xMin = Infinity, xMax = -Infinity;
        let yMin = Infinity, yMax = -Infinity;
        for (const entry of _entries) {
            const r = _entryRect(entry);
            if (!r) continue;
            xMin = Math.min(xMin, r.x);
            xMax = Math.max(xMax, r.x + r.w);
            yMin = Math.min(yMin, r.y);
            yMax = Math.max(yMax, r.y + r.h);
        }
        if (xMin === Infinity) return null;
        return { xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax };
    }

    // ── Strip thickness (perpendicular to edge) ──────────────────────
    function _topmostMargin(side) {
        const w = _topmost ? _topmost.wrapper : null;
        if (!w) return 0;
        if (side === "top")    return w.mTop ?? 0;
        if (side === "right")  return w.mRight ?? 0;
        if (side === "bottom") return w.mBottom ?? 0;
        if (side === "left")   return w.mLeft ?? 0;
        return 0;
    }

    function _stripThickness(side) {
        const t = (Config.border.thickness ?? 0) + _topmostMargin(side);
        if (t > 0) return t;
        return Config.border.defaultMouseAreaThickness ?? 10;
    }

    readonly property int _defaultLen: Config.border.defaultZoneLength ?? 100

    // ── Top strip geometry (for zones touching top edge) ─────────────
    readonly property int _topStripX: {
        if (!touchTop) return 0;
        if (_proj) return Math.max(0, _proj.xMin);
        // Empty zone: anchor at corner for corner zones, center for side
        if (zoneIdx === 0) return 0;                       // topLeft
        if (zoneIdx === 2) return Math.max(0, zWidth - _defaultLen); // topRight
        return Math.max(0, (zWidth - _defaultLen) / 2);    // top (zone 1)
    }
    readonly property int _topStripW: {
        if (!touchTop) return 0;
        if (_proj) return Math.max(0, _proj.xMax - _proj.xMin);
        return _defaultLen;
    }
    readonly property int _topStripH: touchTop ? _stripThickness("top") : 0

    // ── Bottom strip geometry ────────────────────────────────────────
    readonly property int _botStripX: {
        if (!touchBottom) return 0;
        if (_proj) return Math.max(0, _proj.xMin);
        if (zoneIdx === 6) return 0;                       // bottomLeft
        if (zoneIdx === 4) return Math.max(0, zWidth - _defaultLen); // bottomRight
        return Math.max(0, (zWidth - _defaultLen) / 2);    // bottom (zone 5)
    }
    readonly property int _botStripW: {
        if (!touchBottom) return 0;
        if (_proj) return Math.max(0, _proj.xMax - _proj.xMin);
        return _defaultLen;
    }
    readonly property int _botStripH: touchBottom ? _stripThickness("bottom") : 0

    // ── Left strip geometry ──────────────────────────────────────────
    readonly property int _leftStripY: {
        if (!touchLeft) return 0;
        if (_proj) return Math.max(0, _proj.yMin);
        if (zoneIdx === 0) return 0;                       // topLeft
        if (zoneIdx === 6) return Math.max(0, zHeight - _defaultLen); // bottomLeft
        return Math.max(0, (zHeight - _defaultLen) / 2);   // left (zone 7)
    }
    readonly property int _leftStripH: {
        if (!touchLeft) return 0;
        if (_proj) return Math.max(0, _proj.yMax - _proj.yMin);
        return _defaultLen;
    }
    readonly property int _leftStripW: touchLeft ? _stripThickness("left") : 0

    // ── Right strip geometry ─────────────────────────────────────────
    readonly property int _rightStripY: {
        if (!touchRight) return 0;
        if (_proj) return Math.max(0, _proj.yMin);
        if (zoneIdx === 2) return 0;                       // topRight
        if (zoneIdx === 4) return Math.max(0, zHeight - _defaultLen); // bottomRight
        return Math.max(0, (zHeight - _defaultLen) / 2);   // right (zone 3)
    }
    readonly property int _rightStripH: {
        if (!touchRight) return 0;
        if (_proj) return Math.max(0, _proj.yMax - _proj.yMin);
        return _defaultLen;
    }
    readonly property int _rightStripW: touchRight ? _stripThickness("right") : 0

    // ── Debug visual colour (cycle through palette by zoneIdx) ───────
    readonly property color _debugColor: {
        const palette = [
            Qt.rgba(1, 0.3, 0.3, 0.35),  // 0 topLeft   red
            Qt.rgba(1, 0.6, 0.2, 0.35),  // 1 top       orange
            Qt.rgba(1, 0.9, 0.2, 0.35),  // 2 topRight  yellow
            Qt.rgba(0.5, 1, 0.3, 0.35),  // 3 right     green
            Qt.rgba(0.3, 1, 0.8, 0.35),  // 4 botRight  teal
            Qt.rgba(0.3, 0.6, 1, 0.35),  // 5 bottom    blue
            Qt.rgba(0.6, 0.4, 1, 0.35),  // 6 botLeft   purple
            Qt.rgba(1, 0.4, 0.9, 0.35)   // 7 left      pink
        ];
        return palette[zoneIdx] ?? Qt.rgba(0.5, 0.5, 0.5, 0.35);
    }

    // ── Strip prefab ────────────────────────────────────────────────
    // Each visible strip (1 for side zone, 2 for corner zone) carries the
    // same set of input handlers wired to InteractionManager:
    //   - hover (dedup via zone's _stripsHovered counter)
    //   - click (advances stack)
    //   - slide (press inside, drag out → fires once per gesture)
    //   - drop (DragEvent with file/text payload)
    component InteractionStrip: Rectangle {
        id: strip
        color: root._debugColor

        DropArea {
            anchors.fill: parent
            onEntered: InteractionManager.fireDrop(root.rail)
        }

        MouseArea {
            id: strip_mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            property bool _slideArmed: false

            onEntered: root._stripEnter()
            onExited: root._stripExit()
            onClicked: InteractionManager.fireClick(root.rail)

            onPressed: { _slideArmed = true; }
            onReleased: { _slideArmed = false; }
            onCanceled: { _slideArmed = false; }
            onPositionChanged: mouse => {
                if (!_slideArmed) return;
                const inside = mouse.x >= 0 && mouse.x <= width
                            && mouse.y >= 0 && mouse.y <= height;
                if (!inside) {
                    InteractionManager.fireSlide(root.rail);
                    _slideArmed = false;
                }
            }
        }
    }

    // ── Strips ───────────────────────────────────────────────────────
    InteractionStrip {
        visible: root.touchTop
        x: root._topStripX
        y: 0
        width: root._topStripW
        height: root._topStripH
    }

    InteractionStrip {
        visible: root.touchRight
        x: root.zWidth - root._rightStripW
        y: root._rightStripY
        width: root._rightStripW
        height: root._rightStripH
    }

    InteractionStrip {
        visible: root.touchBottom
        x: root._botStripX
        y: root.zHeight - root._botStripH
        width: root._botStripW
        height: root._botStripH
    }

    InteractionStrip {
        visible: root.touchLeft
        x: 0
        y: root._leftStripY
        width: root._leftStripW
        height: root._leftStripH
    }
}
