import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.config

StyledClippingRect {
    id: root

    required property var lock

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2
    radius: Appearance.rounding.extraLarge
    color: Colours.tPalette.surface_container

    FadeImage {
        anchors.fill: parent
        source: Players.getArtUrl(Players.active)
        fillMode: Image.PreserveAspectCrop

        layer.enabled: true

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.surface
            opacity: 0.7
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.extraLarge
        spacing: Appearance.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            animate: true
            text: (Players.active?.trackTitle ?? qsTr("Nothing playing")) || qsTr("Unknown track")
            color: Colours.palette.primary
            horizontalAlignment: Text.AlignHCenter
            font: Appearance.font.title.medium
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            animate: true
            text: (Players.active?.trackArtist ?? qsTr("Try playing some music!")) || qsTr("Unknown artist")
            color: Colours.palette.on_surface_variant
            horizontalAlignment: Text.AlignHCenter
            font: Appearance.font.body.small
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.spacing.medium

            spacing: Appearance.spacing.extraSmall

            IconButton {
                type: IconButton.Tonal
                icon: "" // tabler player-skip-back
                isRound: true
                disabled: !(Players.active?.canGoPrevious ?? false)
                onClicked: Players.active?.previous()
            }

            IconButton {
                icon: Players.active?.isPlaying ? "" : "" // tabler player-pause / player-play
                isRound: true
                toggle: true
                checked: Players.active?.isPlaying ?? false
                disabled: !(Players.active?.canTogglePlaying ?? false)
                onClicked: Players.active?.togglePlaying()
                implicitWidth: implicitHeight + Appearance.padding.largeIncreased * 2
            }

            IconButton {
                type: IconButton.Tonal
                icon: "" // tabler player-skip-forward
                isRound: true
                disabled: !(Players.active?.canGoNext ?? false)
                onClicked: Players.active?.next()
            }
        }
    }
}
