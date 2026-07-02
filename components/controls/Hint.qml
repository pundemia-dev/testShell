import ".."
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Caelestia.Blobs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Rich hint popup: optional text + optional media (static image or animated
// GIF/WebP, auto-detected by extension). Built on Popup so it renders in the
// window's overlay layer — always above everything and never clipped by the
// settings content pane (which uses clip: true).
//
// The background is a single SDF blob (Caelestia.Blobs) seeded as a small
// droplet ON the info icon that morphs UP into the full tooltip — so the hint
// reads as liquid flowing out of the icon (the BlobRect's velocity squash /
// stretch comes for free, same engine as the shell panels). The popup spans
// icon + neck + body, so its own HoverHandler keeps the hint open once it has
// covered the icon. Open/close (and the morph direction) are driven by
// HintIcon. See docs/development/settings.md.
Popup {
    id: root

    required property Item target
    property string text: ""
    property url media: ""
    property int mediaMaxWidth: 320
    property int mediaMaxHeight: 220

    // Liquid morph progress: 0 = seed droplet on the icon, 1 = full tooltip.
    property real growT: 0

    // Cursor over the hint region (icon + neck + body). HintIcon reads this to
    // keep the hint open once the popup has covered the icon.
    readonly property bool hovered: hintHover.hovered

    // Click anywhere on the body — HintIcon toggles the pin.
    signal tapped()

    readonly property bool isAnimated: {
        const s = String(media).toLowerCase();
        return s.endsWith(".gif") || s.endsWith(".webp");
    }

    // ── Geometry ──────────────────────────────────────────────────────────
    readonly property real bodyW: bodyContent.implicitWidth + Appearance.padding.medium * 2
    readonly property real bodyH: bodyContent.implicitHeight + Appearance.padding.medium * 2
    readonly property real iconW: target ? target.width : 0
    readonly property real iconH: target ? target.height : 0
    readonly property real gap: Appearance.spacing.small
    readonly property real seed: Math.max(8, Math.min(iconW, iconH))
    readonly property real fullW: Math.max(bodyW, iconW)

    // Body final rect: centred in the popup (Qt clamps the whole popup to the
    // window so a wide tooltip stays readable).
    readonly property real bodyX: fullW / 2 - bodyW / 2

    // Seed droplet centred on the icon's ACTUAL position. The analytic centre
    // (fullW/2, …) is only correct when the popup is NOT clamped; once Qt shifts
    // a wide popup to keep it on screen, the icon is no longer under the popup
    // centre, so we map the icon's real centre into the content coords and seed
    // there — the morph then runs diagonally from the icon to the clamped body.
    property real seedCx: fullW / 2
    property real seedCy: bodyH + gap + iconH / 2
    readonly property real seedX: seedCx - seed / 2
    readonly property real seedY: seedCy - seed / 2

    function updateSeed(): void {
        if (!visible || !target)
            return;
        const p = contentRoot.mapFromItem(target, target.width / 2, target.height / 2);
        seedCx = p.x;
        seedCy = p.y;
    }

    // Current (morphing) blob geometry — droplet → body.
    readonly property real vx: seedX + (bodyX - seedX) * growT
    readonly property real vy: seedY + (0 - seedY) * growT
    readonly property real vw: seed + (bodyW - seed) * growT
    readonly property real vh: seed + (bodyH - seed) * growT
    readonly property real vr: seed / 2 + (Appearance.rounding.small - seed / 2) * growT

    parent: target
    modal: false
    closePolicy: Popup.NoAutoClose
    padding: 0
    margins: Appearance.padding.medium
    background: Item {}

    // Centre horizontally over the icon; lift the body above it by the gap.
    x: Math.round((target ? target.width : 0) / 2 - fullW / 2)
    y: -(bodyH + gap)

    // Re-seed the droplet onto the icon's real position once the popup has been
    // placed (and clamped) by Qt — synchronously when it becomes visible, plus a
    // deferred pass so a late clamp/relayout still lands the seed on the icon.
    onVisibleChanged: if (visible) {
        updateSeed();
        Qt.callLater(updateSeed);
    }
    onWidthChanged: Qt.callLater(updateSeed)
    onHeightChanged: Qt.callLater(updateSeed)

    enter: Transition {
        Anim {
            target: root
            property: "growT"
            from: 0
            to: 1
            duration: Appearance.anim.durations.normal
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }
    exit: Transition {
        Anim {
            target: root
            property: "growT"
            from: 1
            to: 0
            duration: Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    contentItem: Item {
        id: contentRoot

        implicitWidth: root.fullW
        implicitHeight: root.bodyH + root.gap + root.iconH

        HoverHandler {
            id: hintHover
        }

        Elevation {
            x: hintBlob.x
            y: hintBlob.y
            width: hintBlob.width
            height: hintBlob.height
            radius: hintBlob.radius
            z: -1
            level: 3
            opacity: root.growT
        }

        // Liquid background: a single SDF blob that grows out of the icon.
        BlobGroup {
            id: hintGroup

            color: Colours.palette.surface_container_highest
            smoothing: 32
        }

        BlobRect {
            id: hintBlob

            group: hintGroup
            x: root.vx
            y: root.vy
            width: Math.max(1, root.vw)
            height: Math.max(1, root.vh)
            radius: root.vr
            deformScale: Liquid.deformScale
            stiffness: Liquid.deformStiffness
            damping: Liquid.deformDamping
            deformAtten: Liquid.deformSizeScale(root.bodyW, root.bodyH)
        }

        // Content rides the morph (tracks the blob, scales + fades in) — the
        // SDF engine follows the BlobRect's own geometry, so scaling a parent
        // would leave the shader stale; we scale the content to match instead.
        Item {
            id: body

            x: root.vx
            y: root.vy
            width: root.bodyW
            height: root.bodyH
            transformOrigin: Item.TopLeft
            scale: root.vw / Math.max(1, root.bodyW)
            opacity: Math.max(0, (root.growT - 0.45) / 0.55)

            // Mirror the blob's velocity deform so the content stretches with it.
            transform: Matrix4x4 {
                matrix: hintBlob.deformMatrix
            }

            TapHandler {
                onTapped: root.tapped()
            }

            ColumnLayout {
                id: bodyContent

                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                Loader {
                    active: String(root.media) !== ""
                    visible: active
                    Layout.alignment: Qt.AlignHCenter
                    sourceComponent: root.isAnimated ? animComp : imgComp
                }

                StyledText {
                    visible: root.text !== ""
                    Layout.maximumWidth: root.mediaMaxWidth
                    text: root.text
                    wrapMode: Text.WordWrap
                    color: Colours.palette.on_surface
                    font.pointSize: Appearance.font.size.small
                }
            }
        }
    }

    Component {
        id: imgComp
        Image {
            source: root.media
            fillMode: Image.PreserveAspectFit
            sourceSize.width: root.mediaMaxWidth
            Layout.maximumWidth: root.mediaMaxWidth
            Layout.maximumHeight: root.mediaMaxHeight
        }
    }

    Component {
        id: animComp
        AnimatedImage {
            source: root.media
            playing: root.visible
            fillMode: Image.PreserveAspectFit
            sourceSize.width: root.mediaMaxWidth
            Layout.maximumWidth: root.mediaMaxWidth
            Layout.maximumHeight: root.mediaMaxHeight
        }
    }
}
