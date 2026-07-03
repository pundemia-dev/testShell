import QtQuick
import Quickshell.Services.Mpris
import qs.components
import qs.services
import qs.components.effects

// Media-page ambient shapes: the shared DriftingShapes bg, drifting while
// music plays (same knob defaults as the original in-page implementation).
DriftingShapes {
    active: Players.active?.playbackState === MprisPlaybackState.Playing ?? false
}
