import Quickshell.Io

// Shell-wide preferences that don't belong to a single module. Currently
// just the settings-UI basic/advanced disclosure state; grows over time.
JsonObject {
    // Settings UI disclosure level. false = basic (advanced elements hidden),
    // true = advanced (everything shown). One rule everywhere:
    //   visible: !element.advanced || Config.general.advanced
    property bool advanced: false

    // Panel translucency. `Colours.transparency` reads these; when `enabled`,
    // surface colours are alpha'd (`base` = layer-0 / background fills,
    // `layers` = stacked container fills).
    property Transparency transparency: Transparency {}

    component Transparency: JsonObject {
        property bool enabled: false
        property real base: 0.78    // layer-0 / background opacity (0..1)
        property real layers: 0.58  // stacked container opacity (0..1)

        // Compositor-side background blur (niri ext-background-effect-v1). The
        // blur region is the union of settled panel shapes, published at
        // runtime via BackgroundEffect.blurRegion (see services/BlurManager.qml,
        // drawers/Drawers.qml). niri auto-enables xray inside it.
        property bool blur: false
        // Shader frosted-glass (Approach A): the Blobs plugin fills panels with
        // a pre-blurred copy of the wallpaper sampled inside blob.frag, mixed
        // with the surface tint. Exact SDF contour, native res. Mutually
        // exclusive with `blur` (niri). Blurs only the wallpaper image (not
        // animated awww frames or windows behind the panels).
        property bool shaderBlur: false
        // mix(wallpaper, surfaceColor, blurTint): 0 = pure wallpaper, 1 = pure
        // tint. Controls how much of the surface colour veils the frost.
        property real blurTint: 0.3
        // Blur strength via CPU downscale: 0 = subtle (256px), 1 = heavy (24px).
        property real blurAmount: 0.6
        // Pixels the blur region is shrunk inward on every side, so the hard
        // wl_region edge sits under the panel's translucent rim instead of at
        // the very contour (a sharp blur cut at the edge reads badly).
        property int blurInset: 8
        // A panel must hold its geometry stable for this long (ms) before its
        // blur region is published — so niri never blurs an appearing/resizing
        // (morphing) shape, only a frozen one.
        property int blurSettleMs: 200
    }
}
