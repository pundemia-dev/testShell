pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // List of Region objects registered by active Background instances
    property var regions: []

    // Revision counter — incremented on every refresh to force mask re-evaluation
    // Bind to this in the mask if needed as an extra dependency trigger
    property int revision: 0

    function addRegion(region): void {
        root.regions = [...root.regions, region];
        root.revision++;
    }

    function removeRegion(region): void {
        root.regions = root.regions.filter(r => r !== region);
        root.revision++;
    }

    // Forces the `regions` property to re-emit its change signal
    // by creating a new array reference with the same contents.
    // Call this whenever a registered Region's geometry changes
    // (e.g. when a Background's contentContainer resizes on hover).
    // This is called directly (no debounce) to avoid 1-frame gaps
    // that could cause compositor wl_pointer.leave → hover flickering.
    function refresh(): void {
        root.regions = [...root.regions];
        root.revision++;
    }
}
