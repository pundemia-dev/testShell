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

// Incoming-transfer card: shown when LocalSend has a pending request. Lists
// the sender + files, lets the user pick a destination (default downloadDir,
// or a one-off folder via the system dialog), and accept / reject. While the
// transfer runs it switches to a progress view.
StyledRect {
    id: root

    // Absolute, $HOME-resolved default download dir (from StashContent).
    required property string defaultDir

    readonly property string scriptsDir: (Quickshell.env("HOME") || "/home/user")
        + "/.config/quickshell/pShell/scripts"

    readonly property var req: LocalSend.request
    // A pure text/clipboard send — the card offers a "copy" affordance and the
    // text itself instead of a file row + download destination.
    readonly property bool isTextMsg: req ? (req.isText ?? false) : false
    readonly property string textBody: req ? (req.text ?? "") : ""
    // One-off override chosen via the folder dialog; resets per request.
    property string chosenDir: ""
    readonly property string effectiveDir: chosenDir !== "" ? chosenDir : defaultDir

    // Clear the override whenever a new request takes over the card.
    Connections {
        target: LocalSend
        function onRequestArrived(): void { root.chosenDir = ""; }
    }

    function fmtSize(bytes: real): string {
        if (bytes < 1024) return bytes + " B";
        const u = ["KB", "MB", "GB", "TB"];
        let v = bytes / 1024, i = 0;
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
        return v.toFixed(v < 10 ? 1 : 0) + " " + u[i];
    }

    // freedesktop theme icon for a filename — same mapping FilesTray uses
    // (StashDelegate.themeIcon), so incoming files read identically to tray
    // tiles. Thumbnails aren't possible pre-download; the real previews show
    // once the accepted files land in the tray.
    function themeIcon(name: string): string {
        const ext = name.includes('.') ? name.split('.').pop().toLowerCase() : "";
        if (["png","jpg","jpeg","gif","webp","bmp","svg"].includes(ext)) return "image-x-generic";
        if (ext === "pdf") return "application-pdf";
        if (["mp4","mkv","avi","mov","webm"].includes(ext)) return "video-x-generic";
        if (["mp3","wav","flac","ogg","aac","m4a"].includes(ext)) return "audio-x-generic";
        if (["txt","md","log","csv","json","xml","toml","yaml","yml","sh","py","js","ts","rs","go","cpp","c","h"].includes(ext)) return "text-x-generic";
        if (["zip","tar","gz","bz2","xz","rar","7z"].includes(ext)) return "application-x-archive";
        return "application-x-generic";
    }

    color: Colours.palette.surface
    radius: Appearance.rounding.normal
    opacity: 0.97

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.small

        // ── Header: sender ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledIcon {
                text: ""   // localsend
                color: Colours.palette.primary
                font.pointSize: Appearance.font.size.large
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: root.isTextMsg ? "Incoming message" : "Incoming files"
                    color: Colours.palette.on_surface
                    font.pointSize: Appearance.font.size.normal
                    font.bold: true
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "from " + (root.req ? root.req.alias : "")
                    color: Colours.palette.on_surface_variant
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }
            StyledText {
                visible: root.req
                text: root.req ? root.fmtSize(root.req.totalSize) : ""
                color: Colours.palette.on_surface_variant
                font.pointSize: Appearance.font.size.small
            }
        }

        // ── Text message body (copy affordance) ──────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.isTextMsg
            clip: true
            contentWidth: width
            contentHeight: msgText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            StyledText {
                id: msgText
                width: parent.width
                text: root.textBody
                color: Colours.palette.on_surface
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }

        // ── File list ─────────────────────────────────────────────────
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumHeight: Config.stash.visibleDevicesMax * 32
            visible: !root.isTextMsg
            model: root.req ? root.req.files : []
            clip: true
            spacing: Appearance.spacing.smaller / 2

            delegate: RowLayout {
                id: fileRow
                required property var modelData
                width: ListView.view ? ListView.view.width : 0
                spacing: Appearance.spacing.small

                IconImage {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    Layout.alignment: Qt.AlignVCenter
                    source: Quickshell.iconPath(root.themeIcon(fileRow.modelData.name), "application-x-generic")
                    asynchronous: true
                }
                StyledText {
                    Layout.fillWidth: true
                    text: fileRow.modelData.name
                    color: Colours.palette.on_surface
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideMiddle
                }
                StyledText {
                    text: root.fmtSize(fileRow.modelData.size)
                    color: Colours.palette.on_surface_variant
                    font.pointSize: Appearance.font.size.small
                }
            }
        }

        // ── Progress (while receiving) ────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: LocalSend.receiving
            spacing: Appearance.spacing.smaller

            Item {
                Layout.fillWidth: true
                height: 4

                StyledRect {
                    anchors.fill: parent
                    radius: 2
                    color: Qt.alpha(Colours.palette.primary, 0.22)
                }
                StyledRect {
                    width: parent.width * LocalSend.progress
                    height: parent.height
                    radius: 2
                    color: Colours.palette.primary
                    Behavior on width { Anim {} }
                }
            }
            StyledText {
                text: "Receiving… " + Math.round(LocalSend.progress * 100) + "%"
                color: Colours.palette.on_surface_variant
                font.pointSize: Appearance.font.size.small
            }
        }

        // ── Destination row ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: !LocalSend.receiving && !root.isTextMsg
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.effectiveDir
                color: Colours.palette.on_surface_variant
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideMiddle
            }
            IconButton {
                icon: ""   // folder — choose location
                type: IconButton.Tonal
                implicitHeight: 28
                onClicked: pickProc.running = true
            }
        }

        Process {
            id: pickProc
            command: ["bash", root.scriptsDir + "/localsend_pickdir.sh", root.effectiveDir]
            stdout: StdioCollector {
                id: pickOut
                onStreamFinished: {
                    const dir = pickOut.text.trim();
                    if (dir.length > 0)
                        root.chosenDir = dir;
                }
            }
        }

        // ── Accept / Reject ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: !LocalSend.receiving
            spacing: Appearance.spacing.small

            IconTextButton {
                Layout.fillWidth: true
                type: IconTextButton.Tonal
                text: root.isTextMsg ? "Dismiss" : "Reject"
                onClicked: LocalSend.reject()
            }
            IconTextButton {
                Layout.fillWidth: true
                text: root.isTextMsg ? "Copy" : "Accept"
                onClicked: LocalSend.accept(root.effectiveDir)
            }
        }
    }
}
