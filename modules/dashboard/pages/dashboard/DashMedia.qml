pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../media"

// Dashboard "now playing" widget — 1:1 port of caelestia dash/Media.qml: a
// rotating shape CoverArt wrapped by a wavy progress arc, then track info and a
// round transport row (bongocat intentionally omitted).
Item {
    id: root

    readonly property var player: Players.active
    readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing
    readonly property real arcCoverGap: Appearance.spacing.small

    property real pos: 0
    Timer {
        interval: 1000
        running: root.player !== null && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pos = root.player?.position ?? 0
    }

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: Config.dashboard.dash.mediaWidth

    DashProgress {
        id: prog
        anchors.centerIn: cover
        implicitSize: cover.width + root.arcCoverGap + thickness * 2
        fgColour: Colours.palette.primary
        strokeWidth: Config.dashboard.dash.mediaProgressThickness
        startAngle: -90 - sweepAngle / 2
        sweepAngle: Config.dashboard.media.progressSweep
        value: (root.player?.length ?? 0) > 0 ? root.pos / root.player.length : 0
        wavy: true
        waveFrequency: 8
        wavePaused: !root.playing

        Behavior on clampedVal { Anim {} }
    }

    CoverArt {
        id: cover
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Appearance.padding.normal + root.arcCoverGap + prog.thickness
        implicitHeight: width
    }

    StyledText {
        id: title
        anchors.top: cover.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.spacing.normal
        horizontalAlignment: Text.AlignHCenter
        animate: true
        text: (root.player?.trackTitle ?? qsTr("No media")) || qsTr("Unknown title")
        color: Colours.palette.primary
        font.pointSize: Appearance.font.size.normal
        font.weight: Font.DemiBold
        width: parent.width - Appearance.padding.large
        elide: Text.ElideRight
    }
    StyledText {
        id: album
        anchors.top: title.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.spacing.small
        horizontalAlignment: Text.AlignHCenter
        animate: true
        text: (root.player?.trackAlbum ?? "") || qsTr("Unknown album")
        color: Colours.palette.outline
        font.pointSize: Appearance.font.size.small
        width: parent.width - Appearance.padding.large
        elide: Text.ElideRight
    }
    StyledText {
        id: artist
        anchors.top: album.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.spacing.small
        horizontalAlignment: Text.AlignHCenter
        animate: true
        text: (root.player?.trackArtist ?? "") || qsTr("Unknown artist")
        color: Colours.palette.secondary
        font.pointSize: Appearance.font.size.small
        width: parent.width - Appearance.padding.large
        elide: Text.ElideRight
    }

    RowLayout {
        anchors.top: artist.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.spacing.normal
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.small

        IconButton {
            type: IconButton.Tonal
            icon: "\ued4c" // tabler player-track-prev
            disabled: !(root.player?.canGoPrevious ?? false)
            onClicked: Players.previous()
        }
        IconButton {
            type: IconButton.Filled
            toggle: true
            checked: root.playing
            Layout.fillWidth: true
            icon: root.playing ? "\ued45" : "\ued46"
            disabled: !(root.player?.canTogglePlaying ?? false)
            onClicked: Players.playPause()
        }
        IconButton {
            type: IconButton.Tonal
            icon: "\ued4b" // tabler player-track-next
            disabled: !(root.player?.canGoNext ?? false)
            onClicked: Players.next()
        }
    }
}
