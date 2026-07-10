import Quickshell.Io

JsonObject {
    property int rounding: 30
    // Liquid rounding morph: while a bg appears/collapses, its corner radius
    // rides toward the maximum (capsule) and relaxes to `rounding` — appear
    // starts as a droplet, collapse blooms back into one.
    property bool liquidRounding: false
    // Liquid content squeeze: while the ANIMATED rounding is raised (appear/
    // collapse morph or motion boost), the content grid is pressed into the
    // rounded contour — concave dents at the corners, like a rectangle forced
    // into a chamfered one. Never applies at rest (magnet-driven unequal radii
    // don't trigger it). Requires liquidRounding.
    property bool liquidContentWarp: false
    property bool invertBaseRounding: false
    // Guard band (px) around the border-rounding arcs where присасывание is
    // muted, so sinking bgs never reshape the arcs. -1 = auto (rounding +
    // SDF smoothing).
    property real cornerGuard: 0
    // Neck fatness when a sticking bg bridges a gap to a neighbour. Multiplier
    // on the SDF smoothing radius used for the smin between two sticking rects:
    // 1.0 = legacy thin join, >1 widens it into a tight capsule neck across the
    // gap. Global default; per-bg "присосан/нет" is the `sticks` toggle.
    property real stickSmooth: 1.5
    property Directions margins: Directions {}
    property Directions paddings: Directions {
        left: 15
        right: 15
        top: 15
        bottom: 15
    }
    property Offsets offsets: Offsets {}

    // Per-wrapper opaque rect drawn UNDER this wrapper's content (in
    // contentLayer at z=arrivalSeq, below content at z=arrivalSeq+0.5),
    // clipped to the SDF union of all bg shapes.
    //
    // Geometry:
    //   inner_solid = paintedRect shrunk by `overlapShrink` on every
    //                 side, centred. This is the rectangle the gradient
    //                 grows OUTWARD from.
    //   halo ring  = `fadeWidth` px wide, surrounding inner_solid on
    //                 the OUTSIDE. May extend past paintedRect — the
    //                 SDF-union mask either trims it (no neighbour) or
    //                 lets it continue into a neighbouring SDF-merged bg.
    //
    // Special cases:
    //   overlapShrink = 0       → inner_solid covers the entire bg,
    //                              halo lives entirely outside; visible
    //                              only where SDF-merged neighbours
    //                              exist beyond this bg's edge.
    //   overlapShrink = fadeWidth → halo's outer edge lands exactly on
    //                                paintedRect's edge.
    //   overlapShrink > fadeWidth → halo fully inside paintedRect, with
    //                                a moat to the bg's edge.
    //
    // Variables:
    //   fadeWidth      — visible gradient distance (one and only thing
    //                     that controls how wide the halo is). Only the
    //                     SDF-union mask can shorten the visible fade.
    //   overlapShrink  — how much smaller (per side) the inner_solid
    //                     rect is compared to the bg. Centred.
    //   fadeStrength   — curve exponent for the gradient alpha ramp.
    //                     1.0 = linear (default).
    //                     >1 = "strong at start": alpha climbs quickly
    //                          near the outer (transparent) edge.
    //                     <1 = "weak at start": alpha climbs slowly
    //                          near the outer edge.
    property int fadeWidth: 40
    property int overlapShrink: 15
    property real fadeStrength: 1.0

    // Resize-union holdover collapse buffer (px). When the cursor enters the
    // new bg target after a resize, the holdover display does NOT snap
    // exactly to `newTarget` — instead it snaps to `newTarget` inflated by
    // this many pixels on every side, clipped to the previous display rect
    // so the buffer never extends past the old bg bounds. Protects against
    // accidental jitter (mouse pickup / trackpad touch) that would otherwise
    // push the cursor one pixel outside the freshly shrunk mask.
    property int resizeHoldoverMargin: 30

    component Directions: JsonObject {
        property int left: 0
        property int right: 0
        property int top: 0
        property int bottom: 0
    }

    component Offsets: JsonObject {
        property int vCenterOffset: 0
        property int hCenterOffset: 0
    }
}
