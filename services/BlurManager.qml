pragma Singleton

import Quickshell
import QtQuick
import qs.config

// Collects the per-slot compositor-blur sub-regions and exposes them as one
// list, mirroring InputManager's pattern. The actual blur is driven by niri's
// ext-background-effect-v1: Drawers.qml unions these into a single wl_region
// and assigns it to the drawers window's BackgroundEffect.blurRegion. niri
// then blurs EXACTLY that region (committed atomically with the surface, so no
// lag) and auto-enables xray inside it (frosted wallpaper, ignoring windows
// below).
//
// Regions are rounded-rect approximations of the SDF panel contour — the
// protocol can't take a per-pixel mask. Each settled WindowSlot publishes its
// inset rounded body + any magnet-neck bridges here; non-settled (appearing /
// resizing) slots contribute zero-sized regions so the morphing shape is never
// blurred. See docs and the WindowSlot blur block.
Singleton {
    id: root

    // Master gate. When false, Drawers assigns a null blurRegion (no blur).
    // Disabled while shader frost is on (mutually exclusive).
    readonly property bool enabled: (Config.general.transparency.blur ?? false)
                                    && !(Config.general.transparency.shaderBlur ?? false)

    // Union (Intersection.Combine) of all registered blur sub-regions.
    property var regions: []

    // Bumped on every mutation so a `regions`-bound consumer re-evaluates even
    // when the array identity would otherwise look unchanged.
    property int revision: 0

    function addRegion(region): void {
        root.regions = [...root.regions, region];
        root.revision++;
    }

    function removeRegion(region): void {
        root.regions = root.regions.filter(r => r !== region);
        root.revision++;
    }

    // Force the `regions` list to re-emit (new array ref, same contents) so the
    // composited wl_region rebuilds — call when a registered region's geometry
    // changes (e.g. a slot settles and its body grows from 0 to full).
    function refresh(): void {
        root.regions = [...root.regions];
        root.revision++;
    }
}
