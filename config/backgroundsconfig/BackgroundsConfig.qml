import Quickshell.Io

JsonObject {
    property int rounding: 30
    property bool invertBaseRounding: true
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
