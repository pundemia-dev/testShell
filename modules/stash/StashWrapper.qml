pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.utils
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick
import "content"

Item {
    id: root

    required property var manager
    required property ShellScreen screen

    // ── Visibility ──────────────────────────────────────────────────
    property bool stashVisible: false

    // ── Hover-driven auto-hide ──────────────────────────────────────
    // Either the trigger strip or the open panel (or its content) being
    // hovered counts as "active". When all sources drop hover, leaveTimer
    // counts down Config.stash.autoHideMs and then hides the panel.
    property bool _triggerHovered: false
    property bool _panelHovered: false
    // Set when a file drag enters the trigger strip — lets StashContent
    // show the drop-zone chooser the moment the panel pops in, instead of
    // waiting for the drag to also enter the content area.
    property bool incomingDrag: false
    readonly property bool _anyHovered: _triggerHovered || _panelHovered

    function notePanelHover(hovered) { _panelHovered = hovered; }
    function noteIncomingDrag(active) { incomingDrag = active; }

    onStashVisibleChanged: {
        if (!stashVisible) {
            _triggerHovered = false;
            _panelHovered = false;
            incomingDrag = false;
            leaveTimer.stop();
        }
    }
    on_AnyHoveredChanged: {
        if (!stashVisible) return;
        if (_anyHovered) leaveTimer.stop();
        else if (Config.stash.autoHideMs > 0) leaveTimer.restart();
    }

    Timer {
        id: leaveTimer
        interval: Config.stash.autoHideMs
        repeat: false
        onTriggered: {
            if (!root._anyHovered && root.stashVisible) {
                VisibilitiesManager.setVisibility(root.screen, "stash", false);
            }
        }
    }

    // ── Stash directory (resolved from config) ─────────────────────
    readonly property string stashDir: {
        let p = Config.stash.stashDir;
        if (p.startsWith("~"))    p = p.replace("~", Quickshell.env("HOME") || "/home/user");
        if (p.startsWith("$HOME")) p = p.replace("$HOME", Quickshell.env("HOME") || "/home/user");
        return p;
    }

    // ── Stash model (scanned file list) ────────────────────────────
    ListModel { id: stashModel }
    property alias model: stashModel
    property bool _refreshing: false

    function refreshStash() {
        scanner.running = true;
    }

    Process {
        id: scanner
        command: ["bash", "-c", `mkdir -p '${root.stashDir}' && ls -1A '${root.stashDir}' 2>/dev/null`]
        stdout: StdioCollector {
            id: scannerOut
            onStreamFinished: {
                root._refreshing = true;
                // Diff-update so unchanged delegates aren't destroyed/recreated
                // — that's what caused the thumbnail flicker on every 1.5s tick.
                const names = [];
                const lines = scannerOut.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const n = lines[i].trim();
                    if (n) names.push(n);
                }
                const wanted = new Set(names);
                // Remove entries no longer present (iterate from end so indices stay valid).
                for (let i = stashModel.count - 1; i >= 0; i--) {
                    if (!wanted.has(stashModel.get(i).fileName)) stashModel.remove(i);
                }
                // Build set of names we already have.
                const have = new Set();
                for (let i = 0; i < stashModel.count; i++) have.add(stashModel.get(i).fileName);
                // Append only new entries (preserves existing delegate instances).
                for (let i = 0; i < names.length; i++) {
                    const n = names[i];
                    if (have.has(n)) continue;
                    const filePath = root.stashDir + "/" + n;
                    stashModel.append({
                        fileURL: "file://" + filePath,
                        filePath: filePath,
                        fileName: n,
                        isFav: false
                    });
                }
                root._refreshing = false;
            }
        }
    }

    // Watcher: refresh when files appear/disappear (driven by inotify timer).
    Timer {
        id: watchTick
        interval: 1500
        repeat: true
        running: root.stashVisible
        onTriggered: root.refreshStash()
    }

    Component.onCompleted: {
        VisibilitiesManager.addVisibility(root.screen, "stash", Config.stash.shortcut,
                                          false, false, "Toggle Stash");
        refreshStash();
    }

    Connections {
        target: VisibilitiesManager
        function onVisibilityChanged(screen: ShellScreen, name: string, state: bool) {
            if (screen === root.screen && name === "stash") {
                root.stashVisible = state;
                if (state) root.refreshStash();
            }
        }
    }

    // ── QtObject contract for the rails system ─────────────────────
    property QtObject content: QtObject {
        // Size (auto from content)
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        // Anchors from config
        property bool aLeft: Config.stash.anchors.left ?? undefined
        property bool aRight: Config.stash.anchors.right ?? undefined
        property bool aTop: Config.stash.anchors.top ?? undefined
        property bool aBottom: Config.stash.anchors.bottom ?? undefined
        property bool aHorizontalCenter: Config.stash.anchors.horizontalCenter ?? undefined
        property bool aVerticalCenter: Config.stash.anchors.verticalCenter ?? undefined
        // Margins
        property int mLeft: Config.stash.mLeft
        property int mRight: Config.stash.mRight
        property int mTop: Config.stash.mTop
        property int mBottom: Config.stash.mBottom
        property int vCenterOffset: 0
        property int hCenterOffset: 0
        // Padding
        property int pLeft: Config.stash.padding
        property int pRight: Config.stash.padding
        property int pTop: Config.stash.padding
        property int pBottom: Config.stash.padding
        // Rails contract
        property string mode: Config.stash.mode
        property bool pinned: false
        property bool reservesSpace: false
        readonly property int layer: 0
        property int windowRounding: Config.stash.rounding >= 0 ? Config.stash.rounding : (Config.backgrounds.rounding ?? 0)
        property int invertedJoinRounding: Config.stash.invertedJoinRounding >= 0 ? Config.stash.invertedJoinRounding : (Config.backgrounds.rounding ?? 0)
        // Content
        property Component content: StashContent {
            stash: root
        }
    }

    // ── Hover trigger: thin strip at the chosen edge ───────────────
    Loader {
        active: Config.stash.enabled && Config.stash.hoverStripPx > 0
        anchors.left: Config.stash.anchors.left ? parent.left : (Config.stash.anchors.horizontalCenter ? parent.left : undefined)
        anchors.right: Config.stash.anchors.right ? parent.right : (Config.stash.anchors.horizontalCenter ? parent.right : undefined)
        anchors.top: !Config.stash.anchors.bottom ? parent.top : undefined
        anchors.bottom: Config.stash.anchors.bottom ? parent.bottom : undefined
        height: Config.stash.anchors.top || Config.stash.anchors.bottom ? Config.stash.hoverStripPx : parent.height
        width: Config.stash.anchors.left || Config.stash.anchors.right ? Config.stash.hoverStripPx : parent.width

        sourceComponent: Item {
            HoverHandler {
                id: hover
                onHoveredChanged: {
                    root._triggerHovered = hovered;
                    if (hovered) VisibilitiesManager.setVisibility(root.screen, "stash", true);
                }
            }
            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: {
                    root._triggerHovered = true;
                    root.incomingDrag = true;
                    VisibilitiesManager.setVisibility(root.screen, "stash", true);
                }
                onExited: {
                    root._triggerHovered = false;
                    root.incomingDrag = false;
                }
            }
        }
    }

    // ── Backend Loader: registers/unregisters the bg via manager ───
    Loader {
        active: root.stashVisible
        sourceComponent: Item {
            Component.onCompleted: root.manager.requestBackground(root.content)
            Component.onDestruction: root.manager.removeBackground(root.content)
        }
    }
}
