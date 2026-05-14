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
    BlobRect {
        group: root.group
        implicitWidth: root.paintedWidth
        implicitHeight: root.paintedHeight
        radius: root.effectiveRounding
        deformScale: 0
    }

    // ── Fade-aura: opaque rounded rect (size = paintedRect, color = bg)
    // drawn in contentLayer just BELOW this wrapper's content. The aura
    // hides lower wrappers' content sitting beneath, and along the inner
    // perimeter a `fadeWidth`-px halo ring linearly fades the bg color
    // toward transparent — lower content "dissolves" into the bg in that
    // ring.
    //
    // Geometry:
    //   inner_solid_rect = paintedRect ÷ 2*overlapShrink (shrunk inward)
    //   halo_ring        = fadeWidth-wide ring outward from inner_solid_rect
    //   everything       = clipped to paintedRect rounded-shape via mask
    readonly property int fadeWidth: Math.max(0, Config.backgrounds.fadeWidth ?? 0)
    readonly property int overlapShrink: Math.max(0, Config.backgrounds.overlapShrink ?? 0)
    readonly property color _fadeColor: Colours.palette.surface
    readonly property color _fadeTransparent: Qt.rgba(_fadeColor.r, _fadeColor.g, _fadeColor.b, 0)
    readonly property int _innerW: Math.max(0, paintedWidth - 2 * overlapShrink)
    readonly property int _innerH: Math.max(0, paintedHeight - 2 * overlapShrink)
    readonly property int _innerRadius: Math.max(0, effectiveRounding - overlapShrink)

    // fadeAura is enlarged by `fadeWidth` on every side so halo strips
    // outside paintedRect (the case when overlapShrink < fadeWidth) don't
    // get clipped by the FBO. Final shape is clipped via MultiEffect mask
    // sourced from bgRenderHost's SDF.
    Item {
        id: fadeAura
        parent: root.contentLayer
        visible: root.fadeWidth > 0 || root.overlapShrink > 0
        x: root.x - root.fadeWidth
        y: root.y - root.fadeWidth
        width: root.paintedWidth + 2 * root.fadeWidth
        height: root.paintedHeight + 2 * root.fadeWidth
        z: root.arrivalSeq

        // Mask = union of ALL bg shapes (bgRenderHost FBO), cropped to the
        // same region fadeAura covers. Halo can spill into adjacent bgs
        // that are SDF-merged with this one (e.g. stash glued to bar).
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

        // Inner solid rect — fully opaque, shrunken by overlapShrink.
        // Square (no radius) on purpose: rounded clipping is enforced by
        // the MultiEffect mask (bg SDF). A rounded inner rect would leave
        // a transparent gap between its rounded contour and bbox corner.
        Rectangle {
            x: root.fadeWidth + root.overlapShrink
            y: root.fadeWidth + root.overlapShrink
            width: root._innerW
            height: root._innerH
            radius: 0
            color: root._fadeColor
        }

        // ── Halo ring: 4 strips + 4 corners around inner_solid_rect.
        // Strip width = fadeWidth, fading from opaque (touching solid) to
        // transparent (outer halo edge).

        // Top strip
        Rectangle {
            x: root.fadeWidth + root.overlapShrink
            y: root.overlapShrink
            width: root._innerW
            height: root.fadeWidth
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: root._fadeTransparent }
                GradientStop { position: 1; color: root._fadeColor }
            }
        }
        // Bottom strip
        Rectangle {
            x: root.fadeWidth + root.overlapShrink
            y: root.fadeWidth + root.overlapShrink + root._innerH
            width: root._innerW
            height: root.fadeWidth
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: root._fadeColor }
                GradientStop { position: 1; color: root._fadeTransparent }
            }
        }
        // Left strip
        Rectangle {
            x: root.overlapShrink
            y: root.fadeWidth + root.overlapShrink
            width: root.fadeWidth
            height: root._innerH
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root._fadeTransparent }
                GradientStop { position: 1; color: root._fadeColor }
            }
        }
        // Right strip
        Rectangle {
            x: root.fadeWidth + root.overlapShrink + root._innerW
            y: root.fadeWidth + root.overlapShrink
            width: root.fadeWidth
            height: root._innerH
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root._fadeColor }
                GradientStop { position: 1; color: root._fadeTransparent }
            }
        }

        // ── 4 corner pieces with RadialGradient.
        // Each corner is a fadeWidth × fadeWidth Shape whose radial center
        // is at the corner that touches the inner solid rect. Alpha at the
        // strip boundary equals the strip's linear alpha at the same point
        // (radius-based fade in both is equivalent on the boundary line),
        // so strip↔corner joints are continuous — no visible seams.

        // Top-left — inner anchor at (fw, fw) in shape-local coords
        Shape {
            x: root.overlapShrink
            y: root.overlapShrink
            width: root.fadeWidth; height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: root.fadeWidth; centerY: root.fadeWidth
                    centerRadius: root.fadeWidth
                    focalX: root.fadeWidth; focalY: root.fadeWidth
                    focalRadius: 0
                    GradientStop { position: 0; color: root._fadeColor }
                    GradientStop { position: 1; color: root._fadeTransparent }
                }
                startX: 0; startY: 0
                PathLine { x: root.fadeWidth; y: 0 }
                PathLine { x: root.fadeWidth; y: root.fadeWidth }
                PathLine { x: 0; y: root.fadeWidth }
                PathLine { x: 0; y: 0 }
            }
        }
        // Top-right — inner anchor at (0, fw)
        Shape {
            x: root.fadeWidth + root.overlapShrink + root._innerW
            y: root.overlapShrink
            width: root.fadeWidth; height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 0; centerY: root.fadeWidth
                    centerRadius: root.fadeWidth
                    focalX: 0; focalY: root.fadeWidth
                    focalRadius: 0
                    GradientStop { position: 0; color: root._fadeColor }
                    GradientStop { position: 1; color: root._fadeTransparent }
                }
                startX: 0; startY: 0
                PathLine { x: root.fadeWidth; y: 0 }
                PathLine { x: root.fadeWidth; y: root.fadeWidth }
                PathLine { x: 0; y: root.fadeWidth }
                PathLine { x: 0; y: 0 }
            }
        }
        // Bottom-left — inner anchor at (fw, 0)
        Shape {
            x: root.overlapShrink
            y: root.fadeWidth + root.overlapShrink + root._innerH
            width: root.fadeWidth; height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: root.fadeWidth; centerY: 0
                    centerRadius: root.fadeWidth
                    focalX: root.fadeWidth; focalY: 0
                    focalRadius: 0
                    GradientStop { position: 0; color: root._fadeColor }
                    GradientStop { position: 1; color: root._fadeTransparent }
                }
                startX: 0; startY: 0
                PathLine { x: root.fadeWidth; y: 0 }
                PathLine { x: root.fadeWidth; y: root.fadeWidth }
                PathLine { x: 0; y: root.fadeWidth }
                PathLine { x: 0; y: 0 }
            }
        }
        // Bottom-right — inner anchor at (0, 0)
        Shape {
            x: root.fadeWidth + root.overlapShrink + root._innerW
            y: root.fadeWidth + root.overlapShrink + root._innerH
            width: root.fadeWidth; height: root.fadeWidth
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 0; centerY: 0
                    centerRadius: root.fadeWidth
                    focalX: 0; focalY: 0
                    focalRadius: 0
                    GradientStop { position: 0; color: root._fadeColor }
                    GradientStop { position: 1; color: root._fadeTransparent }
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

    Component.onCompleted: InputManager.addRegion(inputRegion)
    Component.onDestruction: InputManager.removeRegion(inputRegion)
}
