pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.images
import M3Shapes
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// Media tab — 1:1-style port of caelestia Media: cover with a wavy progress arc
// on the left, track details + position slider + transport on the right. The
// audio visualiser (CoverVisualiser/BackgroundShapes) and lyrics panel are
// deferred (heaviest bits) and will be added next.
Item {
    id: root

    readonly property var player: Players.active
    readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing

    property real pos: 0
    Timer {
        interval: 1000
        running: root.player !== null && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pos = root.player?.position ?? 0
    }

    function fmtTime(s: real): string {
        if (!(s > 0)) return "0:00";
        const m = Math.floor(s / 60);
        const sec = Math.floor(s % 60);
        return `${m}:${sec < 10 ? "0" : ""}${sec}`;
    }

    implicitWidth: Config.dashboard.media.tabWidth
    implicitHeight: Config.dashboard.media.tabHeight

    BackgroundShapes {
        anchors.fill: parent
    }

    // ── No media placeholder ──────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.small
        opacity: root.player ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { Anim {} }

        MaterialShape {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: 96
            shape: MaterialShape.ClamShell
            color: Colours.palette.primary_container

            StyledText {
                anchors.centerIn: parent
                text: "\ueafc" // tabler music
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.extraLarge * 1.6
                color: Colours.palette.on_primary_container
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Nothing playing")
            font.pointSize: Appearance.font.size.large
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Play something for it to show up here!")
            color: Colours.palette.on_surface_variant
            font.pointSize: Appearance.font.size.normal
        }
    }

    // ── Now playing ───────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.large
        opacity: root.player ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim {} }

        // Cover with radial spectrum visualiser.
        CoverVisualiser {
            Layout.preferredWidth: Config.dashboard.media.sectionWidth
            Layout.fillHeight: true
        }

        // Details.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.small

            Item { Layout.fillHeight: true }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle ?? ""
                font.pointSize: Appearance.font.size.extraLarge
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                animate: true
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || qsTr("Unknown artist")
                color: Colours.palette.on_surface_variant
                font.pointSize: Appearance.font.size.large
                elide: Text.ElideRight
                animate: true
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackAlbum || qsTr("Unknown album")
                color: Colours.palette.secondary
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
                animate: true
            }

            // Position row.
            RowLayout {
                Layout.topMargin: Appearance.spacing.large
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    text: root.fmtTime(root.pos)
                    color: Colours.palette.on_surface_variant
                    font.pointSize: Appearance.font.size.small
                }

                StyledSlider {
                    id: slider
                    Layout.fillWidth: true
                    value: (root.player?.length ?? 0) > 0 ? root.pos / root.player.length : 0
                    enabled: root.player?.canSeek ?? false
                    wavy: true
                    animateWave: root.playing
                    waveFrequency: 5
                    onInteraction: v => {
                        const p = root.player;
                        if (p?.canSeek && p?.positionSupported)
                            p.position = v * p.length;
                    }
                }

                StyledText {
                    text: root.fmtTime(root.player?.length ?? 0)
                    color: Colours.palette.on_surface_variant
                    font.pointSize: Appearance.font.size.small
                }
            }

            // Transport.
            RowLayout {
                Layout.topMargin: Appearance.spacing.medium
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                IconButton {
                    type: IconButton.Tonal
                    icon: "\uf000" // tabler arrows-shuffle
                    toggle: true
                    checked: root.player?.shuffle ?? false
                    disabled: !(root.player?.shuffleSupported ?? false)
                    onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    type: IconButton.Tonal
                    icon: "\ued48" // tabler player-skip-back
                    disabled: !(root.player?.canGoPrevious ?? false)
                    onClicked: Players.previous()
                }
                IconButton {
                    type: IconButton.Filled
                    icon: root.playing ? "\ued45" : "\ued46" // pause / play
                    toggle: true
                    checked: root.playing
                    Layout.fillWidth: true
                    disabled: !(root.player?.canTogglePlaying ?? false)
                    onClicked: Players.playPause()
                }
                IconButton {
                    type: IconButton.Tonal
                    icon: "\ued49" // tabler player-skip-forward
                    disabled: !(root.player?.canGoNext ?? false)
                    onClicked: Players.next()
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    type: IconButton.Tonal
                    icon: root.player?.loopState === MprisLoopState.Track ? "\ueb71" : "\ueb72" // repeat-once / repeat
                    toggle: true
                    checked: root.player?.loopState === MprisLoopState.Track || root.player?.loopState === MprisLoopState.Playlist
                    disabled: !(root.player?.loopSupported ?? false)
                    onClicked: {
                        const p = root.player;
                        if (!p) return;
                        const s = p.loopState;
                        if (s === MprisLoopState.None) p.loopState = MprisLoopState.Track;
                        else if (s === MprisLoopState.Track) p.loopState = MprisLoopState.Playlist;
                        else p.loopState = MprisLoopState.None;
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // Time-synced lyrics (view over the Lyrics service's runtime output).
        LyricsAndSelector {
            Layout.preferredWidth: Config.dashboard.media.sectionWidth
            Layout.fillHeight: true
        }
    }
}
