import Quickshell.Io

// Shell-wide preferences that don't belong to a single module. Currently
// just the settings-UI basic/advanced disclosure state; grows over time.
JsonObject {
    // Settings UI disclosure level. false = basic (advanced elements hidden),
    // true = advanced (everything shown). One rule everywhere:
    //   visible: !element.advanced || Config.general.advanced
    property bool advanced: false

    // Panel translucency + compositor blur. `Colours.transparency` reads these;
    // when `enabled`, surface colours are alpha'd (`base` = layer-0 / background
    // fills, `layers` = stacked container fills). `blur` toggles the niri
    // background-effect via the generated config/niri/blur.kdl (see utils/NiriBlur).
    property Transparency transparency: Transparency {}

    component Transparency: JsonObject {
        property bool enabled: false
        property real base: 0.78    // layer-0 / background opacity (0..1)
        property real layers: 0.58  // stacked container opacity (0..1)
        property bool blur: false   // niri compositor blur for pShell-drawers
    }
}
