import QtQuick
import QtQuick.Layouts
import qs.config
import qs.utils
import qs.components
import qs.components.controls
import qs.services
import Quickshell
import Quickshell.Io

LauncherModule {
    id: root

    moduleId: "Gif"
    name: "GIF Search"
    description: "Search and copy GIFs from Giphy"
    trigger: "gif"
    icon: "🎞️"

    hasLeftPanel: true
    hasRightPanel: false
    customRightWidth: 380

    readonly property string apiKey: Config.launcher.giphyApiKey ?? ""

    property var selectedGif: null
    property var _pendingGif: null

    Timer {
        id: debounceTimer
        interval: 80
        onTriggered: selectedGif = _pendingGif
    }

    Timer {
        id: networkDebounceTimer
        interval: 500
        property string currentQuery: ""
        onTriggered: root.fetchGifs(currentQuery)
    }

    ScriptModel {
        id: internalModel
    }

    listModel: internalModel

    function onActivated(initialQuery) {
        hasRightPanel = false
        selectedGif = null
        handleInput(initialQuery)
    }

    function handleInput(query) {
        selectedGif = null
        if (query.trim() === "") {
            internalModel.values = []
            networkDebounceTimer.stop()
            hasRightPanel = false
            return
        }
        networkDebounceTimer.currentQuery = query
        networkDebounceTimer.restart()
    }

    function fetchGifs(query) {
        if (!apiKey) {
            console.warn("GifListModule: giphyApiKey is not set in config (launcher.giphyApiKey)")
            internalModel.values = []
            hasRightPanel = false
            return
        }

        let xhr = new XMLHttpRequest()
        let url = `https://api.giphy.com/v1/gifs/search?api_key=${apiKey}&q=${encodeURIComponent(query)}&limit=20`

        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                let response = JSON.parse(xhr.responseText)
                let results = response.data || []

                let newValues = results.map(gif => {
                    let original = gif.images.original
                    let preview = gif.images.fixed_height_small
                    let title = gif.title || "GIF"

                    let gifData = {
                        url: original.url,
                        width: original.width,
                        height: original.height,
                        title: title
                    }

                    return {
                        _gifData: gifData,
                        header: title,
                        text: original.width + "×" + original.height,
                        backgroundImage: preview.url,
                        rightIcon: "\ue14d",
                        rightText: "",

                        onClicked: function() {
                            root.copyGifToClipboard(original.url, true)
                            requestClose(true)
                        },
                        onAltClicked: function() {
                            root.copyGifToClipboard(original.url, false)
                            requestClose(true)
                        },
                        onSelected: function() {
                            root._pendingGif = gifData
                            debounceTimer.restart()
                        }
                    }
                })

                internalModel.values = newValues

                if (newValues.length > 0) {
                    root.hasRightPanel = true
                    root.selectedGif = newValues[0]._gifData ?? null
                } else {
                    root.hasRightPanel = false
                }
            }
        }
        xhr.send()
    }

    function copyGifToClipboard(url, asGif) {
        let proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)

        if (asGif) {
            proc.command = ["sh", "-c",
                `tmpfile=$(mktemp /tmp/qs-gif-XXXXXX.gif) && ` +
                `curl -s "${url}" -o "$tmpfile" && ` +
                `printf 'file://%s\\n' "$tmpfile" | wl-copy -t text/uri-list`
            ]
        } else {
            proc.command = ["sh", "-c", `printf '%s' "${url}" | wl-copy`]
        }

        proc.exited.connect(() => {
            proc.destroy()
        })

        proc.running = true
    }

    // ==========================================
    // КНОПКА ДЛЯ ROW INPUT
    // ==========================================

    inputExtensionComponent: Component {
        StyledRect {
            implicitWidth: 32
            implicitHeight: 32
            radius: Appearance.rounding.small ?? 8
            color: toggleArea.containsMouse
                ? Colours.alpha(Colours.palette.on_surface, 0.1)
                : "transparent"

            StyledIcon {
                anchors.centerIn: parent
                text: root.hasRightPanel ? "\ufc3d" : "\ufc3e"
                font.pointSize: Appearance.font.size.large ?? 16
                color: root.hasRightPanel
                    ? Colours.palette.primary
                    : Colours.palette.on_surface_variant
            }

            MouseArea {
                id: toggleArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.hasRightPanel = !root.hasRightPanel
                }
            }
        }
    }

    // ==========================================
    // ПРАВАЯ ПАНЕЛЬ (Превью GIF)
    // ==========================================

    rightPanelComponent: Component {
        Item {
            id: panelRoot

            anchors.fill: parent

            property var displayedGif: root.selectedGif

            Connections {
                target: root
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
                        panelRoot.displayedGif = root.selectedGif
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
    }
}
