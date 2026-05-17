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
    id: del

    required property Item stash
    required property Item sender

    required property int index
    required property string fileURL
    required property string filePath
    required property string fileName
    required property bool isFav

    readonly property string _ext: fileName.includes('.') ? fileName.split('.').pop().toLowerCase() : ""

    readonly property bool isImage:   ["png","jpg","jpeg","gif","webp","bmp","svg"].includes(_ext)
    readonly property bool isPdf:     _ext === "pdf"
    readonly property bool isVideo:   ["mp4","mkv","avi","mov","webm"].includes(_ext)
    readonly property bool isAudio:   ["mp3","wav","flac","ogg","aac","m4a"].includes(_ext)
    readonly property bool isText:    ["txt","md","log","csv","json","xml","toml","yaml","yml","sh","py","js","ts","rs","go","cpp","c","h"].includes(_ext)
    readonly property bool isArchive: ["zip","tar","gz","bz2","xz","rar","7z"].includes(_ext)

    // Thumb cache: stable name based on sanitised filename
    readonly property string _thumbBase: "/tmp/qs_stash_" + fileName.replace(/[^a-zA-Z0-9-]/g, "_")
    readonly property string _thumbPath: _thumbBase + ".png"

    property string _genThumbPath: ""
    readonly property bool hasThumb: isImage || _genThumbPath !== ""
    readonly property string thumbSource: isImage ? fileURL : (_genThumbPath !== "" ? "file://" + _genThumbPath : "")

    readonly property string themeIcon: {
        if (isImage)   return "image-x-generic"
        if (isPdf)     return "application-pdf"
        if (isVideo)   return "video-x-generic"
        if (isAudio)   return "audio-x-generic"
        if (isText)    return "text-x-generic"
        if (isArchive) return "application-x-archive"
        return "application-x-generic"
    }

    Component.onCompleted: {
        if (isPdf || isVideo) checkThumb.running = true
    }

    // Check if cached thumb already exists before generating
    Process {
        id: checkThumb
        command: ["test", "-f", del._thumbPath]
        onExited: (code, status) => {
            if (code === 0) del._genThumbPath = del._thumbPath
            else if (del.isPdf)   pdfThumb.running = true
            else if (del.isVideo) vidThumb.running = true
        }
    }

    Process {
        id: pdfThumb
        command: ["bash", "-c", "pdftoppm -r 80 -singlefile -png -l 1 '" + del.filePath + "' '" + del._thumbBase + "'"]
        onExited: (code, status) => { if (code === 0) del._genThumbPath = del._thumbPath }
    }

    Process {
        id: vidThumb
        command: ["bash", "-c", "ffmpegthumbnailer -i '" + del.filePath + "' -o '" + del._thumbPath + "' -s 200 -q 8 2>/dev/null"]
        onExited: (code, status) => { if (code === 0) del._genThumbPath = del._thumbPath }
    }

    MouseArea {
        id: tile
        anchors.fill: parent
        anchors.margins: 4
        drag.target: dragItem
        hoverEnabled: true

        StyledRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Colours.palette.surface_container
            clip: true

            // System theme icon underneath — always present, gets faded out
            // when the thumbnail becomes ready. Keeping it on-screen during
            // thumb decode prevents the "blank rectangle" flicker.
            IconImage {
                id: sysIcon
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.52
                height: width
                source: Quickshell.iconPath(del.themeIcon, "application-x-generic")
                asynchronous: true
                opacity: thumb.opacity < 1 ? 1 : 0
                Behavior on opacity { Anim {} }
            }

            // Thumbnail (images / generated PDF+video thumbs). Cached so
            // GridView delegate recycling doesn't re-decode and flash.
            Image {
                id: thumb
                anchors.fill: parent
                source: del.thumbSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: del.hasThumb && status === Image.Ready ? 1 : 0
                Behavior on opacity { Anim {} }
            }

            // File name label — always visible when no thumb, on-hover when thumb shown
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: nameLabel.implicitHeight + Appearance.padding.small * 2
                color: del.hasThumb ? Qt.alpha(Colours.palette.surface, 0.82) : "transparent"
                visible: !del.hasThumb || tile.containsMouse

                StyledText {
                    id: nameLabel
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Appearance.padding.small
                        rightMargin: Appearance.padding.small
                    }
                    text: del.fileName
                    color: del.hasThumb ? Colours.palette.on_surface : Colours.palette.on_surface_variant
                    font.pointSize: Appearance.font.size.smaller
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item {
            id: dragItem
            anchors.fill: parent
            Drag.active: tile.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: { "text/uri-list": del.fileURL }
        }

        RowLayout {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Appearance.padding.small
            spacing: 2
            opacity: tile.containsMouse ? 1.0 : 0.0
            Behavior on opacity { Anim {} }

            IconButton {
                icon: del.isFav ? "" : ""
                type: IconButton.Tonal
                implicitHeight: 24
                onClicked: {
                    const f = !del.isFav
                    del.stash.model.setProperty(del.index, "isFav", f)
                    del.stash.model.move(del.index, f ? 0 : del.stash.model.count - 1, 1)
                }
            }
            IconButton {
                icon: ""
                type: IconButton.Filled
                implicitHeight: 24
                visible: Config.stash.localsendEnabled
                onClicked: del.sender.openSendPicker(del.filePath)
            }
            IconButton {
                icon: ""
                type: IconButton.Tonal
                implicitHeight: 24
                onClicked: deleteProc.running = true
            }
        }

        Process {
            id: deleteProc
            command: ["bash", "-c", "rm -rf '" + del.filePath + "'"]
            onExited: del.stash.refreshStash()
        }
    }
}
