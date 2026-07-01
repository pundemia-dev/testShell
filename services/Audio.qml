pragma Singleton

import qs.config
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Services

// Minimal audio singleton for the dashboard media visualiser: exposes the cava
// spectrum provider and the beat tracker (both self-contained AudioProviders
// that capture the default sink monitor via pipewire). Volume/sink management is
// intentionally out of scope here.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: !!sink?.audio?.muted

    readonly property alias cava: cava
    readonly property alias beatTracker: beatTracker

    CavaProvider {
        id: cava
        bars: Config.dashboard.media.visualiserBars
    }

    BeatTracker {
        id: beatTracker
    }
}
