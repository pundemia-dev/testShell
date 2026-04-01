import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.components.containers
import qs.services

LauncherModule {
    id: root

    moduleId: "Wallpapers"
    name: "Wallpaper Engine"
    description: "Manage backgrounds, themes, slideshows and history"
    icon: "\ue3f4"
    trigger: "wp"

    hasLeftPanel: false
    hasRightPanel: true

    // ── Dynamic sizing ──
    readonly property real imageScale: Config.launcher.carouselImageScale ?? 2.0
    readonly property int visibleItems: Config.launcher.carouselVisibleItems ?? 5
    readonly property real _baseCardW: 160 * imageScale
    readonly property real _baseCardH: _baseCardW * 0.5625
    readonly property real _panelPad: Appearance.padding.large

    customTotalWidth: Math.max(760, _baseCardW * (visibleItems - 1 + 0.6) + _panelPad * 2)
    customRightWidth: customTotalWidth
    customRightHeight: _baseCardH + _panelPad * 2

    // ==========================================
    // STATE
    // ==========================================
    property PathView carousel: null
    property bool isSettingsOpen: false

    property bool isCtrlPressed: false
    property bool isAltPressed: false
    property bool isShiftPressed: false
    property real _lastShortcutTick: 0

    function markShortcut() {
        _lastShortcutTick = Date.now();
    }

    property int visMode: 0 // 0 = Normal, 1 = Include Dot, 2 = Only Dot
    property string lastQuery: ""

    property string originalWallpaper: ""
    property bool isApplied: false

    property int _scrollDirection: 0
    property string _restorePath: ""
    property bool _scrollToCurrentOnLoad: false


    property string targetMonitor: "All"
    property string displayMode: "fill"
    property bool skipThemeGen: false
    property bool isMuted: false
    property real mediaVolume: 100
    property bool isPaused: false
    property string themeMode: "dark"
    property bool themeAuto: false
    property string themeVariant: "scheme-tonal-spot"
    property bool slideshowActive: false
    property real slideshowInterval: 900
    property bool gameMode: false

    readonly property var themeVariants:[
        "scheme-tonal-spot", "scheme-fidelity", "scheme-monochrome", "scheme-neutral",
        "scheme-vibrant", "scheme-expressive", "scheme-content", "scheme-rainbow", "scheme-fruit-salad"
    ]

    readonly property string walltoolBin: `${Quickshell.shellDir}/scripts/walltool/target/release/walltool`
    readonly property string wallpapersDir: Quickshell.env("PSHELL_WALLPAPERS_DIR") || `${Quickshell.env("XDG_PICTURES_DIR") || `${Quickshell.env("HOME")}/Pictures`}/Wallpapers`

    ListModel { id: galleryModel }

    // ==========================================
    // IPC — POOLED PROCESSES
    // ==========================================
    property var _firePool:[]
    property var _respPool:[]

    Component.onCompleted: {
        Qt.callLater(() => {
            for (let i = 0; i < 3; i++) {
                _firePool.push(_fireComp.createObject(root));
                _respPool.push(_respComp.createObject(root));
            }
        });
    }

    Component {
        id: _fireComp
        Process {}
    }

    Component {
        id: _respComp
        Process {
            property var callback: null
            property var chunks:[]

            stdout: SplitParser {
                splitMarker: ""
                onRead: data => chunks.push(data)
            }

            onStarted: chunks =[]

            onExited: (code) => {
                if (code === 0 && chunks.length > 0) {
                    try {
                        let parsed = JSON.parse(chunks.join(""));
                        if (callback) callback(parsed);
                    } catch (e) {
                        console.warn("[WP] JSON parse error:", e);
                    }
                }
                callback = null;
                running = false;
            }
        }
    }

    function sendIpc(args) {
        let proc = _firePool.find(p => !p.running);
        if (!proc) {
            proc = _fireComp.createObject(root);
            _firePool.push(proc);
        }
        proc.command =[root.walltoolBin, "--json"].concat(args);
        proc.running = true;
    }

    function sendIpcWithResponse(args, cb) {
        let proc = _respPool.find(p => !p.running);
        if (!proc) {
            proc = _respComp.createObject(root);
            _respPool.push(proc);
        }
        proc.callback = cb;
        proc.command =[root.walltoolBin, "--json"].concat(args);
        proc.running = true;
    }

    // ==========================================
    // BATCH MODEL LOADING
    // ==========================================
    function reloadModel() {
        let savedPath = root._restorePath || (carousel && carousel.currentIndex >= 0 && carousel.currentIndex < galleryModel.count ? galleryModel.get(carousel.currentIndex).path : "");
        let savedDirection = root._scrollDirection;
        let scrollToCurrent = root._scrollToCurrentOnLoad;

        root._restorePath = "";
        root._scrollToCurrentOnLoad = false;

        let args =["wallpaper", "search", lastQuery || "", "--limit", "0"];

        if (isAltPressed && !isCtrlPressed) args.push("--history");
        if (isShiftPressed && !isCtrlPressed) args.push("--favorites");
        if (visMode === 1) args.push("--include-dot");
        if (visMode === 2) args.push("--only-dot");

        sendIpcWithResponse(args, resp => {
            let entries = _extractSearchResults(resp);

            let newItems = entries.map(e => ({
                name: e.name || _fileNameFromPath(e.path),
                path: e.path || "",
                mediaType: e.media_type || "image",
                tags: (e.tags ||[]).join(", "),
                isFav: e.is_fav || false,
                removing: false
            }));

            galleryModel.clear();
            if (newItems.length > 0) {
                galleryModel.append(newItems);
            }

            Qt.callLater(() => {
                if (!carousel || galleryModel.count === 0) return;

                if (scrollToCurrent && root.originalWallpaper) {
                    let idx = _findIndexByPath(root.originalWallpaper);
                    carousel.currentIndex = Math.max(0, idx);
                } else if (savedPath) {
                    let idx = _findIndexByPath(savedPath);
                    carousel.currentIndex = idx >= 0 ? idx : _findNearestByOldPath(savedPath, savedDirection);
                } else {
                    carousel.currentIndex = 0;
                }
            });
        });
    }

    function _findIndexByPath(path) {
        if (!path) return -1;
        for (let i = 0; i < galleryModel.count; i++) {
            if (galleryModel.get(i).path === path) return i;
        }
        return -1;
    }

    function _findNearestByOldPath(oldPath, direction) {
        if (galleryModel.count === 0) return 0;
        let bestIdx = 0;
        let bestDist = Infinity;
        for (let i = 0; i < galleryModel.count; i++) {
            let p = galleryModel.get(i).path;
            let dist = Math.abs(p.localeCompare(oldPath));
            if (dist < bestDist) {
                bestDist = dist;
                bestIdx = i;
            }
        }
        if (direction > 0 && bestIdx + 1 < galleryModel.count) return Math.min(bestIdx, galleryModel.count - 1);
        if (direction < 0 && bestIdx > 0) return Math.max(bestIdx, 0);
        return bestIdx;
    }

    function _extractSearchResults(resp) {
        if (!resp) return[];
        if (resp.status === "Ok" && resp.data && resp.data.kind === "SearchResults") return resp.data.value ||[];
        if (Array.isArray(resp)) return resp;
        return[];
    }

    function _fileNameFromPath(path) {
        if (!path) return "";
        let fname = path.split("/").pop() || "";
        let dotIdx = fname.lastIndexOf(".");
        return dotIdx > 0 ? fname.substring(0, dotIdx) : fname;
    }

    function handleInput(query) {
        lastQuery = query;
        reloadDebounce.restart();
    }

    function onActivated(initialQuery) {
        isApplied = false;
        isCtrlPressed = false;
        isAltPressed = false;
        isShiftPressed = false;
        visMode = 0;
        _scrollDirection = 0;
        _restorePath = "";

        sendIpcWithResponse(["wallpaper", "current"], resp => {
            let states = (resp && resp.status === "Ok" && resp.data && resp.data.kind === "WallpaperState") ? resp.data.value || [] :[];
            if (states.length > 0 && states[0].path) root.originalWallpaper = states[0].path;
            root._scrollToCurrentOnLoad = true;
            lastQuery = initialQuery;
            reloadModel();
        });
    }

    function onDeactivated() {
        reloadDebounce.stop();
        modifierDebounce.stop();
        // previewDebounceTimer.stop();
        _scrollTier = 0;
        if (!isApplied && originalWallpaper !== "") {
            sendIpc(["wallpaper", "set", originalWallpaper, "--mode", displayMode]);
            originalWallpaper = "";
        }
    }

    function execute(query, isAlt) {
        if (isAlt) sendIpc(["wallpaper", "set", _currentItemPath(), "--mode", "span"]);
        isApplied = true;
        root.requestClose(true);
    }

    function livePreview(path) {
        if (!path) return;
        let args =["wallpaper", "set", path, "--mode", displayMode];
        // if (skipThemeGen) args.push("--no-theme");
        if (targetMonitor !== "All") args.push("--monitor", targetMonitor);
        if (isMuted) args.push("--mute");
        sendIpc(args);
    }

    function setRandom() {
        let args = ["wallpaper", "random", root.wallpapersDir];
        if (lastQuery) args.push("--query", lastQuery);
        if (visMode === 1) args.push("--include-dot");
        if (visMode === 2) args.push("--only-dot");
        args.push("--mode", displayMode);
        if (skipThemeGen) args.push("--no-theme");
        if (isMuted) args.push("--mute");

        sendIpcWithResponse(args, resp => {
            root.isApplied = true;
            let states = (resp && resp.status === "Ok" && resp.data && resp.data.kind === "WallpaperState") ? resp.data.value ||[] : [];
            if (states.length > 0 && states[0].path && carousel) {
                let idx = _findIndexByPath(states[0].path);
                if (idx >= 0) carousel.currentIndex = idx;
            }
        });
    }

    function toggleSettings() {
        isSettingsOpen = !isSettingsOpen;
    }

    // ── Navigation Throttling ──
    property bool _navThrottled: false
    property int _scrollTier: 0
    on_ScrollTierChanged: WallpaperState.transitionTier = _scrollTier
    property int _navStepCount: 0

    readonly property bool _isIdle: _scrollTier === 0
    readonly property bool _isActive: _scrollTier === 1
    readonly property bool _isRapid: _scrollTier === 2

    Timer {
        id: _navThrottle
        interval: root._isRapid ? 30 : root._isActive ? 60 : 100
        onTriggered: root._navThrottled = false
    }

    Timer {
            id: _tierDecay
            interval: root._isRapid ? 250 : 500
            repeat: true
            onTriggered: {
                let wasRapid = root._isRapid; // Запоминаем, были ли мы в быстрой прокрутке

                if (root._scrollTier > 0) root._scrollTier--;

                // Если только что вышли из режима быстрой прокрутки — применяем обои
                if (wasRapid && !root._isRapid) {
                    let p = root._currentItemPath();
                    if (p) root.livePreview(p);
                }

                if (root._scrollTier === 0) {
                    root._navStepCount = 0;
                    stop();
                }
            }
        }
    // Timer {
    //     id: _tierDecay
    //     interval: root._isRapid ? 250 : 500
    //     repeat: true
    //     onTriggered: {
    //         if (root._scrollTier > 0) root._scrollTier--;
    //         if (root._scrollTier === 0) {
    //             root._navStepCount = 0;
    //             stop();
    //             // if (!root.skipThemeGen) {
    //             //     let p = root._currentItemPath();
    //             //     if (p) root.livePreview(p);
    //             // }
    //         }
    //     }
    // }

    function _navStep(dir) {
        if (!carousel || _navThrottled) return;
        _navThrottled = true;
        _navThrottle.restart();
        _navStepCount++;

        if (_navStepCount >= 4) {
            _scrollTier = 2;
        } else if (_scrollTier < 1) {
            _scrollTier = 1;
        }

        _tierDecay.restart();
        root._scrollDirection = dir;

        if (dir < 0) carousel.decrementCurrentIndex();
        else carousel.incrementCurrentIndex();
    }

    function navigateUp() { _navStep(-1); }
    function navigateDown() { _navStep(1); }

    function cycleVisMode() {
        visMode = (visMode + 1) % 3;
        reloadDebounce.stop();
        modifierDebounce.stop();
        reloadModel();
    }

    function _currentItemPath() {
        if (!carousel || carousel.currentIndex < 0 || carousel.currentIndex >= galleryModel.count) return "";
        return galleryModel.get(carousel.currentIndex).path || "";
    }

    // ─── DEFERRED GARBAGE COLLECTION ───
    Timer {
        id: gcTimer
        interval: 600
        onTriggered: {
            let currentPath = root._currentItemPath();
            let removedAny = false;

            for (let i = galleryModel.count - 1; i >= 0; i--) {
                if (galleryModel.get(i).removing) {
                    galleryModel.remove(i);
                    removedAny = true;
                }
            }

            if (removedAny && carousel && currentPath) {
                let safeIdx = root._findIndexByPath(currentPath);
                if (safeIdx >= 0) carousel.currentIndex = safeIdx;
            }
        }
    }

    function _removeItemLocally(idx) {
        if (idx < 0 || idx >= galleryModel.count) return;

        galleryModel.setProperty(idx, "removing", true);

        let nextIdx = idx;
        if (root._scrollDirection >= 0) {
            nextIdx = Math.min(idx + 1, galleryModel.count - 1);
        } else {
            nextIdx = Math.max(idx - 1, 0);
        }

        if (carousel && nextIdx !== idx && galleryModel.count > 1) {
            carousel.currentIndex = nextIdx;
        }

        gcTimer.restart();
    }

    function modifyCurrentItem(action) {
        let idx = carousel ? carousel.currentIndex : -1;
        if (idx < 0 || idx >= galleryModel.count) return;
        let item = galleryModel.get(idx);

        if (item.removing) return;

        if (action === "fav_add") {
            galleryModel.setProperty(idx, "isFav", true);
            sendIpc(["wallpaper", "fav", "add", item.path]);
        } else if (action === "fav_rm") {
            if (root.isShiftPressed && !root.isCtrlPressed) {
                sendIpc(["wallpaper", "fav", "rm", item.path]);
                _removeItemLocally(idx);
            } else {
                galleryModel.setProperty(idx, "isFav", false);
                sendIpc(["wallpaper", "fav", "rm", item.path]);
            }
        } else if (action === "toggle_hidden") {
            sendIpc(["wallpaper", "toggle-hidden", item.path]);
            if (visMode === 1) _mutationReloadTimer.restart();
            else _removeItemLocally(idx);
        }
    }

    function toggleFavForIndex(idx) {
        if (idx < 0 || idx >= galleryModel.count) return;
        let item = galleryModel.get(idx);
        if (item.removing) return;

        if (item.isFav) {
            if (root.isShiftPressed && !root.isCtrlPressed) {
                sendIpc(["wallpaper", "fav", "rm", item.path]);
                _removeItemLocally(idx);
            } else {
                galleryModel.setProperty(idx, "isFav", false);
                sendIpc(["wallpaper", "fav", "rm", item.path]);
            }
        } else {
            galleryModel.setProperty(idx, "isFav", true);
            sendIpc(["wallpaper", "fav", "add", item.path]);
        }
    }

    function onModifierPressed(key) {
        if (key === Qt.Key_Control) {
            root.isCtrlPressed = true;
        } else if (key === Qt.Key_Alt && !root.isAltPressed) {
            root.isAltPressed = true;
            if (!root.isCtrlPressed) modifierDebounce.restart();
        } else if (key === Qt.Key_Shift && !root.isShiftPressed) {
            root.isShiftPressed = true;
            if (!root.isCtrlPressed) modifierDebounce.restart();
        }
    }

    function onModifierReleased(key) {
        if (key === Qt.Key_Control) {
            root.isCtrlPressed = false;
        } else if (key === Qt.Key_Alt && root.isAltPressed) {
            root.isAltPressed = false;
            modifierDebounce.restart();
        } else if (key === Qt.Key_Shift && root.isShiftPressed) {
            root.isShiftPressed = false;
            modifierDebounce.restart();
        }
    }

    // ==========================================
    // ТАЙМЕРЫ
    // ==========================================
    Timer {
        id: reloadDebounce
        interval: 120
        onTriggered: root.reloadModel()
    }

    Timer {
        id: modifierDebounce
        interval: 250
        onTriggered: {
            if (Date.now() - root._lastShortcutTick < 600) return;
            root.reloadModel();
        }
    }

    // Timer {
    //     id: previewDebounceTimer
    //     interval: root._isRapid ? 800 : root._isActive ? 500 : 400
    //     property string pendingPath: ""
    //     onTriggered: {
    //         if (pendingPath !== "") root.livePreview(pendingPath);
    //     }
    // }

    Timer {
        id: _mutationReloadTimer
        interval: 200
        onTriggered: root.reloadModel()
    }

    // ==========================================
    // UI EXTENSIONS
    // ==========================================
    inputExtensionComponent: Component {
        Item {
            implicitWidth: settingsBtn.implicitWidth
            implicitHeight: settingsBtn.implicitHeight

            IconButton {
                id: settingsBtn
                icon: "\ue8b8"
                type: IconButton.Tonal
                toggle: true
                checked: root.isSettingsOpen
                onClicked: root.toggleSettings()

                Tooltip { target: settingsBtn; text: "Settings (Ctrl+I)" }
            }
        }
    }

    shortcutsComponent: Component {
        Item {
            Shortcut {
                sequence: "Ctrl+I"
                onActivated: {
                    root.markShortcut();
                    root.toggleSettings();
                }
            }
            Shortcut {
                sequence: "Ctrl+M"
                onActivated: {
                    root.markShortcut();
                    root.themeMode = root.themeMode === "dark" ? "light" : "dark";
                    root.sendIpc(["theme", "mode", "set", root.themeMode]);
                }
            }
            Shortcut {
                sequence: "Ctrl+T"
                onActivated: {
                    root.markShortcut();
                    let idx = root.themeVariants.indexOf(root.themeVariant);
                    root.themeVariant = root.themeVariants[(idx + 1) % root.themeVariants.length];
                    root.sendIpc(["theme", "palette", "set", root.themeVariant]);
                }
            }
            Shortcut {
                sequence: "Ctrl+H"
                onActivated: {
                    root.markShortcut();
                    root.cycleVisMode();
                }
            }
            Shortcut {
                sequence: "Ctrl+R"
                onActivated: {
                    root.markShortcut();
                    root.setRandom();
                }
            }
            Shortcut {
                sequence: "Ctrl+Shift+A"
                onActivated: {
                    root.markShortcut();
                    root.modifyCurrentItem("fav_add");
                }
            }
            Shortcut {
                sequence: "Ctrl+Shift+D"
                onActivated: {
                    root.markShortcut();
                    root.modifyCurrentItem("fav_rm");
                }
            }
            Shortcut {
                sequence: "Ctrl+Shift+H"
                onActivated: {
                    root.markShortcut();
                    root.modifyCurrentItem("toggle_hidden");
                }
            }
            Shortcut {
                sequence: "Alt+Return"
                onActivated: {
                    root.markShortcut();
                    let p = root._currentItemPath();
                    if (p) {
                        root.sendIpc(["wallpaper", "set", p, "--mode", "span"]);
                        root.isApplied = true;
                        root.requestClose(true);
                    }
                }
            }
        }
    }

    rightPanelComponent: Component {
        Item {
            id: panelContainer
            anchors.fill: parent

            StyledRect {
                id: modBadge
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Appearance.padding.small
                z: 10

                color: Colours.alpha(Colours.palette.surface_container_highest, 0.9)
                border.width: 1
                border.color: Colours.alpha(Colours.palette.outline_variant, 0.5)
                radius: Appearance.rounding.full

                implicitWidth: badgeLayout.implicitWidth + Appearance.padding.large * 2
                implicitHeight: badgeLayout.implicitHeight + Appearance.padding.small * 2

                property bool shouldShow: (!root.isCtrlPressed && (root.isAltPressed || root.isShiftPressed)) || root.visMode > 0
                opacity: shouldShow ? 1.0 : 0.0
                scale: shouldShow ? 1.0 : 0.85
                visible: opacity > 0

                Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.small } }
                Behavior on scale { ScaleAnimator { duration: Appearance.anim.durations.small } }

                RowLayout {
                    id: badgeLayout
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.large

                    StyledIcon {
                        visible: root.isAltPressed && !root.isCtrlPressed
                        text: "\ue8b5"
                        color: Colours.palette.primary
                        font.pointSize: Appearance.font.size.large
                    }
                    StyledIcon {
                        visible: root.isShiftPressed && !root.isCtrlPressed
                        text: "\ue866"
                        color: Colours.palette.tertiary
                        font.pointSize: Appearance.font.size.large
                    }
                    StyledIcon {
                        visible: root.visMode > 0
                        text: root.visMode === 2 ? "\ue8f5" : "\ue8f4"
                        color: Colours.palette.on_surface
                        opacity: root.visMode === 1 ? 0.4 : 1.0
                        font.pointSize: Appearance.font.size.large
                    }
                }
            }

            ColumnLayout {
                id: emptyState
                anchors.centerIn: parent
                spacing: Appearance.spacing.normal
                z: 5

                property bool shouldShow: galleryModel.count === 0
                opacity: shouldShow ? 1.0 : 0.0
                scale: shouldShow ? 1.0 : 0.92
                visible: opacity > 0

                Behavior on opacity { OpacityAnimator {} }
                Behavior on scale { ScaleAnimator {} }

                StyledIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isShiftPressed ? "\ue866" : root.isAltPressed ? "\ue8b5" : root.visMode === 2 ? "\ue8f5" : "\ue8b6"
                    font.pointSize: Appearance.font.size.extraLarge * 2
                    color: Colours.alpha(Colours.palette.on_surface_variant, 0.3)
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isShiftPressed ? "No favorites yet" : root.isAltPressed ? "History is empty" : root.visMode === 2 ? "No hidden wallpapers" : "No wallpapers found"
                    font.pointSize: Appearance.font.size.large
                    color: Colours.palette.on_surface_variant
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isShiftPressed ? "Add wallpapers to favorites with Ctrl+Shift+A" : root.isAltPressed ? "Set a wallpaper first — it will appear here." : root.visMode === 2 ? "Hide wallpapers with Ctrl+Shift+H" : "Try changing filters or your search query."
                    font.pointSize: Appearance.font.size.small
                    color: Colours.alpha(Colours.palette.on_surface_variant, 0.6)
                }
            }

            Item {
                id: carouselContainer
                anchors.fill: parent
                anchors.topMargin: Appearance.padding.normal
                anchors.bottomMargin: Appearance.padding.normal
                clip: true

                readonly property real baseItemWidth: root._baseCardW
                readonly property real baseItemHeight: root._baseCardH

                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)) {
                            if (event.angleDelta.x < 0) root.navigateDown();
                            else root.navigateUp();
                        } else {
                            if (event.angleDelta.y < 0) root.navigateDown();
                            else root.navigateUp();
                        }
                        event.accepted = true;
                    }
                }

                PathView {
                    id: grid
                    Component.onCompleted: root.carousel = grid
                    Component.onDestruction: root.carousel = null
                    anchors.fill: parent
                    model: galleryModel
                    pathItemCount: root.visibleItems
                    cacheItemCount: 15

                    snapMode: PathView.SnapToItem
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    flickDeceleration: 2000
                    maximumFlickVelocity: 2500
                    interactive: true
                    dragMargin: carouselContainer.baseItemWidth * 0.4
                    highlightMoveDuration: root._isRapid ? 0 : root._isActive ? 150 : 350

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0 && currentIndex < count) {
                            let item = galleryModel.get(currentIndex);
                            if (item && !root._isRapid) root.livePreview(item.path); // ← сразу
                        }
                    }
                    // onCurrentIndexChanged: {
                    //     if (currentIndex >= 0 && currentIndex < count) {
                    //         let item = galleryModel.get(currentIndex);
                    //         if (item) {
                    //             previewDebounceTimer.pendingPath = item.path;
                    //             previewDebounceTimer.restart();
                    //         }
                    //     }
                    // }

                    delegate: Item {
                        id: cardDelegate
                        required property int index
                        required property string name
                        required property string path
                        required property string mediaType
                        required property string tags
                        required property bool isFav
                        required property bool removing

                        z: PathView.z ?? 0
                        implicitWidth: carouselContainer.baseItemWidth
                        implicitHeight: carouselContainer.baseItemHeight + Appearance.padding.small

                        readonly property real targetScale: (PathView.itemScale ?? 0.5)
                        readonly property real targetOpacity: (PathView.itemOpacity ?? 0.6)
                        readonly property bool isCenterCard: Math.abs(targetScale - 1.0) < 0.05

                        scale: targetScale
                        opacity: PathView.onPath ? targetOpacity : 0
                        visible: opacity > 0

                        Item {
                            id: transformContainer
                            anchors.fill: parent
                            transformOrigin: Item.Center

                            scale: 0.0
                            opacity: 0.0

                            Component.onCompleted: {
                                if (root._isRapid) {
                                    scale = 1.0;
                                    opacity = 1.0;
                                } else if (!cardDelegate.removing) {
                                    enterScaleAnim.restart();
                                    enterOpacityAnim.restart();
                                }
                            }

                            NumberAnimation {
                                id: enterScaleAnim
                                target: transformContainer
                                property: "scale"
                                to: 1.0
                                duration: Appearance.anim.durations.expressiveDefaultSpatial
                                easing.type: Easing.OutBack
                            }

                            NumberAnimation {
                                id: enterOpacityAnim
                                target: transformContainer
                                property: "opacity"
                                to: 1.0
                                duration: root._isIdle ? Appearance.anim.durations.normal : Appearance.anim.durations.smaller
                                easing.type: Easing.OutSine
                            }

                            NumberAnimation {
                                id: exitScaleAnim
                                target: transformContainer
                                property: "scale"
                                to: 0.0
                                duration: Appearance.anim.durations.expressiveDefaultSpatial
                            }

                            NumberAnimation {
                                id: exitOpacityAnim
                                target: transformContainer
                                property: "opacity"
                                to: 0.0
                                duration: Appearance.anim.durations.expressiveDefaultSpatial
                            }

                            Item {
                                id: cardContent
                                anchors.fill: parent

                                StyledClippingRect {
                                    id: imageClip
                                    anchors.fill: parent
                                    anchors.margins: Appearance.padding.small
                                    radius: Appearance.rounding.normal
                                    color: Colours.palette.surface_variant

                                    CachingImage {
                                        anchors.fill: parent
                                        path: cardDelegate.path
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: parent.height / 2
                                        opacity: cardDelegate.isCenterCard ? 1.0 : 0.4
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7) }
                                        }
                                    }

                                    Item {
                                        id: favArea
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        width: 40
                                        height: 40

                                        HoverHandler { id: favHover }

                                        StyledRect {
                                            id: favButton
                                            anchors.centerIn: parent
                                            width: 28
                                            height: 28
                                            radius: Appearance.rounding.full
                                            color: cardDelegate.isFav ? Colours.alpha(Colours.palette.tertiary_container, 0.9) : Colours.alpha(Colours.palette.surface, 0.7)
                                            opacity: cardDelegate.isFav || favHover.hovered ? 1.0 : 0.0
                                            visible: opacity > 0
                                            scale: cardDelegate.isFav || favHover.hovered ? 1.0 : 0.7

                                            Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.smaller } }
                                            Behavior on scale { ScaleAnimator { duration: Appearance.anim.durations.smaller; easing.type: Easing.OutBack } }

                                            StyledIcon {
                                                anchors.centerIn: parent
                                                text: cardDelegate.isFav ? "\ue866" : "\ue867"
                                                font.pointSize: Appearance.font.size.normal
                                                color: cardDelegate.isFav ? Colours.palette.tertiary : Colours.palette.on_surface
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.toggleFavForIndex(cardDelegate.index)
                                            }
                                        }
                                    }

                                    Loader {
                                        anchors.top: parent.top
                                        anchors.right: favArea.left
                                        anchors.topMargin: Appearance.padding.small
                                        anchors.rightMargin: 2
                                        active: cardDelegate.mediaType !== "image"

                                        sourceComponent: StyledRect {
                                            color: Colours.alpha(Colours.palette.tertiary_container, 0.9)
                                            radius: Appearance.rounding.small
                                            implicitWidth: badgeText.implicitWidth + Appearance.padding.small * 2
                                            implicitHeight: badgeText.implicitHeight + 2

                                            StyledText {
                                                id: badgeText
                                                anchors.centerIn: parent
                                                text: cardDelegate.mediaType === "video" ? "MP4" : (cardDelegate.mediaType === "gif" ? "GIF" : cardDelegate.mediaType.toUpperCase())
                                                font.pointSize: Appearance.font.size.smaller
                                                font.weight: Font.DemiBold
                                                color: Colours.palette.on_tertiary_container
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: Appearance.padding.normal
                                        spacing: 2
                                        opacity: cardDelegate.isCenterCard ? 1.0 : 0.0
                                        visible: opacity > 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: cardDelegate.name
                                            color: "white"
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: cardDelegate.tags || cardDelegate.path
                                            color: "lightgray"
                                            font.pointSize: Appearance.font.size.smaller
                                            elide: Text.ElideRight
                                        }
                                    }

                                    StateLayer {
                                        anchors.fill: parent
                                        radius: Appearance.rounding.normal
                                        function onClicked() { root.execute("", false); }
                                    }
                                }
                            }
                        }

                        onRemovingChanged: {
                            if (removing) {
                                exitScaleAnim.restart();
                                exitOpacityAnim.restart();
                            }
                        }
                    }

                    path: Path {
                        startX: 0
                        startY: grid.height / 2

                        PathAttribute { name: "itemScale"; value: 0.45 }
                        PathAttribute { name: "itemOpacity"; value: 0.4 }
                        PathAttribute { name: "z"; value: 0 }
                        PathLine { x: grid.width * 0.15; relativeY: 0 }

                        PathAttribute { name: "itemScale"; value: 0.68 }
                        PathAttribute { name: "itemOpacity"; value: 0.6 }
                        PathAttribute { name: "z"; value: 1 }
                        PathLine { x: grid.width * 0.32; relativeY: 0 }

                        PathAttribute { name: "itemScale"; value: 0.84 }
                        PathAttribute { name: "itemOpacity"; value: 0.8 }
                        PathAttribute { name: "z"; value: 2 }
                        PathLine { x: grid.width * 0.5; relativeY: 0 }

                        PathAttribute { name: "itemScale"; value: 1.0 }
                        PathAttribute { name: "itemOpacity"; value: 1.0 }
                        PathAttribute { name: "z"; value: 3 }
                        PathLine { x: grid.width * 0.68; relativeY: 0 }

                        PathAttribute { name: "itemScale"; value: 0.84 }
                        PathAttribute { name: "itemOpacity"; value: 0.8 }
                        PathAttribute { name: "z"; value: 2 }
                        PathLine { x: grid.width * 0.85; relativeY: 0 }

                        PathAttribute { name: "itemScale"; value: 0.68 }
                        PathAttribute { name: "itemOpacity"; value: 0.6 }
                        PathAttribute { name: "z"; value: 1 }
                        PathLine { x: grid.width; relativeY: 0 }

                        PathAttribute { name: "itemScale"; value: 0.45 }
                        PathAttribute { name: "itemOpacity"; value: 0.4 }
                        PathAttribute { name: "z"; value: 0 }
                    }
                }
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 4
                text: "Hold[Alt]: History  •  Hold [Shift]: Favorites  •  [Ctrl+H]: Dot-files  •  [←→]: Navigate"
                font.pointSize: Appearance.font.size.smaller
                color: Colours.alpha(Colours.palette.on_surface_variant, 0.5)
                z: 5
            }

            // ── ОВЕРЛЕЙ НАСТРОЕК ──
            StyledRect {
                id: settingsOverlay
                anchors.bottom: parent.bottom
                anchors.right: parent.right

                // Уменьшены отступы к краям модуля
                anchors.bottomMargin: Appearance.padding.smaller
                anchors.rightMargin: Appearance.padding.smaller
                z: 20

                // Ширина - ровно половина окна модуля (минимум 380)
                width: Math.max(380, Math.floor(parent.width * 0.5))
                height: parent.height - (Appearance.padding.smaller * 2)
                radius: Appearance.rounding.large

                color: Colours.alpha(Colours.palette.surface_container_highest, 0.98)
                border.width: 1
                border.color: Colours.alpha(Colours.palette.outline_variant, 0.5)

                transformOrigin: Item.BottomRight
                scale: root.isSettingsOpen ? 1.0 : 0.8
                opacity: root.isSettingsOpen ? 1.0 : 0.0
                visible: opacity > 0

                Behavior on scale { ScaleAnimator { duration: Appearance.anim.durations.small; easing.type: Easing.OutBack } }
                Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.small } }

                StyledFlickable {
                    id: settingsScroll
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    contentWidth: width
                    contentHeight: settingsCol.height
                    clip: true

                    ColumnLayout {
                        id: settingsCol
                        width: parent.width
                        spacing: Appearance.spacing.small

                        ConnectionHeader {
                            Layout.fillWidth: true
                            icon: "\ue8b8"
                            title: "Wallpaper Engine"
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "Display & Apply"
                            expanded: true

                            // ИСПРАВЛЕНИЕ: Используем полноценные компоненты MenuItem для совместимости с Menu.qml
                            SplitButtonRow {
                                label: "Monitor"
                                menuItems:[
                                    MenuItem {
                                        text: "All"
                                        icon: "desktop_windows"
                                        property string val: "All"
                                    },
                                    MenuItem {
                                        text: "DP-1"
                                        icon: "monitor"
                                        property string val: "DP-1"
                                    }
                                ]
                                Component.onCompleted: {
                                    for(let i=0; i < menuItems.length; i++) {
                                        if(menuItems[i].val === root.targetMonitor) active = menuItems[i];
                                    }
                                }
                                onSelected: item => root.targetMonitor = item.val
                            }

                            SplitButtonRow {
                                label: "Mode"
                                menuItems:[
                                    MenuItem {
                                        text: "Fill"
                                        icon: "aspect_ratio"
                                        property string val: "fill"
                                    },
                                    MenuItem {
                                        text: "Span"
                                        icon: "panorama"
                                        property string val: "span"
                                    },
                                    MenuItem {
                                        text: "Fit"
                                        icon: "crop_free"
                                        property string val: "fit"
                                    },
                                    MenuItem {
                                        text: "Center"
                                        icon: "center_focus_strong"
                                        property string val: "center"
                                    }
                                ]
                                Component.onCompleted: {
                                    for(let i=0; i < menuItems.length; i++) {
                                        if(menuItems[i].val === root.displayMode) active = menuItems[i];
                                    }
                                }
                                onSelected: item => root.displayMode = item.val
                            }

                            SwitchRow {
                                label: "Skip Theme Gen"
                                checked: root.skipThemeGen
                                onToggled: function() { root.skipThemeGen = !root.skipThemeGen }
                            }
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "Carousel"
                            expanded: false

                            SpinBoxRow {
                                label: "Visible Items"
                                value: root.visibleItems
                                min: 3
                                max: 9
                                step: 2
                                onValueModified: v => console.log("[WP] carouselVisibleItems should be set in config:", v)
                            }
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "Media & Playback"
                            expanded: false

                            SwitchRow {
                                label: "Mute Audio"
                                checked: root.isMuted
                                onToggled: function() {
                                    root.isMuted = !root.isMuted;
                                    root.sendIpc(["wallpaper", "toggle-mute"]);
                                }
                            }

                            SpinBoxRow {
                                label: "Volume (%)"
                                value: root.mediaVolume
                                min: 0
                                max: 100
                                step: 5
                                onValueModified: v => root.mediaVolume = v
                            }

                            SwitchRow {
                                label: "Pause Media"
                                checked: root.isPaused
                                onToggled: function() {
                                    root.isPaused = !root.isPaused;
                                    root.sendIpc(root.isPaused ?["wallpaper", "pause"] : ["wallpaper", "play"]);
                                }
                            }
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "Theme (Matugen)"
                            expanded: false

                            PropertyRow { label: "Theme Mode (Ctrl+M)"; value: root.themeMode }

                            SwitchRow {
                                label: "Auto Time-of-Day"
                                checked: root.themeAuto
                                onToggled: function() {
                                    root.themeAuto = !root.themeAuto;
                                    if (root.themeAuto) root.sendIpc(["theme", "mode", "auto"]);
                                }
                            }

                            PropertyRow { label: "Palette (Ctrl+T)"; value: root.themeVariant }
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "Slideshow"
                            expanded: false

                            SwitchRow {
                                label: "Active"
                                checked: root.slideshowActive
                                onToggled: function() {
                                    root.slideshowActive = !root.slideshowActive;
                                    if (root.slideshowActive) {
                                        root.sendIpc(["daemon", "slideshow", "start", root.wallpapersDir, "-i", String(Math.round(root.slideshowInterval))]);
                                    } else {
                                        root.sendIpc(["daemon", "slideshow", "stop"]);
                                    }
                                }
                            }

                            SpinBoxRow {
                                label: "Interval (Sec)"
                                value: root.slideshowInterval
                                min: 10
                                max: 86400
                                step: 60
                                onValueModified: v => root.slideshowInterval = v
                            }
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "System & Shortcuts"
                            expanded: false

                            SwitchRow {
                                label: "Game Mode (Pause All)"
                                checked: root.gameMode
                                onToggled: function() {
                                    root.gameMode = !root.gameMode;
                                    root.sendIpc(root.gameMode ?["daemon", "pause-all"] : ["daemon", "resume-all"]);
                                }
                            }

                            PropertyRow { label: "Ctrl+H"; value: "Cycle Hidden Files mode" }
                            PropertyRow { label: "Ctrl+R"; value: "Set Random (matches filters)" }
                            PropertyRow { label: "Shift (Hold)"; value: "View Favorites" }
                            PropertyRow { label: "Ctrl+Shift+A / D"; value: "Add/Remove Favorite" }
                            PropertyRow { label: "Ctrl+Shift+H"; value: "Toggle Hidden state" }
                            PropertyRow { label: "Alt+Enter"; value: "Apply in Span mode" }
                            PropertyRow { label: "Enter / Esc"; value: "Apply / Revert" }
                        }

                        Item { Layout.preferredHeight: Appearance.padding.larger }
                    }
                }

                StyledScrollBar {
                    flickable: settingsScroll
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
            }
        }
    }
}
