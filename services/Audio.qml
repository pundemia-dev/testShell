pragma Singleton

import qs.config
import qs.components.misc
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Services

// Audio singleton. Exposes the default sink/source with volume/mute controls,
// the discovered sink/source/stream lists (for the OSD device selectors and
// per-app streams), plus the cava spectrum + beat tracker used by the dashboard
// media visualiser. Volume clamps/steps read from Config.osd.
Singleton {
    id: root

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property alias cava: cava
    readonly property alias beatTracker: beatTracker

    // ── Sink (speaker) ─────────────────────────────────────────────────────
    function setVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(Config.osd.maxVolume, newVolume));
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || Config.osd.volumeStep));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || Config.osd.volumeStep));
    }

    function toggleMute(): void {
        if (sink?.ready && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    // ── Source (microphone) ─────────────────────────────────────────────────
    function setSourceVolume(newVolume: real): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(Config.osd.maxVolume, newVolume));
        }
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || Config.osd.volumeStep));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || Config.osd.volumeStep));
    }

    function toggleSourceMute(): void {
        if (source?.ready && source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // ── Device selection ─────────────────────────────────────────────────────
    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    // ── Per-app streams ─────────────────────────────────────────────────────
    function setStreamVolume(stream: PwNode, newVolume: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = Math.max(0, Math.min(Config.osd.maxVolume, newVolume));
        }
    }

    function setStreamMuted(stream: PwNode, muted: bool): void {
        if (stream?.ready && stream?.audio)
            stream.audio.muted = muted;
    }

    function getStreamVolume(stream: PwNode): real {
        return stream?.audio?.volume ?? 0;
    }

    function getStreamMuted(stream: PwNode): bool {
        return !!stream?.audio?.muted;
    }

    function deviceName(node: PwNode): string {
        if (!node)
            return qsTr("Unknown");
        return node.description || node.name || qsTr("Unknown device");
    }

    function getStreamName(stream: PwNode): string {
        if (!stream)
            return qsTr("Unknown");
        return stream.properties["application.name"] || stream.description || stream.name || qsTr("Unknown application");
    }

    Connections {
        function onValuesChanged(): void {
            const newSinks = [];
            const newSources = [];
            const newStreams = [];

            for (const node of Pipewire.nodes.values) {
                if (!node.isStream) {
                    if (node.isSink)
                        newSinks.push(node);
                    else if (node.audio)
                        newSources.push(node);
                } else if (node.audio) {
                    newStreams.push(node);
                }
            }

            root.sinks = newSinks;
            root.sources = newSources;
            root.streams = newStreams;
        }

        target: Pipewire.nodes
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }

    CavaProvider {
        id: cava
        bars: Config.dashboard.media.visualiserBars
    }

    BeatTracker {
        id: beatTracker
    }

    // ── Media-key IPC targets (bind in niri config → `qs ipc call <name>
    // activate`). Each mutation triggers the OSD via its Audio Connections.
    CustomShortcut {
        name: "volumeUp"
        description: "Raise volume"
        onActivated: () => root.incrementVolume(0)
    }
    CustomShortcut {
        name: "volumeDown"
        description: "Lower volume"
        onActivated: () => root.decrementVolume(0)
    }
    CustomShortcut {
        name: "volumeMute"
        description: "Toggle output mute"
        onActivated: () => root.toggleMute()
    }
    CustomShortcut {
        name: "micMute"
        description: "Toggle microphone mute"
        onActivated: () => root.toggleSourceMute()
    }
}
