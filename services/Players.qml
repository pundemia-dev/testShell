pragma Singleton

import QtQml
import Quickshell
import Quickshell.Services.Mpris

// Simplified MPRIS aggregator (port of caelestia Players without toasts /
// aliases / global config). Exposes the list of players and the "active" one
// (a manual pick, else the first available), plus a cover-art helper with a
// YouTube thumbnail fallback.
Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    property MprisPlayer manualActive: null
    readonly property MprisPlayer active: manualActive ?? list[0] ?? null

    // Reactive cover-art URL for the active player. Declared as a property so
    // QML tracks trackArtUrl and metadata as dependencies — a plain function
    // call only re-evaluates when `active` itself changes, missing track
    // changes on the same player (e.g. gapless playback).
    readonly property string artUrl: {
        const player = active;
        if (!player) return "";
        if (player.trackArtUrl) return player.trackArtUrl;
        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;

        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    function playPause(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }
    function next(): void {
        if (active?.canGoNext)
            active.next();
    }
    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }
}
