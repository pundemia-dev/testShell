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

    // ── Focus-driven auto-hide (no timer) ───────────────────────────
    //
    // Module closes the instant focus leaves it. Sources of "cursor is
    // engaged with this module":
    //   _stripHovered    — BorderZone trigger strip is hovered.
    //   _stripDragOver   — drag (file/text) is over the strip.
    //   _slotHovered     — cursor is on the bg's painted rect OR any of
    //                      its 4 bridge gaps (published by WindowSlot to
    //                      manager.slotHover, gap-free via HoverHandler +
    //                      DropArea on each).
    //   _slotDragOver    — drag (file/text) is over the bg or its bridges
    //                      (kept separate so incomingDrag can use it).
    // _anyHovered = OR of all four. The moment it goes false, we hide.
    property int _interactionRail: -1
    property int _arrivalSeq: -1
    readonly property bool _stripHovered: _interactionRail >= 0
        ? (InteractionManager.stripHovered[_interactionRail] ?? false)
        : false
    readonly property bool _stripDragOver: _interactionRail >= 0
        ? (InteractionManager.stripDragOver[_interactionRail] ?? false)
        : false
    readonly property bool _slotHovered: _arrivalSeq >= 0
        ? (manager.slotHover[_arrivalSeq] ?? false)
        : false
    readonly property bool _slotDragOver: _arrivalSeq >= 0
        ? (manager.slotDragOver[_arrivalSeq] ?? false)
        : false

    // Reliable signal from inside StashContent (not blocked by Qt's
    // topmost-only hover event delivery).
    property bool _panelHovered: false
    property bool _panelDragging: false

    // incomingDrag is true any time a file/text drag is anywhere in the
    // module's input region (strip + bg + bridges). Keeps the drop-zone
    // chooser visible during the entire transit from strip to inner tile.
    readonly property bool incomingDrag: _stripDragOver || _slotDragOver || _panelDragging

    // Sticky strip engagement: when the strip's hover/drag drops, hold a
    // brief "still engaged" flag so the cursor has time to land on the
    // panel itself (whose HoverHandler/DropArea fire reliably via
    // notePanelHover / notePanelDragging from StashContent).
    property bool _stickyStripEngaged: false
    readonly property bool _rawStripEngaged: _stripHovered || _stripDragOver
    on_RawStripEngagedChanged: {
        if (_rawStripEngaged) {
            _stickyStripEngaged = true;
            stickyExitTimer.stop();
        } else {
            stickyExitTimer.restart();
        }
    }
    Timer {
        id: stickyExitTimer
        interval: 300
        repeat: false
        onTriggered: root._stickyStripEngaged = false
    }

    // _anyHovered = engaged on strip (with sticky grace) OR panel itself.
    // _panelHovered / _panelDragging come from StashContent — they're
    // reliable because they're on the same Item as Qt's hover delivery
    // target (no z-blocking from the strip).
    readonly property bool _anyHovered: _stickyStripEngaged
                                        || _slotHovered || _slotDragOver
                                        || _panelHovered || _panelDragging

    function notePanelHover(hovered)  { _panelHovered = hovered; }
    function notePanelDragging(active) { _panelDragging = active; }
    function noteIncomingDrag(active) { /* legacy stub */ }

    onStashVisibleChanged: {
        if (!stashVisible) {
            // Reset the hover stack so the next fresh hover on the strip
            // fires layer 0 (this module) again.
            if (_interactionRail >= 0)
                InteractionManager.resetCounter(_interactionRail);
        }
    }
    on_AnyHoveredChanged: {
        if (!stashVisible) return;
        if (_anyHovered) {
            transitGraceTimer.stop();
            return;
        }
        transitGraceTimer.restart();
    }

    Timer {
        id: transitGraceTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.stashVisible && !root._anyHovered)
                VisibilitiesManager.setVisibility(root.screen, "stash", false);
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

        // Register with InteractionManager on the rail derived from the
        // wrapper's anchors. Hover at layer 0 opens the panel; drop also
        // opens it (and incomingDrag tracks stripDragOver automatically).
        _interactionRail = manager.determineRailIndex(content);
        if (_interactionRail >= 0) {
            InteractionManager.registerHover(_interactionRail, 0, "stash", () => {
                VisibilitiesManager.setVisibility(root.screen, "stash", true);
            });
            InteractionManager.registerDrop(_interactionRail, "stash", () => {
                VisibilitiesManager.setVisibility(root.screen, "stash", true);
            });
        }

        refreshStash();
    }

    Component.onDestruction: {
        if (_interactionRail >= 0) {
            InteractionManager.unregisterHover(_interactionRail, "stash");
            InteractionManager.unregisterDrop(_interactionRail, "stash");
        }
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

    // Hover trigger replaced by BorderZone strips driven through
    // InteractionManager — see Component.onCompleted above.

    // ── Backend Loader: registers/unregisters the bg via manager ───
    Loader {
        active: root.stashVisible
        sourceComponent: Item {
            Component.onCompleted: {
                root._arrivalSeq = root.manager.requestBackground(root.content);
            }
            Component.onDestruction: {
                root.manager.removeBackground(root.content);
                root._arrivalSeq = -1;
            }
        }
    }
}
