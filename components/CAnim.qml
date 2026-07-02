import qs.config
import QtQuick

// Ported from caelestia: colour transitions use the expressive slow-effects
// motion (curve + duration) rather than the generic standard/normal pair.
ColorAnimation {
    duration: Appearance.anim.durations.expressiveSlowEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.curves.expressiveSlowEffects
}
