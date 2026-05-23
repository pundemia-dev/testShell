pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Caelestia.Blobs
import Quickshell
import qs.config
import qs.services
import qs.utils
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

    // ── Content sizing ───────────────────────────────────────────────
    property Item contentLoader: null

    readonly property int targetWrapperWidth: {
        if (!wrapper) return 0;
        if (wrapper.wrapperWidth !== undefined && wrapper.wrapperWidth > 0) return wrapper.wrapperWidth;
        if (contentLoader && contentLoader.item) {
            return (contentLoader.item.childrenRect.width || contentLoader.item.implicitWidth) + pLeft + pRight;
        }
        return 0;
    }
    readonly property int targetWrapperHeight: {
        if (!wrapper) return 0;
        if (wrapper.wrapperHeight !== undefined && wrapper.wrapperHeight > 0) return wrapper.wrapperHeight;
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

    property int _rawWidth: targetWrapperWidth
    property int _rawHeight: targetWrapperHeight
    readonly property int paintedWidth: Math.max(0, _rawWidth)
    readonly property int paintedHeight: Math.max(0, _rawHeight)

    Behavior on _rawWidth {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.bubblyWidth
            duration: Math.max(root.targetWrapperWidth, root.targetWrapperHeight)
        }
    }
    Behavior on _rawHeight {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.bubblyHeight
            duration: Math.max(root.targetWrapperWidth, root.targetWrapperHeight)
        }
    }

    // ── Anchor flags ─────────────────────────────────────────────────
    readonly property bool aLeft: anchor === "topLeft" || anchor === "left" || anchor === "bottomLeft"
    readonly property bool aRight: anchor === "topRight" || anchor === "right" || anchor === "bottomRight"
    readonly property bool aTop: anchor === "topLeft" || anchor === "top" || anchor === "topRight"
    readonly property bool aBottom: anchor === "bottomLeft" || anchor === "bottom" || anchor === "bottomRight"
    readonly property bool aHCenter: anchor === "top" || anchor === "center" || anchor === "bottom"
    readonly property bool aVCenter: anchor === "left" || anchor === "center" || anchor === "right"
    readonly property bool aCorner: anchor === "topLeft" || anchor === "topRight" || anchor === "bottomLeft" || anchor === "bottomRight"

    // ── Wrapper props ────────────────────────────────────────────────
    readonly property int mLeft: wrapper?.mLeft ?? 0
    readonly property int mRight: wrapper?.mRight ?? 0
    readonly property int mTop: wrapper?.mTop ?? 0
    readonly property int mBottom: wrapper?.mBottom ?? 0
    readonly property int vCenterOffset: wrapper?.vCenterOffset ?? 0
    readonly property int hCenterOffset: wrapper?.hCenterOffset ?? 0
    readonly property int pLeft: wrapper?.pLeft ?? Config.backgrounds.paddings.left ?? 0
    readonly property int pTop: wrapper?.pTop ?? Config.backgrounds.paddings.top ?? 0
    readonly property int pRight: wrapper?.pRight ?? Config.backgrounds.paddings.right ?? 0
    readonly property int pBottom: wrapper?.pBottom ?? Config.backgrounds.paddings.bottom ?? 0
    readonly property int windowRounding: wrapper?.windowRounding ?? Config.backgrounds.rounding ?? 0
    readonly property int effectiveRounding: Math.min(windowRounding, paintedWidth / 2, paintedHeight / 2)
    readonly property string mode: wrapper?.mode ?? "push"
    readonly property bool isPinned: wrapper?.pinned ?? false
    readonly property bool isOverlay: mode === "overlay"

    readonly property var content: wrapper?.content

    // ── Edge offsets ─────────────────────────────────────────────────
    // Pinned wrappers paint at the very edge (edge=0). Push-mode non-pinned
    // wrappers are inset by the reserved area so they don't overlap pinned
    // wrappers that reserve exclusion zones. Overlay wrappers intentionally
    // sit *on top of* other wrappers (that's the whole point of overlay),
    // so they also get edge=0 — otherwise mode:"overlay" would actually
    // behave as "push offset by reserved area".
    readonly property int edgeLeft: (isPinned || isOverlay) ? 0 : left_area
    readonly property int edgeRight: (isPinned || isOverlay) ? 0 : right_area
    readonly property int edgeTop: (isPinned || isOverlay) ? 0 : top_area
    readonly property int edgeBottom: (isPinned || isOverlay) ? 0 : bottom_area

    // ── Previous sibling on rail ─────────────────────────────────────
    readonly property var prevSlot: railRef ? railRef.prevSlot(layerIdx - 1) : null

    // ── L-step detection (corner rails, layer 2, side reservation) ──
    readonly property string _sideForCorner: {
        if (anchor === "topLeft" || anchor === "bottomLeft") return "left";
        if (anchor === "topRight" || anchor === "bottomRight") return "right";
        return "";
    }
    readonly property bool isLStep: {
        if (!aCorner) return false;
        if (layerIdx !== 2) return false;
        if (isOverlay) return false;
        if (!prevSlot || !prevSlot.isPinned) return false;
        if (!_sideForCorner) return false;
        return (manager.reservedEdge(_sideForCorner) || 0) > 0;
    }

    // ── Own-anchor formulas (used when overlay or for non-growth axis) ──
    readonly property int ownX: {
        if (aHCenter && !aLeft && !aRight) {
            return (zWidth / 2) - (paintedWidth / 2) + hCenterOffset;
        }
        if (aLeft) return mLeft + edgeLeft;
        if (aRight) return zWidth - paintedWidth - mRight - edgeRight;
        return 0;
    }
    readonly property int ownY: {
        if (aVCenter && !aTop && !aBottom) {
            return (zHeight / 2) - (paintedHeight / 2) + vCenterOffset;
        }
        if (aTop) return mTop + edgeTop;
        if (aBottom) return zHeight - paintedHeight - mBottom - edgeBottom;
        return 0;
    }

    // ── Position resolved ────────────────────────────────────────────
    readonly property int targetX: {
        // Overlay: cover prev (act like layer 1 of this anchor).
        if (isOverlay) return ownX;
        // Layer 1: own-anchor on both axes.
        if (layerIdx <= 1 || !prevSlot) return ownX;
        // L-step (layer 2 on corner with side reservation): sideways step.
        if (isLStep) {
            if (anchor === "topLeft" || anchor === "bottomLeft") {
                return prevSlot.targetX + prevSlot.paintedWidth + (prevSlot.mRight || 0);
            }
            // topRight / bottomRight
            return prevSlot.targetX - paintedWidth - (prevSlot.mLeft || 0);
        }
        // Side-growing rails (left/right): X is growth axis → from prev.
        if (anchor === "left") return prevSlot.targetX + prevSlot.paintedWidth + (prevSlot.mRight || 0);
        if (anchor === "right") return prevSlot.targetX - paintedWidth - (prevSlot.mLeft || 0);
        // Otherwise (vertical-growth rails): own X.
        return ownX;
    }

    readonly property int targetY: {
        if (isOverlay) return ownY;
        if (layerIdx <= 1 || !prevSlot) return ownY;
        if (isLStep) {
            // Align with prev's edge facing the corner.
            if (anchor === "topLeft" || anchor === "topRight") {
                return prevSlot.targetY;
            }
            // bottomLeft / bottomRight: align bottoms.
            return prevSlot.targetY + prevSlot.paintedHeight - paintedHeight;
        }
        // Top/center/topLeft/topRight rails grow DOWN; left/right keep own Y.
        if (aTop) return prevSlot.targetY + prevSlot.paintedHeight + (prevSlot.mBottom || 0);
        if (aBottom) return prevSlot.targetY - paintedHeight - (prevSlot.mTop || 0);
        if (anchor === "center") return prevSlot.targetY + prevSlot.paintedHeight + (prevSlot.mBottom || 0);
        return ownY;
    }

    // ── Geometry ─────────────────────────────────────────────────────
    x: targetX
    y: targetY
    width: paintedWidth
    height: paintedHeight
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

    Connections {
        target: root
        function onXChanged() { InputManager.refresh(); }
        function onYChanged() { InputManager.refresh(); }
        function onWidthChanged() { InputManager.refresh(); }
        function onHeightChanged() { InputManager.refresh(); }
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
        group: root.group
        implicitWidth: root.paintedWidth
        implicitHeight: root.paintedHeight
        radius: root.effectiveRounding
        deformScale: 0
        zoneIndex: root.manager ? root.manager.zoneForRail(root.railRef ? root.railRef.railIndex : -1) : -1
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
    readonly property int _innerW: Math.max(0, paintedWidth - 2 * overlapShrink)
    readonly property int _innerH: Math.max(0, paintedHeight - 2 * overlapShrink)
    // Inner-solid origin in fadeAura-local coords. fadeAura is expanded
    // by fadeWidth on every side, so the inner solid (which is paintedRect
    // shrunk by overlapShrink) sits at (fw+os, fw+os).
    readonly property int _innerOff: fadeWidth + overlapShrink

    // alpha(t) = t^(1/strength). t=0 → fully transparent (outer edge),
    // t=1 → fully opaque (inner edge).
    function _fadeAt(t) {
        const a = Math.pow(t, 1.0 / root.fadeStrength);
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
        visible: root.fadeWidth > 0 || root.overlapShrink > 0
        x: root.x - root.fadeWidth
        y: root.y - root.fadeWidth
        width: root.paintedWidth + 2 * root.fadeWidth
        height: root.paintedHeight + 2 * root.fadeWidth
        z: root.arrivalSeq

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
            sourceRect: Qt.rect(root.x - root.fadeWidth,
                                root.y - root.fadeWidth,
                                root.paintedWidth + 2 * root.fadeWidth,
                                root.paintedHeight + 2 * root.fadeWidth)
            width: root.paintedWidth + 2 * root.fadeWidth
            height: root.paintedHeight + 2 * root.fadeWidth
            visible: false
            live: true
            hideSource: false
            recursive: false
        }

        // Inner solid rect — fully opaque, size = paintedRect shrunk by
        // overlapShrink on every side, centred over paintedRect. No
        // radius: rounded clipping comes from the SDF-union mask.
        Rectangle {
            x: root._innerOff
            y: root._innerOff
            width: root._innerW
            height: root._innerH
            radius: 0
            color: root._fadeColor
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
                GradientStop { position: 0.0; color: root._fadeAt(0.0) }
                GradientStop { position: 0.1; color: root._fadeAt(0.1) }
                GradientStop { position: 0.2; color: root._fadeAt(0.2) }
                GradientStop { position: 0.3; color: root._fadeAt(0.3) }
                GradientStop { position: 0.4; color: root._fadeAt(0.4) }
                GradientStop { position: 0.5; color: root._fadeAt(0.5) }
                GradientStop { position: 0.6; color: root._fadeAt(0.6) }
                GradientStop { position: 0.7; color: root._fadeAt(0.7) }
                GradientStop { position: 0.8; color: root._fadeAt(0.8) }
                GradientStop { position: 0.9; color: root._fadeAt(0.9) }
                GradientStop { position: 1.0; color: root._fadeAt(1.0) }
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
                GradientStop { position: 0.0; color: root._fadeAt(1.0) }
                GradientStop { position: 0.1; color: root._fadeAt(0.9) }
                GradientStop { position: 0.2; color: root._fadeAt(0.8) }
                GradientStop { position: 0.3; color: root._fadeAt(0.7) }
                GradientStop { position: 0.4; color: root._fadeAt(0.6) }
                GradientStop { position: 0.5; color: root._fadeAt(0.5) }
                GradientStop { position: 0.6; color: root._fadeAt(0.4) }
                GradientStop { position: 0.7; color: root._fadeAt(0.3) }
                GradientStop { position: 0.8; color: root._fadeAt(0.2) }
                GradientStop { position: 0.9; color: root._fadeAt(0.1) }
                GradientStop { position: 1.0; color: root._fadeAt(0.0) }
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
                GradientStop { position: 0.0; color: root._fadeAt(0.0) }
                GradientStop { position: 0.1; color: root._fadeAt(0.1) }
                GradientStop { position: 0.2; color: root._fadeAt(0.2) }
                GradientStop { position: 0.3; color: root._fadeAt(0.3) }
                GradientStop { position: 0.4; color: root._fadeAt(0.4) }
                GradientStop { position: 0.5; color: root._fadeAt(0.5) }
                GradientStop { position: 0.6; color: root._fadeAt(0.6) }
                GradientStop { position: 0.7; color: root._fadeAt(0.7) }
                GradientStop { position: 0.8; color: root._fadeAt(0.8) }
                GradientStop { position: 0.9; color: root._fadeAt(0.9) }
                GradientStop { position: 1.0; color: root._fadeAt(1.0) }
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
                GradientStop { position: 0.0; color: root._fadeAt(1.0) }
                GradientStop { position: 0.1; color: root._fadeAt(0.9) }
                GradientStop { position: 0.2; color: root._fadeAt(0.8) }
                GradientStop { position: 0.3; color: root._fadeAt(0.7) }
                GradientStop { position: 0.4; color: root._fadeAt(0.6) }
                GradientStop { position: 0.5; color: root._fadeAt(0.5) }
                GradientStop { position: 0.6; color: root._fadeAt(0.4) }
                GradientStop { position: 0.7; color: root._fadeAt(0.3) }
                GradientStop { position: 0.8; color: root._fadeAt(0.2) }
                GradientStop { position: 0.9; color: root._fadeAt(0.1) }
                GradientStop { position: 1.0; color: root._fadeAt(0.0) }
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
            width: root.fadeWidth; height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: root.fadeWidth; centerY: root.fadeWidth
                    centerRadius: root.fadeWidth
                    focalX: root.fadeWidth; focalY: root.fadeWidth
                    focalRadius: 0
                    GradientStop { position: 0.0; color: root._fadeAt(1.0) }
                    GradientStop { position: 0.1; color: root._fadeAt(0.9) }
                    GradientStop { position: 0.2; color: root._fadeAt(0.8) }
                    GradientStop { position: 0.3; color: root._fadeAt(0.7) }
                    GradientStop { position: 0.4; color: root._fadeAt(0.6) }
                    GradientStop { position: 0.5; color: root._fadeAt(0.5) }
                    GradientStop { position: 0.6; color: root._fadeAt(0.4) }
                    GradientStop { position: 0.7; color: root._fadeAt(0.3) }
                    GradientStop { position: 0.8; color: root._fadeAt(0.2) }
                    GradientStop { position: 0.9; color: root._fadeAt(0.1) }
                    GradientStop { position: 1.0; color: root._fadeAt(0.0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.fadeWidth; y: 0 }
                PathLine { x: root.fadeWidth; y: root.fadeWidth }
                PathLine { x: 0; y: root.fadeWidth }
                PathLine { x: 0; y: 0 }
            }
        }
        // Top-right — sits at the TR corner outside inner solid.
        // Radial centre at (0, fw) = the corner of inner solid.
        Shape {
            x: root._innerOff + root._innerW
            y: root._innerOff - root.fadeWidth
            width: root.fadeWidth; height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 0; centerY: root.fadeWidth
                    centerRadius: root.fadeWidth
                    focalX: 0; focalY: root.fadeWidth
                    focalRadius: 0
                    GradientStop { position: 0.0; color: root._fadeAt(1.0) }
                    GradientStop { position: 0.1; color: root._fadeAt(0.9) }
                    GradientStop { position: 0.2; color: root._fadeAt(0.8) }
                    GradientStop { position: 0.3; color: root._fadeAt(0.7) }
                    GradientStop { position: 0.4; color: root._fadeAt(0.6) }
                    GradientStop { position: 0.5; color: root._fadeAt(0.5) }
                    GradientStop { position: 0.6; color: root._fadeAt(0.4) }
                    GradientStop { position: 0.7; color: root._fadeAt(0.3) }
                    GradientStop { position: 0.8; color: root._fadeAt(0.2) }
                    GradientStop { position: 0.9; color: root._fadeAt(0.1) }
                    GradientStop { position: 1.0; color: root._fadeAt(0.0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.fadeWidth; y: 0 }
                PathLine { x: root.fadeWidth; y: root.fadeWidth }
                PathLine { x: 0; y: root.fadeWidth }
                PathLine { x: 0; y: 0 }
            }
        }
        // Bottom-left — sits at the BL corner outside inner solid.
        // Radial centre at (fw, 0) = the corner of inner solid.
        Shape {
            x: root._innerOff - root.fadeWidth
            y: root._innerOff + root._innerH
            width: root.fadeWidth; height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: root.fadeWidth; centerY: 0
                    centerRadius: root.fadeWidth
                    focalX: root.fadeWidth; focalY: 0
                    focalRadius: 0
                    GradientStop { position: 0.0; color: root._fadeAt(1.0) }
                    GradientStop { position: 0.1; color: root._fadeAt(0.9) }
                    GradientStop { position: 0.2; color: root._fadeAt(0.8) }
                    GradientStop { position: 0.3; color: root._fadeAt(0.7) }
                    GradientStop { position: 0.4; color: root._fadeAt(0.6) }
                    GradientStop { position: 0.5; color: root._fadeAt(0.5) }
                    GradientStop { position: 0.6; color: root._fadeAt(0.4) }
                    GradientStop { position: 0.7; color: root._fadeAt(0.3) }
                    GradientStop { position: 0.8; color: root._fadeAt(0.2) }
                    GradientStop { position: 0.9; color: root._fadeAt(0.1) }
                    GradientStop { position: 1.0; color: root._fadeAt(0.0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.fadeWidth; y: 0 }
                PathLine { x: root.fadeWidth; y: root.fadeWidth }
                PathLine { x: 0; y: root.fadeWidth }
                PathLine { x: 0; y: 0 }
            }
        }
        // Bottom-right — sits at the BR corner outside inner solid.
        // Radial centre at (0, 0) = the corner of inner solid.
        Shape {
            x: root._innerOff + root._innerW
            y: root._innerOff + root._innerH
            width: root.fadeWidth; height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 0; centerY: 0
                    centerRadius: root.fadeWidth
                    focalX: 0; focalY: 0
                    focalRadius: 0
                    GradientStop { position: 0.0; color: root._fadeAt(1.0) }
                    GradientStop { position: 0.1; color: root._fadeAt(0.9) }
                    GradientStop { position: 0.2; color: root._fadeAt(0.8) }
                    GradientStop { position: 0.3; color: root._fadeAt(0.7) }
                    GradientStop { position: 0.4; color: root._fadeAt(0.6) }
                    GradientStop { position: 0.5; color: root._fadeAt(0.5) }
                    GradientStop { position: 0.6; color: root._fadeAt(0.4) }
                    GradientStop { position: 0.7; color: root._fadeAt(0.3) }
                    GradientStop { position: 0.8; color: root._fadeAt(0.2) }
                    GradientStop { position: 0.9; color: root._fadeAt(0.1) }
                    GradientStop { position: 1.0; color: root._fadeAt(0.0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.fadeWidth; y: 0 }
                PathLine { x: root.fadeWidth; y: root.fadeWidth }
                PathLine { x: 0; y: root.fadeWidth }
                PathLine { x: 0; y: 0 }
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
        z: root.arrivalSeq + 0.5

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
                    x: (parent.width - (item ? (item.childrenRect.width || item.implicitWidth) : 0)) / 2
                    y: (parent.height - (item ? (item.childrenRect.height || item.implicitHeight) : 0)) / 2
                    Component.onCompleted: root.contentLoader = loader
                }
            }
        }
    }

    // Publish painted geometry to manager so BorderZones can read the actual
    // rendered size of this slot (wrapperWidth/Height in the contract may be
    // 0 for auto-sized wrappers — manager-driven slot rects are the source
    // of truth for layout computations downstream).
    readonly property var _publishSlotRect: {
        if (manager && manager.setSlotRect) {
            manager.setSlotRect(arrivalSeq, x, y, paintedWidth, paintedHeight);
        }
        return null;
    }

    Component.onCompleted: InputManager.addRegion(inputRegion)
    Component.onDestruction: {
        InputManager.removeRegion(inputRegion);
        if (manager && manager.clearSlotRect)
            manager.clearSlotRect(arrivalSeq);
    }
}
