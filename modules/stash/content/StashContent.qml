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
    readonly property int _hCount: Math.max(1, Math.min(Config.stash.colsMax, stash.model.count))
    // Actions strip dimensions. When vertical: actions sit *below* the grid
    // as a row, so we need its height. When horizontal: actions sit to the
    // *right* of the row, so we need its width.
    readonly property int _actW:   84
    readonly property int _actH:   40

    // Drop-zone tile dimensions (drag-into-stash chooser). x/y swap with
    // orientation per Config.stash.dropZoneX / dropZoneY contract.
    readonly property int _zoneW: isVertical ? Config.stash.dropZoneX : Config.stash.dropZoneY
    readonly property int _zoneH: isVertical ? Config.stash.dropZoneY : Config.stash.dropZoneX

    // Device picker sizing — approximate, kept in sync with DeviceUnit's
    // natural layout (icon + alias + badges row).
    readonly property int _deviceRowH:    60
    readonly property int _pickerHeaderH: 44   // header row (state label + rescan)
    readonly property int _pickerPadH:    Appearance.padding.normal * 2
    // Visible device count = devices found, clamped to 1..visibleDevicesMax
    // so the panel always has at least one row's worth of vertical space
    // for the "Scanning…" / "Sending…" placeholders.
    readonly property int _pickerVisibleRows: Math.max(1,
        Math.min(deviceModel.count, Config.stash.visibleDevicesMax))
    readonly property int _pickerH: _pickerHeaderH + _pickerPadH +
        _pickerVisibleRows * _deviceRowH +
        Math.max(0, _pickerVisibleRows - 1) * Appearance.spacing.smaller

    // View state: dropping a file into the trigger strip or directly onto
    // this content area pivots from "file tray" to "pick a drop zone".
    //
    // _localDragging is the OR of containsDrag across every drop-receiving
    // surface in the panel: the outer drag tracker plus the two inner tiles
    // (filesDrop and sendDrop). This is critical — Qt routes drag events
    // to the topmost DropArea, so when the drag moves from the outer into
    // a tile, the outer fires onExited and would otherwise drop _localDragging
    // to false mid-drag. Binding to containsDrag of all three keeps it true
    // for the whole duration the drag is anywhere inside the panel.
    readonly property bool _localDragging:
        outerDropTracker.containsDrag
        || (typeof filesDrop !== "undefined" && filesDrop.containsDrag)
        || (typeof sendDrop !== "undefined" && sendDrop.containsDrag)
    on_LocalDraggingChanged: root.stash.notePanelDragging(_localDragging)
    readonly property bool _dragging: (root.stash.incomingDrag ?? false) || _localDragging

    // Incoming LocalSend request takes precedence over every other view.
    readonly property bool _showIncoming: LocalSend.hasIncoming
    readonly property bool _showZones:  !_showIncoming && _dragging && lsState === "idle"
    readonly property bool _showPicker: !_showIncoming && lsState !== "idle"
    readonly property bool _showFiles:  !_showIncoming && !_dragging && lsState === "idle"

    // Default download dir for accepted files ($HOME-resolved).
    readonly property string defaultDownloadDir: {
        let p = Config.stash.downloadDir
        const home = Quickshell.env("HOME") || "/home/user"
        if (p.startsWith("~"))      p = home + p.slice(1)
        else if (p.startsWith("$HOME")) p = home + p.slice(5)
        return p
    }

    // Base (file-tray) dimensions, reused by the size bindings below.
    readonly property int _baseW: isVertical
        ? (_cell + _gap) * _cols + _gap
        : (_cell + _gap) * _hCount + _gap + _actW + _gap
    readonly property int _baseH: isVertical
        ? (_cell + _gap) * _rows + _gap + _actH + _gap
        : _cell + _gap * 2

    // Incoming card height: header + file rows (capped) + destination + buttons.
    readonly property bool _incomingIsText: LocalSend.request
        ? (LocalSend.request.isText ?? false) : false
    readonly property int _incomingRows: Math.max(1, Math.min(Config.stash.visibleDevicesMax,
        LocalSend.request ? LocalSend.request.files.length : 1))
    readonly property int _incomingH: _incomingIsText
        ? _pickerHeaderH + _pickerPadH + 160 + 44 + Appearance.spacing.small * 3
        : _pickerHeaderH + _pickerPadH
            + _incomingRows * 32
            + 36   // destination row
            + 44   // accept / reject buttons
            + Appearance.spacing.small * 3

    // Content-driven sizing: one dimension is fixed (column count when vertical,
    // single-row height when horizontal), the other shrinks to fit the actual
    // visible file count (capped by rowsMax / colsMax). Picker mode picks its
    // own height from visibleDevicesMax instead.
    implicitWidth: _showZones
        ? (isVertical ? _zoneW : (_zoneW * 2 + _gap))
        : _showIncoming ? Math.max(280, _baseW)
        : _baseW
    implicitHeight: _showZones
        ? (isVertical ? (_zoneH * 2 + _gap) : _zoneH)
        : _showIncoming ? _incomingH
        : _showPicker ? _pickerH
        : _baseH

    HoverHandler {
        onHoveredChanged: root.stash.notePanelHover(hovered)
    }

    // Outer drag tracker — only consulted via its `containsDrag` property
    // (see _localDragging binding above). Drag events still route to the
    // topmost DropArea, but containsDrag of the tile DropAreas keeps
    // _localDragging asserted while the drag is anywhere in the panel.
    DropArea {
        id: outerDropTracker
        anchors.fill: parent
        keys: ["text/uri-list"]
    }

    // ── LocalSend state ────────────────────────────────────────────
    // Files queued for the current outbound transfer. They all go out in a
    // single LocalSend session (one prepare-upload, one accept prompt on the
    // peer), so multi-file sends work for both the send-all button and a
    // multi-file drop onto the LocalSend zone.
    property var pendingFiles: []
    property string lsState: "idle"   // idle | scanning | ready | sending
    ListModel { id: deviceModel }

    Process {
        id: discoverProc
        command: [root.scriptsDir + "/localsend_discover.py"]
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
                    deviceModel.append({
                        alias: parts[0].trim(),
                        ip: ip,
                        deviceType: parts.length > 2 ? parts[2].trim() : "",
                        deviceModel: parts.length > 3 ? parts[3].trim() : ""
                    })
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
            root.pendingFiles = []
        }
    }

    function openSendPicker(file) {
        pendingFiles = [file]
        startScan()
    }

    function openSendPickerAll() {
        const all = []
        for (let i = 0; i < root.stash.model.count; i++) {
            all.push(root.stash.model.get(i).filePath)
        }
        if (all.length === 0) return
        pendingFiles = all
        startScan()
    }

    function startScan() {
        deviceModel.clear()
        lsState = "scanning"
        discoverProc.running = true
    }

    function sendTo(ip) {
        if (pendingFiles.length === 0) return
        lsState = "sending"
        sendProc.command = [root.scriptsDir + "/localsend_send.py", ip].concat(pendingFiles)
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

    // Helpers — collect dropped URLs and start an outbound send queue
    // straight from the LocalSend zone (no stash detour).
    function pathsFromDrop(drop) {
        const paths = []
        if (!drop.hasUrls) return paths
        for (let i = 0; i < drop.urls.length; i++) {
            const u = drop.urls[i].toString().trim()
            if (!u.startsWith("file://")) continue
            paths.push(decodeURIComponent(u.replace("file://", "")))
        }
        return paths
    }

    function sendDroppedFiles(paths) {
        if (paths.length === 0) return
        pendingFiles = paths
        startScan()
    }

    // ── State 1: Drop-zone chooser (drag in progress) ──────────────
    // Two equal-size tiles. FilesTray copies/symlinks into the stash dir.
    // LocalSend immediately fires up the device picker — no stash detour.
    GridLayout {
        anchors.fill: parent
        visible: root._showZones
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.isVertical ? 2 : 1
        columns: root.isVertical ? 1 : 2
        rowSpacing: root._gap
        columnSpacing: root._gap

        // FilesTray zone — transparent by default, dashed border on hover.
        Item {
            Layout.preferredWidth:  root._zoneW
            Layout.preferredHeight: root._zoneH

            DashedRect {
                anchors.fill: parent
                strokeColor: Colours.palette.primary
                strokeWidth: Config.stash.dashedBorderWidth
                dashLength:  Config.stash.dashedBorderDashLength
                gapLength:   Config.stash.dashedBorderGapLength
                cornerRadius: Config.stash.dashedBorderRadius
                opacity: filesDrop.containsDrag ? 1 : 0
                Behavior on opacity { Anim {} }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.small

                StyledIcon {
                    text: "\ueac4"
                    color: Colours.palette.primary
                    font.pointSize: Appearance.font.size.extraLarge
                    Layout.alignment: Qt.AlignLeft
                }
                StyledText {
                    text: "Files Tray"
                    color: Colours.palette.on_surface
                    font.pointSize: Appearance.font.size.normal
                    Layout.alignment: Qt.AlignLeft
                }
            }

            DropArea {
                id: filesDrop
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: drop => {
                    if (!drop.hasUrls) return
                    for (let i = 0; i < drop.urls.length; i++) {
                        const url = drop.urls[i].toString().trim()
                        if (!url.startsWith("file://")) continue
                        root.dropPath(decodeURIComponent(url.replace("file://", "")))
                    }
                    drop.accept()
                }
            }
        }

        // LocalSend zone — always tinted; hover bumps the alpha.
        Item {
            Layout.preferredWidth:  root._zoneW
            Layout.preferredHeight: root._zoneH

            StyledRect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Qt.alpha(Colours.palette.primary, sendDrop.containsDrag ? 0.34 : 0.18)
                Behavior on color { CAnim {} }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.small

                StyledIcon {
                    text: "\uf016"
                    color: Colours.palette.primary
                    font.pointSize: Appearance.font.size.extraLarge
                    Layout.alignment: Qt.AlignLeft
                }
                StyledText {
                    text: "LocalSend"
                    color: Colours.palette.on_surface
                    font.pointSize: Appearance.font.size.normal
                    Layout.alignment: Qt.AlignLeft
                }
            }

            DropArea {
                id: sendDrop
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: drop => {
                    const paths = root.pathsFromDrop(drop)
                    drop.accept()
                    if (paths.length > 0) root.sendDroppedFiles(paths)
                }
            }
        }
    }

    // ── State 2: File tray (default open view) ─────────────────────
    GridLayout {
        anchors.fill: parent
        visible: root._showFiles
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
                visible: root.stash.model.count === 0

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
                visible: root.isVertical && root.stash.model.count > 0
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
                visible: !root.isVertical && root.stash.model.count > 0
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

            // DropArea: file dropped on the open tray goes into the stash dir.
            // Kept passive (no hover background) so it doesn't compete with
            // the explicit drop-zone chooser shown during drag.
            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: drop => {
                    if (!drop.hasUrls) return
                    for (let i = 0; i < drop.urls.length; i++) {
                        const url = drop.urls[i].toString().trim()
                        if (!url.startsWith("file://")) continue
                        root.dropPath(decodeURIComponent(url.replace("file://", "")))
                    }
                    drop.accept()
                }
            }
        }

        // ── Actions strip ──────────────────────────────────────────
        GridLayout {
            Layout.preferredWidth:  root.isVertical ? -1 : root._actW
            Layout.preferredHeight: root.isVertical ? root._actH : -1
            Layout.fillWidth:  root.isVertical
            Layout.fillHeight: !root.isVertical
            rowSpacing: root._gap
            columnSpacing: root._gap
            flow: root.isVertical ? GridLayout.LeftToRight : GridLayout.TopToBottom
            rows: root.isVertical ? 1 : 6
            columns: root.isVertical ? 6 : 1

            IconButton {
                Layout.alignment: Qt.AlignCenter
                icon: "\ueb13"
                type: IconButton.Tonal
                onClicked: root.stash.refreshStash()
            }

            IconButton {
                Layout.alignment: Qt.AlignCenter
                icon: "\ueaad"
                type: IconButton.Tonal
                onClicked: openProc.running = true
            }
            Process {
                id: openProc
                command: ["xdg-open", root.stash.stashDir]
            }

            IconButton {
                Layout.alignment: Qt.AlignCenter
                icon: "\ueb21"
                type: IconButton.Tonal
                visible: Config.stash.localsendEnabled
                disabled: root.stash.model.count === 0
                onClicked: { if (root.stash.model.count > 0) root.openSendPickerAll() }
            }

            // Receive toggle — turn the LocalSend receive server on/off.
            // Checked state is persisted in shell.json via Config.stash.
            IconButton {
                Layout.alignment: Qt.AlignCenter
                icon: ""   // localsend
                type: IconButton.Tonal
                toggle: true
                visible: Config.stash.localsendEnabled
                checked: Config.stash.localsendReceiveEnabled
                onClicked: Config.stash.localsendReceiveEnabled = !Config.stash.localsendReceiveEnabled
            }

            Item {
                Layout.fillWidth:  root.isVertical
                Layout.fillHeight: !root.isVertical
            }

            IconButton {
                Layout.alignment: Qt.AlignCenter
                icon: "\ueb41"
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

    // ── State 3: Device picker (scanning / sending) ────────────────
    DevicePicker {
        anchors.fill: parent
        visible: root._showPicker
        stateText: root.lsState === "scanning" ? "Scanning…"
                 : root.lsState === "sending"  ? "Sending…"
                 : deviceModel.count === 0     ? "No devices found"
                 : "Send to"
        sending: root.lsState === "sending"
        scanning: root.lsState === "scanning"
        devices: deviceModel
        onPicked: ip => root.sendTo(ip)
        onRescan: {
            discoverProc.running = false
            root.startScan()
        }
    }

    // ── State 4: Incoming LocalSend request (accept / reject) ──────
    IncomingRequest {
        anchors.fill: parent
        visible: root._showIncoming
        defaultDir: root.defaultDownloadDir
    }
}
