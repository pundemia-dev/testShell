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
    // clipped to the bg's rounded-rect shape.
    //
    // Geometry:
    //   inner_solid_rect = bg_rect shrunk by `overlapShrink` on each side
    //   halo_ring        = `fadeWidth` px wide gradient from opaque (at
    //                      inner_solid_rect edge) to transparent, growing
    //                      outward toward the bg edge
    //   everything is masked to the bg's rounded shape
    //
    // Effect: lower wrappers' content under inner_solid_rect is hidden,
    // and within the halo_ring it linearly dissolves into the bg color.
    //
    // Tuning:
    //   fadeWidth ≥ overlapShrink → halo is clipped at the bg edge (some
    //                                fade is "cut off")
    //   fadeWidth ≤ overlapShrink → halo fully inside bg edge, leaves a
    //                                visible transparent moat between
    //                                halo's outer edge and bg edge
    //   fadeWidth == overlapShrink → halo exactly fills the ring, smooth
    //
    // 0 = disabled (no inner_solid_rect drawn at all when both are 0).
    property int fadeWidth: 40
    property int overlapShrink: 20

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
