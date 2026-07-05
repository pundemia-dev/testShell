import QtQuick
import qs.config
import qs.components
import qs.components.controls
import qs.services
import Quickshell
import Quickshell.Io
import qs.modules.launcher.content

LauncherModule {
    id: root

    hasLeftPanel: true
    hasRightPanel: false
    customRightWidth: 380

    readonly property string apiKey: Config.getCustom("gif", "apiKey", "") ?? ""

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
            console.warn("GifModule: Giphy API key is not set (Settings → GIF Search)")
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
                        rightIcon: "",
                        rightText: "",

                        onClicked: function() {
                            root.copyGifToClipboard(original.url, true)
                            root.requestClose(true)
                        },
                        onAltClicked: function() {
                            root.copyGifToClipboard(original.url, false)
                            root.requestClose(true)
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
                text: root.hasRightPanel ? "ﰽ" : "ﰾ"
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
        GifPreviewPanel {
            mod: root
        }
    }
}
