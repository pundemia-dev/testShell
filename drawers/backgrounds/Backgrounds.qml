pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Caelestia.Blobs
import qs.config
import qs.services
import "components"

// Per-screen background container. One BlobGroup for SDF rendering, one
// BlobInvertedRect for the screen-edge frame with per-zone roundings, and 9
// Rails (one per anchor position). Each Rail owns a Repeater over
// manager.rails[index].
Item {
    id: root

    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area
    required property var manager

    anchors.fill: parent

    readonly property var _anchors: [
        "topLeft", "top", "topRight",
        "left", "center", "right",
        "bottomLeft", "bottom", "bottomRight"
    ]

    // BlobGroup is a QObject (configuration holder, not a QQuickItem) —
    // the actual SDF compositing happens in scene-graph nodes attached
    // to each BlobShape (BlobRect / BlobInvertedRect). To capture the
    // *union* of all bg shapes as a single texture (for halo masking),
    // we host all bg-rendering items in `bgRenderHost` Item with
    // `layer.enabled: true`. That Item's FBO contains the merged SDF.
    BlobGroup {
        id: blobGroup
        color: Colours.palette.surface
        smoothing: 32
        stickSmooth: Config.backgrounds.stickSmooth
        // Frosted-glass (Approach A): the plugin samples a pre-blurred copy of
        // the wallpaper inside blob.frag and mixes it with `color`, painted with
        // the SDF alpha — exact contour, native res, no separate-layer corner
        // mismatch. The wallpaper path comes from awww; blur/tint from config.
        wallpaperEnabled: Config.general.transparency.shaderBlur ?? false
        wallpaperTint: Config.general.transparency.blurTint ?? 0.3
        wallpaperBlur: Config.general.transparency.blurAmount ?? 0.6
        screenSize: Qt.size(root.width, root.height)
        wallpaperPath: root._wpPath
    }

    // Current wallpaper path (eDP-style single output) from awww, fed to the
    // BlobGroup for the frost texture. Re-queried whenever frost turns on.
    // awww (swww fork) emits no wallpaper-change signal, so poll `awww query`
    // while frost is on. setWallpaperPath ignores an unchanged path, so the
    // texture only rebuilds when the wallpaper actually changes.
    property string _wpPath: ""
    Timer {
        running: Config.general.transparency.shaderBlur ?? false
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: wpQuery.running = true
    }
    Process {
        id: wpQuery
        command: ["sh", "-c", "awww query | sed -n 's/.*image: //p' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p)
                    root._wpPath = p;
            }
        }
    }

    // Screen-edge SDF frame. Its outer edge sits OUTSIDE the viewport
    // (anchors.margins: -marginAbs); its inner cutout is inset to the visible
    // border's inner edge (see _frameInset* below), so the frame's solid band
    // covers the border strip and bgs присасываются to the border, not the bare
    // screen edge. The shader uses its inverted geometry for per-bg sink. Per-zone
    // присасывание strengths come from Config.border.zoneRoundings:
    //   0 = bgs in that zone do NOT pull the frame's inner edge inward
    //   1 = full sink (legacy unscaled behavior)
    readonly property int _invertedFrameMargin: 50
    // Border rounding (bg-coloured inner cutout of the frame) — shared with
    // the visible border chrome (Border.qml). Independent from BOTH the
    // window rounding (Config.backgrounds.rounding) and the BLACK
    // screen-corner rounding (Config.corners.rounding, drawn by Corners
    // ABOVE the backgrounds — the shader never affects it).
    // Config.backgrounds.invertBaseRounding gates whether window
    // присасывание gets a rounded cutout at all.
    readonly property int _invertedRadius: (Config.backgrounds.invertBaseRounding ?? false)
                                            ? (Config.border.rounding ?? 0)
                                            : 0

    // Inset the frame's inner cutout to the VISIBLE border's inner edge so bgs
    // присасываются to the border, not the bare screen edge. Mirrors the mask
    // in Border.qml (fillBar → per-side reserved area, else uniform thickness).
    readonly property int _frameInsetLeft: Config.border.fillBar ? left_area : border_area
    readonly property int _frameInsetRight: Config.border.fillBar ? right_area : border_area
    readonly property int _frameInsetTop: Config.border.fillBar ? top_area : border_area
    readonly property int _frameInsetBottom: Config.border.fillBar ? bottom_area : border_area

    Item {
        id: bgRenderHost
        anchors.fill: parent
        // Panel-background opacity. With shader frost the blob fill already IS
        // the (opaque) frosted wallpaper, so keep it at 1.0 — dimming it would
        // double-expose the real wallpaper behind. Otherwise (niri-blur or plain
        // transparency) dim to `base` so a compositor blur shows through; the
        // blob shader ignores color.a but multiplies the material's qt_Opacity.
        // Content is unaffected (sibling contentLayer z=100).
        opacity: (Config.general.transparency.shaderBlur ?? false)
                 ? 1.0
                 : (Colours.transparency.enabled ? Colours.transparency.base : 1.0)
        // Already layered to expose the merged-SDF union texture for
        // WindowSlot's halo mask (ShaderEffectSource sourceItem). The
        // effect below also makes this FBO the shell's drop-shadow source —
        // cast from the panel shapes only, so content text (in contentLayer,
        // not in this item) stays out of any resampled layer. The external
        // halo ShaderEffectSource samples the raw layer texture, unaffected
        // by this composite-time effect.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            // Drop-shadow blur is a fullscreen pass re-run every blob animation
            // frame; on weak GPUs it's ~20% of the shell's per-frame GPU cost.
            // 6 vs 15 is visually near-identical for a soft shadow but ~12% cheaper.
            blurMax: 6
            shadowColor: Qt.alpha(Colours.palette.shadow, 0.7)
        }

        BlobInvertedRect {
            id: invertedFrame
            anchors.fill: parent
            anchors.margins: -root._invertedFrameMargin
            group: blobGroup
            radius: root._invertedRadius
            // Присасывание never overrides the border rounding: inside this
            // band around the cutout arcs the shader mutes the sink and
            // hardens the frame smin. Auto = radius + smoothing.
            cornerGuard: (Config.backgrounds.cornerGuard ?? -1) >= 0
                         ? Config.backgrounds.cornerGuard
                         : root._invertedRadius + blobGroup.smoothing
            borderLeft: root._invertedFrameMargin + root._frameInsetLeft
            borderRight: root._invertedFrameMargin + root._frameInsetRight
            borderTop: root._invertedFrameMargin + root._frameInsetTop
            borderBottom: root._invertedFrameMargin + root._frameInsetBottom
            // Normalised to exactly 8 entries: a truncated stored array (the
            // old sparse default collapsed to 7 elements on persist) would
            // otherwise zero-pad in C++ and silently disable the last zones.
            zoneRoundings: {
                const src = Config.border.zoneRoundings ?? [];
                const a = [];
                for (let i = 0; i < 8; i++)
                    a.push(src[i] ?? 0);
                return a;
            }
        }

        Repeater {
            id: rails
            model: 9
            delegate: Rail {
                required property int index
                railIndex: index
                anchor: root._anchors[index]
                windows: root.manager.rails[index]
                group: blobGroup
                groupHost: bgRenderHost
                contentLayer: contentLayer
                zWidth: root.width
                zHeight: root.height
                left_area: root.left_area
                top_area: root.top_area
                right_area: root.right_area
                bottom_area: root.bottom_area
                manager: root.manager
            }
        }
    }

    // All window content (and overlay bgs) get reparented here. Sits above
    // the BlobGroup's painted bg layer, so content of any window is always
    // drawn above any bg — and z=arrivalSeq inside this layer gives true
    // cross-rail arrival ordering for content.
    Item {
        id: contentLayer
        anchors.fill: parent
        z: 100
    }
}
