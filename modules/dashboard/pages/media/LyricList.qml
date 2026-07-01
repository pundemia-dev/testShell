pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.containers
import Caelestia.Services
import Quickshell.Services.Mpris
import QtQuick

// Time-synced lyric list. Purely a view over the Lyrics service's runtime output
// (Lyrics.lyrics is fetched over the network by the C++ backend); this file
// contains no lyric text of its own. The current line is highlighted and
// centred; clicking a line seeks to it.
Item {
    id: root

    // Feed the current track to the backend so it fetches matching lyrics.
    readonly property var _track: {
        const p = Players.active;
        if (p)
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        else
            Lyrics.clearTrack();
    }

    property real pos: 0
    Timer {
        interval: 500
        running: root.visible && (Players.active?.playbackState === MprisPlaybackState.Playing)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pos = Players.active?.position ?? 0
    }

    readonly property int currentIndex: Lyrics.hasLyrics ? Lyrics.indexForTime(root.pos) : -1
    onCurrentIndexChanged: if (currentIndex >= 0) view.positionViewAtIndex(currentIndex, ListView.Center)

    // Placeholder when nothing to show.
    StyledText {
        anchors.centerIn: parent
        width: parent.width - Appearance.padding.large * 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !Lyrics.hasLyrics
        text: Lyrics.loading ? qsTr("Loading lyrics…") : qsTr("No lyrics found")
        color: Colours.palette.on_surface_variant
        font.pointSize: Appearance.font.size.normal
    }

    StyledListView {
        id: view
        anchors.fill: parent
        clip: true
        visible: Lyrics.hasLyrics
        model: Lyrics.lyrics
        spacing: Appearance.spacing.small
        // Leave room so first/last lines can centre.
        header: Item { implicitHeight: view.height / 2 }
        footer: Item { implicitHeight: view.height / 2 }

        delegate: StyledText {
            id: line
            required property int index
            required property var modelData
            readonly property bool current: index === root.currentIndex

            width: view.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: modelData
            font.pointSize: current ? Appearance.font.size.large : Appearance.font.size.normal
            font.weight: current ? Font.DemiBold : Font.Normal
            color: current ? Colours.palette.primary : Colours.palette.on_surface_variant
            opacity: current ? 1 : 0.6

            Behavior on font.pointSize { Anim {} }
            Behavior on color { CAnim {} }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const p = Players.active;
                    if (p?.canSeek && p?.positionSupported)
                        p.position = Lyrics.timeForIndex(line.index);
                }
            }
        }
    }
}
