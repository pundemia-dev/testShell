pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import qs.components.controls

Item {
    id: root

    required property Item stash

    readonly property string scriptsDir: (Quickshell.env("HOME") || "/home/user") + "/.config/quickshell/pShell/scripts"

    // Direction: true = vertical column (side panel), false = horizontal row (top/bottom overlay).
    // Auto rule: top/bottom anchor takes priority over left/right — if both are present
    // (e.g. corner mount), horizontal wins. Only-center fallback stays vertical.
    readonly property bool isVertical: {
        const d = Config.stash.direction
        if (d === "vertical")   return true
        if (d === "horizontal") return false
        if (Config.stash.anchors.top || Config.stash.anchors.bottom) return false
        if (Config.stash.anchors.left || Config.stash.anchors.right) return true
        return true
    }

    readonly property int _gap:    Appearance.spacing.small
    readonly property int _cell:   Config.stash.cellSize
    readonly property int _cols:   Config.stash.columns
    readonly property int _rows:   Math.max(1, Math.min(Config.stash.rowsMax,
                                        Math.ceil(Math.max(1, stash.model.count) / _cols)))
    readonly property int _hCount: Math.max(1, Math.min(8, stash.model.count))
    // Actions strip dimensions. When vertical: actions sit *below* the grid
    // as a row, so we need its height. When horizontal: actions sit to the
    // *right* of the row, so we need its width.
    readonly property int _actW:   84
    readonly property int _actH:   40

    implicitWidth: isVertical
        ? (_cell + _gap) * _cols + _gap
        : (_cell + _gap) * _hCount + _gap + _actW + _gap
    implicitHeight: isVertical
        ? (_cell + _gap) * _rows + _gap + _actH + _gap
        : _cell + _gap * 2

    HoverHandler {
        onHoveredChanged: root.stash.notePanelHover(hovered)
    }

    // ── LocalSend state ────────────────────────────────────────────
    property string pendingFile: ""
    property string lsState: "idle"   // idle | scanning | ready | sending
    ListModel { id: deviceModel }

    Process {
        id: discoverProc
        command: ["bash", root.scriptsDir + "/localsend_discover.sh"]
        stdout: StdioCollector {
            id: discoverOut
            onStreamFinished: {
                if (root.lsState !== "scanning") return
                deviceModel.clear()
                const lines = discoverOut.text.trim().split('\n')
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split('\t')
                    if (parts.length < 2) continue
                    const ip = parts[1].trim()
                    if (!/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(ip)) continue
                    deviceModel.append({ alias: parts[0].trim(), ip: ip })
                }
                root.lsState = "ready"
            }
        }
    }

    Process {
        id: sendProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: {
            root.lsState = "idle"
            root.pendingFile = ""
        }
    }

    function openSendPicker(file) {
        pendingFile = file
        deviceModel.clear()
        lsState = "scanning"
        discoverProc.running = true
    }

    function sendTo(ip) {
        lsState = "sending"
        sendProc.command = ["bash", root.scriptsDir + "/localsend_send.sh", pendingFile, ip]
        sendProc.running = true
    }

    function dropPath(srcPath) {
        const cmd = Config.stash.dropMode === "symlink"
            ? "ln -sf '" + srcPath + "' '" + root.stash.stashDir + "/'"
            : "cp -n '" + srcPath + "' '" + root.stash.stashDir + "/'"
        dropProc.command = ["bash", "-c", cmd + " && touch '" + root.stash.stashDir + "'"]
        dropProc.running = true
    }
    Process { id: dropProc; onExited: root.stash.refreshStash() }

    // ── Main layout ────────────────────────────────────────────────
    // Outer layout switches orientation with `isVertical`:
    //   vertical   → GridLayout flows top→bottom: file area on top, actions row below.
    //   horizontal → GridLayout flows left→right: file area on left, actions column right.
    // The inner actions panel mirrors the same switch so buttons stack
    // perpendicular to the panel's long axis.
    GridLayout {
        anchors.fill: parent
        rowSpacing: root._gap
        columnSpacing: root._gap
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.isVertical ? 2 : 1
        columns: root.isVertical ? 1 : 2

        // ── File view area ─────────────────────────────────────────
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Appearance.spacing.small
                visible: root.stash.model.count === 0 && root.lsState === "idle"

                IconImage {
                    source: Quickshell.iconPath("folder-open", "folder")
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignHCenter
                    asynchronous: true
                }
                StyledText {
                    text: "Files Tray"
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.on_surface
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: "Drop files here"
                    color: Colours.palette.on_surface_variant
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Vertical mode: GridView
            GridView {
                id: vGrid
                anchors.fill: parent
                visible: root.isVertical && root.stash.model.count > 0 && root.lsState === "idle"
                model: root.stash.model
                cellWidth:  root._cell + root._gap
                cellHeight: root._cell + root._gap
                clip: true

                delegate: StashDelegate {
                    width:  vGrid.cellWidth
                    height: vGrid.cellHeight
                    stash:  root.stash
                    sender: root
                }
            }

            // Horizontal mode: ListView (single row, horizontal scroll)
            ListView {
                id: hList
                anchors.fill: parent
                visible: !root.isVertical && root.stash.model.count > 0 && root.lsState === "idle"
                model: root.stash.model
                orientation: ListView.Horizontal
                spacing: root._gap
                clip: true

                delegate: StashDelegate {
                    width:  root._cell
                    height: root._cell
                    stash:  root.stash
                    sender: root
                }
            }

            // DropArea: accept dragged files
            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                property bool isHovered: false
                onEntered: isHovered = true
                onExited:  isHovered = false
                onDropped: drop => {
                    isHovered = false
                    if (!drop.hasUrls) return
                    for (let i = 0; i < drop.urls.length; i++) {
                        const url = drop.urls[i].toString().trim()
                        if (!url.startsWith("file://")) continue
                        root.dropPath(decodeURIComponent(url.replace("file://", "")))
                    }
                    drop.accept()
                }

                StyledRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: parent.isHovered ? Qt.alpha(Colours.palette.primary, 0.18) : "transparent"
                }
            }

            // Device picker overlay (LocalSend)
            DevicePicker {
                anchors.fill: parent
                visible: root.lsState !== "idle"
                stateText: root.lsState === "scanning" ? "Scanning…"
                         : root.lsState === "sending"  ? "Sending…"
                         : deviceModel.count === 0     ? "No devices found"
                         : "Send to"
                sending: root.lsState === "sending"
                devices: deviceModel
                onPicked: ip => root.sendTo(ip)
                onClosed: {
                    root.lsState = "idle"
                    root.pendingFile = ""
                    discoverProc.running = false
                }
            }
        }

        // ── Actions strip (row below grid / column beside row) ─────
        GridLayout {
            Layout.preferredWidth:  root.isVertical ? -1 : root._actW
            Layout.preferredHeight: root.isVertical ? root._actH : -1
            Layout.fillWidth:  root.isVertical
            Layout.fillHeight: !root.isVertical
            rowSpacing: root._gap
            columnSpacing: root._gap
            flow: root.isVertical ? GridLayout.LeftToRight : GridLayout.TopToBottom
            rows: root.isVertical ? 1 : 5
            columns: root.isVertical ? 5 : 1

            StyledText {
                text: root.stash.model.count + " file" + (root.stash.model.count === 1 ? "" : "s")
                color: Colours.palette.on_surface_variant
                font.pointSize: Appearance.font.size.smaller
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
            }

            IconButton {
                Layout.alignment: Qt.AlignCenter
                icon: ""
                type: IconButton.Tonal
                onClicked: root.stash.refreshStash()
            }

            IconButton {
                Layout.alignment: Qt.AlignCenter
                icon: ""
                type: IconButton.Tonal
                onClicked: openProc.running = true
            }
            Process {
                id: openProc
                command: ["xdg-open", root.stash.stashDir]
            }

            Item {
                Layout.fillWidth:  root.isVertical
                Layout.fillHeight: !root.isVertical
            }

            IconButton {
                Layout.alignment: Qt.AlignCenter
                icon: ""
                type: IconButton.Tonal
                onClicked: clearAllProc.running = true
            }
            Process {
                id: clearAllProc
                command: ["bash", "-c", "rm -rf '" + root.stash.stashDir + "'/* && touch '" + root.stash.stashDir + "'"]
                onExited: root.stash.refreshStash()
            }
        }
    }
}
