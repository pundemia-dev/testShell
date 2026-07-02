import QtQuick.Effects

// Ported from caelestia: soft alpha mask (used as a layer.effect with a
// gradient maskSource, e.g. VerticalFadeFlickable's edge fade). Distinct from
// pShell's OpacityMask (custom straight-alpha shader).
MultiEffect {
    maskEnabled: true
    maskSpreadAtMin: 1
    maskThresholdMin: 0.5
}
