pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import Caelestia.Services
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root

    readonly property var _track: {
        const p = Players.active;
        if (p)
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        else
            Lyrics.clearTrack();
    }

    readonly property real fadeAmount: 0.1
    property bool flag
    property list<string> lyricList: Lyrics.lyrics

    property real pos: 0
    Timer {
        interval: 500
        running: root.visible && (Players.active?.playbackState === MprisPlaybackState.Playing)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pos = Players.active?.position ?? 0
    }

    layer.enabled: true
    layer.effect: Mask {
        maskSource: mask

        Rectangle {
            id: mask

            layer.enabled: true
            visible: false
            implicitWidth: root.width
            implicitHeight: root.height

            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop { color: Qt.alpha("black", 0); position: 0 }
                GradientStop { color: Qt.alpha("black", 1); position: root.fadeAmount }
                GradientStop { color: Qt.alpha("black", 1); position: 1 - root.fadeAmount }
                GradientStop { color: Qt.alpha("black", 0); position: 1 }
            }
        }
    }

    state: {
        flag;
        if (Lyrics.hasLyrics)
            return "hasLyrics";
        if (Lyrics.loading)
            return "loading";
        return "noLyrics";
    }

    states: [
        State {
            name: "loading"
            PropertyChanges {
                loadingIndicator.opacity: 1
                lyricsView.opacity: 0
                noLyrics.opacity: 0
            }
        },
        State {
            name: "hasLyrics"
            PropertyChanges {
                loadingIndicator.opacity: 0
                lyricsView.opacity: 1
                noLyrics.opacity: 0
            }
        },
        State {
            name: "noLyrics"
            PropertyChanges {
                loadingIndicator.opacity: 0
                lyricsView.opacity: 0
                noLyrics.opacity: 1
            }
        }
    ]

    transitions: [
        Transition {
            from: "loading"
            SequentialAnimation {
                Anim { target: loadingIndicator; property: "opacity"; type: Anim.DefaultEffects }
                Anim { targets: [lyricsView, noLyrics]; property: "opacity"; type: Anim.SlowEffects }
            }
        },
        Transition {
            from: "hasLyrics"
            SequentialAnimation {
                Anim { target: lyricsView; property: "opacity"; type: Anim.DefaultEffects }
                Anim { targets: [loadingIndicator, noLyrics]; property: "opacity"; type: Anim.SlowEffects }
            }
        },
        Transition {
            from: "noLyrics"
            SequentialAnimation {
                Anim { target: noLyrics; property: "opacity"; type: Anim.DefaultEffects }
                Anim { targets: [loadingIndicator, lyricsView]; property: "opacity"; type: Anim.SlowEffects }
            }
        }
    ]

    Connections {
        target: Lyrics
        function onHasLyricsChanged(): void { root.flag = !root.flag; }
    }

    Loader {
        id: loadingIndicator

        anchors.centerIn: parent
        asynchronous: true
        active: opacity > 0
        opacity: 0

        sourceComponent: ColumnLayout {
            spacing: Appearance.spacing.large

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: shape.implicitSize + Appearance.padding.medium * 2
                implicitHeight: shape.implicitSize + Appearance.padding.medium * 2
                color: Colours.palette.primary_container
                radius: Appearance.rounding.full

                LoadingIndicator {
                    id: shape

                    anchors.centerIn: parent
                    implicitSize: Math.round(Config.dashboard.media.sectionWidth / 5)
                    containsIcon: true
                }
            }

            StyledText {
                text: qsTr("Loading lyrics...")
                color: Colours.palette.on_surface_variant
                font: Appearance.font.title.medium
            }
        }

        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
    }

    Loader {
        id: noLyrics

        anchors.centerIn: parent
        asynchronous: true
        active: opacity > 0
        opacity: 0

        sourceComponent: ColumnLayout {
            spacing: Appearance.spacing.small

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: ""
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.extraLarge * 2
                color: Colours.palette.outline
            }

            StyledText {
                text: qsTr("No lyrics found")
                color: Colours.palette.outline
                font: Appearance.font.title.medium
            }
        }

        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
    }

    StyledListView {
        id: lyricsView

        anchors.fill: parent
        anchors.topMargin: parent.height * root.fadeAmount / 2
        anchors.bottomMargin: parent.height * root.fadeAmount / 2

        displayMarginBeginning: anchors.topMargin
        displayMarginEnd: anchors.bottomMargin

        model: root.lyricList

        Component.onCompleted: {
            currentIndex = Qt.binding(() => {
                model;
                return Lyrics.hasLyrics ? Lyrics.indexForTime(root.pos) : -1;
            });
            positionViewAtIndex(currentIndex, ListView.Center);
        }
        onModelChanged: Qt.callLater(() => positionViewAtIndex(currentIndex, ListView.Center))

        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: Appearance.anim.durations.large
        highlightMoveVelocity: -1
        preferredHighlightBegin: (height - (currentItem?.implicitHeight ?? 0)) / 2
        preferredHighlightEnd: (height + (currentItem?.implicitHeight ?? 0)) / 2

        spacing: Appearance.spacing.small
        opacity: 0

        delegate: StyledText {
            id: lyric

            required property string modelData
            required property int index
            property real effectScale: ListView.isCurrentItem ? 1 : 0

            anchors.left: lyricsView.contentItem.left
            anchors.right: lyricsView.contentItem.right

            text: modelData || ". . ."
            color: ListView.isCurrentItem ? Colours.palette.primary : mouse.containsMouse ? Colours.palette.on_surface : Colours.palette.outline
            font: Appearance.font.body.medium
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere

            layer.enabled: effectScale > 0
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.primary
                shadowOpacity: 0.5 * lyric.effectScale
                shadowBlur: 0.6 * lyric.effectScale
                blur: 0.4 * lyric.effectScale
            }

            Behavior on effectScale { Anim { type: Anim.SlowEffects } }

            MouseArea {
                id: mouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    const p = Players.active;
                    if (p)
                        p.position = Lyrics.timeForIndex(lyric.index);
                }
            }
        }

        Behavior on opacity { Anim { type: Anim.SlowEffects } }
    }

    Behavior on lyricList {
        SequentialAnimation {
            Anim { target: lyricsView; property: "opacity"; to: 0; type: Anim.DefaultEffects }
            PropertyAction {}
            Anim { target: lyricsView; property: "opacity"; to: 1; type: Anim.SlowEffects }
        }
    }
}
