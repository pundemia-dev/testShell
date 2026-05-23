import Quickshell.Io

JsonObject {
    property bool enabled: false
    property int thickness: 10
    property int rounding: 15
    property int minMouseArea: 1
    property bool fillBar: false

    // Default length of a zone's MouseArea strip along its edge when the zone
    // has no edge-nearest bgs. Used as floor; a populated zone's length comes
    // from union projection of (layer-1 + overlay) bgs.
    property int defaultZoneLength: 100

    // Fallback thickness (perpendicular to edge) of a zone's MouseArea strip
    // when the computed (thickness + edge-facing margin) sum is 0.
    property int defaultMouseAreaThickness: 10

    // Per-zone присасывание strengths (0 = disabled, 1 = full).
    // Order: topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left.
    property list<real> zoneRoundings: [0, 0, 0, 1, 0, , 1, 1]
}
