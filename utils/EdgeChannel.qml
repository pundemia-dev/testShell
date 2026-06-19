pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.utils

// One edge (top/bottom/left/right) of one screen. In reuse mode (the only mode
// for now) it owns a single persistent rails wrapper that slides + morphs
// between hosts on this edge as the active handle changes.
//
// Position is composed entirely from the existing rails contract — NO new
// contract fields:
//   • anchored to the edge's CENTRE rail (top→rail 1, bottom→7, left→3, right→5),
//     push layer-2 so it sits just past the host (below a top bar, above a
//     bottom dock, etc.);
//   • the free axis offset (hCenterOffset for top/bottom, vCenterOffset for
//     left/right) is set to (host centre − screen centre), so it lands under
//     the hovered widget;
//   • we ease the offset HERE (WindowSlot.x has no Behavior — only its size
//     springs), so changing the active handle makes the bg glide across.
//
// Open state is decided ENTIRELY from hover inputs that do NOT depend on the
// rails seq, so there is no open→seq→hover→open feedback loop:
//   • engaged     — a content handle is hovered (opens + drives content/offset)
//   • panelHovered — cursor on the popout itself (HoverHandler in the content,
//                    with a margin that reaches across the gap to the host);
//                    holds the popout open AND can recover/revive it mid-close
// Non-visual: instantiated by PopoutsManager with no visual parent.
Item {
    id: ch

    required property string edge
    required property var manager        // BackgroundsManager
    required property var screen          // ShellScreen
    required property int screenWidth
    required property int screenHeight

    // Active content handle for this (screen, edge); driven by PopoutsManager.
    property var activeHandle: null
    // Cursor over the popout panel itself; set by the content's HoverHandler,
    // whose margin reaches across the gap to the host so the widget↔popout
    // move stays hovered (the geometric bridge).
    property bool panelHovered: false

    readonly property bool isHorizontalEdge: edge === "top" || edge === "bottom"

    // Retained content/overrides: keep showing the last host's content while
    // the cursor is bridging on the popout/bar (activeHandle momentarily null).
    property var currentComponent: null
    property var currentOverrides: ({})

    // ── Eased offset (the "slide") ───────────────────────────────────
    property bool _noAnim: false
    property real offset: 0
    Behavior on offset {
        enabled: !ch._noAnim
        SpringAnimation {
            spring: Liquid.sizeSpring
            damping: Liquid.sizeDamping
            epsilon: Liquid.sizeEpsilon
        }
    }

    function _computeOffset(h) {
        const a = h ? h.anchorItem : null;
        if (!a)
            return ch.offset;
        if (ch.isHorizontalEdge) {
            const p = a.mapToItem(null, a.width / 2, 0);
            return p.x - ch.screenWidth / 2;
        }
        const p = a.mapToItem(null, 0, a.height / 2);
        return p.y - ch.screenHeight / 2;
    }

    onActiveHandleChanged: {
        if (!activeHandle)
            return;
        currentComponent = activeHandle.popoutContent;
        currentOverrides = activeHandle.overrides ?? ({});
        const o = _computeOffset(activeHandle);
        if (!_live) {
            // Fresh open → snap to the host (no slide-in from screen centre).
            _noAnim = true;
            offset = o;
            _noAnim = false;
        } else {
            // Already open on another host → glide across.
            offset = o;
        }
    }

    // ── Open state + lifecycle ───────────────────────────────────────
    // A content handle is actively hovered → (re)opens + drives content/offset.
    readonly property bool engaged: activeHandle !== null
    // HOLDS the popout open while the cursor is on the popout itself (its content
    // HoverHandler). Holds only — panelHovered can't be true unless the popout is
    // already open, so it can't summon an empty popout.
    readonly property bool keepAlive: panelHovered

    // Instantaneous intent. Recoverable (OR of both inputs), so reaching the
    // popout re-asserts it even if the widget hover momentarily dropped.
    readonly property bool _wantOpen: engaged || keepAlive

    property bool open: false
    property bool _live: false      // bg currently requested (one-way; snap gate)

    // Close DEBOUNCE. Opening a popout perturbs the layershell input mask near
    // the bar's inner seam (and the popout's own hover margin overlaps that
    // strip), so the compositor briefly fires wl_pointer.leave on the host
    // widget AND the popout — a multi-frame round-trip that flaps _wantOpen
    // false→true with a stationary cursor. We open immediately but defer the
    // CLOSE by a short grace; if intent returns within it (it does, because the
    // cursor never actually left), the close is cancelled → no open/close
    // oscillation. This is scoped to the popout's own churn — NOT a cross-module
    // transit bridge. Doubles as the revive-on-re-hover window.
    on_WantOpenChanged: {
        if (_wantOpen) {
            closeTimer.stop();
            open = true;
        } else {
            closeTimer.restart();
        }
    }
    Timer {
        id: closeTimer
        interval: Appearance.anim.durations.small
        onTriggered: ch.open = false
    }

    onOpenChanged: {
        if (open) {
            manager.requestBackground(wrapper);
            _live = true;
        } else {
            manager.removeBackground(wrapper);
            _live = false;
        }
    }

    function _ovr(key, def) {
        const v = currentOverrides ? currentOverrides[key] : undefined;
        return (v !== undefined && v !== null) ? v : def;
    }
    readonly property int _gap: _ovr("gap", Config.popouts.gap)
    readonly property int _pad: _ovr("padding", Config.popouts.padding)

    // ── Rails contract wrapper ───────────────────────────────────────
    property QtObject wrapper: QtObject {
        property int wrapperWidth: 0
        property int wrapperHeight: 0

        property bool aTop: ch.edge === "top"
        property bool aBottom: ch.edge === "bottom"
        property bool aLeft: ch.edge === "left"
        property bool aRight: ch.edge === "right"
        property bool aHorizontalCenter: ch.isHorizontalEdge
        property bool aVerticalCenter: !ch.isHorizontalEdge

        // Facing margin = gap to the host; perpendicular margins 0.
        property int mTop: ch.edge === "top" ? ch._gap : 0
        property int mBottom: ch.edge === "bottom" ? ch._gap : 0
        property int mLeft: ch.edge === "left" ? ch._gap : 0
        property int mRight: ch.edge === "right" ? ch._gap : 0

        // The slide axis.
        property int hCenterOffset: ch.isHorizontalEdge ? Math.round(ch.offset) : 0
        property int vCenterOffset: ch.isHorizontalEdge ? 0 : Math.round(ch.offset)

        property int pLeft: ch._pad
        property int pRight: ch._pad
        property int pTop: ch._pad
        property int pBottom: ch._pad

        property string mode: ch._ovr("mode", Config.popouts.mode)
        property bool sticks: ch._ovr("sticks", Config.popouts.sticks)
        property bool pinned: false
        property bool reservesSpace: false
        readonly property int layer: 0

        property int windowRounding: {
            const r = ch._ovr("rounding", Config.popouts.rounding);
            return r >= 0 ? r : (Config.backgrounds.rounding ?? 0);
        }

        // Content wrapper: a HoverHandler whose `margin` reaches out across the
        // padding + gap to the host, so the cursor moving from the bar onto the
        // popout stays "hovered" the whole way (the geometric bridge). The inner
        // Loader does the naked content swap — changing currentComponent just
        // swaps its child, so the slot resizes via the size spring.
        property Component content: Item {
            id: panelWrap
            implicitWidth: panelLoader.implicitWidth
            implicitHeight: panelLoader.implicitHeight
            HoverHandler {
                margin: ch._gap + ch._pad + 8
                onHoveredChanged: ch.panelHovered = hovered
            }
            Loader {
                id: panelLoader
                sourceComponent: ch.currentComponent
            }
        }
    }
}
