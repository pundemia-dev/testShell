import Quickshell.Io

JsonObject {
    property bool enabled: true
    property int thickness: 1
    property int rounding: 1
    property int minMouseArea: 1
    property bool fillBar: false

    // Default length of a zone's MouseArea strip along its edge when the zone
    // has no edge-nearest bgs. Used as floor; a populated zone's length comes
    // from union projection of (layer-1 + overlay) bgs.
    property int defaultZoneLength: 100

    // Fallback thickness (perpendicular to edge) of a zone's MouseArea strip
    // when the computed (thickness + edge-facing margin) sum is 0.
    property int defaultMouseAreaThickness: 10

    // Gap (px) left between two adjacent same-edge zone strips after one is
    // clipped against the other. When two neighbours' strips overlap along the
    // edge, the LONGER one is clipped to the shorter one's boundary + this gap
    // (so the shorter, e.g. a corner trigger, is always preserved).
    property int zoneGap: 8

    // Per-zone присасывание strengths (0 = disabled, 1 = full).
    // Order: topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left.
    property list<real> zoneRoundings: [0, 0, 0, 1, 0, , 1, 1]
}
