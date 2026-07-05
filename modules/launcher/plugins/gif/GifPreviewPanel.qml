import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.services

// Правая панель модуля GIF Search: превью выбранной гифки + название/размер.
// `mod` — инстанс GifModule.
Item {
    id: panelRoot

    anchors.fill: parent

    required property var mod

    property var displayedGif: mod.selectedGif

    Connections {
        target: panelRoot.mod
        function onSelectedGifChanged() { fadeOut.start() }
    }

    SequentialAnimation {
        id: fadeOut

        ParallelAnimation {
            Anim { target: content; property: "opacity"; to: 0; duration: Appearance.anim.durations.small }
            Anim { target: content; property: "scale"; to: 0.97; duration: Appearance.anim.durations.small }
        }
        ScriptAction {
            script: {
                panelRoot.displayedGif = panelRoot.mod.selectedGif
                fadeIn.start()
            }
        }
    }

    ParallelAnimation {
        id: fadeIn

        Anim { target: content; property: "opacity"; to: 1; duration: Appearance.anim.durations.small }
        Anim { target: content; property: "scale"; to: 1; duration: Appearance.anim.durations.small }
    }

    ColumnLayout {
        id: content

        anchors.centerIn: parent
        width: parent.width - Appearance.padding.large * 2
        spacing: Appearance.spacing.medium
        transformOrigin: Item.Center

        // ── Превью GIF ────────────────────────────────────────────────
        Item {
            id: gifContainer

            Layout.fillWidth: true
            Layout.preferredHeight: width * 0.75

            // Вычисляем вписанные размеры гифки в контейнер 4:3
            readonly property real gifNativeW: (panelRoot.displayedGif?.width ?? 0) > 0
                ? panelRoot.displayedGif.width : 4
            readonly property real gifNativeH: (panelRoot.displayedGif?.height ?? 0) > 0
                ? panelRoot.displayedGif.height : 3
            readonly property real gifAspect: gifNativeW / gifNativeH
            readonly property real containerAspect: width / height

            readonly property real fittedWidth: gifAspect >= containerAspect
                ? width
                : height * gifAspect
            readonly property real fittedHeight: gifAspect >= containerAspect
                ? width / gifAspect
                : height

            // Подложка — ровно под гифкой, те же скругления
            StyledRect {
                anchors.centerIn: parent
                width: gifContainer.fittedWidth
                height: gifContainer.fittedHeight
                radius: Appearance.rounding.large
                color: Colours.alpha(Colours.palette.surface_variant, 0.4)
                visible: gifPlayer.status === AnimatedImage.Ready
                    || gifPlayer.status === AnimatedImage.Loading
            }

            // Индикатор загрузки
            Loader {
                active: gifPlayer.status !== AnimatedImage.Ready
                    && gifPlayer.status !== AnimatedImage.Error
                anchors.centerIn: parent
                z: 2
                sourceComponent: CircularIndicator {}
                onLoaded: item.running = true
            }

            // GIF со скруглёнными углами через ClippingRectangle
            StyledClippingRect {
                anchors.centerIn: parent
                width: gifContainer.fittedWidth
                height: gifContainer.fittedHeight
                radius: Appearance.rounding.large
                color: "transparent"
                z: 1

                AnimatedImage {
                    id: gifPlayer

                    anchors.fill: parent
                    // Контейнер уже имеет правильный aspect ratio → Stretch без артефактов
                    fillMode: Image.Stretch
                    source: panelRoot.displayedGif ? panelRoot.displayedGif.url : ""
                    playing: status === AnimatedImage.Ready
                    asynchronous: true
                }
            }
        }

        // ── Название + размер с тултипом ──────────────────────────────
        Item {
            id: infoBlock

            Layout.fillWidth: true
            implicitHeight: infoColumn.implicitHeight

            property bool hovered: infoHover.hovered

            HoverHandler {
                id: infoHover
            }

            ColumnLayout {
                id: infoColumn
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Appearance.spacing.small

                StyledText {
                    id: titleText

                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    text: panelRoot.displayedGif?.title ?? ""
                    font.pointSize: Appearance.font.size.large
                    font.weight: Font.DemiBold
                    color: Colours.palette.primary
                    elide: Text.ElideRight
                }

                StyledText {
                    id: sizeText

                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: panelRoot.displayedGif
                        ? panelRoot.displayedGif.width + "×" + panelRoot.displayedGif.height
                        : ""
                    font.pointSize: Appearance.font.size.small
                    color: Colours.alpha(Colours.palette.on_surface, 0.5)
                    visible: text !== ""
                }
            }

            Loader {
                active: true
                z: 10000
                width: 0
                height: 0
                sourceComponent: Tooltip {
                    target: infoBlock
                    text: "Alt+Enter — Copy link URL"
                }
            }
        }
    }
}
