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
    // fires fireHover and publishes stripHovered=true; 1 → 0 publishes
    // stripHovered=false.
    property int _stripsHovered: 0
    property int _stripsDragOver: 0

    function _stripEnter() {
        _stripsHovered++;
        if (_stripsHovered === 1) {
            InteractionManager._setStripHovered(rail, true);
            InteractionManager.fireHover(rail);
        }
    }

    function _stripExit() {
        if (_stripsHovered > 0)
            _stripsHovered--;
        if (_stripsHovered === 0)
            InteractionManager._setStripHovered(rail, false);
    }

    function _dropEnter() {
        _stripsDragOver++;
        if (_stripsDragOver === 1) {
            InteractionManager._setStripDragOver(rail, true);
            InteractionManager.fireDrop(rail);
        }
    }

    function _dropExit() {
        if (_stripsDragOver > 0)
            _stripsDragOver--;
        if (_stripsDragOver === 0)
            InteractionManager._setStripDragOver(rail, false);
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
        if (!entry)
            return null;
        const live = manager.slotRectByArrivalSeq(entry.arrivalSeq);
        if (live && live.w > 0 && live.h > 0)
            return {
                x: live.x,
                y: live.y,
                w: live.w,
                h: live.h
            };

        const wrapper = entry.wrapper;
        if (!wrapper)
            return null;
        const w = wrapper.wrapperWidth || 0;
        const h = wrapper.wrapperHeight || 0;
        if (w <= 0 || h <= 0)
            return null;

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
        // Clamp the free-axis offset so the strip tracks the bg, which is
        // itself clamped to keep its facing margin off the screen edge (see
        // WindowSlot._clampHOffset / _clampVOffset).
        const clampOff = (off, span, gapLow, gapHigh) => {
            if (off === 0)
                return 0;
            const half = (span) / 2;
            const lo = gapLow - half;
            const hi = half - gapHigh;
            if (lo > hi)
                return 0;
            return Math.max(lo, Math.min(hi, off));
        };
        const hCO = clampOff(wrapper.hCenterOffset ?? 0, root.zWidth - w, mL + eL, mR + eR);
        const vCO = clampOff(wrapper.vCenterOffset ?? 0, root.zHeight - h, mT + eT, mB + eB);

        let x, y;
        if (aHC && !aLeft && !aRight)
            x = (root.zWidth / 2) - (w / 2) + hCO;
        else if (aLeft)
            x = mL + eL;
        else if (aRight)
            x = root.zWidth - w - mR - eR;
        else
            x = 0;

        if (aVC && !aTop && !aBottom)
            y = (root.zHeight / 2) - (h / 2) + vCO;
        else if (aTop)
            y = mT + eT;
        else if (aBottom)
            y = root.zHeight - h - mB - eB;
        else
            y = 0;

        return {
            x: x,
            y: y,
            w: w,
            h: h
        };
    }

    // ── Projection extents (union of edge-nearest bg rects) ──────────
    readonly property var _proj: {
        void _slotRectsRef;
        void _railsRef;
        let xMin = Infinity, xMax = -Infinity;
        let yMin = Infinity, yMax = -Infinity;
        for (const entry of _entries) {
            const r = _entryRect(entry);
            if (!r)
                continue;
            xMin = Math.min(xMin, r.x);
            xMax = Math.max(xMax, r.x + r.w);
            yMin = Math.min(yMin, r.y);
            yMax = Math.max(yMax, r.y + r.h);
        }
        if (xMin === Infinity)
            return null;
        return {
            xMin: xMin,
            xMax: xMax,
            yMin: yMin,
            yMax: yMax
        };
    }

    // ── Strip thickness (perpendicular to edge) ──────────────────────
    function _topmostMargin(side) {
        const w = _topmost ? _topmost.wrapper : null;
        if (!w)
            return 0;
        if (side === "top")
            return w.mTop ?? 0;
        if (side === "right")
            return w.mRight ?? 0;
        if (side === "bottom")
            return w.mBottom ?? 0;
        if (side === "left")
            return w.mLeft ?? 0;
        return 0;
    }

    function _stripThickness(side) {
        const def = Config.border.defaultMouseAreaThickness ?? 10;
        const margin = _topmostMargin(side);
        // Pinned AND overlay bgs sit flush at edge=0 (under the border), so
        // adding the full border thickness would push the strip onto the bg.
        // Give them only the facing margin (gap to the edge) + a small default
        // band. Push bgs (inset by the border) and empty zones also get the
        // border thickness floor.
        const w = _topmost ? _topmost.wrapper : null;
        const noEdge = !!w && ((w.pinned ?? false) || ((w.mode ?? "push") === "overlay"));
        if (noEdge)
            return margin + def;
        return margin + (Config.border.thickness ?? 0) + def;
    }

    readonly property int _defaultLen: Config.border.defaultZoneLength ?? 100

    // ── Top strip geometry (for zones touching top edge) ─────────────
    readonly property int _topStripX: {
        if (!touchTop)
            return 0;
        if (_proj)
            return Math.max(0, _proj.xMin);
        // Empty zone: anchor at corner for corner zones, center for side
        if (zoneIdx === 0)
            return 0;                       // topLeft
        if (zoneIdx === 2)
            return Math.max(0, zWidth - _defaultLen); // topRight
        return Math.max(0, (zWidth - _defaultLen) / 2);    // top (zone 1)
    }
    readonly property int _topStripW: {
        if (!touchTop)
            return 0;
        if (_proj)
            return Math.max(0, _proj.xMax - _proj.xMin);
        return _defaultLen;
    }
    readonly property int _topStripH: touchTop ? _stripThickness("top") : 0

    // ── Bottom strip geometry ────────────────────────────────────────
    readonly property int _botStripX: {
        if (!touchBottom)
            return 0;
        if (_proj)
            return Math.max(0, _proj.xMin);
        if (zoneIdx === 6)
            return 0;                       // bottomLeft
        if (zoneIdx === 4)
            return Math.max(0, zWidth - _defaultLen); // bottomRight
        return Math.max(0, (zWidth - _defaultLen) / 2);    // bottom (zone 5)
    }
    readonly property int _botStripW: {
        if (!touchBottom)
            return 0;
        if (_proj)
            return Math.max(0, _proj.xMax - _proj.xMin);
        return _defaultLen;
    }
    readonly property int _botStripH: touchBottom ? _stripThickness("bottom") : 0

    // ── Left strip geometry ──────────────────────────────────────────
    readonly property int _leftStripY: {
        if (!touchLeft)
            return 0;
        if (_proj)
            return Math.max(0, _proj.yMin);
        if (zoneIdx === 0)
            return 0;                       // topLeft
        if (zoneIdx === 6)
            return Math.max(0, zHeight - _defaultLen); // bottomLeft
        return Math.max(0, (zHeight - _defaultLen) / 2);   // left (zone 7)
    }
    readonly property int _leftStripH: {
        if (!touchLeft)
            return 0;
        if (_proj)
            return Math.max(0, _proj.yMax - _proj.yMin);
        return _defaultLen;
    }
    readonly property int _leftStripW: touchLeft ? _stripThickness("left") : 0

    // ── Right strip geometry ─────────────────────────────────────────
    readonly property int _rightStripY: {
        if (!touchRight)
            return 0;
        if (_proj)
            return Math.max(0, _proj.yMin);
        if (zoneIdx === 2)
            return 0;                       // topRight
        if (zoneIdx === 4)
            return Math.max(0, zHeight - _defaultLen); // bottomRight
        return Math.max(0, (zHeight - _defaultLen) / 2);   // right (zone 3)
    }
    readonly property int _rightStripH: {
        if (!touchRight)
            return 0;
        if (_proj)
            return Math.max(0, _proj.yMax - _proj.yMin);
        return _defaultLen;
    }
    readonly property int _rightStripW: touchRight ? _stripThickness("right") : 0

    // ── Same-edge neighbour clipping ─────────────────────────────────
    // Two adjacent zones on one edge can overlap along it (e.g. a full-height
    // side bar's strip vs the empty corner zones' fallback strips). Rule: the
    // LONGER strip is clipped to the shorter one's boundary + zoneGap, so the
    // shorter (corner trigger) is always preserved. Each zone publishes its
    // RAW (unclipped) extent and clips itself against neighbours' RAW extents,
    // so there is no feedback loop.
    function _sideOrder(side) {
        // Zones along an edge, ordered by increasing coordinate (x for
        // top/bottom, y for left/right).
        if (side === "top")
            return [0, 1, 2];
        if (side === "bottom")
            return [6, 5, 4];
        if (side === "left")
            return [0, 7, 6];
        return [2, 3, 4]; // right
    }

    function _clip(side, lo, hi) {
        void manager.zoneStrips;            // re-evaluate when neighbours change
        const gap = Config.border.zoneGap ?? 8;
        const order = _sideOrder(side);
        const i = order.indexOf(zoneIdx);
        if (i < 0)
            return { lo: lo, hi: hi };
        const myLen = hi - lo;
        let clo = lo, chi = hi;
        // lo-side neighbour (smaller coordinate)
        if (i > 0) {
            const n = manager.zoneStripExtent(order[i - 1], side);
            if (n && n.hi > clo) {
                const nLen = n.hi - n.lo;
                if (myLen > nLen || (myLen === nLen && zoneIdx > order[i - 1]))
                    clo = n.hi + gap;
            }
        }
        // hi-side neighbour (larger coordinate)
        if (i < order.length - 1) {
            const n = manager.zoneStripExtent(order[i + 1], side);
            if (n && n.lo < chi) {
                const nLen = n.hi - n.lo;
                if (myLen > nLen || (myLen === nLen && zoneIdx > order[i + 1]))
                    chi = n.lo - gap;
            }
        }
        if (chi < clo)
            chi = clo;
        return { lo: clo, hi: chi };
    }

    // RAW extents per touched side — published for neighbours to read.
    readonly property var _rawExtents: ({
            top: touchTop ? { lo: _topStripX, hi: _topStripX + _topStripW } : null,
            bottom: touchBottom ? { lo: _botStripX, hi: _botStripX + _botStripW } : null,
            left: touchLeft ? { lo: _leftStripY, hi: _leftStripY + _leftStripH } : null,
            right: touchRight ? { lo: _rightStripY, hi: _rightStripY + _rightStripH } : null
        })
    on_RawExtentsChanged: _publishExtents()
    Component.onCompleted: _publishExtents()
    function _publishExtents() {
        for (const side of ["top", "bottom", "left", "right"]) {
            const e = _rawExtents[side];
            if (e)
                manager.publishZoneStrip(zoneIdx, side, e.lo, e.hi);
        }
    }

    // Clipped extents fed to the strips (along the edge axis).
    readonly property var _clipTop: touchTop ? _clip("top", _topStripX, _topStripX + _topStripW) : null
    readonly property var _clipBot: touchBottom ? _clip("bottom", _botStripX, _botStripX + _botStripW) : null
    readonly property var _clipLeft: touchLeft ? _clip("left", _leftStripY, _leftStripY + _leftStripH) : null
    readonly property var _clipRight: touchRight ? _clip("right", _rightStripY, _rightStripY + _rightStripH) : null

    // ── Debug visual colour (cycle through palette by zoneIdx) ───────
    readonly property color _debugColor: {
        const palette = [Qt.rgba(1, 0.3, 0.3, 0.35)  // 0 topLeft   red
            , Qt.rgba(1, 0.6, 0.2, 0.35)  // 1 top       orange
            , Qt.rgba(1, 0.9, 0.2, 0.35)  // 2 topRight  yellow
            , Qt.rgba(0.5, 1, 0.3, 0.35)  // 3 right     green
            , Qt.rgba(0.3, 1, 0.8, 0.35)  // 4 botRight  teal
            , Qt.rgba(0.3, 0.6, 1, 0.35)  // 5 bottom    blue
            , Qt.rgba(0.6, 0.4, 1, 0.35)  // 6 botLeft   purple
            , Qt.rgba(1, 0.4, 0.9, 0.35)   // 7 left      pink

        // Qt.rgba(1, 0.3, 0.3, 1.0)  // 0 topLeft   red
        // , Qt.rgba(1, 0.6, 0.2, 1.0)  // 1 top       orange
        // , Qt.rgba(1, 0.9, 0.2, 1.0)  // 2 topRight  yellow
        // , Qt.rgba(0.5, 1, 0.3, 1.0)  // 3 right     green
        // , Qt.rgba(0.3, 1, 0.8, 1.0)  // 4 botRight  teal
        // , Qt.rgba(0.3, 0.6, 1, 1.0)  // 5 bottom    blue
        // , Qt.rgba(0.6, 0.4, 1, 1.0)  // 6 botLeft   purple
        // , Qt.rgba(1, 0.4, 0.9, 1.0)   // 7 left      pink
        ];
        return palette[zoneIdx] ?? Qt.rgba(0.5, 0.5, 0.5, 0.35);
    }

    // ── Strip prefab ────────────────────────────────────────────────
    //
    // Resize-union semantics: while cursor is inside the strip and the
    // strip's target geometry changes (e.g. because a bg in the zone is
    // physics-shrinking), the strip's RENDERED rect (`displayRect`) stays
    // expanded to the union(previousDisplay, newTarget). The union
    // collapses back to the live target only when one of:
    //   - cursor enters the new target rect specifically
    //   - cursor exits the union entirely
    //
    // Without this, the strip would shrink out from under a stationary
    // cursor, causing onExited → close → bg removed → strip back to default
    // → cursor enters again → reopen → loop.
    component InteractionStrip: Rectangle {
        id: strip
        required property int targetX
        required property int targetY
        required property int targetWidth
        required property int targetHeight
        color: root._debugColor

        // Live display rect — bound through (x/y/width/height) so the
        // visible Rectangle AND its MouseArea/DropArea bounds follow it.
        property int _dx: targetX
        property int _dy: targetY
        property int _dw: targetWidth
        property int _dh: targetHeight
        x: _dx
        y: _dy
        width: _dw
        height: _dh

        function _snapToTarget() {
            _dx = targetX;
            _dy = targetY;
            _dw = targetWidth;
            _dh = targetHeight;
        }

        function _expandToTarget() {
            const x0 = Math.min(_dx, targetX);
            const y0 = Math.min(_dy, targetY);
            const x1 = Math.max(_dx + _dw, targetX + targetWidth);
            const y1 = Math.max(_dy + _dh, targetY + targetHeight);
            _dx = x0;
            _dy = y0;
            _dw = x1 - x0;
            _dh = y1 - y0;
        }

        function _resyncOnTargetChange() {
            // Expand if cursor (hover OR drag) is inside the strip's current
            // display rect. HoverHandler reports hover state without blocking
            // underlying handlers; DropArea reports drag state.
            if (strip_hover.hovered || strip_drop.containsDrag)
                _expandToTarget();
            else
                _snapToTarget();
        }
        onTargetXChanged: _resyncOnTargetChange()
        onTargetYChanged: _resyncOnTargetChange()
        onTargetWidthChanged: _resyncOnTargetChange()
        onTargetHeightChanged: _resyncOnTargetChange()

        function _maybeCollapseFromCursor(localX, localY) {
            // If cursor/drag entered the live TARGET rect specifically (a
            // subset of the held display), collapse the union — old hold is
            // no longer needed.
            const ax = localX + strip._dx;
            const ay = localY + strip._dy;
            if (ax >= strip.targetX && ax < strip.targetX + strip.targetWidth && ay >= strip.targetY && ay < strip.targetY + strip.targetHeight) {
                strip._snapToTarget();
            }
        }

        // Hover via HoverHandler — does NOT block underlying handlers (the
        // WindowSlot envelope's HoverHandler must still fire while cursor
        // is on this strip, so the seam between strip and bg is gap-free).
        HoverHandler {
            id: strip_hover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered)
                    root._stripEnter();
                else {
                    root._stripExit();
                    if (!strip_drop.containsDrag)
                        strip._snapToTarget();
                }
            }
        }

        // Drag tracking + slide hint position.
        DropArea {
            id: strip_drop
            anchors.fill: parent
            onEntered: root._dropEnter()
            onExited: {
                root._dropExit();
                strip._snapToTarget();
            }
            onPositionChanged: drag => strip._maybeCollapseFromCursor(drag.x, drag.y)
        }

        // Cursor position tracker for resize-union collapse.
        readonly property point _hoverPos: strip_hover.point.position
        on_HoverPosChanged: {
            if (strip_hover.hovered)
                strip._maybeCollapseFromCursor(_hoverPos.x, _hoverPos.y);
        }

        // Press / click / slide — MouseArea WITHOUT hoverEnabled so it does
        // not consume hover events away from the envelope's HoverHandler.
        MouseArea {
            id: strip_click
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: false

            property bool _slideArmed: false

            onClicked: InteractionManager.fireClick(root.rail)
            onPressed: {
                _slideArmed = true;
            }
            onReleased: {
                _slideArmed = false;
            }
            onCanceled: {
                _slideArmed = false;
            }
            onPositionChanged: mouse => {
                if (!_slideArmed)
                    return;
                const inside = mouse.x >= 0 && mouse.x <= width && mouse.y >= 0 && mouse.y <= height;
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
        targetX: root._clipTop ? root._clipTop.lo : root._topStripX
        targetY: 0
        targetWidth: root._clipTop ? (root._clipTop.hi - root._clipTop.lo) : root._topStripW
        targetHeight: root._topStripH
    }

    InteractionStrip {
        visible: root.touchRight
        targetX: root.zWidth - root._rightStripW
        targetY: root._clipRight ? root._clipRight.lo : root._rightStripY
        targetWidth: root._rightStripW
        targetHeight: root._clipRight ? (root._clipRight.hi - root._clipRight.lo) : root._rightStripH
    }

    InteractionStrip {
        visible: root.touchBottom
        targetX: root._clipBot ? root._clipBot.lo : root._botStripX
        targetY: root.zHeight - root._botStripH
        targetWidth: root._clipBot ? (root._clipBot.hi - root._clipBot.lo) : root._botStripW
        targetHeight: root._botStripH
    }

    InteractionStrip {
        visible: root.touchLeft
        targetX: 0
        targetY: root._clipLeft ? root._clipLeft.lo : root._leftStripY
        targetWidth: root._leftStripW
        targetHeight: root._clipLeft ? (root._clipLeft.hi - root._clipLeft.lo) : root._leftStripH
    }
}
