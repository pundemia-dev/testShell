pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Caelestia.Blobs
import Quickshell
import qs.config
import qs.services
import qs.components

// One window on a rail. Renders a BlobRect (in the rail's shared BlobGroup)
// plus a content Loader. Position computed from the rail's anchor + layerIdx
// + the previous sibling's painted geometry, with the "own-anchor" non-growth
// axis (fixes off-screen when siblings differ in size) and L-step for layer 2
// on corner rails when a side reservation exists.
Item {
    id: root

    // ── Inputs from Rail ─────────────────────────────────────────────
    required property var wrapper
    required property string anchor
    required property int layerIdx
    required property var railRef
    required property BlobGroup group
    required property Item groupHost       // QQuickItem-wrapped BlobGroup (for SES mask)
    required property Item contentLayer
    required property int zWidth
    required property int zHeight
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area
    required property int arrivalSeq
    required property var manager

    // ── Borrow state (mode "replace") ────────────────────────────────
    // While another wrapper borrows this slot's bg, every wrapper-derived
    // input below reads from the ACTIVE wrapper (borrow-stack top) instead:
    // the bg morphs to the borrower's anchors/margins/size and back home
    // when the stack drains. The rail entry itself never changes (identity
    // rule) — everything is keyed off the out-of-band manager.borrowState
    // map, so the flip reaches this live delegate as a property change.
    // Latched arrivalSeq: ScriptModel transiently nulls modelData during row
    // moves/removals, flipping the required arrivalSeq to -1 and back on a
    // LIVE delegate. All borrow/publish logic keys off this latched copy so
    // the flicker can't fake a borrow transition (which would enable the
    // x/y flight springs mid-collapse and skew where a closing bg flies) or
    // pollute the manager's seq-keyed maps with -1 entries.
    property int latchedSeq: -1
    onArrivalSeqChanged: {
        if (arrivalSeq >= 0)
            latchedSeq = arrivalSeq;
    }

    readonly property var _borrow: manager.borrowState[latchedSeq]
    readonly property var borrowers: _borrow?.stack ?? []
    readonly property bool borrowed: borrowers.length > 0
    readonly property var activeWrapper: borrowed ? borrowers[borrowers.length - 1].wrapper : wrapper
    // Seq the slot's live geometry/hover is published under: the top
    // borrower's borrowSeq while borrowed (so the borrower's module can
    // subscribe to slotHover/slotRects with the seq requestBackground gave
    // it), the entry's own seq otherwise.
    readonly property int activeSeq: borrowed ? borrowers[borrowers.length - 1].borrowSeq : latchedSeq

    // ── Close animation (dying) ──────────────────────────────────────
    // Bound from manager.dyingState via the Rail delegate. While true, the slot
    // collapses its size to 0 (mirror of the appear) and, once collapsed, asks
    // the manager to finalise the real removal. The flip reaches this delegate
    // in place (rail entries are identity-stable, so the Repeater doesn't
    // recreate it). `deathRect` is the slot's last painted rect, used to seed
    // the collapse start size in the safety path where the delegate WAS created
    // already-dying (e.g. the whole Rail re-instantiated mid-collapse).
    property bool dying: false
    property var deathRect: null
    property bool _collapseStarted: false
    property bool _finalized: false

    // ── Content sizing ───────────────────────────────────────────────
    // The loader whose item drives targetWrapper* sizing: the borrower's
    // while its content is on this slot, the donor's own otherwise.
    // Assigned IMPERATIVELY (loader Component.onCompleted + the borrow
    // transition handler), NOT as a declarative binding: it must stay null
    // through the delegate's initial binding pass so targetWrapper* first
    // evaluates to 0 and the size springs animate the appear from zero.
    // A binding resolves the loader id within the creation pass and the
    // panel pops in at full size with no appear animation.
    property Item contentLoader: null

    function _syncContentLoader() {
        contentLoader = borrowed ? borrowLoader : loader;
    }

    readonly property int targetWrapperWidth: {
        if (!activeWrapper)
            return 0;
        if (activeWrapper.wrapperWidth !== undefined && activeWrapper.wrapperWidth > 0)
            return activeWrapper.wrapperWidth;
        if (contentLoader && contentLoader.item) {
            return (contentLoader.item.childrenRect.width || contentLoader.item.implicitWidth) + pLeft + pRight;
        }
        return 0;
    }
    readonly property int targetWrapperHeight: {
        if (!activeWrapper)
            return 0;
        if (activeWrapper.wrapperHeight !== undefined && activeWrapper.wrapperHeight > 0)
            return activeWrapper.wrapperHeight;
        if (contentLoader && contentLoader.item) {
            return (contentLoader.item.childrenRect.height || contentLoader.item.implicitHeight) + pTop + pBottom;
        }
        return 0;
    }

    property int lastTargetWidth: 0
    property int lastTargetHeight: 0
    Binding {
        target: root
        property: "lastTargetWidth"
        value: root.targetWrapperWidth
        when: root.targetWrapperWidth > 0
    }
    Binding {
        target: root
        property: "lastTargetHeight"
        value: root.targetWrapperHeight
        when: root.targetWrapperHeight > 0
    }

    // _rawWidth/_rawHeight are driven by EXPLICIT SpringAnimations (below),
    // not by a declared binding + Behavior. Reason: this delegate is created
    // from within another component's finalization (wrapper Loader →
    // requestBackground → Repeater), so its Behaviors aren't finalized yet
    // when the content size settles ~30-160ms later — and a non-finalized
    // Behavior passes EVERY write straight through (binding or imperative),
    // which snapped the appear to full size. Explicitly started animations
    // don't care about Behavior finalization, so the appear springs from the
    // first frame of the delegate's life.
    property int _rawWidth: 0
    property int _rawHeight: 0
    // No size writes before Component.onCompleted. Content loads (and often
    // fully lays out) INSIDE this delegate's finalization — Loader loads at
    // its componentComplete, while the SpringAnimations (created earlier in
    // the document) complete LAST, in reverse creation order. Any spring
    // started in that window is silently deferred (running=true, no job) —
    // the size freezes and the content gets scaled to a stale bg. So the
    // first drive happens in onCompleted (guaranteed after every
    // componentComplete); late-settling content springs from these handlers.
    property bool _sizeReady: false
    onTargetWrapperWidthChanged: {
        if (!dying && _sizeReady)
            _driveWidth(targetWrapperWidth);
    }
    onTargetWrapperHeightChanged: {
        if (!dying && _sizeReady)
            _driveHeight(targetWrapperHeight);
    }
    readonly property int paintedWidth: Math.max(0, _rawWidth)
    readonly property int paintedHeight: Math.max(0, _rawHeight)

    // Spring _rawWidth/_rawHeight toward v. A standalone SpringAnimation
    // captures `to` when it starts and does NOT track later changes — a
    // mid-flight retarget MUST restart, or the spring settles on the stale
    // target (bg stuck ≠ content size → the content gets scaled to the bg).
    function _driveWidth(v) {
        if (sprW.running && sprW.to === v)
            return; // already flying there
        sprW.to = v;
        sprW.restart();
    }
    function _driveHeight(v) {
        if (sprH.running && sprH.to === v)
            return;
        sprH.to = v;
        sprH.restart();
    }


    // ── Liquid rounding morph (Config.backgrounds.liquidRounding) ───────
    // Time-based corner morph parallel to appear/collapse (not size-keyed):
    // 0 = configured windowRounding, 1 = full capsule (half the painted short
    // side). Appear starts as a droplet and relaxes into the configured
    // radius; collapse blooms back toward a droplet as the panel shrinks.
    // The appear morph runs slower than the size spring (~150ms) on purpose —
    // the visible phase is the full-size panel's corners settling.
    property real _roundMix: 0
    NumberAnimation {
        id: appearRoundAnim
        target: root; property: "_roundMix"
        from: 1.0; to: 0.0
        duration: Appearance.anim.durations.normal
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.curves.emphasized
    }
    NumberAnimation {
        id: collapseRoundAnim
        target: root; property: "_roundMix"
        to: 1.0
        // The collapse spring reaches ~0 in ±150ms — bloom fast (decel curve)
        // so the capsule reads while the panel is still big enough to see.
        duration: Appearance.anim.durations.expressiveFastEffects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
    }

    // ── Liquid content effects driver ───────────────────────────────────
    // The ANIMATED part of the rounding only: open/close morph (_roundMix)
    // OR motion boost (bgRect.roundBoost). Both are zero at rest, so a
    // settled panel with magnet-shrunk (unequal) corners never triggers the
    // content effects. Two independent consumers on the scalingRoot shader:
    // the GridMesh squeeze (needs liquidRounding — it presses into the
    // animated contour) and the content blur (standalone).
    readonly property real _liquidMix: _liquidMixNeeded ? Math.max(_roundMix, bgRect.roundBoost) : 0
    readonly property real _warpMix: (Config.backgrounds.liquidContentWarp ?? false) && liquidRounding
        ? _liquidMix : 0
    readonly property real _blurPx: liquidContentBlur
        ? _liquidMix * (Config.backgrounds.liquidContentBlurMax ?? 16) : 0

    // Size follow: one brisk spring per axis, both sharing Liquid's params. The
    // visible "liquid glass" squash/stretch is NOT produced here — it's the SDF
    // deform engine on the BlobRect below, driven by the centre velocity this
    // motion generates (resize from an edge moves the centre toward that edge, so
    // the stretch direction encodes the expansion origin). See services/Liquid.qml.
    SpringAnimation {
        id: sprW
        target: root
        property: "_rawWidth"
        spring: Liquid.sizeSpring
        damping: Liquid.sizeDamping
        epsilon: Liquid.sizeEpsilon
    }
    SpringAnimation {
        id: sprH
        target: root
        property: "_rawHeight"
        spring: Liquid.sizeSpring
        damping: Liquid.sizeDamping
        epsilon: Liquid.sizeEpsilon
    }

    // ── Collapse-on-close ────────────────────────────────────────────
    // Drive the size springs to 0 (mirror of the appear) while `dying`. The
    // existing edge-anchored position formulas make the slot collapse toward its
    // growth origin, the content Scale (paintedWidth/lastTargetWidth) shrinks the
    // content with it, and same-rail siblings re-pack as they track this slot's
    // shrinking paintedWidth via prevSlot. When the collapse reaches 0 we ask the
    // manager to perform the real splice.
    onDyingChanged: {
        if (root.dying)
            root._startCollapse();
        else
            root._cancelCollapse();
    }

    function _startCollapse() {
        if (root._collapseStarted)
            return;
        root._collapseStarted = true;
        root._finalized = false;
        // Seed the start size from the LARGEST known size. deathRect is the
        // authoritative last-painted rect; targetWrapperWidth/Height can't be
        // trusted alone here because a delegate created already-dying (safety
        // path: the whole Rail re-instantiated mid-collapse) may not have laid
        // out its content yet — targetWrapperWidth then resolves to just
        // pLeft+pRight (a small POSITIVE value), which a naive `> 0` check
        // would accept, seeding the collapse from a paddings-sized box and
        // slamming effectiveRounding to ~0 for the whole shrink. Max over all
        // three avoids that.
        const startW = Math.max(root.deathRect ? root.deathRect.w : 0,
                                root.targetWrapperWidth, root._rawWidth);
        const startH = Math.max(root.deathRect ? root.deathRect.h : 0,
                                root.targetWrapperHeight, root._rawHeight);
        sprW.stop();
        sprH.stop();
        root._rawWidth = startW;
        root._rawHeight = startH;
        // Next tick so the snapped start size lands before the collapse animates.
        Qt.callLater(() => {
            if (!root.dying)
                return;
            root._driveWidth(0);
            root._driveHeight(0);
        });
        // Bloom the corners back toward a droplet (the shader content blur
        // rides the same mix, hence the wider gate).
        if (root._liquidMixNeeded) {
            appearRoundAnim.stop();
            collapseRoundAnim.restart();
        }
        finalizeTimer.restart();
    }

    function _cancelCollapse() {
        // Revived mid-collapse → reverse into a re-open. Re-sync to the live
        // targets; the onTargetWrapper*Changed handlers (gated on `dying`,
        // which just flipped false) take over subsequent changes.
        finalizeTimer.stop();
        root._collapseStarted = false;
        root._finalized = false;
        root._driveWidth(root.targetWrapperWidth);
        root._driveHeight(root.targetWrapperHeight);
        // Re-open rounding (relax the droplet back to the configured radius;
        // the shader content blur rides the same mix, hence the wider gate).
        collapseRoundAnim.stop();
        if (!root.isPinned && root._liquidMixNeeded)
            appearRoundAnim.restart();
        else
            root._roundMix = 0;
    }

    function _maybeFinalize() {
        if (!root.dying || root._finalized)
            return;
        if (root.paintedWidth <= 1 && root.paintedHeight <= 1)
            root._finalize();
    }

    function _finalize() {
        if (root._finalized)
            return;
        root._finalized = true;
        finalizeTimer.stop();
        // Defer the splice — it removes this entry from the rail model, which
        // destroys this very delegate. Doing that from inside the delegate's
        // own call stack is asking for trouble.
        // latchedSeq, not arrivalSeq — the raw value may be flickering -1
        // (ScriptModel modelData null) exactly when the splice lands.
        const seq = root.latchedSeq;
        const mgr = root.manager;
        Qt.callLater(() => {
            if (mgr && mgr.finalizeRemoval)
                mgr.finalizeRemoval(seq);
        });
    }

    // Fallback: if the spring stalls above the 1px finalize threshold, force the
    // splice so a dying slot can never get stuck on the rail.
    Timer {
        id: finalizeTimer
        interval: Appearance.anim.durations.extraLarge
        onTriggered: root._finalize()
    }

    // ── Anchor flags ─────────────────────────────────────────────────
    // While borrowed, the slot positions by the BORROWER's contract anchors
    // (own-anchor on both axes, like an overlay) — the rail's anchor string
    // only describes the donor's home.
    readonly property bool aLeft: borrowed ? (activeWrapper.aLeft ?? false)
        : anchor === "topLeft" || anchor === "left" || anchor === "bottomLeft"
    readonly property bool aRight: borrowed ? (activeWrapper.aRight ?? false)
        : anchor === "topRight" || anchor === "right" || anchor === "bottomRight"
    readonly property bool aTop: borrowed ? (activeWrapper.aTop ?? false)
        : anchor === "topLeft" || anchor === "top" || anchor === "topRight"
    readonly property bool aBottom: borrowed ? (activeWrapper.aBottom ?? false)
        : anchor === "bottomLeft" || anchor === "bottom" || anchor === "bottomRight"
    readonly property bool aHCenter: borrowed ? (activeWrapper.aHorizontalCenter ?? false)
        : anchor === "top" || anchor === "center" || anchor === "bottom"
    readonly property bool aVCenter: borrowed ? (activeWrapper.aVerticalCenter ?? false)
        : anchor === "left" || anchor === "center" || anchor === "right"
    readonly property bool aCorner: anchor === "topLeft" || anchor === "topRight" || anchor === "bottomLeft" || anchor === "bottomRight"

    // ── Wrapper props (all from the ACTIVE wrapper — borrower when borrowed) ──
    readonly property int mLeft: activeWrapper?.mLeft ?? 0
    readonly property int mRight: activeWrapper?.mRight ?? 0
    readonly property int mTop: activeWrapper?.mTop ?? 0
    readonly property int mBottom: activeWrapper?.mBottom ?? 0
    readonly property int vCenterOffset: activeWrapper?.vCenterOffset ?? 0
    readonly property int hCenterOffset: activeWrapper?.hCenterOffset ?? 0
    readonly property int pLeft: activeWrapper?.pLeft ?? Config.backgrounds.paddings.left ?? 0
    readonly property int pTop: activeWrapper?.pTop ?? Config.backgrounds.paddings.top ?? 0
    readonly property int pRight: activeWrapper?.pRight ?? Config.backgrounds.paddings.right ?? 0
    readonly property int pBottom: activeWrapper?.pBottom ?? Config.backgrounds.paddings.bottom ?? 0
    readonly property int windowRounding: activeWrapper?.windowRounding ?? Config.backgrounds.rounding ?? 0
    readonly property bool liquidRounding: Config.backgrounds.liquidRounding ?? false
    // Content blur is an independent consumer of the liquid mix — it needs the
    // mix animated (and the C++ boost computed) even with liquidRounding off.
    readonly property bool liquidContentBlur: Config.backgrounds.liquidContentBlur ?? false
    readonly property bool _liquidMixNeeded: liquidRounding || liquidContentBlur
    readonly property real _maxRounding: Math.min(paintedWidth, paintedHeight) / 2
    readonly property int effectiveRounding: {
        const base = Math.min(windowRounding, _maxRounding);
        if (!liquidRounding || _roundMix <= 0)
            return base;
        return Math.round(base + (_maxRounding - base) * Math.min(1, _roundMix));
    }
    readonly property string mode: wrapper?.mode ?? "push"
    // Whether this bg присасывается (merges with neighbours + frame). false →
    // clean floating contour. Default true preserves legacy merge behaviour.
    readonly property bool sticks: activeWrapper?.sticks ?? true
    readonly property bool isPinned: wrapper?.pinned ?? false
    // mode "replace" reaches a slot of its own only via the no-donor
    // fallback — it positions like an overlay.
    readonly property bool isOverlay: mode === "overlay" || mode === "replace"

    readonly property var content: wrapper?.content
    readonly property var borrowContent: borrowed ? activeWrapper.content : null

    // ── Edge offsets ─────────────────────────────────────────────────
    // Pinned wrappers paint at the very edge (edge=0). Push-mode non-pinned
    // wrappers are inset by the reserved area so they don't overlap pinned
    // wrappers that reserve exclusion zones. Overlay wrappers intentionally
    // sit *on top of* other wrappers (that's the whole point of overlay),
    // so they also get edge=0 — otherwise mode:"overlay" would actually
    // behave as "push offset by reserved area".
    // A borrowed slot flies as the borrower's panel: push-style insets
    // (respect exclusion zones) regardless of the donor's own pinned/mode.
    readonly property int edgeLeft: (!borrowed && (isPinned || isOverlay)) ? 0 : left_area
    readonly property int edgeRight: (!borrowed && (isPinned || isOverlay)) ? 0 : right_area
    readonly property int edgeTop: (!borrowed && (isPinned || isOverlay)) ? 0 : top_area
    readonly property int edgeBottom: (!borrowed && (isPinned || isOverlay)) ? 0 : bottom_area

    // ── Previous sibling on rail ─────────────────────────────────────
    readonly property var prevSlot: railRef ? railRef.prevSlot(layerIdx - 1) : null

    // ── L-step detection (corner rails, layer 2, side reservation) ──
    readonly property string _sideForCorner: {
        if (anchor === "topLeft" || anchor === "bottomLeft")
            return "left";
        if (anchor === "topRight" || anchor === "bottomRight")
            return "right";
        return "";
    }
    readonly property bool isLStep: {
        if (borrowed)
            return false;
        if (!aCorner)
            return false;
        if (layerIdx !== 2)
            return false;
        if (isOverlay)
            return false;
        if (!prevSlot || !prevSlot.isPinned)
            return false;
        if (!_sideForCorner)
            return false;
        return (manager.reservedEdge(_sideForCorner) || 0) > 0;
    }

    // ── Centre-offset clamping ──────────────────────────────────────
    // The free-axis offset (h/vCenterOffset) may shift a centred bg until
    // the gap on the side it moves toward shrinks to that side's margin —
    // then it stops. This stops an over-large offset from driving the bg
    // off-screen: the facing margin is the hard floor on the gap to the
    // edge. Width/height are passed in because the envelope uses a stable
    // size while ownX/ownY use the animated painted size.
    function _clampHOffset(off, w) {
        if (off === 0)
            return 0;
        const half = (zWidth - w) / 2;
        const lo = (mLeft + edgeLeft) - half;    // left edge reaches mLeft
        const hi = half - (mRight + edgeRight);  // right edge reaches mRight
        if (lo > hi)                              // no room → stay centred
            return 0;
        return Math.max(lo, Math.min(hi, off));
    }
    function _clampVOffset(off, h) {
        if (off === 0)
            return 0;
        const half = (zHeight - h) / 2;
        const lo = (mTop + edgeTop) - half;        // top edge reaches mTop
        const hi = half - (mBottom + edgeBottom);  // bottom edge reaches mBottom
        if (lo > hi)
            return 0;
        return Math.max(lo, Math.min(hi, off));
    }

    // ── Own-anchor formulas (used when overlay or for non-growth axis) ──
    readonly property int ownX: {
        if (aHCenter && !aLeft && !aRight) {
            return (zWidth / 2) - (paintedWidth / 2) + _clampHOffset(hCenterOffset, paintedWidth);
        }
        if (aLeft)
            return mLeft + edgeLeft;
        if (aRight)
            return zWidth - paintedWidth - mRight - edgeRight;
        return 0;
    }
    readonly property int ownY: {
        if (aVCenter && !aTop && !aBottom) {
            return (zHeight / 2) - (paintedHeight / 2) + _clampVOffset(vCenterOffset, paintedHeight);
        }
        if (aTop)
            return mTop + edgeTop;
        if (aBottom)
            return zHeight - paintedHeight - mBottom - edgeBottom;
        return 0;
    }

    // ── Position resolved ────────────────────────────────────────────
    //
    // The gap between this slot and its prev on the same rail is taken from
    // THIS slot's own facing margin — i.e. the margin on the side that faces
    // prev. So a layer-2 bg below a pinned bar uses its own `mTop` as the
    // gap, not prev.mBottom. Each margin reads as "gap on this side from
    // whatever is adjacent" (prev bg, reserved space, or screen edge).
    readonly property int targetX: {
        // Overlay / borrowed: cover prev (act like layer 1 of this anchor).
        if (isOverlay || borrowed)
            return ownX;
        // Layer 1: own-anchor on both axes.
        if (layerIdx <= 1 || !prevSlot)
            return ownX;
        // L-step (layer 2 on corner with side reservation): sideways step.
        if (isLStep) {
            if (anchor === "topLeft" || anchor === "bottomLeft") {
                return prevSlot.chainX + prevSlot.chainW + mLeft;
            }
            // topRight / bottomRight
            return prevSlot.chainX - paintedWidth - mRight;
        }
        // Side-growing rails (left/right): X is growth axis → from prev.
        if (anchor === "left")
            return prevSlot.chainX + prevSlot.chainW + mLeft;
        if (anchor === "right")
            return prevSlot.chainX - paintedWidth - mRight;
        // Otherwise (vertical-growth rails): own X.
        return ownX;
    }

    readonly property int targetY: {
        if (isOverlay || borrowed)
            return ownY;
        if (layerIdx <= 1 || !prevSlot)
            return ownY;
        if (isLStep) {
            // Align with prev's edge facing the corner.
            if (anchor === "topLeft" || anchor === "topRight") {
                return prevSlot.chainY;
            }
            // bottomLeft / bottomRight: align bottoms.
            return prevSlot.chainY + prevSlot.chainH - paintedHeight;
        }
        // Top/center/topLeft/topRight rails grow DOWN; left/right keep own Y.
        if (aTop)
            return prevSlot.chainY + prevSlot.chainH + mTop;
        if (aBottom)
            return prevSlot.chainY - paintedHeight - mBottom;
        if (anchor === "center")
            return prevSlot.chainY + prevSlot.chainH + mTop;
        return ownY;
    }

    // ── Chain-facing geometry (what SIBLINGS on this rail see) ───────
    // While this slot's bg is out on loan (borrowed), its place in the chain
    // is frozen at the pre-borrow rect so neighbours don't follow the flying
    // bg — consistent with the frozen wlr exclusion. Falls back to the live
    // values if the donor was borrowed before ever publishing a rect.
    readonly property real chainX: borrowed && _borrow.homeRect ? _borrow.homeRect.x : targetX
    readonly property real chainY: borrowed && _borrow.homeRect ? _borrow.homeRect.y : targetY
    readonly property real chainW: borrowed && _borrow.homeRect ? _borrow.homeRect.w : paintedWidth
    readonly property real chainH: borrowed && _borrow.homeRect ? _borrow.homeRect.h : paintedHeight

    // ── Geometry ─────────────────────────────────────────────────────
    x: targetX
    y: targetY
    width: paintedWidth
    height: paintedHeight

    // ── Borrow morph (position) ──────────────────────────────────────
    // x/y are normally unanimated — chain re-packs already ride the
    // neighbours' size springs, so a permanent position Behavior would
    // double-animate them. A borrow transition (stack top changed: borrow,
    // return, or hand-off between borrowers) re-anchors the slot in one
    // step instead, so the springs are enabled for one flight window. The
    // SDF velocity deform + repolish already ride x/y changes, so the
    // flight gets the liquid stretch for free.
    property bool _posAnimActive: false
    property int _prevActiveSeq: -1
    // activeSeq derives from latchedSeq + borrowState only, so this fires
    // exactly once at completion (the latch, prev < 0 → no-op) and then on
    // REAL borrow transitions — never on ScriptModel's modelData flicker.
    onActiveSeqChanged: {
        const prev = _prevActiveSeq;
        _prevActiveSeq = activeSeq;
        _syncContentLoader();
        if (prev < 0)
            return; // initial latch, not a borrow transition
        _posAnimActive = true;
        posAnimOffTimer.restart();
        // Re-key the published geometry/hover to the new active seq. Stale
        // borrower keys are dropped; the donor's own key is refreshed by
        // _publishSlotRect (frozen homeRect while borrowed).
        if (manager) {
            if (prev !== latchedSeq) {
                manager.clearSlotRect(prev);
                manager.clearSlotHover(prev);
                manager.clearSlotDragOver(prev);
            }
            _publishSlotRect();
            manager.setSlotHover(activeSeq, _slotHovered);
            manager.setSlotDragOver(activeSeq, _slotDragOver);
        }
    }
    Timer {
        id: posAnimOffTimer
        interval: Appearance.anim.durations.extraLarge
        onTriggered: root._posAnimActive = false
    }
    Behavior on x {
        enabled: root._posAnimActive
        SpringAnimation {
            spring: Liquid.sizeSpring
            damping: Liquid.sizeDamping
            epsilon: Liquid.sizeEpsilon
        }
    }
    Behavior on y {
        enabled: root._posAnimActive
        SpringAnimation {
            spring: Liquid.sizeSpring
            damping: Liquid.sizeDamping
            epsilon: Liquid.sizeEpsilon
        }
    }
    // WindowSlot itself is a logical geometry holder; visible fragments
    // (bg + content) are reparented to contentLayer with z=arrivalSeq so
    // they stack correctly across rails (z compared in a shared parent).

    // ── Input region for hit-testing ─────────────────────────────────
    Region {
        id: inputRegion
        x: root.x
        y: root.y
        width: root.lastTargetWidth
        height: root.lastTargetHeight
        intersection: Intersection.Subtract
    }

    // ── Resize-union holdover (cursor-aware) ─────────────────────────
    //
    // When the slot's geometry changes (resize / move), the input mask
    // shrinks the moment the target changes — so the cursor that was inside
    // the old shape can momentarily fall outside the new shape and trigger
    // wl_pointer.leave. To prevent that, two "display" rects lag the live
    // targets:
    //
    //   _slotDisplayRect      — display for the slot input region
    //   _envelopeDisplayRect  — display for the slot envelope (hover/drag)
    //
    // Both follow the same InteractionStrip-style semantics:
    //   - On target change: if cursor (hover OR drag) is engaged with the
    //     envelope, expand display to union(old display, new target). Else
    //     snap display to target.
    //   - When cursor enters the new target rect specifically: snap that
    //     display to its target (old part no longer needed).
    //   - When cursor leaves the envelope entirely: snap both.
    //
    // The envelope HoverHandler / DropArea below drive the engagement and
    // position signals. Cursor coords are mapped to window space (envelope
    // local + envelope x/y), which matches the slot/envelope target rects
    // (computed in window coords).
    readonly property rect _slotTargetRect: Qt.rect(root.x, root.y, root.paintedWidth, root.paintedHeight)
    property rect _slotDisplayRect: Qt.rect(0, 0, 0, 0)
    property rect _envelopeDisplayRect: Qt.rect(0, 0, 0, 0)

    function _rectUnion(a, b) {
        // Empty rect contributes nothing — otherwise (0,0,0,0) would be
        // treated as a point at origin and pull the union back to the screen
        // corner, which matters before Qt.callLater seeds the displays.
        if (a.width <= 0 || a.height <= 0)
            return b;
        if (b.width <= 0 || b.height <= 0)
            return a;
        const x0 = Math.min(a.x, b.x);
        const y0 = Math.min(a.y, b.y);
        const x1 = Math.max(a.x + a.width, b.x + b.width);
        const y1 = Math.max(a.y + a.height, b.y + b.height);
        return Qt.rect(x0, y0, x1 - x0, y1 - y0);
    }
    function _rectContains(r, x, y) {
        return x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height;
    }
    function _rectInflate(r, m) {
        return Qt.rect(r.x - m, r.y - m, r.width + 2 * m, r.height + 2 * m);
    }
    function _rectClip(inner, outer) {
        const x0 = Math.max(outer.x, inner.x);
        const y0 = Math.max(outer.y, inner.y);
        const x1 = Math.min(outer.x + outer.width, inner.x + inner.width);
        const y1 = Math.min(outer.y + outer.height, inner.y + inner.height);
        return Qt.rect(x0, y0, Math.max(0, x1 - x0), Math.max(0, y1 - y0));
    }
    // On target change: ALWAYS union with the previous display. Collapse is
    // never triggered by a resize itself — only by explicit cursor signals
    // (cursor entered new target → _maybeCollapseFromCursor, or cursor left
    // envelope → _snapDisplaysToTarget). This avoids a race where `_envHovered`
    // is briefly false during the binding cascade of a click (Qt may rearrange
    // hover delivery when a MouseArea grabs the press), which previously caused
    // _resyncDisplays to take the snap branch and shrink the mask out from
    // under a still-engaged cursor.
    function _resyncDisplays() {
        _slotDisplayRect = _rectUnion(_slotDisplayRect, _slotTargetRect);
        _envelopeDisplayRect = _rectUnion(_envelopeDisplayRect, _slotEnvelopeRect);
    }
    function _snapDisplaysToTarget() {
        _slotDisplayRect = _slotTargetRect;
        _envelopeDisplayRect = _slotEnvelopeRect;
    }
    // On collapse: snap to a buffered version of target = inflate(target, m)
    // clipped to the CURRENT display (= previous bg bounds). The buffer
    // protects against accidental cursor jitter pushing one pixel outside
    // the freshly shrunk mask; the clip guarantees the buffer never extends
    // past where the bg already was, so we never grow.
    function _maybeCollapseFromCursor(wx, wy) {
        const m = Math.max(0, Config.backgrounds.resizeHoldoverMargin ?? 0);
        if (_rectContains(_slotTargetRect, wx, wy)) {
            _slotDisplayRect = _rectClip(_rectInflate(_slotTargetRect, m), _slotDisplayRect);
        }
        if (_rectContains(_slotEnvelopeRect, wx, wy)) {
            _envelopeDisplayRect = _rectClip(_rectInflate(_slotEnvelopeRect, m), _envelopeDisplayRect);
        }
    }

    on_SlotTargetRectChanged: _resyncDisplays()
    on_SlotEnvelopeRectChanged: _resyncDisplays()

    Region {
        id: holdoverRegion
        x: root._slotDisplayRect.x
        y: root._slotDisplayRect.y
        width: root._slotDisplayRect.width
        height: root._slotDisplayRect.height
        intersection: Intersection.Subtract
    }

    // ── Bridge regions ───────────────────────────────────────────────
    //
    // Cover the margin gap between this slot's facing edge and its anchor
    // (prev's far edge or screen edge for layer-1) so cursor traversal
    // through the gap doesn't fire wl_pointer.leave on the underlying
    // compositor surface. Up to 4 sides: any side with a positive gap
    // produces a non-empty bridge; zero-sized bridges contribute nothing
    // to the mask.
    readonly property int _prevBottom: prevSlot ? prevSlot.chainY + prevSlot.chainH : 0
    readonly property int _prevTop: prevSlot ? prevSlot.chainY : zHeight
    readonly property int _prevRight: prevSlot ? prevSlot.chainX + prevSlot.chainW : 0
    readonly property int _prevLeft: prevSlot ? prevSlot.chainX : zWidth

    readonly property rect _bridgeTopRect: {
        // Layer-1 with top anchor: gap from screen top to root.y
        if (!isOverlay && !borrowed && layerIdx <= 1 && aTop && root.y > 0)
            return Qt.rect(root.x, 0, paintedWidth, root.y);
        // Layer-2+ aTop / center / topLeft+topRight non-L-step: from prev.bottom to root.y
        if (!isOverlay && !borrowed && layerIdx > 1 && prevSlot && !isLStep && (aTop || anchor === "center")) {
            const gap = root.y - _prevBottom;
            if (gap > 0)
                return Qt.rect(root.x, _prevBottom, paintedWidth, gap);
        }
        return Qt.rect(0, 0, 0, 0);
    }

    readonly property rect _bridgeBottomRect: {
        if (!isOverlay && !borrowed && layerIdx <= 1 && aBottom && (root.y + paintedHeight) < zHeight) {
            const top = root.y + paintedHeight;
            return Qt.rect(root.x, top, paintedWidth, zHeight - top);
        }
        if (!isOverlay && !borrowed && layerIdx > 1 && prevSlot && !isLStep && aBottom) {
            const top = root.y + paintedHeight;
            const gap = _prevTop - top;
            if (gap > 0)
                return Qt.rect(root.x, top, paintedWidth, gap);
        }
        return Qt.rect(0, 0, 0, 0);
    }

    readonly property rect _bridgeLeftRect: {
        // Layer-1 with left anchor: from x=0 to root.x
        if (!isOverlay && !borrowed && layerIdx <= 1 && aLeft && root.x > 0)
            return Qt.rect(0, root.y, root.x, paintedHeight);
        // Layer-2+ left rail or L-step topLeft/bottomLeft: from prev.right to root.x
        if (!isOverlay && !borrowed && layerIdx > 1 && prevSlot && (anchor === "left" || ((anchor === "topLeft" || anchor === "bottomLeft") && isLStep))) {
            const gap = root.x - _prevRight;
            if (gap > 0)
                return Qt.rect(_prevRight, root.y, gap, paintedHeight);
        }
        return Qt.rect(0, 0, 0, 0);
    }

    readonly property rect _bridgeRightRect: {
        if (!isOverlay && !borrowed && layerIdx <= 1 && aRight && (root.x + paintedWidth) < zWidth) {
            const left = root.x + paintedWidth;
            return Qt.rect(left, root.y, zWidth - left, paintedHeight);
        }
        if (!isOverlay && !borrowed && layerIdx > 1 && prevSlot && (anchor === "right" || ((anchor === "topRight" || anchor === "bottomRight") && isLStep))) {
            const left = root.x + paintedWidth;
            const gap = _prevLeft - left;
            if (gap > 0)
                return Qt.rect(left, root.y, gap, paintedHeight);
        }
        return Qt.rect(0, 0, 0, 0);
    }

    Region {
        id: bridgeTop
        x: root._bridgeTopRect.x
        y: root._bridgeTopRect.y
        width: root._bridgeTopRect.width
        height: root._bridgeTopRect.height
        intersection: Intersection.Subtract
    }
    Region {
        id: bridgeBottom
        x: root._bridgeBottomRect.x
        y: root._bridgeBottomRect.y
        width: root._bridgeBottomRect.width
        height: root._bridgeBottomRect.height
        intersection: Intersection.Subtract
    }
    Region {
        id: bridgeLeft
        x: root._bridgeLeftRect.x
        y: root._bridgeLeftRect.y
        width: root._bridgeLeftRect.width
        height: root._bridgeLeftRect.height
        intersection: Intersection.Subtract
    }
    Region {
        id: bridgeRight
        x: root._bridgeRightRect.x
        y: root._bridgeRightRect.y
        width: root._bridgeRightRect.width
        height: root._bridgeRightRect.height
        intersection: Intersection.Subtract
    }

    // ── Compositor blur region (ext-background-effect-v1) ────────────
    //
    // Published to niri (union'd in Drawers via BackgroundEffect.blurRegion).
    // niri blurs EXACTLY the wl_region we hand it, committed atomically with
    // the surface → no lag. The region is a rounded-rect approximation of the
    // SDF contour (the protocol takes no per-pixel mask), so:
    //   • body  — the panel's rounded rect, inset inward by blurInset so the
    //             hard region edge hides under the panel's translucent rim;
    //   • necks — the magnet bridges to the PREVIOUS sibling on this rail
    //             (layer-2+), included only when both stick and the gap is
    //             within the SDF merge reach (group.smoothing × stickSmooth).
    //
    // Settle gate: while the slot is appearing / resizing (geometry in flux)
    // every region collapses to 0, so niri never blurs a morphing shape — only
    // a frozen one, where the rectangle approximation actually matches.
    readonly property int _blurInset: Config.general.transparency.blurInset ?? 8
    readonly property int _blurInsetEff: Math.min(_blurInset, Math.floor(paintedWidth / 2), Math.floor(paintedHeight / 2))
    readonly property real _blurMagnetDist: (group?.smoothing ?? 32) * (Config.backgrounds.stickSmooth ?? 1)

    property bool _blurSettled: false
    readonly property bool _blurOn: BlurManager.enabled && _blurSettled && !dying
    // Necks temporarily disabled: the distance≤magnet heuristic over-publishes
    // — it adds a blur rect in real (non-merging) gaps between stacked panels,
    // so blur shows where there's no blob. Revisit with an accurate SDF-merge
    // test before re-enabling. Body-only blur for now.
    readonly property bool _blurNeckOn: false

    Timer {
        id: _blurSettleTimer
        interval: Config.general.transparency.blurSettleMs ?? 200
        onTriggered: {
            root._blurSettled = true;
            BlurManager.refresh();
        }
    }
    function _blurUnsettle(): void {
        if (!BlurManager.enabled)
            return;
        if (root._blurSettled) {
            root._blurSettled = false;
            BlurManager.refresh();
        }
        _blurSettleTimer.restart();
    }
    // x/y are bound to targetX/targetY; paintedWidth/Height ride the size
    // spring. Any of them moving means the contour is still in flux.
    onXChanged: _blurUnsettle()
    onYChanged: _blurUnsettle()
    onPaintedWidthChanged: _blurUnsettle()
    onPaintedHeightChanged: _blurUnsettle()
    Connections {
        target: BlurManager
        // Toggling blur on for an already-static panel fires no geometry
        // signal — kick the settle timer so it publishes after blurSettleMs.
        function onEnabledChanged(): void {
            root._blurUnsettle();
        }
    }

    // Clamp a neighbour-neck bridge rect to the magnet reach: beyond it the SDF
    // doesn't merge the panels, so blurring the gap would show a blurred sliver
    // with no blob painted over it.
    function _blurNeck(r: rect): rect {
        if (!_blurNeckOn || r.width <= 0 || r.height <= 0)
            return Qt.rect(0, 0, 0, 0);
        if (Math.min(r.width, r.height) > _blurMagnetDist)
            return Qt.rect(0, 0, 0, 0);
        return r;
    }
    readonly property rect _blurNeckTopRect: layerIdx > 1 ? _blurNeck(_bridgeTopRect) : Qt.rect(0, 0, 0, 0)
    readonly property rect _blurNeckBottomRect: layerIdx > 1 ? _blurNeck(_bridgeBottomRect) : Qt.rect(0, 0, 0, 0)
    readonly property rect _blurNeckLeftRect: layerIdx > 1 ? _blurNeck(_bridgeLeftRect) : Qt.rect(0, 0, 0, 0)
    readonly property rect _blurNeckRightRect: layerIdx > 1 ? _blurNeck(_bridgeRightRect) : Qt.rect(0, 0, 0, 0)

    Region {
        id: blurBody
        x: root.x + root._blurInsetEff
        y: root.y + root._blurInsetEff
        width: root._blurOn ? Math.max(0, root.paintedWidth - 2 * root._blurInsetEff) : 0
        height: root._blurOn ? Math.max(0, root.paintedHeight - 2 * root._blurInsetEff) : 0
        radius: Math.max(0, root.effectiveRounding - root._blurInsetEff)
    }
    Region {
        id: blurNeckTop
        x: root._blurNeckTopRect.x
        y: root._blurNeckTopRect.y
        width: root._blurNeckTopRect.width
        height: root._blurNeckTopRect.height
    }
    Region {
        id: blurNeckBottom
        x: root._blurNeckBottomRect.x
        y: root._blurNeckBottomRect.y
        width: root._blurNeckBottomRect.width
        height: root._blurNeckBottomRect.height
    }
    Region {
        id: blurNeckLeft
        x: root._blurNeckLeftRect.x
        y: root._blurNeckLeftRect.y
        width: root._blurNeckLeftRect.width
        height: root._blurNeckLeftRect.height
    }
    Region {
        id: blurNeckRight
        x: root._blurNeckRightRect.x
        y: root._blurNeckRightRect.y
        width: root._blurNeckRightRect.width
        height: root._blurNeckRightRect.height
    }

    // ── Slot hover/drag tracking ─────────────────────────────────────
    //
    // ONE invisible "envelope" Item covering the bounding box of the slot's
    // EVENTUAL rect + adjacent bridges (gap-to-edge / gap-to-prev). Carries
    // HoverHandler + DropArea. Critical: envelope geometry must NOT depend
    // on the animated paintedWidth/Height, because at open time those are
    // 0 and grow over hundreds of ms — during that window the envelope
    // would otherwise have no area and never report hovered=true.
    //
    // Stable rect: use lastTargetWidth/Height (the latest non-zero target,
    // updated synchronously when content loads) → so the envelope already
    // covers where the bg WILL be once animation completes.
    readonly property int _envStableW: Math.max(paintedWidth, lastTargetWidth, targetWrapperWidth)
    readonly property int _envStableH: Math.max(paintedHeight, lastTargetHeight, targetWrapperHeight)
    function _envStablePos() {
        let sx, sy;
        if (aHCenter && !aLeft && !aRight)
            sx = (zWidth / 2) - (_envStableW / 2) + _clampHOffset(hCenterOffset, _envStableW);
        else if (aLeft)
            sx = mLeft + edgeLeft;
        else if (aRight)
            sx = zWidth - _envStableW - mRight - edgeRight;
        else
            sx = root.x;

        if (aVCenter && !aTop && !aBottom)
            sy = (zHeight / 2) - (_envStableH / 2) + _clampVOffset(vCenterOffset, _envStableH);
        else if (aTop)
            sy = mTop + edgeTop;
        else if (aBottom)
            sy = zHeight - _envStableH - mBottom - edgeBottom;
        else
            sy = root.y;
        return Qt.point(sx, sy);
    }

    readonly property rect _slotEnvelopeRect: {
        // Stable slot rect (from target dimensions).
        const sp = _envStablePos();
        const sw = _envStableW;
        const sh = _envStableH;
        // Union with current animated rect — in case animation overshoots.
        let xMin = Math.min(sp.x, root.x);
        let yMin = Math.min(sp.y, root.y);
        let xMax = Math.max(sp.x + sw, root.x + root.paintedWidth);
        let yMax = Math.max(sp.y + sh, root.y + root.paintedHeight);
        // Add adjacent bridges using STABLE position so they're correct from
        // the first frame too. Bridges extend to the screen edge for layer-1
        // anchored sides, and toward prev for layer-2+.
        if (!isOverlay && !borrowed && layerIdx <= 1) {
            if (aTop && sp.y > 0)
                yMin = Math.min(yMin, 0);
            if (aBottom && (sp.y + sh) < zHeight)
                yMax = Math.max(yMax, zHeight);
            if (aLeft && sp.x > 0)
                xMin = Math.min(xMin, 0);
            if (aRight && (sp.x + sw) < zWidth)
                xMax = Math.max(xMax, zWidth);
        } else if (!isOverlay && !borrowed && layerIdx > 1 && prevSlot) {
            // Layer-2+: bridge toward prev (existing _bridge*Rect logic uses
            // animated geometry; we approximate using prev's stable bounds
            // would be complex — just include prevSlot's chain rect, which is
            // its current rect unless prev's bg is out on loan).
            xMin = Math.min(xMin, prevSlot.chainX);
            yMin = Math.min(yMin, prevSlot.chainY);
            xMax = Math.max(xMax, prevSlot.chainX + prevSlot.chainW);
            yMax = Math.max(yMax, prevSlot.chainY + prevSlot.chainH);
        }
        return Qt.rect(xMin, yMin, xMax - xMin, yMax - yMin);
    }

    property bool _envHovered: false
    property bool _envDragOver: false
    readonly property bool _slotHovered: _envHovered || _envDragOver
    readonly property bool _slotDragOver: _envDragOver

    on_SlotHoveredChanged: {
        if (manager && manager.setSlotHover && activeSeq >= 0)
            manager.setSlotHover(activeSeq, _slotHovered);
    }
    on_SlotDragOverChanged: {
        if (manager && manager.setSlotDragOver && activeSeq >= 0)
            manager.setSlotDragOver(activeSeq, _slotDragOver);
    }

    // Envelope Item — sized to the resize-union DISPLAY rect, not the live
    // target. While the slot/envelope geometry changes with the cursor
    // engaged, the display rect holds the union of old & new, so the
    // HoverHandler keeps reporting hovered=true until the cursor enters the
    // new target rect (collapse) or leaves entirely (snap on exit).
    Item {
        id: envelopeItem
        parent: root.contentLayer
        x: root._envelopeDisplayRect.x
        y: root._envelopeDisplayRect.y
        width: root._envelopeDisplayRect.width
        height: root._envelopeDisplayRect.height
        z: -1
        HoverHandler {
            id: envHover
            onHoveredChanged: {
                root._envHovered = hovered;
                if (!hovered && !root._envDragOver)
                    root._snapDisplaysToTarget();
            }
        }
        readonly property point _hoverPos: envHover.point.position
        on_HoverPosChanged: {
            if (envHover.hovered)
                root._maybeCollapseFromCursor(_hoverPos.x + envelopeItem.x, _hoverPos.y + envelopeItem.y);
        }
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onContainsDragChanged: {
                root._envDragOver = containsDrag;
                if (!containsDrag && !root._envHovered)
                    root._snapDisplaysToTarget();
            }
            onPositionChanged: drag => {
                root._maybeCollapseFromCursor(drag.x + envelopeItem.x, drag.y + envelopeItem.y);
            }
        }
    }

    Connections {
        target: root
        // bgRect sits at (0,0) inside this slot, so a pure move (margin change
        // repositioning root, no size change) never fires geometryChange on the
        // BlobRect — the SDF compositor would keep drawing it at its stale scene
        // position (a ghost) until something else dirties the group. Nudge it.
        function onXChanged() {
            InputManager.refresh();
            bgRect.repolish();
        }
        function onYChanged() {
            InputManager.refresh();
            bgRect.repolish();
        }
        function onWidthChanged() {
            InputManager.refresh();
        }
        function onHeightChanged() {
            InputManager.refresh();
        }
    }

    // ── SDF bg — every wrapper (overlay included) lives in the shared
    // BlobGroup so adjacent panels merge through the SDF shader (smooth
    // bubbly join, à la Caelestia dock). Overlay no longer paints a flat
    // Rectangle in contentLayer; its z-ordering above bar content is
    // achieved via contentLayer's z=arrivalSeq+0.5 on the content tree.
    //
    // zoneIndex propagates the wrapper's rail-derived zone (0..7 or -1 for
    // center) to the shader, which uses per-zone roundings to enable/disable
    // присасывание per bg.
    BlobRect {
        id: bgRect
        group: root.group
        implicitWidth: root.paintedWidth
        implicitHeight: root.paintedHeight
        radius: root.effectiveRounding
        // Liquid-glass velocity deform (see services/Liquid.qml). The engine tracks
        // this rect's centre speed in the scene and stretches along motion.
        deformScale: Liquid.deformScale
        stiffness: Liquid.deformStiffness
        damping: Liquid.deformDamping
        // Per-panel deform attenuation, keyed on the STABLE target size (not the
        // animating size) so a will-be-large panel is tamed all through its appear.
        deformAtten: Liquid.deformSizeScale(root.lastTargetWidth, root.lastTargetHeight)
        // Speed-keyed rounding: compute the motion boost whenever ANY liquid
        // consumer needs it (rounding bloom or content blur), but let it
        // reshape the visible corners only with liquidRounding on.
        speedRounding: root._liquidMixNeeded ? Liquid.roundingSpeed : 0
        speedRoundingApply: root.liquidRounding
        // While borrowed, присасывание follows the borrower's zone (the rail
        // its anchors imply), not the donor's home zone.
        zoneIndex: root.manager
            ? root.manager.zoneForRail(root.borrowed
                ? root.manager.determineRailIndex(root.activeWrapper)
                : (root.railRef ? root.railRef.railIndex : -1))
            : -1
        sticks: root.sticks
    }

    // ── Fade-aura: opaque inner rect with halo ring OUTSIDE it. Drawn
    // below this wrapper's content (z=arrivalSeq) and above older
    // wrappers' content. The SDF-union mask clips everything to the
    // rounded contour formed by all bgs together — that's the only
    // thing that can shorten the halo's visible distance (e.g. spilling
    // past the rounded contour) or extend it (into SDF-merged
    // neighbours).
    //
    // Layout (centered, symmetric):
    //                       fadeWidth halo (extends past paintedRect if
    //                                       overlapShrink < fadeWidth)
    //          ↓↓
    //   ┌────────────────────────────┐   ← paintedRect (bg edge)
    //   │   ┌────────────────────┐   │   ← inner solid edge (α=1)
    //   │   │ overlapShrink (os) │   │      = paintedRect shrunk by os
    //   │   │                    │   │
    //   │   │     inner solid    │   │
    //   │   │                    │   │
    //   │   └────────────────────┘   │
    //   └────────────────────────────┘
    //
    //   os = 0       → inner solid = paintedRect, halo entirely OUTSIDE
    //                  (only visible where SDF-merged neighbours exist).
    //   os = fw      → halo outer edge exactly at paintedRect's edge.
    //   os > fw      → halo fully inside paintedRect with a moat to the
    //                  bg edge.
    //   os < fw      → halo partly outside paintedRect, mask trims it.
    //
    // fadeStrength shapes the alpha ramp via t^(1/strength):
    //   1.0 = linear, >1 = strong at start (alpha climbs fast near the
    //   transparent outer edge), <1 = weak at start.
    readonly property int fadeWidth: Math.max(0, Config.backgrounds.fadeWidth ?? 0)
    readonly property int overlapShrink: Math.max(0, Config.backgrounds.overlapShrink ?? 0)
    readonly property real fadeStrength: Math.max(0.05, Config.backgrounds.fadeStrength ?? 1.0)
    readonly property color _fadeColor: Colours.palette.surface
    // Peak opacity of the content-backing aura. Honours transparency so the
    // frosted blur behind the panels (niri BackgroundEffect or the QML frost
    // layer) shows through the WHOLE panel, not just the fade ring — otherwise
    // the opaque inner solid hides it in the centre. 1.0 when transparency off.
    readonly property real _fadeMaxAlpha: Colours.transparency.enabled ? Colours.transparency.base : 1.0
    readonly property int _innerW: Math.max(0, paintedWidth - 2 * overlapShrink)
    readonly property int _innerH: Math.max(0, paintedHeight - 2 * overlapShrink)
    // Inner-solid origin in fadeAura-local coords. fadeAura is expanded
    // by fadeWidth on every side, so the inner solid (which is paintedRect
    // shrunk by overlapShrink) sits at (fw+os, fw+os).
    readonly property int _innerOff: fadeWidth + overlapShrink

    // alpha(t) = t^(1/strength). t=0 → fully transparent (outer edge),
    // t=1 → fully opaque (inner edge).
    function _fadeAt(t) {
        const a = Math.pow(t, 1.0 / root.fadeStrength) * root._fadeMaxAlpha;
        return Qt.rgba(root._fadeColor.r, root._fadeColor.g, root._fadeColor.b, a);
    }

    // fadeAura is expanded by `fadeWidth` on each side so the halo ring
    // (which sits OUTSIDE the inner solid) is never clipped by the FBO.
    // Final shape is enforced by the SDF-union mask — halo only paints
    // where bgs actually exist, so it can extend into SDF-merged
    // neighbours and is otherwise cropped to the rounded bg contour.
    Item {
        id: fadeAura
        parent: root.contentLayer
        // Disabled while shader frost is on: the aura's surface backing would
        // cover the frosted-wallpaper fill (content sits directly on the frost).
        // Auto-restored when shaderBlur is off.
        visible: !(Config.general.transparency.shaderBlur ?? false)
                 && (root.fadeWidth > 0 || root.overlapShrink > 0)
        x: root.x - root.fadeWidth
        y: root.y - root.fadeWidth
        width: root.paintedWidth + 2 * root.fadeWidth
        height: root.paintedHeight + 2 * root.fadeWidth
        // activeSeq: a borrow is a fresh "open", so the loaned bg (and its
        // content at +0.5) stacks above everything older, like any new panel.
        z: root.activeSeq

        // Mask = SDF union of all bgs (bgRenderHost FBO), cropped to the
        // same region fadeAura covers.
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskShape
            maskThresholdMin: 0.01
            maskInverted: false
        }

        ShaderEffectSource {
            id: maskShape
            sourceItem: root.groupHost
            sourceRect: Qt.rect(root.x - root.fadeWidth, root.y - root.fadeWidth, root.paintedWidth + 2 * root.fadeWidth, root.paintedHeight + 2 * root.fadeWidth)
            width: root.paintedWidth + 2 * root.fadeWidth
            height: root.paintedHeight + 2 * root.fadeWidth
            visible: false
            live: true
            hideSource: false
            recursive: false
        }

        // Inner solid rect — size = paintedRect shrunk by overlapShrink on
        // every side, centred over paintedRect. No radius: rounded clipping
        // comes from the SDF-union mask. Opacity follows _fadeMaxAlpha (via
        // _fadeAt(1.0)) so it's translucent when transparency is on → frost
        // shows through the centre, not just the fade ring.
        Rectangle {
            x: root._innerOff
            y: root._innerOff
            width: root._innerW
            height: root._innerH
            radius: 0
            color: root._fadeAt(1.0)
        }

        // ── Halo ring: 4 strips + 4 corners around inner_solid_rect.
        // Strip width = fadeWidth, fading from opaque (touching solid) to
        // transparent (outer halo edge).

        // Top strip — sits ABOVE inner solid, gradient transparent→opaque
        Rectangle {
            x: root._innerOff
            y: root._innerOff - root.fadeWidth
            width: root._innerW
            height: root.fadeWidth
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: root._fadeAt(0.0)
                }
                GradientStop {
                    position: 0.1
                    color: root._fadeAt(0.1)
                }
                GradientStop {
                    position: 0.2
                    color: root._fadeAt(0.2)
                }
                GradientStop {
                    position: 0.3
                    color: root._fadeAt(0.3)
                }
                GradientStop {
                    position: 0.4
                    color: root._fadeAt(0.4)
                }
                GradientStop {
                    position: 0.5
                    color: root._fadeAt(0.5)
                }
                GradientStop {
                    position: 0.6
                    color: root._fadeAt(0.6)
                }
                GradientStop {
                    position: 0.7
                    color: root._fadeAt(0.7)
                }
                GradientStop {
                    position: 0.8
                    color: root._fadeAt(0.8)
                }
                GradientStop {
                    position: 0.9
                    color: root._fadeAt(0.9)
                }
                GradientStop {
                    position: 1.0
                    color: root._fadeAt(1.0)
                }
            }
        }
        // Bottom strip — sits BELOW inner solid, gradient opaque→transparent
        Rectangle {
            x: root._innerOff
            y: root._innerOff + root._innerH
            width: root._innerW
            height: root.fadeWidth
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: root._fadeAt(1.0)
                }
                GradientStop {
                    position: 0.1
                    color: root._fadeAt(0.9)
                }
                GradientStop {
                    position: 0.2
                    color: root._fadeAt(0.8)
                }
                GradientStop {
                    position: 0.3
                    color: root._fadeAt(0.7)
                }
                GradientStop {
                    position: 0.4
                    color: root._fadeAt(0.6)
                }
                GradientStop {
                    position: 0.5
                    color: root._fadeAt(0.5)
                }
                GradientStop {
                    position: 0.6
                    color: root._fadeAt(0.4)
                }
                GradientStop {
                    position: 0.7
                    color: root._fadeAt(0.3)
                }
                GradientStop {
                    position: 0.8
                    color: root._fadeAt(0.2)
                }
                GradientStop {
                    position: 0.9
                    color: root._fadeAt(0.1)
                }
                GradientStop {
                    position: 1.0
                    color: root._fadeAt(0.0)
                }
            }
        }
        // Left strip — sits LEFT of inner solid, gradient transparent→opaque
        Rectangle {
            x: root._innerOff - root.fadeWidth
            y: root._innerOff
            width: root.fadeWidth
            height: root._innerH
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: root._fadeAt(0.0)
                }
                GradientStop {
                    position: 0.1
                    color: root._fadeAt(0.1)
                }
                GradientStop {
                    position: 0.2
                    color: root._fadeAt(0.2)
                }
                GradientStop {
                    position: 0.3
                    color: root._fadeAt(0.3)
                }
                GradientStop {
                    position: 0.4
                    color: root._fadeAt(0.4)
                }
                GradientStop {
                    position: 0.5
                    color: root._fadeAt(0.5)
                }
                GradientStop {
                    position: 0.6
                    color: root._fadeAt(0.6)
                }
                GradientStop {
                    position: 0.7
                    color: root._fadeAt(0.7)
                }
                GradientStop {
                    position: 0.8
                    color: root._fadeAt(0.8)
                }
                GradientStop {
                    position: 0.9
                    color: root._fadeAt(0.9)
                }
                GradientStop {
                    position: 1.0
                    color: root._fadeAt(1.0)
                }
            }
        }
        // Right strip — sits RIGHT of inner solid, gradient opaque→transparent
        Rectangle {
            x: root._innerOff + root._innerW
            y: root._innerOff
            width: root.fadeWidth
            height: root._innerH
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: root._fadeAt(1.0)
                }
                GradientStop {
                    position: 0.1
                    color: root._fadeAt(0.9)
                }
                GradientStop {
                    position: 0.2
                    color: root._fadeAt(0.8)
                }
                GradientStop {
                    position: 0.3
                    color: root._fadeAt(0.7)
                }
                GradientStop {
                    position: 0.4
                    color: root._fadeAt(0.6)
                }
                GradientStop {
                    position: 0.5
                    color: root._fadeAt(0.5)
                }
                GradientStop {
                    position: 0.6
                    color: root._fadeAt(0.4)
                }
                GradientStop {
                    position: 0.7
                    color: root._fadeAt(0.3)
                }
                GradientStop {
                    position: 0.8
                    color: root._fadeAt(0.2)
                }
                GradientStop {
                    position: 0.9
                    color: root._fadeAt(0.1)
                }
                GradientStop {
                    position: 1.0
                    color: root._fadeAt(0.0)
                }
            }
        }

        // ── 4 corner pieces with RadialGradient.
        // Each corner is a fadeWidth × fadeWidth Shape whose radial center
        // is at the corner that touches the inner solid rect. Alpha at the
        // strip boundary equals the strip's linear alpha at the same point
        // (radius-based fade in both is equivalent on the boundary line),
        // so strip↔corner joints are continuous — no visible seams.

        // Top-left — sits at the TL corner outside inner solid.
        // Radial centre at (fw, fw) = the corner of inner solid.
        Shape {
            x: root._innerOff - root.fadeWidth
            y: root._innerOff - root.fadeWidth
            width: root.fadeWidth
            height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: root.fadeWidth
                    centerY: root.fadeWidth
                    centerRadius: root.fadeWidth
                    focalX: root.fadeWidth
                    focalY: root.fadeWidth
                    focalRadius: 0
                    GradientStop {
                        position: 0.0
                        color: root._fadeAt(1.0)
                    }
                    GradientStop {
                        position: 0.1
                        color: root._fadeAt(0.9)
                    }
                    GradientStop {
                        position: 0.2
                        color: root._fadeAt(0.8)
                    }
                    GradientStop {
                        position: 0.3
                        color: root._fadeAt(0.7)
                    }
                    GradientStop {
                        position: 0.4
                        color: root._fadeAt(0.6)
                    }
                    GradientStop {
                        position: 0.5
                        color: root._fadeAt(0.5)
                    }
                    GradientStop {
                        position: 0.6
                        color: root._fadeAt(0.4)
                    }
                    GradientStop {
                        position: 0.7
                        color: root._fadeAt(0.3)
                    }
                    GradientStop {
                        position: 0.8
                        color: root._fadeAt(0.2)
                    }
                    GradientStop {
                        position: 0.9
                        color: root._fadeAt(0.1)
                    }
                    GradientStop {
                        position: 1.0
                        color: root._fadeAt(0.0)
                    }
                }
                startX: 0
                startY: 0
                PathLine {
                    x: root.fadeWidth
                    y: 0
                }
                PathLine {
                    x: root.fadeWidth
                    y: root.fadeWidth
                }
                PathLine {
                    x: 0
                    y: root.fadeWidth
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
        // Top-right — sits at the TR corner outside inner solid.
        // Radial centre at (0, fw) = the corner of inner solid.
        Shape {
            x: root._innerOff + root._innerW
            y: root._innerOff - root.fadeWidth
            width: root.fadeWidth
            height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 0
                    centerY: root.fadeWidth
                    centerRadius: root.fadeWidth
                    focalX: 0
                    focalY: root.fadeWidth
                    focalRadius: 0
                    GradientStop {
                        position: 0.0
                        color: root._fadeAt(1.0)
                    }
                    GradientStop {
                        position: 0.1
                        color: root._fadeAt(0.9)
                    }
                    GradientStop {
                        position: 0.2
                        color: root._fadeAt(0.8)
                    }
                    GradientStop {
                        position: 0.3
                        color: root._fadeAt(0.7)
                    }
                    GradientStop {
                        position: 0.4
                        color: root._fadeAt(0.6)
                    }
                    GradientStop {
                        position: 0.5
                        color: root._fadeAt(0.5)
                    }
                    GradientStop {
                        position: 0.6
                        color: root._fadeAt(0.4)
                    }
                    GradientStop {
                        position: 0.7
                        color: root._fadeAt(0.3)
                    }
                    GradientStop {
                        position: 0.8
                        color: root._fadeAt(0.2)
                    }
                    GradientStop {
                        position: 0.9
                        color: root._fadeAt(0.1)
                    }
                    GradientStop {
                        position: 1.0
                        color: root._fadeAt(0.0)
                    }
                }
                startX: 0
                startY: 0
                PathLine {
                    x: root.fadeWidth
                    y: 0
                }
                PathLine {
                    x: root.fadeWidth
                    y: root.fadeWidth
                }
                PathLine {
                    x: 0
                    y: root.fadeWidth
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
        // Bottom-left — sits at the BL corner outside inner solid.
        // Radial centre at (fw, 0) = the corner of inner solid.
        Shape {
            x: root._innerOff - root.fadeWidth
            y: root._innerOff + root._innerH
            width: root.fadeWidth
            height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: root.fadeWidth
                    centerY: 0
                    centerRadius: root.fadeWidth
                    focalX: root.fadeWidth
                    focalY: 0
                    focalRadius: 0
                    GradientStop {
                        position: 0.0
                        color: root._fadeAt(1.0)
                    }
                    GradientStop {
                        position: 0.1
                        color: root._fadeAt(0.9)
                    }
                    GradientStop {
                        position: 0.2
                        color: root._fadeAt(0.8)
                    }
                    GradientStop {
                        position: 0.3
                        color: root._fadeAt(0.7)
                    }
                    GradientStop {
                        position: 0.4
                        color: root._fadeAt(0.6)
                    }
                    GradientStop {
                        position: 0.5
                        color: root._fadeAt(0.5)
                    }
                    GradientStop {
                        position: 0.6
                        color: root._fadeAt(0.4)
                    }
                    GradientStop {
                        position: 0.7
                        color: root._fadeAt(0.3)
                    }
                    GradientStop {
                        position: 0.8
                        color: root._fadeAt(0.2)
                    }
                    GradientStop {
                        position: 0.9
                        color: root._fadeAt(0.1)
                    }
                    GradientStop {
                        position: 1.0
                        color: root._fadeAt(0.0)
                    }
                }
                startX: 0
                startY: 0
                PathLine {
                    x: root.fadeWidth
                    y: 0
                }
                PathLine {
                    x: root.fadeWidth
                    y: root.fadeWidth
                }
                PathLine {
                    x: 0
                    y: root.fadeWidth
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
        // Bottom-right — sits at the BR corner outside inner solid.
        // Radial centre at (0, 0) = the corner of inner solid.
        Shape {
            x: root._innerOff + root._innerW
            y: root._innerOff + root._innerH
            width: root.fadeWidth
            height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 0
                    centerY: 0
                    centerRadius: root.fadeWidth
                    focalX: 0
                    focalY: 0
                    focalRadius: 0
                    GradientStop {
                        position: 0.0
                        color: root._fadeAt(1.0)
                    }
                    GradientStop {
                        position: 0.1
                        color: root._fadeAt(0.9)
                    }
                    GradientStop {
                        position: 0.2
                        color: root._fadeAt(0.8)
                    }
                    GradientStop {
                        position: 0.3
                        color: root._fadeAt(0.7)
                    }
                    GradientStop {
                        position: 0.4
                        color: root._fadeAt(0.6)
                    }
                    GradientStop {
                        position: 0.5
                        color: root._fadeAt(0.5)
                    }
                    GradientStop {
                        position: 0.6
                        color: root._fadeAt(0.4)
                    }
                    GradientStop {
                        position: 0.7
                        color: root._fadeAt(0.3)
                    }
                    GradientStop {
                        position: 0.8
                        color: root._fadeAt(0.2)
                    }
                    GradientStop {
                        position: 0.9
                        color: root._fadeAt(0.1)
                    }
                    GradientStop {
                        position: 1.0
                        color: root._fadeAt(0.0)
                    }
                }
                startX: 0
                startY: 0
                PathLine {
                    x: root.fadeWidth
                    y: 0
                }
                PathLine {
                    x: root.fadeWidth
                    y: root.fadeWidth
                }
                PathLine {
                    x: 0
                    y: root.fadeWidth
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
    }

    // ── Content tree (reparented to contentLayer; z=arrivalSeq+0.5 keeps
    // each window's content above its overlay bg AND above all older bgs).
    Item {
        id: contentRoot
        parent: root.contentLayer
        x: root.x
        y: root.y
        width: root.paintedWidth
        height: root.paintedHeight
        z: root.activeSeq + 0.5

        // Mirror the SDF blob's velocity deform onto the content so it stretches
        // WITH the background instead of staying rectangular. bgRect.deformMatrix
        // is the centred deform in the blob's local px space (same paintedWidth ×
        // paintedHeight as contentRoot), so it maps 1:1. Composes on top of
        // scalingRoot's size-fit Scale below.
        transform: Matrix4x4 {
            matrix: bgRect.deformMatrix
        }

        Item {
            id: scalingRoot
            anchors.centerIn: parent
            width: root.lastTargetWidth
            height: root.lastTargetHeight

            transform: Scale {
                xScale: root.lastTargetWidth > 0 ? root.paintedWidth / root.lastTargetWidth : 0
                yScale: root.lastTargetHeight > 0 ? root.paintedHeight / root.lastTargetHeight : 0
                origin.x: scalingRoot.width / 2
                origin.y: scalingRoot.height / 2
            }

            // Liquid content effects: squeeze (vertex warp over a GridMesh
            // pressing the grid into the animated rounded contour) + blur
            // (13-tap Poisson in the fragment stage). Applied HERE — in
            // pre-Scale/pre-deform space — so the size-fit Scale and the SDF
            // deform (which also shapes the blob contour) compose on top and
            // content + contour stay in step. Layer only exists while active.
            layer.enabled: root._warpMix > 0.01 || root._blurPx > 0.1
            layer.smooth: true
            // Mipmaps feed the blur's mip-bias prefilter (kills tap grain).
            // Only generated while the layer exists, so zero cost at rest.
            layer.mipmap: root.liquidContentBlur
            layer.effect: ShaderEffect {
                mesh: GridMesh {
                    resolution: Qt.size(24, 24)
                }
                vertexShader: `file://${Quickshell.shellDir}/drawers/backgrounds/shaders/contentwarp.vert.qsb`
                fragmentShader: `file://${Quickshell.shellDir}/drawers/backgrounds/shaders/contentwarp.frag.qsb`
                property variant source
                property vector2d contentSize: Qt.vector2d(scalingRoot.width, scalingRoot.height)
                // Same lerp the rounding rides: base → capsule by the animated
                // mix, in scalingRoot (pre-Scale) units.
                property real radiusPx: {
                    const maxR = Math.min(scalingRoot.width, scalingRoot.height) / 2;
                    const base = Math.min(root.windowRounding, maxR);
                    return base + (maxR - base) * root._warpMix;
                }
                property real amount: root._warpMix
                property real invertMode: (Config.backgrounds.liquidContentWarpInvert ?? false) ? 1.0 : 0.0
                property real edgeStrength: Config.backgrounds.liquidContentWarpEdge ?? 1.0
                property real pinchStrength: Config.backgrounds.liquidContentWarpPinch ?? 0.6
                property real blurPx: root._blurPx
                property real blurSpread: Config.backgrounds.liquidContentBlurSpread ?? 1.0
                property real blurSoftness: Config.backgrounds.liquidContentBlurSoftness ?? 1.0
            }

            Item {
                id: paddingContainer
                anchors.fill: parent
                anchors.leftMargin: root.pLeft
                anchors.topMargin: root.pTop
                anchors.rightMargin: root.pRight
                anchors.bottomMargin: root.pBottom

                Loader {
                    id: loader
                    sourceComponent: root.content
                    // Donor content stays ALIVE (state preserved — e.g. the
                    // bar) but hidden while its bg is out on loan.
                    visible: !root.borrowed

                    // Content size is mirrored into plain properties instead of
                    // read inline: the x/y bindings also depend on parent size,
                    // which itself derives from the same childrenRect (via
                    // targetWrapper* → lastTarget* → scalingRoot), so an inline
                    // read re-fires childrenRectChanged mid-evaluation and Qt
                    // flags a binding loop on y.
                    property real contentW: 0
                    property real contentH: 0
                    x: (parent.width - contentW) / 2
                    y: (parent.height - contentH) / 2

                    function updateContentSize(): void {
                        contentW = item ? (item.childrenRect.width || item.implicitWidth) : 0;
                        contentH = item ? (item.childrenRect.height || item.implicitHeight) : 0;
                    }

                    onItemChanged: updateContentSize()
                    Connections {
                        target: loader.item

                        function onChildrenRectChanged(): void {
                            loader.updateContentSize();
                        }
                        function onImplicitWidthChanged(): void {
                            loader.updateContentSize();
                        }
                        function onImplicitHeightChanged(): void {
                            loader.updateContentSize();
                        }
                    }

                    Component.onCompleted: root._syncContentLoader()
                }

                // Borrower content (mode "replace"): only the borrow-stack
                // TOP is instantiated; a hand-off between borrowers swaps the
                // component here and the slot morphs to the new size. Unloads
                // itself once the stack drains (borrowContent → null).
                Loader {
                    id: borrowLoader
                    sourceComponent: root.borrowContent
                    visible: root.borrowed

                    property real contentW: 0
                    property real contentH: 0
                    x: (parent.width - contentW) / 2
                    y: (parent.height - contentH) / 2

                    function updateContentSize(): void {
                        contentW = item ? (item.childrenRect.width || item.implicitWidth) : 0;
                        contentH = item ? (item.childrenRect.height || item.implicitHeight) : 0;
                    }

                    onItemChanged: updateContentSize()
                    Connections {
                        target: borrowLoader.item

                        function onChildrenRectChanged(): void {
                            borrowLoader.updateContentSize();
                        }
                        function onImplicitWidthChanged(): void {
                            borrowLoader.updateContentSize();
                        }
                        function onImplicitHeightChanged(): void {
                            borrowLoader.updateContentSize();
                        }
                    }
                }
            }
        }
    }

    // Publish painted geometry to manager so BorderZones can read the actual
    // rendered size of this slot (wrapperWidth/Height in the contract may be
    // 0 for auto-sized wrappers — manager-driven slot rects are the source
    // of truth for layout computations downstream).
    //
    // Implemented imperatively via signal handlers (NOT a side-effecting
    // readonly binding) — Qt 6 flags the latter as a binding loop.
    function _publishSlotRect() {
        if (!manager || !manager.setSlotRect || activeSeq < 0)
            return;
        // Live (possibly flying) geometry goes to the active seq; while
        // borrowed, the donor's own seq keeps the frozen home footprint so
        // BorderZone strips hold the donor's place.
        manager.setSlotRect(activeSeq, x, y, paintedWidth, paintedHeight);
        if (borrowed && _borrow.homeRect) {
            const hr = _borrow.homeRect;
            manager.setSlotRect(latchedSeq, hr.x, hr.y, hr.w, hr.h);
        }
    }
    Connections {
        target: root
        function onXChanged() {
            root._publishSlotRect();
        }
        function onYChanged() {
            root._publishSlotRect();
        }
        function onPaintedWidthChanged() {
            root._publishSlotRect();
            root._maybeFinalize();
        }
        function onPaintedHeightChanged() {
            root._publishSlotRect();
            root._maybeFinalize();
        }
    }

    Component.onCompleted: {
        // Seed display rects once bindings have resolved, so they start at
        // the live target instead of (0,0,0,0).
        Qt.callLater(() => {
            root._slotDisplayRect = root._slotTargetRect;
            root._envelopeDisplayRect = root._slotEnvelopeRect;
        });
        InputManager.addRegion(inputRegion);
        InputManager.addRegion(holdoverRegion);
        InputManager.addRegion(bridgeTop);
        InputManager.addRegion(bridgeBottom);
        InputManager.addRegion(bridgeLeft);
        InputManager.addRegion(bridgeRight);
        // Compositor-blur sub-regions (gated to 0 until settled).
        BlurManager.addRegion(blurBody);
        BlurManager.addRegion(blurNeckTop);
        BlurManager.addRegion(blurNeckBottom);
        BlurManager.addRegion(blurNeckLeft);
        BlurManager.addRegion(blurNeckRight);
        // Latch the seq. This fires the activeSeq handler once; prev < 0
        // makes it a no-op beyond seeding _prevActiveSeq + contentLoader
        // (already pointed at the donor loader by its own onCompleted).
        root.latchedSeq = root.arrivalSeq;
        // First size drive. Everything in this delegate has completed by
        // now, so the springs are guaranteed startable. Pinned surfaces
        // (bar segments at startup) snap into place; anything else with a
        // known size springs from zero — that's the appear. Content that
        // hasn't laid out yet springs later from the target handlers.
        root._sizeReady = true;
        if (!root.dying) {
            if (root.isPinned) {
                sprW.stop();
                sprH.stop();
                root._rawWidth = root.targetWrapperWidth;
                root._rawHeight = root.targetWrapperHeight;
            } else {
                if (root.targetWrapperWidth > 0)
                    root._driveWidth(root.targetWrapperWidth);
                if (root.targetWrapperHeight > 0)
                    root._driveHeight(root.targetWrapperHeight);
            }
        }
        // Delegate created already dying (safety path — normally the flip
        // reaches a live delegate), so onDyingChanged won't fire. Kick off
        // the collapse here.
        if (root.dying) {
            root._startCollapse();
        } else if (!root.isPinned && !root.borrowed) {
            // Real open → droplet rounding (+ shader content blur/squeeze on
            // the same mix, hence the wider gate). Pinned panels (bar) skip
            // the droplet by design — they appear at startup, not as an
            // interactive open.
            if (root._liquidMixNeeded)
                appearRoundAnim.start();
        }
    }
    Component.onDestruction: {
        InputManager.removeRegion(inputRegion);
        InputManager.removeRegion(holdoverRegion);
        InputManager.removeRegion(bridgeTop);
        InputManager.removeRegion(bridgeBottom);
        InputManager.removeRegion(bridgeLeft);
        InputManager.removeRegion(bridgeRight);
        BlurManager.removeRegion(blurBody);
        BlurManager.removeRegion(blurNeckTop);
        BlurManager.removeRegion(blurNeckBottom);
        BlurManager.removeRegion(blurNeckLeft);
        BlurManager.removeRegion(blurNeckRight);
        if (manager && manager.clearSlotRect) {
            manager.clearSlotRect(latchedSeq);
            if (activeSeq !== latchedSeq)
                manager.clearSlotRect(activeSeq);
        }
        if (manager && manager.clearSlotHover) {
            manager.clearSlotHover(latchedSeq);
            if (activeSeq !== latchedSeq)
                manager.clearSlotHover(activeSeq);
        }
        if (manager && manager.clearSlotDragOver) {
            manager.clearSlotDragOver(latchedSeq);
            if (activeSeq !== latchedSeq)
                manager.clearSlotDragOver(activeSeq);
        }
    }
}
