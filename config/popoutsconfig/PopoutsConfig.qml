import Quickshell.Io

// Popout backgrounds: transient panels attached to a host widget (bar/dock).
// One bg per edge is reused (slides + morphs between widgets) by default.
// See utils/PopoutsManager.qml.
JsonObject {
    property bool enabled: true

    // Gap (px) between the host's bg edge and the popout — i.e. the popout's
    // facing margin toward the host (mTop for a top edge, mBottom for bottom,
    // etc.). The rails system bridges this gap for cursor traversal.
    property int gap: 30

    // Padding around the popout content inside the bg.
    property int padding: 12

    // Rounding (-1 → falls back to backgrounds.rounding).
    property int rounding: -1

    // Whether the popout присасывается to its host (bar/dock): true → liquid
    // capsule neck across the gap (fatness = backgrounds.stickSmooth); false →
    // clean floating panel with full rounding, no neck, no magnet corner-shrink.
    // Per-handle overridable via overrides.sticks.
    property bool sticks: true

    // Stacking mode. "push" = layer below/above the host on its rail (the
    // popout sits just past the host). Overridable per-handle.
    property string mode: "push"

    // Reuse one shared bg per edge (true, default) vs a fresh bg per handle
    // (false). Reuse never crosses edges — each edge has its own instance.
    property bool reuse: true
}
