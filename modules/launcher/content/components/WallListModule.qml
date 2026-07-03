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
import qs.modules.launcher.content.components

LauncherModule {
    id: root

    moduleId: "Wallpapers"
    name: "Wallpaper Engine"
    description: "Manage backgrounds, themes, slideshows and history"
    icon: "\ue3f4"
    trigger: "wp"

    hasLeftPanel: false
    hasRightPanel: true

    // ── Orientation ──
    property bool isVertical: false

    // ── Sizing ──
    readonly property real imageScale:    Config.launcher.carouselImageScale   ?? 2.0
    readonly property int  visibleItems:  Config.launcher.carouselVisibleItems ?? 5
    readonly property real _baseCardW:    160 * imageScale
    readonly property real _baseCardH:    _baseCardW * 0.5625
    readonly property real _panelPad:     Appearance.padding.large
    readonly property real _settingsWidth:  800
    readonly property real _settingsHeight: 540

    readonly property real _carouselWidth: isVertical
        ? _baseCardW + _panelPad * 2
        : Math.max(760, _baseCardW * (visibleItems - 1 + 0.6) + _panelPad * 2)
    readonly property real _carouselHeight: isVertical
        ? _baseCardH * (visibleItems - 1 + 0.6) + _panelPad * 2
        : _baseCardH + _panelPad * 2

    customTotalWidth:  isSettingsOpen ? _settingsWidth  : _carouselWidth
    customRightWidth:  isSettingsOpen ? _settingsWidth  : _carouselWidth
    customRightHeight: isSettingsOpen ? _settingsHeight : _carouselHeight

    Behavior on customTotalWidth  { NumberAnimation { duration: Appearance.anim.durations.normal; easing.type: Easing.OutCubic } }
    Behavior on customRightWidth  { NumberAnimation { duration: Appearance.anim.durations.normal; easing.type: Easing.OutCubic } }
    Behavior on customRightHeight { NumberAnimation { duration: Appearance.anim.durations.normal; easing.type: Easing.OutCubic } }

    property bool needsOverflow: isSettingsOpen

    // ══════════════════════════════════════════════════════════════════════════════
    //  STATE
    // ══════════════════════════════════════════════════════════════════════════════
    property PathView carousel: null
    property bool isSettingsOpen: false
    property int  settingsTabIndex: 0

    property bool isCtrlPressed:  false
    property bool isAltPressed:   false
    property bool isShiftPressed: false
    property real _lastShortcutTick: 0
    function markShortcut() { _lastShortcutTick = Date.now(); }

    property int    visMode:     0   // 0=Normal 1=IncludeDot 2=OnlyDot
    property string lastQuery:   ""
    property string originalWallpaper: ""
    property bool   isApplied:   false
    property bool   _isInitialLoad: false
    property int    _scrollDirection: 0
    property string _restorePath: ""
    property bool   _scrollToCurrentOnLoad: false

    // ── Runtime wallpaper state ──
    property string targetMonitor:   "All"
    property bool   skipThemeGen:    false
    property bool   slideshowActive: false
    property bool   gameMode:        false

    // ── Display settings (awww.defaults — persisted to config.toml) ──
    property string resizeMode:        "crop"
    property string fillColor:         "000000ff"
    property string imageFilter:       "Lanczos3"
    property string transitionType:    "simple"
    property real   transitionDuration: 3.0
    property int    transitionFps:     30
    property int    transitionStep:    2
    property real   transitionAngle:   45.0
    property string transitionPos:     "center"
    property string transitionBezier:  ".54,0,.34,.99"
    property string transitionWave:    "20,20"
    property bool   transitionInvertY: false
    property string awwwNamespace:     ""

    // ── Per-monitor overrides (loaded from config.toml) ──
    property var monitorConfigs: []   // [{monitor, options:{resize,...}}]

    // ── Theme settings (matugen — dual: runtime th set + persistent cfg set-matugen-default) ──
    property string themeMode:         "dark"
    property string themeSchemeType:   "scheme-tonal-spot"
    property real   themeContrast:     0.0
    property int    themeColorIndex:   0
    property string themePrefer:       "saturation"
    property string themeFallbackColor: ""
    property real   themeOpacity:      1.0
    property real   themeLightnessDark:  0.0
    property real   themeLightnessLight: 0.0
    property bool   themeAutoEnabled:  false

    // ── Theme auto schedule (config.toml [theme.auto]) ──
    property string themeAutoSunrise: "07:00"
    property string themeAutoSunset:  "19:00"

    // ── Gallery ──
    property string indexDir:   wallpapersDir
    property bool   indexForce: false
    property string sortBy:    "score"
    property bool   sortReverse: false
    property int    historyCount:   0
    property int    favoritesCount: 0

    // ── Indexer (config.toml [indexer]) ──
    property var    watchDirs:  []    // string[]
    property bool   aiTagging:  false
    property string newWatchDir: ""

    // ── Slideshow ──
    property real   slideshowInterval:      900
    property string slideshowDir:           wallpapersDir
    property bool   slideshowIncludeHidden: false
    property bool   slideshowOnlyHidden:    false
    property bool   slideshowOnlyFavorites: false
    property string slideshowTextFilter:    ""

    // ── System ──
    property string daemonStatus:  "unknown"
    property real   daemonUptime:  0
    property real   daemonMemory:  0
    property bool   indexingActive: false
    property int    indexQueueSize: 0
    property bool   previewActive:  false
    property var    monitorsList:  []
    property var    profilesList:  []
    property string currentProfile: ""
    property string configFullText: ""

    // ── Enums ──
    readonly property var themeVariants: [
        "scheme-tonal-spot","scheme-fidelity","scheme-monochrome","scheme-neutral",
        "scheme-vibrant","scheme-expressive","scheme-content","scheme-rainbow","scheme-fruit-salad"
    ]
    readonly property var resizeModes:    ["crop","fit","stretch","no"]
    readonly property var imageFilters:   ["Nearest","Bilinear","CatmullRom","Mitchell","Lanczos3"]
    readonly property var transitionTypes:["none","simple","fade","left","right","top","bottom","wipe","wave","grow","center","any","outer","random"]
    readonly property var sortFields:     ["score","time","name","color"]
    readonly property var colorPrefs:     ["darkness","lightness","saturation","less-saturation","value","closest-to-fallback"]

    readonly property string walltoolBin: `${Quickshell.shellDir}/scripts/walltool/target/release/walltool`
    readonly property string wallpapersDir: Quickshell.env("PSHELL_WALLPAPERS_DIR")
        || `${Quickshell.env("XDG_PICTURES_DIR") || `${Quickshell.env("HOME")}/Pictures`}/Wallpapers`

    ListModel { id: galleryModel }

    // ══════════════════════════════════════════════════════════════════════════════
    //  IPC — POOLED PROCESSES
    // ══════════════════════════════════════════════════════════════════════════════
    property var _firePool: []
    property var _respPool: []

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
            property var chunks: []
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => chunks.push(data)
            }
            onStarted: chunks = []
            onExited: (code) => {
                if (code === 0 && chunks.length > 0) {
                    try {
                        let parsed = JSON.parse(chunks.join(""));
                        if (callback) callback(parsed);
                    } catch (e) { console.warn("[WP] JSON parse error:", e); }
                }
                callback = null;
                running = false;
            }
        }
    }

    function sendIpc(args) {
        let proc = _firePool.find(p => !p.running);
        if (!proc) { proc = _fireComp.createObject(root); _firePool.push(proc); }
        proc.command = [root.walltoolBin, "--json"].concat(args);
        proc.running = true;
    }

    function sendIpcWithResponse(args, cb) {
        let proc = _respPool.find(p => !p.running);
        if (!proc) { proc = _respComp.createObject(root); _respPool.push(proc); }
        proc.callback = cb;
        proc.command = [root.walltoolBin, "--json"].concat(args);
        proc.running = true;
    }

    // ── Config helpers ──

    // Save one awww.defaults key to config AND update runtime state
    function saveAwwwDefault(key, value) {
        sendIpc(["config", "set-awww-default", key, String(value)]);
    }

    // Save one matugen.defaults key to config.toml (persistent)
    function saveMatugenDefault(key, value) {
        sendIpc(["config", "set-matugen-default", key, String(value)]);
    }

    // Save one matugen param runtime (th set) AND persist to config
    function setThemeParam(key, value) {
        sendIpc(["theme", "set", key, String(value)]);
        saveMatugenDefault(key, String(value));
    }

    // Save slideshow config key
    function saveSlideshowConfig(key, value) {
        sendIpc(["config", "set-slideshow", key, String(value)]);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  GALLERY MODEL
    // ══════════════════════════════════════════════════════════════════════════════
    function reloadModel() {
        let savedPath = root._restorePath || (carousel && carousel.currentIndex >= 0 && carousel.currentIndex < galleryModel.count ? galleryModel.get(carousel.currentIndex).path : "");
        let savedDirection = root._scrollDirection;
        let scrollToCurrent = root._scrollToCurrentOnLoad || root._isInitialLoad;
        let currentOriginal = root.originalWallpaper;

        root._restorePath = "";
        root._scrollToCurrentOnLoad = false;

        let args = ["wallpaper", "search", lastQuery || "", "--limit", "0"];
        if (isAltPressed && !isCtrlPressed)   args.push("--history");
        if (isShiftPressed && !isCtrlPressed) args.push("--favorites");
        if (visMode === 1) args.push("--include-dot");
        if (visMode === 2) args.push("--only-dot");

        sendIpcWithResponse(args, resp => {
            let entries = _extractSearchResults(resp);
            let newItems = entries.map(e => ({
                name:      e.name || _fileNameFromPath(e.path),
                path:      e.path || "",
                mediaType: e.media_type || "image",
                tags:      (e.tags || []).join(", "),
                isFav:     e.is_fav || false,
                removing:  false
            }));

            galleryModel.clear();
            if (newItems.length > 0) galleryModel.append(newItems);
            if (root._isInitialLoad) root._isInitialLoad = false;

            Qt.callLater(() => {
                if (!carousel || galleryModel.count === 0) return;
                let targetIdx = 0;
                if (scrollToCurrent && currentOriginal) {
                    let idx = _findIndexByPath(currentOriginal);
                    targetIdx = idx >= 0 ? idx : 0;
                } else if (savedPath) {
                    let idx = _findIndexByPath(savedPath);
                    targetIdx = idx >= 0 ? idx : _findNearestByOldPath(savedPath, savedDirection);
                }
                scrollTimer.targetIndex = targetIdx;
                scrollTimer.restart();
            });
        });
    }

    function _findIndexByPath(path) {
        if (!path) return -1;
        for (let i = 0; i < galleryModel.count; i++)
            if (galleryModel.get(i).path === path) return i;
        return -1;
    }

    function _findNearestByOldPath(oldPath, direction) {
        if (galleryModel.count === 0) return 0;
        let bestIdx = 0, bestDist = Infinity;
        for (let i = 0; i < galleryModel.count; i++) {
            let dist = Math.abs(galleryModel.get(i).path.localeCompare(oldPath));
            if (dist < bestDist) { bestDist = dist; bestIdx = i; }
        }
        return bestIdx;
    }

    function _extractSearchResults(resp) {
        if (!resp) return [];
        if (resp.status === "Ok" && resp.data && resp.data.kind === "SearchResults")
            return resp.data.value || [];
        if (Array.isArray(resp)) return resp;
        return [];
    }

    function _fileNameFromPath(path) {
        if (!path) return "";
        let fname = path.split("/").pop() || "";
        let dotIdx = fname.lastIndexOf(".");
        return dotIdx > 0 ? fname.substring(0, dotIdx) : fname;
    }

    Timer {
        id: scrollTimer
        interval: 50; repeat: false
        property int targetIndex: 0
        onTriggered: {
            if (carousel && galleryModel.count > 0) {
                carousel.currentIndex = targetIndex;
                carousel.positionViewAtIndex(targetIndex, PathView.Center);
            }
        }
    }

    Timer {
        id: themeDebounce
        interval: 300; repeat: false
        onTriggered: {
            if (root.originalWallpaper)
                root.sendIpc(["theme", "generate", root.originalWallpaper]);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  MODULE LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════════
    function handleInput(query) {
        lastQuery = query;
        reloadDebounce.restart();
    }

    function onActivated(initialQuery) {
        isApplied = false;
        isCtrlPressed = isAltPressed = isShiftPressed = false;
        visMode = 0;
        _scrollDirection = 0;
        _restorePath = "";
        _isInitialLoad = true;

        sendIpcWithResponse(["wallpaper", "search", "", "--limit", "1"], countResp => {
            let wallpapers = _extractSearchResults(countResp);
            if (wallpapers.length === 0) {
                sendIpcWithResponse(["wallpaper", "index", root.wallpapersDir], _ => {
                    loadCurrentAndModel(initialQuery);
                });
            } else {
                loadCurrentAndModel(initialQuery);
            }
        });
    }

    function loadCurrentAndModel(initialQuery) {
        sendIpcWithResponse(["wallpaper", "history", "list", "--limit", "1"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let entries = resp.data.value || [];
                if (Array.isArray(entries) && entries.length > 0 && entries[0].path)
                    root.originalWallpaper = entries[0].path;
            }
            root._scrollToCurrentOnLoad = true;
            lastQuery = initialQuery;
            reloadModel();
        });
    }

    function onDeactivated() {
        reloadDebounce.stop();
        _isInitialLoad = false;
        modifierDebounce.stop();
        _scrollTier = 0;
        if (!isApplied) sendIpc(["wallpaper", "preview", "stop"]);
        originalWallpaper = "";
    }

    function execute(query, isAlt) {
        sendIpc(["wallpaper", "preview", "commit"]);
        if (isAlt) sendIpc(["wallpaper", "set", _currentItemPath(), "--resize", "stretch"]);
        isApplied = true;
        root.requestClose(true);
    }

    function livePreview(path) {
        if (!path) return;
        let args = ["wallpaper", "preview", "start", path, "--transition-type", "none"];
        if (targetMonitor !== "All") args.push("--outputs", targetMonitor);
        sendIpc(args);
    }

    function setRandom() {
        let args = ["wallpaper", "random", root.wallpapersDir];
        if (lastQuery)   args.push("--query", lastQuery);
        if (visMode === 1) args.push("--include-dot");
        if (visMode === 2) args.push("--only-dot");
        if (skipThemeGen)  args.push("--no-theme");
        sendIpcWithResponse(args, resp => {
            root.isApplied = true;
            if (resp?.status === "Ok") {
                sendIpcWithResponse(["wallpaper", "history", "list", "--limit", "1"], histResp => {
                    if (histResp?.status === "Ok" && histResp.data) {
                        let e = histResp.data.value || [];
                        if (Array.isArray(e) && e.length > 0 && e[0].path) {
                            root.originalWallpaper = e[0].path;
                            root._scrollToCurrentOnLoad = true;
                        }
                    }
                    root.reloadModel();
                });
            }
        });
    }

    function toggleSettings() {
        isSettingsOpen = !isSettingsOpen;
        if (isSettingsOpen) fetchDaemonData();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  FETCH ALL DAEMON / CONFIG STATE
    // ══════════════════════════════════════════════════════════════════════════════
    function fetchDaemonData() {
        // Daemon status
        sendIpcWithResponse(["daemon", "status"], resp => {
            if (resp?.status === "Ok") {
                root.daemonStatus = "running";
                let s = resp.data?.value || resp.data || {};
                if (s.slideshow_active !== undefined) root.slideshowActive  = s.slideshow_active;
                if (s.game_mode        !== undefined) root.gameMode         = s.game_mode;
                if (s.uptime_secs      !== undefined) root.daemonUptime     = s.uptime_secs;
                if (s.memory_mb        !== undefined) root.daemonMemory     = s.memory_mb;
                if (s.indexing         !== undefined) root.indexingActive   = s.indexing;
                if (s.index_queue_size !== undefined) root.indexQueueSize   = s.index_queue_size;
                if (s.preview_active   !== undefined) root.previewActive    = s.preview_active;
            } else {
                root.daemonStatus = "stopped";
            }
        });

        // Runtime theme state
        sendIpcWithResponse(["theme", "get"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let t = resp.data.value || resp.data || {};
                if (t.mode)               root.themeMode        = t.mode;
                if (t.scheme_type)        root.themeSchemeType  = t.scheme_type;
                if (t.contrast            !== undefined) root.themeContrast      = t.contrast ?? 0.0;
                if (t.source_color_index  !== undefined) root.themeColorIndex    = t.source_color_index ?? 0;
                if (t.prefer)             root.themePrefer      = t.prefer;
                if (t.fallback_color)     root.themeFallbackColor = t.fallback_color;
                if (t.opacity             !== undefined) root.themeOpacity       = t.opacity ?? 1.0;
                if (t.lightness_dark      !== undefined) root.themeLightnessDark = t.lightness_dark ?? 0.0;
                if (t.lightness_light     !== undefined) root.themeLightnessLight = t.lightness_light ?? 0.0;
            }
        });

        // awww defaults from config.toml
        sendIpcWithResponse(["config", "get-awww-defaults"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let o = resp.data.value || resp.data || {};
                if (o.resize)              root.resizeMode        = o.resize;
                if (o.fill_color)          root.fillColor         = o.fill_color;
                if (o.filter)              root.imageFilter       = o.filter;
                if (o.transition_type)     root.transitionType    = o.transition_type;
                if (o.transition_duration !== undefined) root.transitionDuration = o.transition_duration;
                if (o.transition_fps      !== undefined) root.transitionFps      = o.transition_fps;
                if (o.transition_step     !== undefined) root.transitionStep     = o.transition_step;
                if (o.transition_angle    !== undefined) root.transitionAngle    = o.transition_angle;
                if (o.transition_pos)      root.transitionPos     = o.transition_pos;
                if (o.transition_bezier)   root.transitionBezier  = o.transition_bezier;
                if (o.transition_wave)     root.transitionWave    = o.transition_wave;
                if (o.invert_y            !== undefined) root.transitionInvertY  = o.invert_y;
            }
        });

        // awww namespace from config
        sendIpcWithResponse(["config", "get-namespace"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let v = resp.data.value || "";
                root.awwwNamespace = (v === "(not set)") ? "" : v;
            }
        });

        // Matugen defaults from config.toml
        sendIpcWithResponse(["config", "get-matugen-defaults"], resp => {
            // ThemeParams response — same shape as theme get
            // Already handled by theme get above; this is for config-persisted values
        });

        // Theme auto schedule
        sendIpcWithResponse(["config", "get-theme-auto"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let a = resp.data.value || resp.data || {};
                if (a.sunrise) root.themeAutoSunrise = a.sunrise;
                if (a.sunset)  root.themeAutoSunset  = a.sunset;
            }
        });

        // Indexer config
        sendIpcWithResponse(["config", "get-indexer"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let i = resp.data.value || resp.data || {};
                if (Array.isArray(i.watch_dirs)) root.watchDirs = i.watch_dirs;
                if (i.ai_tagging !== undefined)  root.aiTagging = i.ai_tagging;
            }
        });

        // Per-monitor configs
        sendIpcWithResponse(["config", "list-monitors"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let entries = resp.data.value || [];
                if (Array.isArray(entries)) root.monitorConfigs = entries;
            }
        });

        // Slideshow options
        sendIpcWithResponse(["config", "get-slideshow"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let o = resp.data.value || resp.data || {};
                if (o.dir)                         root.slideshowDir            = o.dir;
                if (o.interval           !== undefined) root.slideshowInterval       = o.interval;
                if (o.include_hidden     !== undefined) root.slideshowIncludeHidden  = o.include_hidden;
                if (o.only_hidden        !== undefined) root.slideshowOnlyHidden     = o.only_hidden;
                if (o.only_favorites     !== undefined) root.slideshowOnlyFavorites  = o.only_favorites;
                if (o.text_filter)                 root.slideshowTextFilter     = o.text_filter;
            }
        });

        // Monitors list
        sendIpcWithResponse(["monitor", "list"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let m = resp.data.value || [];
                if (Array.isArray(m)) root.monitorsList = m;
            }
        });

        // Profiles list
        sendIpcWithResponse(["config", "profile", "list"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let p = resp.data.value || [];
                if (Array.isArray(p)) root.profilesList = p;
            }
        });

        // History count
        sendIpcWithResponse(["wallpaper", "history", "list", "--limit", "1000"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let e = resp.data.value || [];
                root.historyCount = Array.isArray(e) ? e.length : 0;
            }
        });

        // Favorites count
        sendIpcWithResponse(["wallpaper", "fav", "list", "--limit", "1000"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                let e = resp.data.value || [];
                root.favoritesCount = Array.isArray(e) ? e.length : 0;
            }
        });

        // Full config TOML for display
        sendIpcWithResponse(["config", "show"], resp => {
            if (resp?.status === "Ok" && resp.data) {
                root.configFullText = resp.data.value || "";
            }
        });
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  NAVIGATION THROTTLE
    // ══════════════════════════════════════════════════════════════════════════════
    property bool _navThrottled: false
    property int  _scrollTier:   0
    property int  _navStepCount: 0
    on_ScrollTierChanged: WallpaperState.transitionTier = _scrollTier

    readonly property bool _isIdle:   _scrollTier === 0
    readonly property bool _isActive: _scrollTier === 1
    readonly property bool _isRapid:  _scrollTier === 2

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
            let wasRapid = root._isRapid;
            if (root._scrollTier > 0) root._scrollTier--;
            if (wasRapid && !root._isRapid) {
                let p = root._currentItemPath();
                if (p) root.livePreview(p);
            }
            if (root._scrollTier === 0) { root._navStepCount = 0; stop(); }
        }
    }

    function _navStep(dir) {
        if (!carousel || _navThrottled) return;
        _navThrottled = true;
        _navThrottle.restart();
        _navStepCount++;
        if (_navStepCount >= 4) _scrollTier = 2;
        else if (_scrollTier < 1) _scrollTier = 1;
        _tierDecay.restart();
        root._scrollDirection = dir;
        if (dir < 0) carousel.decrementCurrentIndex();
        else         carousel.incrementCurrentIndex();
    }

    function navigateUp()   { _navStep(-1); }
    function navigateDown() { _navStep(1);  }
    function cycleVisMode() {
        visMode = (visMode + 1) % 3;
        reloadDebounce.stop(); modifierDebounce.stop();
        reloadModel();
    }
    function _currentItemPath() {
        if (!carousel || carousel.currentIndex < 0 || carousel.currentIndex >= galleryModel.count) return "";
        return galleryModel.get(carousel.currentIndex).path || "";
    }

    // ── Item mutation ──
    Timer {
        id: gcTimer; interval: 600
        onTriggered: {
            let cur = root._currentItemPath();
            let removed = false;
            for (let i = galleryModel.count - 1; i >= 0; i--) {
                if (galleryModel.get(i).removing) { galleryModel.remove(i); removed = true; }
            }
            if (removed && carousel && cur) {
                let idx = root._findIndexByPath(cur);
                if (idx >= 0) carousel.currentIndex = idx;
            }
        }
    }

    function _removeItemLocally(idx) {
        if (idx < 0 || idx >= galleryModel.count) return;
        galleryModel.setProperty(idx, "removing", true);
        let next = root._scrollDirection >= 0
            ? Math.min(idx + 1, galleryModel.count - 1)
            : Math.max(idx - 1, 0);
        if (carousel && next !== idx && galleryModel.count > 1) carousel.currentIndex = next;
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
            if (visMode === 1) _mutationReload.restart();
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
        if (key === Qt.Key_Control) { root.isCtrlPressed = true; }
        else if (key === Qt.Key_Alt   && !root.isAltPressed)   { root.isAltPressed   = true; if (!root.isCtrlPressed) modifierDebounce.restart(); }
        else if (key === Qt.Key_Shift && !root.isShiftPressed) { root.isShiftPressed = true; if (!root.isCtrlPressed) modifierDebounce.restart(); }
    }
    function onModifierReleased(key) {
        if (key === Qt.Key_Control) { root.isCtrlPressed = false; }
        else if (key === Qt.Key_Alt   && root.isAltPressed)   { root.isAltPressed   = false; modifierDebounce.restart(); }
        else if (key === Qt.Key_Shift && root.isShiftPressed) { root.isShiftPressed = false; modifierDebounce.restart(); }
    }

    Timer { id: reloadDebounce; interval: 120; onTriggered: root.reloadModel() }
    Timer { id: modifierDebounce; interval: 250; onTriggered: { if (Date.now() - root._lastShortcutTick < 600) return; root.reloadModel(); } }
    Timer { id: _mutationReload; interval: 200; onTriggered: root.reloadModel() }

    // ══════════════════════════════════════════════════════════════════════════════
    //  EXTENSIONS
    // ══════════════════════════════════════════════════════════════════════════════
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
            Shortcut { sequence: "Ctrl+I";         onActivated: { root.markShortcut(); root.toggleSettings(); } }
            Shortcut { sequence: "Ctrl+M";         onActivated: { root.markShortcut(); root.sendIpc(["theme","mode","toggle"]); root.fetchDaemonData(); } }
            Shortcut { sequence: "Ctrl+T";         onActivated: {
                root.markShortcut();
                let idx = root.themeVariants.indexOf(root.themeSchemeType);
                let next = root.themeVariants[(idx + 1) % root.themeVariants.length];
                root.sendIpc(["theme","palette","set",next]);
                Qt.callLater(() => root.fetchDaemonData());
            }}
            Shortcut { sequence: "Ctrl+H";         onActivated: { root.markShortcut(); root.cycleVisMode(); } }
            Shortcut { sequence: "Ctrl+R";         onActivated: { root.markShortcut(); root.setRandom(); } }
            Shortcut { sequence: "Ctrl+Shift+A";   onActivated: { root.markShortcut(); root.modifyCurrentItem("fav_add"); } }
            Shortcut { sequence: "Ctrl+Shift+D";   onActivated: { root.markShortcut(); root.modifyCurrentItem("fav_rm"); } }
            Shortcut { sequence: "Ctrl+Shift+H";   onActivated: { root.markShortcut(); root.modifyCurrentItem("toggle_hidden"); } }
            Shortcut { sequence: "Ctrl+G";         onActivated: { root.markShortcut(); root.gameMode = !root.gameMode; root.sendIpc(root.gameMode ? ["daemon","pause-all"] : ["daemon","resume-all"]); } }
            Shortcut { sequence: "Ctrl+[";         onActivated: { root.markShortcut(); root.sendIpcWithResponse(["wallpaper","history","prev"], resp => { if (resp?.status==="Ok") { root.isApplied=true; root.reloadModel(); } }); } }
            Shortcut { sequence: "Ctrl+]";         onActivated: { root.markShortcut(); root.sendIpcWithResponse(["wallpaper","history","next"], resp => { if (resp?.status==="Ok") { root.isApplied=true; root.reloadModel(); } }); } }
            Shortcut { sequence: "Alt+Return";     onActivated: { root.markShortcut(); let p = root._currentItemPath(); if (p) { root.sendIpc(["wallpaper","set",p,"--resize","stretch"]); root.isApplied=true; root.requestClose(true); } } }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  RIGHT PANEL
    // ══════════════════════════════════════════════════════════════════════════════
    rightPanelComponent: Component {
        Item {
            id: panelContainer
            anchors.fill: parent

            // ── Modifier badge ──
            StyledRect {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Appearance.padding.small
                z: 10
                color: Colours.alpha(Colours.palette.surface_container_highest, 0.9)
                border.width: 1; border.color: Colours.alpha(Colours.palette.outline_variant, 0.5)
                radius: Appearance.rounding.full
                implicitWidth: _badgeRow.implicitWidth + Appearance.padding.large * 2
                implicitHeight: _badgeRow.implicitHeight + Appearance.padding.small * 2
                property bool shouldShow: (!root.isCtrlPressed && (root.isAltPressed || root.isShiftPressed)) || root.visMode > 0
                opacity: shouldShow ? 1.0 : 0.0; scale: shouldShow ? 1.0 : 0.85; visible: opacity > 0
                Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.small } }
                Behavior on scale   { ScaleAnimator   { duration: Appearance.anim.durations.small } }
                RowLayout {
                    id: _badgeRow; anchors.centerIn: parent; spacing: Appearance.spacing.large
                    StyledIcon { visible: root.isAltPressed && !root.isCtrlPressed;  text: "\ue8b5"; color: Colours.palette.primary;     font.pointSize: Appearance.font.size.large }
                    StyledIcon { visible: root.isShiftPressed && !root.isCtrlPressed; text: "\ue866"; color: Colours.palette.tertiary;    font.pointSize: Appearance.font.size.large }
                    StyledIcon { visible: root.visMode > 0; text: root.visMode === 2 ? "\ue8f5" : "\ue8f4"; color: Colours.palette.on_surface; opacity: root.visMode===1?0.4:1.0; font.pointSize: Appearance.font.size.large }
                }
            }

            // ── Empty state ──
            ColumnLayout {
                anchors.centerIn: parent; spacing: Appearance.spacing.medium; z: 5
                property bool shouldShow: galleryModel.count === 0
                opacity: shouldShow ? 1.0 : 0.0; scale: shouldShow ? 1.0 : 0.92; visible: opacity > 0
                Behavior on opacity {
                    OpacityAnimator {}
                }
                Behavior on scale { ScaleAnimator {} }
                StyledIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isShiftPressed?"\ue866":root.isAltPressed?"\ue8b5":root.visMode===2?"\ue8f5":"\ue8b6"
                    font.pointSize: Appearance.font.size.extraLarge*2
                    color: Colours.alpha(Colours.palette.on_surface_variant,0.3)
                }
                StyledText  {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isShiftPressed?"No favorites yet":root.isAltPressed?"History is empty":root.visMode===2?"No hidden wallpapers":"No wallpapers found"
                    font.pointSize: Appearance.font.size.large
                    color: Colours.palette.on_surface_variant
                }
                StyledText  {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isShiftPressed?"Add with Ctrl+Shift+A":root.isAltPressed?"Set a wallpaper first":root.visMode===2?"Hide with Ctrl+Shift+H":"Try changing filters or query"
                    font.pointSize: Appearance.font.size.small
                    color: Colours.alpha(Colours.palette.on_surface_variant,0.6)
                }
            }

            // ── Carousel ──
            Item {
                id: carouselContainer
                anchors.fill: parent
                anchors.topMargin: Appearance.padding.medium
                anchors.bottomMargin: Appearance.padding.medium
                clip: true

                readonly property real baseItemWidth:  root._baseCardW
                readonly property real baseItemHeight: root._baseCardH
                readonly property bool showNavButtons: galleryModel.count > 1 && !root.isSettingsOpen

                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        let primary   = root.isVertical ? event.angleDelta.y : event.angleDelta.x;
                        let secondary = root.isVertical ? event.angleDelta.x : event.angleDelta.y;
                        if (Math.abs(primary) > Math.abs(secondary)) {
                            if (primary < 0) root.navigateDown(); else root.navigateUp();
                        } else {
                            if (secondary < 0) root.navigateDown(); else root.navigateUp();
                        }
                        event.accepted = true;
                    }
                }

                // prev button
                Item {
                    id: navPrevBtn; z: 10; visible: carouselContainer.showNavButtons
                    anchors.left: root.isVertical?undefined:parent.left; anchors.top: root.isVertical?parent.top:undefined
                    anchors.verticalCenter: root.isVertical?undefined:parent.verticalCenter
                    anchors.horizontalCenter: root.isVertical?parent.horizontalCenter:undefined
                    anchors.leftMargin: root.isVertical?0:Appearance.padding.small
                    anchors.topMargin:  root.isVertical?Appearance.padding.small:0
                    width: _prevBtn.width; height: _prevBtn.height
                    property bool hovered: _prevHov.hovered
                    IconButton {
                        id: _prevBtn; anchors.centerIn: parent
                        icon: root.isVertical?"\ue5c7":"\ue5c4"
                        type: IconButton.Tonal
                        opacity: navPrevBtn.hovered?1.0:0.4
                        Behavior on opacity {
                            OpacityAnimator {
                                duration: Appearance.anim.durations.smaller
                            }
                        }
                        onClicked: root.navigateUp()
                    }
                    HoverHandler { id: _prevHov }
                    Tooltip {
                        target: navPrevBtn
                        text: root.isVertical?"Previous (↑)":"Previous (←)"
                    }
                }

                // next button
                Item {
                    id: navNextBtn; z: 10; visible: carouselContainer.showNavButtons
                    anchors.right: root.isVertical?undefined:parent.right; anchors.bottom: root.isVertical?parent.bottom:undefined
                    anchors.verticalCenter: root.isVertical?undefined:parent.verticalCenter
                    anchors.horizontalCenter: root.isVertical?parent.horizontalCenter:undefined
                    anchors.rightMargin:  root.isVertical?0:Appearance.padding.small
                    anchors.bottomMargin: root.isVertical?Appearance.padding.small:0
                    width: _nextBtn.width; height: _nextBtn.height
                    property bool hovered: _nextHov.hovered
                    IconButton {
                        id: _nextBtn; anchors.centerIn: parent
                        icon: root.isVertical?"\ue5c5":"\ue5c8"
                        type: IconButton.Tonal; opacity: navNextBtn.hovered?1.0:0.4
                        Behavior on opacity {
                            OpacityAnimator {
                                duration: Appearance.anim.durations.smaller
                            }
                        }
                        onClicked: root.navigateDown()
                    }
                    HoverHandler { id: _nextHov }
                    Tooltip {
                        target: navNextBtn
                        text: root.isVertical?"Next (↓)":"Next (→)"
                    }
                }

                PathView {
                    id: grid
                    Component.onCompleted:  root.carousel = grid
                    Component.onDestruction: root.carousel = null
                    anchors.fill: parent
                    model: galleryModel
                    pathItemCount: root.visibleItems
                    cacheItemCount: 15
                    snapMode: PathView.SnapToItem
                    preferredHighlightBegin: 0.5; preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    flickDeceleration: 2000; maximumFlickVelocity: 2500
                    interactive: true; dragMargin: carouselContainer.baseItemWidth * 0.4
                    highlightMoveDuration: root._isRapid ? 0 : root._isActive ? 150 : 350

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0 && currentIndex < count) {
                            let item = galleryModel.get(currentIndex);
                            if (item && !root._isRapid) root.livePreview(item.path);
                        }
                    }

                    delegate: Item {
                        id: cardDelegate
                        required property int    index
                        required property string name
                        required property string path
                        required property string mediaType
                        required property string tags
                        required property bool   isFav
                        required property bool   removing

                        z: PathView.z ?? 0
                        implicitWidth:  carouselContainer.baseItemWidth
                        implicitHeight: carouselContainer.baseItemHeight + Appearance.padding.small

                        readonly property real targetScale:   PathView.itemScale  ?? 0.5
                        readonly property real targetOpacity: PathView.itemOpacity ?? 0.6
                        readonly property bool isCenterCard:  Math.abs(targetScale - 1.0) < 0.05

                        scale: targetScale; opacity: PathView.onPath ? targetOpacity : 0; visible: opacity > 0

                        Item {
                            id: transformContainer; anchors.fill: parent; transformOrigin: Item.Center
                            scale: 0.0; opacity: 0.0
                            Component.onCompleted: {
                                if (root._isRapid) { scale = 1.0; opacity = 1.0; }
                                else if (!cardDelegate.removing) { enterScaleAnim.restart(); enterOpacityAnim.restart(); }
                            }
                            NumberAnimation { id: enterScaleAnim;   target: transformContainer; property: "scale";   to: 1.0; duration: Appearance.anim.durations.expressiveDefaultSpatial; easing.type: Easing.OutBack }
                            NumberAnimation { id: enterOpacityAnim; target: transformContainer; property: "opacity"; to: 1.0; duration: root._isIdle?Appearance.anim.durations.normal:Appearance.anim.durations.smaller; easing.type: Easing.OutSine }
                            NumberAnimation { id: exitScaleAnim;    target: transformContainer; property: "scale";   to: 0.0; duration: Appearance.anim.durations.expressiveDefaultSpatial }
                            NumberAnimation { id: exitOpacityAnim;  target: transformContainer; property: "opacity"; to: 0.0; duration: Appearance.anim.durations.expressiveDefaultSpatial }

                            StyledClippingRect {
                                anchors.fill: parent; anchors.margins: Appearance.padding.small
                                radius: Appearance.rounding.large; color: Colours.palette.surface_variant

                                CachingImage { anchors.fill: parent; path: cardDelegate.path; asynchronous: true }

                                Rectangle {
                                    anchors.bottom: parent.bottom; width: parent.width; height: parent.height/2
                                    opacity: cardDelegate.isCenterCard?1.0:0.4
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.7) }
                                    }
                                }

                                // Fav button
                                Item {
                                    id: favArea; anchors.top: parent.top; anchors.right: parent.right; width: 40; height: 40
                                    HoverHandler { id: favHov }
                                    StyledRect {
                                        anchors.centerIn: parent; width: 28; height: 28; radius: Appearance.rounding.full
                                        color: cardDelegate.isFav ? Colours.alpha(Colours.palette.tertiary_container,0.9) : Colours.alpha(Colours.palette.surface,0.7)
                                        opacity: cardDelegate.isFav || favHov.hovered ? 1.0 : 0.0; visible: opacity>0
                                        scale: cardDelegate.isFav || favHov.hovered ? 1.0 : 0.7
                                        Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.smaller } }
                                        Behavior on scale   { ScaleAnimator   { duration: Appearance.anim.durations.smaller; easing.type: Easing.OutBack } }
                                        StyledIcon { anchors.centerIn: parent; text: cardDelegate.isFav?"\ue866":"\ue867"; font.pointSize: Appearance.font.size.normal; color: cardDelegate.isFav?Colours.palette.tertiary:Colours.palette.on_surface }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleFavForIndex(cardDelegate.index) }
                                    }
                                }

                                // Media type badge
                                Loader {
                                    anchors.top: parent.top; anchors.right: favArea.left; anchors.topMargin: Appearance.padding.small; anchors.rightMargin: 2
                                    active: cardDelegate.mediaType !== "image"
                                    sourceComponent: StyledRect {
                                        color: Colours.alpha(Colours.palette.tertiary_container,0.9); radius: Appearance.rounding.small
                                        implicitWidth: _badgeTxt.implicitWidth + Appearance.padding.small*2; implicitHeight: _badgeTxt.implicitHeight + 2
                                        StyledText { id: _badgeTxt; anchors.centerIn: parent; text: cardDelegate.mediaType==="video"?"MP4":cardDelegate.mediaType==="gif"?"GIF":cardDelegate.mediaType.toUpperCase(); font.pointSize: Appearance.font.size.smaller; font.weight: Font.DemiBold; color: Colours.palette.on_tertiary_container }
                                    }
                                }

                                // Title
                                ColumnLayout {
                                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: Appearance.padding.medium; spacing: 2
                                    opacity: cardDelegate.isCenterCard?1.0:0.0; visible: opacity>0
                                    StyledText { Layout.fillWidth: true; text: cardDelegate.name; color: "white"; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    StyledText { Layout.fillWidth: true; text: cardDelegate.tags||cardDelegate.path; color: "lightgray"; font.pointSize: Appearance.font.size.smaller; elide: Text.ElideRight }
                                }

                                StateLayer { anchors.fill: parent; radius: Appearance.rounding.large; function onClicked() { root.execute("",false); } }
                            }
                        }

                        onRemovingChanged: { if (removing) { exitScaleAnim.restart(); exitOpacityAnim.restart(); } }
                    }

                    path: root.isVertical ? _vertPath : _horizPath

                    Path {
                        id: _horizPath; startX: 0; startY: grid.height/2
                        PathAttribute{name:"itemScale";value:0.45} PathAttribute{name:"itemOpacity";value:0.4} PathAttribute{name:"z";value:0}
                        PathLine{x:grid.width*0.15;relativeY:0}
                        PathAttribute{name:"itemScale";value:0.68} PathAttribute{name:"itemOpacity";value:0.6} PathAttribute{name:"z";value:1}
                        PathLine{x:grid.width*0.32;relativeY:0}
                        PathAttribute{name:"itemScale";value:0.84} PathAttribute{name:"itemOpacity";value:0.8} PathAttribute{name:"z";value:2}
                        PathLine{x:grid.width*0.5;relativeY:0}
                        PathAttribute{name:"itemScale";value:1.0}  PathAttribute{name:"itemOpacity";value:1.0} PathAttribute{name:"z";value:3}
                        PathLine{x:grid.width*0.68;relativeY:0}
                        PathAttribute{name:"itemScale";value:0.84} PathAttribute{name:"itemOpacity";value:0.8} PathAttribute{name:"z";value:2}
                        PathLine{x:grid.width*0.85;relativeY:0}
                        PathAttribute{name:"itemScale";value:0.68} PathAttribute{name:"itemOpacity";value:0.6} PathAttribute{name:"z";value:1}
                        PathLine{x:grid.width;relativeY:0}
                        PathAttribute{name:"itemScale";value:0.45} PathAttribute{name:"itemOpacity";value:0.4} PathAttribute{name:"z";value:0}
                    }

                    Path {
                        id: _vertPath; startX: grid.width/2; startY: 0
                        PathAttribute{name:"itemScale";value:0.45} PathAttribute{name:"itemOpacity";value:0.4} PathAttribute{name:"z";value:0}
                        PathLine{relativeX:0;y:grid.height*0.15}
                        PathAttribute{name:"itemScale";value:0.68} PathAttribute{name:"itemOpacity";value:0.6} PathAttribute{name:"z";value:1}
                        PathLine{relativeX:0;y:grid.height*0.32}
                        PathAttribute{name:"itemScale";value:0.84} PathAttribute{name:"itemOpacity";value:0.8} PathAttribute{name:"z";value:2}
                        PathLine{relativeX:0;y:grid.height*0.5}
                        PathAttribute{name:"itemScale";value:1.0}  PathAttribute{name:"itemOpacity";value:1.0} PathAttribute{name:"z";value:3}
                        PathLine{relativeX:0;y:grid.height*0.68}
                        PathAttribute{name:"itemScale";value:0.84} PathAttribute{name:"itemOpacity";value:0.8} PathAttribute{name:"z";value:2}
                        PathLine{relativeX:0;y:grid.height*0.85}
                        PathAttribute{name:"itemScale";value:0.68} PathAttribute{name:"itemOpacity";value:0.6} PathAttribute{name:"z";value:1}
                        PathLine{relativeX:0;y:grid.height}
                        PathAttribute{name:"itemScale";value:0.45} PathAttribute{name:"itemOpacity";value:0.4} PathAttribute{name:"z";value:0}
                    }
                }
            }

            // Hint
            StyledText {
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 4
                text: "Hold[Alt]: History  •  Hold[Shift]: Favorites  •  [Ctrl+H]: Dot-files  •  [←→]: Navigate"
                font.pointSize: Appearance.font.size.smaller; color: Colours.alpha(Colours.palette.on_surface_variant, 0.5); z: 5
            }

            // ══════════════════════════════════════════════════════════════════════════════
            //  SETTINGS PANEL
            // ══════════════════════════════════════════════════════════════════════════════
            StyledRect {
                id: settingsOverlay
                anchors.fill: parent; z: 20
                color: Colours.palette.surface_container; radius: Appearance.rounding.large
                opacity: root.isSettingsOpen ? 1.0 : 0.0; visible: opacity > 0
                Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.normal } }

                MouseArea { anchors.fill: parent; enabled: root.isSettingsOpen; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }

                RowLayout {
                    anchors.fill: parent; spacing: 0

                    // ── Navigation Rail ──
                    StyledRect {
                        Layout.fillHeight: true; Layout.preferredWidth: 72
                        color: Colours.palette.surface_container_low; radius: Appearance.rounding.large

                        ColumnLayout {
                            anchors.fill: parent; anchors.topMargin: Appearance.padding.medium; anchors.bottomMargin: Appearance.padding.medium; spacing: Appearance.spacing.small

                            Repeater {
                                model: [
                                    { icon: "\ue30d", label: "Display",   index: 0 },
                                    { icon: "\ue40a", label: "Theme",     index: 1 },
                                    { icon: "\ue3b6", label: "Gallery",   index: 2 },
                                    { icon: "\ue41b", label: "Slideshow", index: 3 },
                                    { icon: "\ue8b8", label: "System",    index: 4 },
                                    { icon: "\ue312", label: "Keys",      index: 5 }
                                ]
                                delegate: Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 56
                                    property bool isActive: root.settingsTabIndex === modelData.index
                                    StyledRect {
                                        anchors.centerIn: parent; width: 56; height: 48; radius: Appearance.rounding.full
                                        color: parent.isActive ? Colours.palette.secondary_container : _navHov.hovered ? Colours.alpha(Colours.palette.on_surface,0.08) : "transparent"
                                        Behavior on color { ColorAnimation { duration: Appearance.anim.durations.smaller } }
                                        ColumnLayout { anchors.centerIn: parent; spacing: 2
                                            StyledIcon { Layout.alignment: Qt.AlignHCenter; text: modelData.icon; font.pointSize: Appearance.font.size.large; color: parent.parent.parent.parent.isActive?Colours.palette.on_secondary_container:Colours.palette.on_surface_variant }
                                            StyledText  { Layout.alignment: Qt.AlignHCenter; text: modelData.label; font.pointSize: Appearance.font.size.smaller; font.weight: parent.parent.parent.parent.isActive?Font.DemiBold:Font.Normal; color: parent.parent.parent.parent.isActive?Colours.palette.on_secondary_container:Colours.palette.on_surface_variant }
                                        }
                                        HoverHandler { id: _navHov }
                                        TapHandler { onTapped: root.settingsTabIndex = modelData.index }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // ── Content ──
                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

                        StackLayout {
                            anchors.fill: parent; anchors.margins: Appearance.padding.medium
                            currentIndex: root.settingsTabIndex

                            // ════════════════════════════════════════════════════════════
                            //  TAB 0: Display
                            // ════════════════════════════════════════════════════════════
                            StyledFlickable {
                                id: displayScroll; contentWidth: width; contentHeight: displayCol.height; clip: true
                                ColumnLayout {
                                    id: displayCol; width: parent.width; spacing: Appearance.spacing.small

                                    SectionHeader { title: "Target" }

                                    SplitButtonRow {
                                        label: "Monitor"
                                        menuItems: {
                                            let items = [Qt.createQmlObject('import qs.components.controls; MenuItem { text:"All"; icon:"desktop_windows"; property string val:"All" }', displayCol)];
                                            for (let m of root.monitorsList) {
                                                let n = m.name || m;
                                                items.push(Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${n}"; icon:"monitor"; property string val:"${n}" }`, displayCol));
                                            }
                                            return items;
                                        }
                                        Component.onCompleted: {
                                            for (let i = 0; i < menuItems.length; i++)
                                                if (menuItems[i].val === root.targetMonitor) { active = menuItems[i]; break; }
                                        }
                                        onSelected: item => root.targetMonitor = item.val
                                    }

                                    SwitchRow {
                                        label: "Skip theme generation"
                                        checked: root.skipThemeGen
                                        onToggled: function() { root.skipThemeGen = !root.skipThemeGen; }
                                    }

                                    SectionHeader { title: "awww Namespace" }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        StyledText { text: "Namespace"; color: Colours.palette.on_surface }
                                        Item { Layout.fillWidth: true }
                                        StyledTextField {
                                            Layout.preferredWidth: 200
                                            text: root.awwwNamespace
                                            placeholderText: "(default)"
                                            onEditingFinished: {
                                                root.awwwNamespace = text;
                                                root.sendIpc(["config", "set-namespace", text || "null"]);
                                            }
                                        }
                                    }

                                    SectionHeader { title: "Resize" }

                                    SplitButtonRow {
                                        label: "Mode"
                                        menuItems: root.resizeModes.map(m => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${m[0].toUpperCase()+m.slice(1)}"; property string val:"${m}" }`, displayCol))
                                        Component.onCompleted: {
                                            for (let i = 0; i < menuItems.length; i++)
                                                if (menuItems[i].val === root.resizeMode) { active = menuItems[i]; break; }
                                        }
                                        onSelected: item => { root.resizeMode = item.val; root.saveAwwwDefault("resize", item.val); }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        StyledText { text: "Fill Color"; color: Colours.palette.on_surface }
                                        Item { Layout.fillWidth: true }
                                        Rectangle { width:24; height:24; radius:4; color:"#"+root.fillColor.substring(0,6); border.width:1; border.color:Colours.palette.outline }
                                        StyledTextField {
                                            Layout.preferredWidth: 110; text: root.fillColor
                                            onEditingFinished: {
                                                let c = text.replace(/[^0-9a-fA-F]/g,"");
                                                if (c.length >= 6) { let n = c.substring(0,8).padEnd(8,"f"); root.fillColor = n; root.saveAwwwDefault("fill_color", n); }
                                            }
                                        }
                                    }

                                    SplitButtonRow {
                                        label: "Filter"
                                        menuItems: root.imageFilters.map(f => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${f}"; property string val:"${f}" }`, displayCol))
                                        Component.onCompleted: {
                                            for (let i = 0; i < menuItems.length; i++)
                                                if (menuItems[i].val === root.imageFilter) { active = menuItems[i]; break; }
                                        }
                                        onSelected: item => { root.imageFilter = item.val; root.saveAwwwDefault("filter", item.val); }
                                    }

                                    // Transition
                                    CollapsibleSection {
                                        Layout.fillWidth: true; title: "Transition"; expanded: false

                                        SplitButtonRow {
                                            label: "Type"
                                            menuItems: root.transitionTypes.map(t => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${t}"; property string val:"${t}" }`, displayCol))
                                            Component.onCompleted: {
                                                for (let i = 0; i < menuItems.length; i++)
                                                    if (menuItems[i].val === root.transitionType) { active = menuItems[i]; break; }
                                            }
                                            onSelected: item => { root.transitionType = item.val; root.saveAwwwDefault("transition_type", item.val); }
                                        }

                                        SpinBoxRow { label:"Duration (s)"; value: root.transitionDuration; min:0.1; max:10; step:0.1; onValueModified: v => { root.transitionDuration=v; root.saveAwwwDefault("transition_duration",v); } }
                                        SpinBoxRow { label:"FPS";           value: root.transitionFps;      min:10;  max:144; step:5;  onValueModified: v => { root.transitionFps=v;      root.saveAwwwDefault("transition_fps",v); } }
                                        SpinBoxRow { visible: root.transitionType==="simple"; label:"Step (1-255)"; value:root.transitionStep; min:1; max:255; step:1; onValueModified: v => { root.transitionStep=v; root.saveAwwwDefault("transition_step",v); } }
                                        SpinBoxRow { visible: root.transitionType==="wipe"||root.transitionType==="wave"; label:"Angle (°)"; value:root.transitionAngle; min:0; max:360; step:15; onValueModified: v => { root.transitionAngle=v; root.saveAwwwDefault("transition_angle",v); } }

                                        RowLayout {
                                            visible: root.transitionType==="grow"||root.transitionType==="outer"||root.transitionType==="any"
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Position"; color:Colours.palette.on_surface }
                                            Item { Layout.fillWidth: true }
                                            StyledTextField { Layout.preferredWidth:120; text:root.transitionPos; onEditingFinished: { root.transitionPos=text; root.saveAwwwDefault("transition_pos",text); } }
                                        }
                                        RowLayout {
                                            visible: root.transitionType==="fade"
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Bezier"; color:Colours.palette.on_surface }
                                            Item { Layout.fillWidth: true }
                                            StyledTextField { Layout.preferredWidth:150; text:root.transitionBezier; onEditingFinished: { root.transitionBezier=text; root.saveAwwwDefault("transition_bezier",text); } }
                                        }
                                        RowLayout {
                                            visible: root.transitionType==="wave"
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Wave (W,H)"; color:Colours.palette.on_surface }
                                            Item { Layout.fillWidth: true }
                                            StyledTextField { Layout.preferredWidth:80; text:root.transitionWave; onEditingFinished: { root.transitionWave=text; root.saveAwwwDefault("transition_wave",text); } }
                                        }
                                        SwitchRow {
                                            visible: root.transitionType==="grow"||root.transitionType==="outer"||root.transitionType==="any"
                                            label:"Invert Y"; checked:root.transitionInvertY
                                            onToggled: function() { root.transitionInvertY=!root.transitionInvertY; root.saveAwwwDefault("invert_y",root.transitionInvertY); }
                                        }
                                    }

                                    // Per-monitor overrides
                                    CollapsibleSection {
                                        Layout.fillWidth: true; title: "Per-monitor Overrides"; expanded: false

                                        Repeater {
                                            model: root.monitorConfigs
                                            delegate: RowLayout {
                                                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                                StyledText { text: modelData.monitor; font.weight: Font.DemiBold; color: Colours.palette.primary }
                                                StyledText {
                                                    Layout.fillWidth: true; elide: Text.ElideRight
                                                    color: Colours.palette.on_surface_variant
                                                    text: {
                                                        let o = modelData.options || {};
                                                        let parts = [];
                                                        if (o.resize)          parts.push("resize:"+o.resize);
                                                        if (o.transition_type) parts.push("tr:"+o.transition_type);
                                                        if (o.filter)          parts.push("filter:"+o.filter);
                                                        return parts.join("  ") || "(no overrides)";
                                                    }
                                                }
                                                IconButton {
                                                    icon: "\ue872"; type: IconButton.Tonal
                                                    onClicked: {
                                                        let mon = modelData.monitor;
                                                        root.sendIpc(["config","rm-monitor",mon]);
                                                        root.sendIpcWithResponse(["config","list-monitors"], resp => {
                                                            if (resp?.status==="Ok" && resp.data) root.monitorConfigs = resp.data.value || [];
                                                        });
                                                    }
                                                    Tooltip { target: parent; text: "Remove "+modelData.monitor+" overrides" }
                                                }
                                            }
                                        }

                                        // Add override for current monitor
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text: "Set override for:"; color: Colours.palette.on_surface }
                                            SplitButtonRow {
                                                label: ""
                                                menuItems: root.monitorsList.map(m => {
                                                    let n = m.name||m;
                                                    return Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${n}"; property string val:"${n}" }`, displayCol);
                                                })
                                                onSelected: item => {
                                                    // Apply current global settings as monitor override
                                                    root.sendIpc(["config","set-monitor",item.val,"resize",root.resizeMode]);
                                                    root.sendIpc(["config","set-monitor",item.val,"transition_type",root.transitionType]);
                                                    root.sendIpc(["config","set-monitor",item.val,"filter",root.imageFilter]);
                                                    root.sendIpcWithResponse(["config","list-monitors"], resp => {
                                                        if (resp?.status==="Ok"&&resp.data) root.monitorConfigs = resp.data.value||[];
                                                    });
                                                }
                                            }
                                        }
                                    }

                                    // Per-wallpaper options
                                    CollapsibleSection {
                                        Layout.fillWidth: true; title: "Per-wallpaper Options"; expanded: false
                                        PropertyRow { label:"Current"; value: root.originalWallpaper?root._fileNameFromPath(root.originalWallpaper):"None" }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            TextButton { text:"Save Current Options"; onClicked: { let args=["wallpaper","options","set","--resize",root.resizeMode,"--filter",root.imageFilter,"--transition-type",root.transitionType]; root.sendIpc(args); } }
                                            TextButton { text:"Clear Options";         onClicked: root.sendIpc(["wallpaper","options","clear"]) }
                                        }
                                        TextButton {
                                            text: "View Saved Options"
                                            onClicked: root.sendIpcWithResponse(["wallpaper","options","get"], resp => {
                                                if (resp?.status==="Ok"&&resp.data) console.log("[WP] options:", JSON.stringify(resp.data));
                                            })
                                        }
                                    }

                                    Item { Layout.preferredHeight: Appearance.padding.large }
                                }
                                StyledScrollBar { flickable: displayScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
                            }

                            // ════════════════════════════════════════════════════════════
                            //  TAB 1: Theme
                            // ════════════════════════════════════════════════════════════
                            StyledFlickable {
                                id: themeScroll; contentWidth: width; contentHeight: themeCol.height; clip: true
                                ColumnLayout {
                                    id: themeCol; width: parent.width; spacing: Appearance.spacing.small

                                    SectionHeader { title: "Mode" }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.large
                                        ToggleButton {
                                            label: "Dark"; toggled: root.themeMode === "dark"
                                            onClicked: { root.themeMode="dark"; root.setThemeParam("mode","dark"); }
                                        }
                                        ToggleButton {
                                            label: "Light"; toggled: root.themeMode === "light"
                                            onClicked: { root.themeMode="light"; root.setThemeParam("mode","light"); }
                                        }
                                    }

                                    SectionHeader { title: "Auto Mode Schedule" }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        StyledText { text:"Sunrise"; color:Colours.palette.on_surface }
                                        Item { Layout.fillWidth: true }
                                        StyledTextField {
                                            Layout.preferredWidth:80; text:root.themeAutoSunrise
                                            placeholderText:"07:00"
                                            onEditingFinished: {
                                                root.themeAutoSunrise = text;
                                                root.sendIpc(["config","set-theme-auto","sunrise",text]);
                                            }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        StyledText { text:"Sunset"; color:Colours.palette.on_surface }
                                        Item { Layout.fillWidth: true }
                                        StyledTextField {
                                            Layout.preferredWidth:80; text:root.themeAutoSunset
                                            placeholderText:"19:00"
                                            onEditingFinished: {
                                                root.themeAutoSunset = text;
                                                root.sendIpc(["config","set-theme-auto","sunset",text]);
                                            }
                                        }
                                    }
                                    TextButton {
                                        text: "Enable Auto Mode"
                                        onClicked: root.sendIpc(["theme","mode","auto"])
                                    }

                                    SectionHeader { title: "Palette" }

                                    SplitButtonRow {
                                        id: schemeSplitBtn; label: "Scheme"
                                        menuItems: root.themeVariants.map(v => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${v.replace('scheme-','')}"; property string val:"${v}" }`, themeCol))
                                        Component.onCompleted: {
                                            for (let i = 0; i < menuItems.length; i++)
                                                if (menuItems[i].val === root.themeSchemeType) { active = menuItems[i]; break; }
                                        }
                                        onSelected: item => {
                                            root.themeSchemeType = item.val;
                                            root.sendIpc(["theme","palette","set",item.val]);
                                            root.saveMatugenDefault("scheme_type", item.val);
                                        }
                                    }

                                    // Fine-tune
                                    CollapsibleSection {
                                        Layout.fillWidth: true; title: "Fine-tune"; expanded: true

                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Contrast"; color:Colours.palette.on_surface }
                                            StyledSlider { id:contrastSl; Layout.fillWidth:true; from:-1.0; to:1.0; stepSize:0.05
                                                value: root.themeContrast
                                                onInteraction: v => { root.themeContrast=v; root.setThemeParam("contrast",v.toFixed(2)); themeDebounce.restart(); }
                                            }
                                            StyledText { text:contrastSl.value.toFixed(2); color:Colours.palette.on_surface_variant; Layout.preferredWidth:38 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Dark brightness"; color:Colours.palette.on_surface }
                                            StyledSlider { id:darkSl; Layout.fillWidth:true; from:-1.0; to:1.0; stepSize:0.05
                                                value: root.themeLightnessDark
                                                onInteraction: v => { root.themeLightnessDark=v; root.setThemeParam("lightness-dark",v.toFixed(2)); themeDebounce.restart(); }
                                            }
                                            StyledText { text:darkSl.value.toFixed(2); color:Colours.palette.on_surface_variant; Layout.preferredWidth:38 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Light brightness"; color:Colours.palette.on_surface }
                                            StyledSlider { id:lightSl; Layout.fillWidth:true; from:-1.0; to:1.0; stepSize:0.05
                                                value: root.themeLightnessLight
                                                onInteraction: v => { root.themeLightnessLight=v; root.setThemeParam("lightness-light",v.toFixed(2)); themeDebounce.restart(); }
                                            }
                                            StyledText { text:lightSl.value.toFixed(2); color:Colours.palette.on_surface_variant; Layout.preferredWidth:38 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Opacity"; color:Colours.palette.on_surface }
                                            StyledSlider { id:opacSl; Layout.fillWidth:true; from:0.0; to:1.0; stepSize:0.05
                                                value: root.themeOpacity
                                                onInteraction: v => { root.themeOpacity=v; root.setThemeParam("opacity",v.toFixed(2)); themeDebounce.restart(); }
                                            }
                                            StyledText { text:opacSl.value.toFixed(2); color:Colours.palette.on_surface_variant; Layout.preferredWidth:38 }
                                        }

                                        SpinBoxRow {
                                            label:"Color index (0–4)"; value:root.themeColorIndex; min:0; max:4; step:1
                                            onValueModified: v => { root.themeColorIndex=v; root.setThemeParam("source-color-index",v); themeDebounce.restart(); }
                                        }

                                        SplitButtonRow {
                                            id: preferBtn; label:"Prefer"
                                            menuItems: root.colorPrefs.map(p => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${p}"; property string val:"${p}" }`, themeCol))
                                            Component.onCompleted: {
                                                for (let i = 0; i < menuItems.length; i++)
                                                    if (menuItems[i].val === root.themePrefer) { active = menuItems[i]; break; }
                                            }
                                            onSelected: item => {
                                                root.themePrefer = item.val;
                                                root.setThemeParam("prefer", item.val);
                                                themeDebounce.restart();
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Fallback color"; color:Colours.palette.on_surface }
                                            Item { Layout.fillWidth: true }
                                            Rectangle { width:24;height:24;radius:4; color:"#"+(root.themeFallbackColor?root.themeFallbackColor.substring(0,6):"4285f4"); border.width:1;border.color:Colours.palette.outline }
                                            StyledTextField {
                                                Layout.preferredWidth:110; text:root.themeFallbackColor; placeholderText:"rrggbb"
                                                onEditingFinished: {
                                                    let c = text.replace(/[^0-9a-fA-F]/g,"");
                                                    if (c.length >= 6) { root.themeFallbackColor=c.substring(0,6); root.setThemeParam("fallback-color",c.substring(0,6)); themeDebounce.restart(); }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        TextButton { text:"Regenerate Theme"; onClicked: { if (root.originalWallpaper) root.sendIpc(["theme","generate",root.originalWallpaper]); } }
                                        TextButton { text:"Reset to Defaults"; onClicked: root.sendIpc(["theme","set","contrast","0"]) }
                                    }

                                    Item { Layout.preferredHeight: Appearance.padding.large }
                                }
                                StyledScrollBar { flickable: themeScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
                            }

                            // ════════════════════════════════════════════════════════════
                            //  TAB 2: Gallery
                            // ════════════════════════════════════════════════════════════
                            StyledFlickable {
                                id: galleryScroll; contentWidth: width; contentHeight: galleryCol.height; clip: true
                                ColumnLayout {
                                    id: galleryCol; width: parent.width; spacing: Appearance.spacing.small

                                    SectionHeader { title: "Index" }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        StyledText { text:"Directory"; color:Colours.palette.on_surface }
                                        StyledTextField { Layout.fillWidth:true; text:root.indexDir; onTextChanged:root.indexDir=text }
                                    }
                                    SwitchRow { label:"Force re-index"; checked:root.indexForce; onToggled: function(){root.indexForce=!root.indexForce} }
                                    TextButton { text:"Index Now"; onClicked: { let a=["wallpaper","index",root.indexDir]; if(root.indexForce) a.push("--force"); root.sendIpc(a); } }

                                    SectionHeader { title: "Watch Directories (auto-index)" }

                                    SwitchRow {
                                        label: "AI Tagging (requires Moondream)"
                                        checked: root.aiTagging
                                        onToggled: function() {
                                            root.aiTagging = !root.aiTagging;
                                            root.sendIpc(["config","set-indexer","ai_tagging",String(root.aiTagging)]);
                                        }
                                    }

                                    Repeater {
                                        model: root.watchDirs
                                        delegate: RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledIcon { text:"\ue2c7"; color:Colours.palette.on_surface_variant }
                                            StyledText { Layout.fillWidth:true; text:modelData; elide:Text.ElideLeft; color:Colours.palette.on_surface }
                                            IconButton {
                                                icon:"\ue872"; type:IconButton.Tonal
                                                onClicked: {
                                                    root.sendIpc(["config","set-indexer","rm_watch_dir",modelData]);
                                                    let updated = root.watchDirs.filter(d=>d!==modelData);
                                                    root.watchDirs = updated;
                                                }
                                                Tooltip { target:parent; text:"Remove watch dir" }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        StyledTextField {
                                            id: watchDirField; Layout.fillWidth:true
                                            placeholderText: "Path to watch…"
                                            text: root.newWatchDir
                                            onTextChanged: root.newWatchDir = text
                                        }
                                        TextButton {
                                            text:"Add"
                                            enabled: root.newWatchDir.length > 0
                                            onClicked: {
                                                root.sendIpc(["config","set-indexer","add_watch_dir",root.newWatchDir]);
                                                root.watchDirs = root.watchDirs.concat([root.newWatchDir]);
                                                root.newWatchDir = "";
                                                watchDirField.text = "";
                                            }
                                        }
                                    }

                                    SectionHeader { title: "History" }
                                    PropertyRow { label:"Entries"; value:String(root.historyCount) }
                                    TextButton { text:"Clear History"; onClicked: { root.sendIpc(["wallpaper","history","clear"]); root.historyCount=0; } }

                                    SectionHeader { title: "Favorites" }
                                    PropertyRow { label:"Entries"; value:String(root.favoritesCount) }
                                    TextButton {
                                        text:"Clear All Favorites"
                                        onClicked: root.sendIpcWithResponse(["wallpaper","fav","list","--limit","1000"], resp => {
                                            if (resp?.status==="Ok"&&resp.data) {
                                                let e = resp.data.value||[];
                                                for (let x of e) if (x.path) root.sendIpc(["wallpaper","fav","rm",x.path]);
                                                root.favoritesCount=0;
                                            }
                                        })
                                    }

                                    SectionHeader { title: "Random & Sort" }
                                    SplitButtonRow {
                                        label:"Sort by"
                                        menuItems: root.sortFields.map(f => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${f[0].toUpperCase()+f.slice(1)}"; property string val:"${f}" }`, galleryCol))
                                        Component.onCompleted: {
                                            for (let i=0;i<menuItems.length;i++) if(menuItems[i].val===root.sortBy){active=menuItems[i];break;}
                                        }
                                        onSelected: item => root.sortBy = item.val
                                    }
                                    SwitchRow { label:"Reverse order"; checked:root.sortReverse; onToggled:function(){root.sortReverse=!root.sortReverse} }

                                    Item { Layout.preferredHeight: Appearance.padding.large }
                                }
                                StyledScrollBar { flickable: galleryScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
                            }

                            // ════════════════════════════════════════════════════════════
                            //  TAB 3: Slideshow
                            // ════════════════════════════════════════════════════════════
                            StyledFlickable {
                                id: slideshowScroll; contentWidth: width; contentHeight: slideshowCol.height; clip: true
                                ColumnLayout {
                                    id: slideshowCol; width: parent.width; spacing: Appearance.spacing.small

                                    SectionHeader { title: "Slideshow" }

                                    SwitchRow {
                                        label:"Active"; checked:root.slideshowActive
                                        onToggled: function() {
                                            root.slideshowActive = !root.slideshowActive;
                                            if (root.slideshowActive) {
                                                let a = ["daemon","slideshow","start",root.slideshowDir,"-i",String(Math.round(root.slideshowInterval))];
                                                if (root.slideshowTextFilter)  a.push("--query",root.slideshowTextFilter);
                                                if (root.slideshowIncludeHidden) a.push("--include-dot");
                                                if (root.slideshowOnlyHidden)    a.push("--only-dot");
                                                if (root.slideshowOnlyFavorites) a.push("--favorites");
                                                root.sendIpc(a);
                                            } else {
                                                root.sendIpc(["daemon","slideshow","stop"]);
                                            }
                                        }
                                    }

                                    SpinBoxRow {
                                        label:"Interval (sec)"; value:root.slideshowInterval; min:10; max:86400; step:60
                                        onValueModified: v => { root.slideshowInterval=v; root.saveSlideshowConfig("interval",v); }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        StyledText { text:"Directory"; color:Colours.palette.on_surface }
                                        StyledTextField { Layout.fillWidth:true; text:root.slideshowDir; onEditingFinished: { root.slideshowDir=text; root.saveSlideshowConfig("dir",text); } }
                                    }

                                    CollapsibleSection {
                                        Layout.fillWidth: true; title:"Filters"; expanded:false

                                        SwitchRow {
                                            label:"Include hidden files"; checked:root.slideshowIncludeHidden
                                            onToggled: function() {
                                                root.slideshowIncludeHidden=!root.slideshowIncludeHidden;
                                                if (root.slideshowIncludeHidden) root.slideshowOnlyHidden=false;
                                                root.saveSlideshowConfig("include_hidden",root.slideshowIncludeHidden);
                                                if (root.slideshowIncludeHidden) root.saveSlideshowConfig("only_hidden",false);
                                            }
                                        }
                                        SwitchRow {
                                            label:"Only hidden files"; checked:root.slideshowOnlyHidden
                                            onToggled: function() {
                                                root.slideshowOnlyHidden=!root.slideshowOnlyHidden;
                                                if (root.slideshowOnlyHidden) root.slideshowIncludeHidden=false;
                                                root.saveSlideshowConfig("only_hidden",root.slideshowOnlyHidden);
                                                if (root.slideshowOnlyHidden) root.saveSlideshowConfig("include_hidden",false);
                                            }
                                        }
                                        SwitchRow {
                                            label:"Only favorites"; checked:root.slideshowOnlyFavorites
                                            onToggled: function() { root.slideshowOnlyFavorites=!root.slideshowOnlyFavorites; root.saveSlideshowConfig("only_favorites",root.slideshowOnlyFavorites); }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                            StyledText { text:"Text filter"; color:Colours.palette.on_surface }
                                            StyledTextField { Layout.fillWidth:true; placeholderText:"name, tags, or color…"; text:root.slideshowTextFilter; onEditingFinished: { root.slideshowTextFilter=text; root.saveSlideshowConfig("text_filter",text||""); } }
                                        }
                                    }

                                    Item { Layout.preferredHeight: Appearance.padding.large }
                                }
                                StyledScrollBar { flickable: slideshowScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
                            }

                            // ════════════════════════════════════════════════════════════
                            //  TAB 4: System
                            // ════════════════════════════════════════════════════════════
                            StyledFlickable {
                                id: systemScroll; contentWidth: width; contentHeight: systemCol.height; clip: true
                                ColumnLayout {
                                    id: systemCol; width: parent.width; spacing: Appearance.spacing.small

                                    SectionHeader { title: "Daemon" }
                                    PropertyRow { label:"Status";   value:root.daemonStatus }
                                    PropertyRow { label:"Uptime";   value:{ let s=root.daemonUptime; return `${Math.floor(s/3600)}h ${Math.floor((s%3600)/60)}m ${s%60}s`; } }
                                    PropertyRow { label:"Memory";   value:root.daemonMemory.toFixed(1)+" MiB" }
                                    PropertyRow { label:"Indexing"; value:root.indexingActive?`running (${root.indexQueueSize} queued)`:"idle" }
                                    PropertyRow { label:"Preview";  value:root.previewActive?"active":"off" }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        TextButton { text:"Restart Daemon"; onClicked: { root.sendIpc(["daemon","stop"]); root.daemonStatus="restarting…"; Qt.callLater(()=>{ Quickshell.execDetached([root.walltoolBin,"daemon","start"]); Qt.callLater(()=>root.fetchDaemonData(),1000); }); } }
                                        TextButton { text:"Refresh";        onClicked: root.fetchDaemonData() }
                                    }

                                    SectionHeader { title: "Game Mode" }
                                    SwitchRow {
                                        label:"Pause all (Game Mode)"; checked:root.gameMode
                                        onToggled: function() { root.gameMode=!root.gameMode; root.sendIpc(root.gameMode?["daemon","pause-all"]:["daemon","resume-all"]); }
                                    }

                                    SectionHeader { title: "Monitors" }
                                    Repeater {
                                        model: root.monitorsList
                                        delegate: PropertyRow {
                                            label: modelData.name||modelData
                                            value: modelData.width&&modelData.height?`${modelData.width}×${modelData.height} @(${modelData.x},${modelData.y}) ×${(modelData.scale||1).toFixed(1)}`:""
                                        }
                                    }
                                    TextButton { text:"Identify Monitors"; onClicked: root.sendIpc(["monitor","identify"]) }

                                    SectionHeader { title: "Profiles" }
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        StyledText { text:"Profile name"; color:Colours.palette.on_surface }
                                        StyledTextField { Layout.preferredWidth:140; text:root.currentProfile; onTextChanged:root.currentProfile=text; placeholderText:"my-profile" }
                                    }
                                    SplitButtonRow {
                                        label:"Existing"
                                        menuItems: root.profilesList.map(p => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${p}"; property string val:"${p}" }`, systemCol))
                                        onSelected: item => root.currentProfile = item.val
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        TextButton { text:"Save";   enabled:root.currentProfile!==""; onClicked: root.sendIpc(["config","profile","save",root.currentProfile]) }
                                        TextButton { text:"Load";   enabled:root.currentProfile!==""; onClicked: root.sendIpc(["config","profile","load",root.currentProfile]) }
                                        TextButton { text:"Delete"; enabled:root.currentProfile!==""; onClicked: { root.sendIpc(["config","profile","rm",root.currentProfile]); root.currentProfile=""; root.fetchDaemonData(); } }
                                    }

                                    SectionHeader { title: "Config" }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Appearance.spacing.medium
                                        TextButton { text:"Open in Editor"; onClicked: root.sendIpc(["config","edit"]) }
                                        TextButton { text:"Reload";          onClicked: root.fetchDaemonData() }
                                    }

                                    // Config preview
                                    CollapsibleSection {
                                        Layout.fillWidth: true; title:"config.toml preview"; expanded:false
                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: cfgText.implicitHeight + Appearance.padding.medium*2
                                            StyledRect {
                                                anchors.fill: parent
                                                color: Colours.palette.surface_variant; radius: Appearance.rounding.small
                                                StyledText {
                                                    id: cfgText
                                                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:Appearance.padding.medium }
                                                    text: root.configFullText || "# (click Reload to fetch config)"
                                                    font.family: "monospace"; font.pointSize: Appearance.font.size.smaller
                                                    color: Colours.palette.on_surface_variant; wrapMode: Text.WordWrap
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.preferredHeight: Appearance.padding.large }
                                }
                                StyledScrollBar { flickable: systemScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
                            }

                            // ════════════════════════════════════════════════════════════
                            //  TAB 5: Keys
                            // ════════════════════════════════════════════════════════════
                            StyledFlickable {
                                id: keysScroll; contentWidth: width; contentHeight: keysCol.height; clip: true
                                ColumnLayout {
                                    id: keysCol; width: parent.width; spacing: Appearance.spacing.small

                                    SectionHeader { title: "Navigation" }
                                    PropertyRow { label:"← / → (↑ / ↓)";    value:"Navigate carousel" }
                                    PropertyRow { label:"Enter";               value:"Apply wallpaper" }
                                    PropertyRow { label:"Esc";                 value:"Cancel and close" }
                                    PropertyRow { label:"Alt+Enter";           value:"Apply in Stretch mode" }

                                    SectionHeader { title: "Settings & Modes" }
                                    PropertyRow { label:"Ctrl+I";  value:"Open / close settings" }
                                    PropertyRow { label:"Ctrl+M";  value:"Toggle dark / light" }
                                    PropertyRow { label:"Ctrl+T";  value:"Next palette scheme" }
                                    PropertyRow { label:"Ctrl+H";  value:"Cycle dot-file modes: normal → include → only" }
                                    PropertyRow { label:"Ctrl+R";  value:"Set random wallpaper" }
                                    PropertyRow { label:"Ctrl+G";  value:"Toggle Game Mode" }

                                    SectionHeader { title: "Favorites & Hidden" }
                                    PropertyRow { label:"Ctrl+Shift+A"; value:"Add to favorites" }
                                    PropertyRow { label:"Ctrl+Shift+D"; value:"Remove from favorites" }
                                    PropertyRow { label:"Ctrl+Shift+H"; value:"Toggle hidden status (.filename)" }

                                    SectionHeader { title: "History" }
                                    PropertyRow { label:"Ctrl+["; value:"Previous wallpaper in history" }
                                    PropertyRow { label:"Ctrl+]"; value:"Next wallpaper in history" }

                                    SectionHeader { title: "View Modes (Hold)" }
                                    PropertyRow { label:"Alt (hold)";   value:"Show history" }
                                    PropertyRow { label:"Shift (hold)"; value:"Show favorites" }

                                    SectionHeader { title: "In Favorites mode" }
                                    PropertyRow { label:"Shift+Ctrl+D (hold Shift)"; value:"Remove and hide item immediately" }

                                    Item { Layout.preferredHeight: Appearance.padding.large }
                                }
                                StyledScrollBar { flickable: keysScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
                            }
                        }
                    }
                }
            }
        }
    }
}

// import QtQuick
// import QtQuick.Layouts
// import Quickshell
// import Quickshell.Io
// import qs.config
// import qs.utils
// import qs.components
// import qs.components.controls
// import qs.components.effects
// import qs.components.images
// import qs.components.containers
// import qs.services

// LauncherModule {
//     id: root

//     moduleId: "Wallpapers"
//     name: "Wallpaper Engine"
//     description: "Manage backgrounds, themes, slideshows and history"
//     icon: "\ue3f4"
//     trigger: "wp"

//     hasLeftPanel: false
//     hasRightPanel: true

//     // ══════════════════════════════════════════════════════════════════════════════
//     //  ORIENTATION CONFIGURATION
//     //  Set to true for vertical carousel (cards stacked top-to-bottom)
//     //  Set to false for horizontal carousel (cards side-by-side)
//     // ══════════════════════════════════════════════════════════════════════════════
//     property bool isVertical: false

//     // ── Dynamic sizing ──
//     readonly property real imageScale: Config.launcher.carouselImageScale ?? 2.0
//     readonly property int visibleItems: Config.launcher.carouselVisibleItems ?? 5
//     readonly property real _baseCardW: 160 * imageScale
//     readonly property real _baseCardH: _baseCardW * 0.5625
//     readonly property real _panelPad: Appearance.padding.large

//     // Settings panel dimensions
//     readonly property real _settingsWidth: 760
//     readonly property real _settingsHeight: 500

//     // Calculate carousel dimensions based on orientation
//     readonly property real _carouselWidth: isVertical
//         ? _baseCardW + _panelPad * 2
//         : Math.max(760, _baseCardW * (visibleItems - 1 + 0.6) + _panelPad * 2)
//     readonly property real _carouselHeight: isVertical
//         ? _baseCardH * (visibleItems - 1 + 0.6) + _panelPad * 2
//         : _baseCardH + _panelPad * 2

//     customTotalWidth: isSettingsOpen ? _settingsWidth : _carouselWidth
//     customRightWidth: isSettingsOpen ? _settingsWidth : _carouselWidth
//     customRightHeight: isSettingsOpen ? _settingsHeight : _carouselHeight

//     Behavior on customTotalWidth { NumberAnimation { duration: Appearance.anim.durations.normal; easing.type: Easing.OutCubic } }
//     Behavior on customRightWidth { NumberAnimation { duration: Appearance.anim.durations.normal; easing.type: Easing.OutCubic } }
//     Behavior on customRightHeight { NumberAnimation { duration: Appearance.anim.durations.normal; easing.type: Easing.OutCubic } }

//     // Signal parent to disable clip when settings with dropdowns are open
//     property bool needsOverflow: isSettingsOpen

//     // ==========================================
//     // STATE
//     // ==========================================
//     property PathView carousel: null
//     property bool isSettingsOpen: false

//     property bool isCtrlPressed: false
//     property bool isAltPressed: false
//     property bool isShiftPressed: false
//     property real _lastShortcutTick: 0

//     function markShortcut() {
//         _lastShortcutTick = Date.now();
//     }

//     property int visMode: 0 // 0 = Normal, 1 = Include Dot, 2 = Only Dot
//     property string lastQuery: ""

//     property string originalWallpaper: ""
//     property bool isApplied: false
//     property bool _isInitialLoad: false  // Track if this is the first load after activation

//     property int _scrollDirection: 0
//     property string _restorePath: ""
//     property bool _scrollToCurrentOnLoad: false


//     property string targetMonitor: "All"
//     property string displayMode: "crop"  // awww default
//     property bool skipThemeGen: false
//     property bool isMuted: false
//     property real mediaVolume: 100
//     property bool isPaused: false
//     property bool slideshowActive: false
//     property real slideshowInterval: 900
//     property bool gameMode: false

//     // ── Settings Panel State ──
//     property int settingsTabIndex: 0

//     // ── Display Settings ──
//     property string resizeMode: "crop"  // awww default
//     property string fillColor: "000000ff"
//     property string imageFilter: "lanczos3"
//     property string transitionType: "fade"
//     property real transitionDuration: 1.0
//     property int transitionFps: 30
//     property int transitionStep: 90
//     property real transitionAngle: 45
//     property string transitionPos: "center"
//     property string transitionBezier: ".54,0,.34,.99"
//     property string transitionWave: "20,20"
//     property bool transitionInvertY: false

//     // ── Theme Fine-tune Settings ──

//     // ── Gallery Settings ──
//     property string indexDir: wallpapersDir
//     property bool indexForce: false
//     property string sortBy: "score"
//     property bool sortReverse: false
//     property int historyCount: 0
//     property int favoritesCount: 0

//     // ── Slideshow Settings ──
//     property string slideshowDir: wallpapersDir
//     property bool slideshowIncludeHidden: false
//     property bool slideshowOnlyHidden: false
//     property bool slideshowOnlyFavorites: false
//     property string slideshowTextFilter: ""

//     // ── System Settings ──
//     property string daemonStatus: "unknown"
//     property var monitorsList: []
//     property var profilesList: []
//     property string currentProfile: ""

//     readonly property var themeVariants:[
//         "scheme-tonal-spot", "scheme-fidelity", "scheme-monochrome", "scheme-neutral",
//         "scheme-vibrant", "scheme-expressive", "scheme-content", "scheme-rainbow", "scheme-fruit-salad"
//     ]

//     readonly property var resizeModes: ["crop", "fit", "stretch", "no"]
//     readonly property var imageFilters: ["nearest", "bilinear", "catmull-rom", "mitchell", "lanczos3"]
//     readonly property var transitionTypes: ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"]
//     readonly property var sortFields: ["score", "time", "name", "color"]
//     readonly property var colorPreferences: ["darkness", "lightness", "saturation", "less-saturation", "value", "closest-to-fallback"]

//     readonly property string walltoolBin: `${Quickshell.shellDir}/scripts/walltool/target/release/walltool`
//     readonly property string wallpapersDir: Quickshell.env("PSHELL_WALLPAPERS_DIR") || `${Quickshell.env("XDG_PICTURES_DIR") || `${Quickshell.env("HOME")}/Pictures`}/Wallpapers`

//     ListModel { id: galleryModel }

//     // ==========================================
//     // IPC — POOLED PROCESSES
//     // ==========================================
//     property var _firePool:[]
//     property var _respPool:[]

//     Component.onCompleted: {
//         Qt.callLater(() => {
//             for (let i = 0; i < 3; i++) {
//                 _firePool.push(_fireComp.createObject(root));
//                 _respPool.push(_respComp.createObject(root));
//             }
//         });
//     }

//     Component {
//         id: _fireComp
//         Process {}
//     }

//     Component {
//         id: _respComp
//         Process {
//             property var callback: null
//             property var chunks:[]

//             stdout: SplitParser {
//                 splitMarker: ""
//                 onRead: data => chunks.push(data)
//             }

//             onStarted: chunks =[]

//             onExited: (code) => {
//                 if (code === 0 && chunks.length > 0) {
//                     try {
//                         let parsed = JSON.parse(chunks.join(""));
//                         if (callback) callback(parsed);
//                     } catch (e) {
//                         console.warn("[WP] JSON parse error:", e);
//                     }
//                 }
//                 callback = null;
//                 running = false;
//             }
//         }
//     }

//     function sendIpc(args) {
//         let proc = _firePool.find(p => !p.running);
//         if (!proc) {
//             proc = _fireComp.createObject(root);
//             _firePool.push(proc);
//         }
//         proc.command =[root.walltoolBin, "--json"].concat(args);
//         proc.running = true;
//     }

//     function sendIpcWithResponse(args, cb) {
//         let proc = _respPool.find(p => !p.running);
//         if (!proc) {
//             proc = _respComp.createObject(root);
//             _respPool.push(proc);
//         }
//         proc.callback = cb;
//         proc.command =[root.walltoolBin, "--json"].concat(args);
//         proc.running = true;
//     }

//     // Save transition parameter to config
//     function saveTransitionConfig(key, value) {
//         sendIpc(["config", "set-awww-default", key, String(value)]);
//     }

//     // Save slideshow parameter to config
//     function saveSlideshowConfig(key, value) {
//         sendIpc(["config", "set-slideshow", key, String(value)]);
//     }

//     // ==========================================
//     // BATCH MODEL LOADING
//     // ==========================================
//     function reloadModel() {
//         let savedPath = root._restorePath || (carousel && carousel.currentIndex >= 0 && carousel.currentIndex < galleryModel.count ? galleryModel.get(carousel.currentIndex).path : "");
//         let savedDirection = root._scrollDirection;
//         let scrollToCurrent = root._scrollToCurrentOnLoad || root._isInitialLoad;
//         let currentOriginal = root.originalWallpaper;  // Capture in closure

//         root._restorePath = "";
//         root._scrollToCurrentOnLoad = false;

//         let args =["wallpaper", "search", lastQuery || "", "--limit", "0"];

//         if (isAltPressed && !isCtrlPressed) args.push("--history");
//         if (isShiftPressed && !isCtrlPressed) args.push("--favorites");
//         if (visMode === 1) args.push("--include-dot");
//         if (visMode === 2) args.push("--only-dot");

//         sendIpcWithResponse(args, resp => {
//             let entries = _extractSearchResults(resp);

//             console.log("[WP] Loaded", entries.length, "wallpapers, scrollToCurrent:", scrollToCurrent, "originalWallpaper:", currentOriginal);
//             if (entries.length > 0) {
//                 console.log("[WP] First entry:", JSON.stringify(entries[0]));
//             }

//             let newItems = entries.map(e => ({
//                 name: e.name || _fileNameFromPath(e.path),
//                 path: e.path || "",
//                 mediaType: e.media_type || "image",
//                 tags: (e.tags ||[]).join(", "),
//                 isFav: e.is_fav || false,
//                 removing: false
//             }));

//             galleryModel.clear();
//             if (newItems.length > 0) {
//                 galleryModel.append(newItems);
//                 console.log("[WP] Model updated, count:", galleryModel.count);
//             }

//             // Mark initial load as done after first successful load
//             if (root._isInitialLoad) {
//                 root._isInitialLoad = false;
//             }

//             Qt.callLater(() => {
//                 if (!carousel || galleryModel.count === 0) {
//                     console.log("[WP] Cannot scroll: carousel=", !!carousel, "count=", galleryModel.count);
//                     return;
//                 }

//                 let targetIdx = 0;
//                 if (scrollToCurrent && currentOriginal) {
//                     let idx = _findIndexByPath(currentOriginal);
//                     targetIdx = idx >= 0 ? idx : 0;
//                     console.log("[WP] Scrolling to current wallpaper:", currentOriginal, "idx:", targetIdx);
//                 } else if (savedPath) {
//                     let idx = _findIndexByPath(savedPath);
//                     targetIdx = idx >= 0 ? idx : _findNearestByOldPath(savedPath, savedDirection);
//                     console.log("[WP] Scrolling to saved path:", savedPath, "idx:", targetIdx);
//                 }

//                 // Use Timer to ensure PathView is ready
//                 scrollTimer.targetIndex = targetIdx;
//                 scrollTimer.restart();
//             });
//         });
//     }

//     function _findIndexByPath(path) {
//         if (!path) return -1;
//         for (let i = 0; i < galleryModel.count; i++) {
//             if (galleryModel.get(i).path === path) return i;
//         }
//         return -1;
//     }

//     function _findNearestByOldPath(oldPath, direction) {
//         if (galleryModel.count === 0) return 0;
//         let bestIdx = 0;
//         let bestDist = Infinity;
//         for (let i = 0; i < galleryModel.count; i++) {
//             let p = galleryModel.get(i).path;
//             let dist = Math.abs(p.localeCompare(oldPath));
//             if (dist < bestDist) {
//                 bestDist = dist;
//                 bestIdx = i;
//             }
//         }
//         if (direction > 0 && bestIdx + 1 < galleryModel.count) return Math.min(bestIdx, galleryModel.count - 1);
//         if (direction < 0 && bestIdx > 0) return Math.max(bestIdx, 0);
//         return bestIdx;
//     }

//     function _extractSearchResults(resp) {
//         if (!resp) return[];
//         if (resp.status === "Ok" && resp.data && resp.data.kind === "SearchResults") {
//             return resp.data.value ||[];
//         }
//         if (Array.isArray(resp)) return resp;
//         return[];
//     }

//     function _fileNameFromPath(path) {
//         if (!path) return "";
//         let fname = path.split("/").pop() || "";
//         let dotIdx = fname.lastIndexOf(".");
//         return dotIdx > 0 ? fname.substring(0, dotIdx) : fname;
//     }

//     // Timer for delayed scroll to ensure PathView is ready
//     Timer {
//         id: scrollTimer
//         interval: 50
//         repeat: false
//         property int targetIndex: 0
//         onTriggered: {
//             if (carousel && galleryModel.count > 0) {
//                 carousel.currentIndex = targetIndex;
//                 carousel.positionViewAtIndex(targetIndex, PathView.Center);
//                 console.log("[WP] Scroll timer: set index to", targetIndex);
//             }
//         }
//     }

//     // Debounce timer for theme regeneration after slider changes
//     Timer {
//         id: themeRegenerateDebounce
//         interval: 300
//         repeat: false
//         onTriggered: {
//             if (root.originalWallpaper) {
//                 root.sendIpc(["theme", "generate", root.originalWallpaper]);
//             }
//         }
//     }

//     function handleInput(query) {
//         lastQuery = query;
//         reloadDebounce.restart();
//     }

//     function onActivated(initialQuery) {
//         isApplied = false;
//         isCtrlPressed = false;
//         isAltPressed = false;
//         isShiftPressed = false;
//         visMode = 0;
//         _scrollDirection = 0;
//         _restorePath = "";
//         _isInitialLoad = true;  // Mark as initial load

//         // First, check if database has wallpapers
//         sendIpcWithResponse(["wallpaper", "search", "", "--limit", "1"], countResp => {
//             let wallpapers = _extractSearchResults(countResp);

//             // If database is empty, index the wallpaper directory first
//             if (wallpapers.length === 0) {
//                 console.log("[WP] Database is empty, indexing wallpaper directory...");
//                 console.log("[WP] Indexing directory:", root.wallpapersDir);
//                 sendIpcWithResponse(["wallpaper", "index", root.wallpapersDir], indexResp => {
//                     console.log("[WP] Indexing complete:", JSON.stringify(indexResp));
//                     // Now load initial data
//                     loadCurrentAndModel(initialQuery);
//                 });
//             } else {
//                 // Database has wallpapers, proceed normally
//                 loadCurrentAndModel(initialQuery);
//             }
//         });
//     }

//     function loadCurrentAndModel(initialQuery) {
//         // Get current wallpaper from history (most recent entry)
//         sendIpcWithResponse(["wallpaper", "history", "list", "--limit", "1"], resp => {
//             if (resp && resp.status === "Ok" && resp.data) {
//                 let entries = resp.data.value || [];
//                 if (Array.isArray(entries) && entries.length > 0 && entries[0].path) {
//                     root.originalWallpaper = entries[0].path;
//                     console.log("[WP] Current wallpaper from history:", root.originalWallpaper);
//                 }
//             }
//             root._scrollToCurrentOnLoad = true;
//             lastQuery = initialQuery;
//             reloadModel();
//         });
//     }

//     function onDeactivated() {
//         reloadDebounce.stop();
//         _isInitialLoad = false;
//         modifierDebounce.stop();
//         _scrollTier = 0;
//         if (!isApplied) {
//             // User cancelled — restore from preview backup
//             sendIpc(["wallpaper", "preview", "stop"]);
//         }
//         originalWallpaper = "";
//     }

//     function execute(query, isAlt) {
//         // Commit the preview to history and apply
//         sendIpc(["wallpaper", "preview", "commit"]);
//         if (isAlt) {
//             // Also set with stretch mode for Alt+Enter
//             sendIpc(["wallpaper", "set", _currentItemPath(), "--resize", "stretch"]);
//         }
//         isApplied = true;
//         root.requestClose(true);
//     }

//     function livePreview(path) {
//         if (!path) return;
//         let args = ["wallpaper", "preview", "start", path, "--transition-type", "none"];
//         if (targetMonitor !== "All") args.push("--outputs", targetMonitor);
//         sendIpc(args);
//     }

//     function setRandom() {
//         let args = ["wallpaper", "random", root.wallpapersDir];
//         if (lastQuery) args.push("--query", lastQuery);
//         if (visMode === 1) args.push("--include-dot");
//         if (visMode === 2) args.push("--only-dot");
//         if (skipThemeGen) args.push("--no-theme");

//         sendIpcWithResponse(args, resp => {
//             root.isApplied = true;
//             if (resp && resp.status === "Ok") {
//                 // After random, get current wallpaper and scroll to it
//                 sendIpcWithResponse(["wallpaper", "history", "list", "--limit", "1"], histResp => {
//                     if (histResp && histResp.status === "Ok" && histResp.data) {
//                         let entries = histResp.data.value || [];
//                         if (Array.isArray(entries) && entries.length > 0 && entries[0].path) {
//                             root.originalWallpaper = entries[0].path;
//                             root._scrollToCurrentOnLoad = true;  // Enable scroll to new wallpaper
//                             console.log("[WP] Random set to:", entries[0].path);
//                         }
//                     }
//                     root.reloadModel();
//                 });
//             }
//         });
//     }

//     function toggleSettings() {
//         isSettingsOpen = !isSettingsOpen;
//         if (isSettingsOpen) {
//             fetchDaemonData();
//         }
//     }

//     function fetchDaemonData() {
//         // Fetch monitors
//         sendIpcWithResponse(["monitor", "list"], resp => {
//             if (resp && resp.status === "Ok" && resp.data) {
//                 let monitors = resp.data.value || resp.data || [];
//                 if (Array.isArray(monitors)) {
//                     root.monitorsList = monitors;
//                 }
//             }
//         });

//         // Fetch theme state
//         sendIpcWithResponse(["theme", "get"], resp => {
//             if (resp && resp.status === "Ok" && resp.data) {
//                 let theme = resp.data.value || resp.data;
//                 if (theme.contrast !== undefined) contrastSlider.value = theme.contrast;
//                 if (theme.mode) {
//                     modeDarkToggle.toggled = (theme.mode === "dark");
//                     modeLightToggle.toggled = (theme.mode === "light");
//                 }
//                 if (theme.scheme_type) {
//                     for (let i = 0; i < schemeSplitButton.menuItems.length; i++) {
//                         if (schemeSplitButton.menuItems[i].val === theme.scheme_type) {
//                             schemeSplitButton.active = schemeSplitButton.menuItems[i];
//                             break;
//                         }
//                     }
//                 }
//                 if (theme.lightness_dark !== undefined) lightnessDarkSlider.value = theme.lightness_dark;
//                 if (theme.lightness_light !== undefined) lightnessLightSlider.value = theme.lightness_light;
//                 if (theme.opacity !== undefined) opacitySlider.value = theme.opacity;
//                 if (theme.source_color_index !== undefined) colorIndexSpinBox.value = theme.source_color_index;
//                                 if (theme.prefer) {
//                     for (let i = 0; i < preferSplitButton.menuItems.length; i++) {
//                         if (preferSplitButton.menuItems[i].val === theme.prefer) {
//                             preferSplitButton.active = preferSplitButton.menuItems[i];
//                             break;
//                         }
//                     }
//                 }
//                 if (theme.fallback_color) fallbackColorField.text = theme.fallback_color;
//             }
//         });

//         // Fetch awww defaults (global display settings from config.toml)
//         sendIpcWithResponse(["config", "get-awww-defaults"], resp => {
//             if (resp && resp.status === "Ok" && resp.data) {
//                 let opts = resp.data.value || resp.data;
//                 if (opts.resize) root.resizeMode = opts.resize;
//                 if (opts.fill_color) root.fillColor = opts.fill_color;
//                 if (opts.filter) root.imageFilter = opts.filter;
//                 if (opts.transition_type) root.transitionType = opts.transition_type;
//                 if (opts.transition_duration !== undefined) root.transitionDuration = opts.transition_duration;
//                 if (opts.transition_fps !== undefined) root.transitionFps = opts.transition_fps;
//                 if (opts.transition_step !== undefined) root.transitionStep = opts.transition_step;
//                 if (opts.transition_angle !== undefined) root.transitionAngle = opts.transition_angle;
//                 if (opts.transition_pos) root.transitionPos = opts.transition_pos;
//                 if (opts.transition_bezier) root.transitionBezier = opts.transition_bezier;
//                 if (opts.transition_wave) root.transitionWave = opts.transition_wave;
//                 if (opts.invert_y !== undefined) root.transitionInvertY = opts.invert_y;
//             }
//         });

//         // Fetch daemon status
//         sendIpcWithResponse(["daemon", "status"], resp => {
//             if (resp && resp.status === "Ok") {
//                 root.daemonStatus = "running";
//                 if (resp.data) {
//                     let status = resp.data.value || resp.data;
//                     if (status.slideshow_active !== undefined) root.slideshowActive = status.slideshow_active;
//                     if (status.game_mode !== undefined) root.gameMode = status.game_mode;
//                 }
//             } else {
//                 root.daemonStatus = "stopped";
//             }
//         });

//         // Fetch history count
//         sendIpcWithResponse(["wallpaper", "history", "list", "--limit", "1000"], resp => {
//             if (resp && resp.status === "Ok" && resp.data) {
//                 let entries = resp.data.value || [];
//                 root.historyCount = Array.isArray(entries) ? entries.length : 0;
//             }
//         });

//         // Fetch favorites count
//         sendIpcWithResponse(["wallpaper", "fav", "list", "--limit", "1000"], resp => {
//             if (resp && resp.status === "Ok" && resp.data) {
//                 let entries = resp.data.value || [];
//                 root.favoritesCount = Array.isArray(entries) ? entries.length : 0;
//             }
//         });

//         // Fetch profiles
//         sendIpcWithResponse(["config", "profile", "list"], resp => {
//             if (resp && resp.status === "Ok" && resp.data) {
//                 let profiles = resp.data.value || resp.data || [];
//                 if (Array.isArray(profiles)) {
//                     root.profilesList = profiles;
//                 }
//             }
//         });

//         // Fetch slideshow options from config
//         sendIpcWithResponse(["config", "get-slideshow"], resp => {
//             if (resp && resp.status === "Ok" && resp.data) {
//                 let opts = resp.data.value || resp.data;
//                 if (opts.dir) root.slideshowDir = opts.dir;
//                 if (opts.interval !== undefined) root.slideshowInterval = opts.interval;
//                 if (opts.include_hidden !== undefined) root.slideshowIncludeHidden = opts.include_hidden;
//                 if (opts.only_hidden !== undefined) root.slideshowOnlyHidden = opts.only_hidden;
//                 if (opts.only_favorites !== undefined) root.slideshowOnlyFavorites = opts.only_favorites;
//                 if (opts.text_filter) root.slideshowTextFilter = opts.text_filter;
//             }
//         });
//     }

//     // ── Navigation Throttling ──
//     property bool _navThrottled: false
//     property int _scrollTier: 0
//     on_ScrollTierChanged: WallpaperState.transitionTier = _scrollTier
//     property int _navStepCount: 0

//     readonly property bool _isIdle: _scrollTier === 0
//     readonly property bool _isActive: _scrollTier === 1
//     readonly property bool _isRapid: _scrollTier === 2

//     Timer {
//         id: _navThrottle
//         interval: root._isRapid ? 30 : root._isActive ? 60 : 100
//         onTriggered: root._navThrottled = false
//     }

//     Timer {
//             id: _tierDecay
//             interval: root._isRapid ? 250 : 500
//             repeat: true
//             onTriggered: {
//                 let wasRapid = root._isRapid; // Запоминаем, были ли мы в быстрой прокрутке

//                 if (root._scrollTier > 0) root._scrollTier--;

//                 // Если только что вышли из режима быстрой прокрутки — применяем обои
//                 if (wasRapid && !root._isRapid) {
//                     let p = root._currentItemPath();
//                     if (p) root.livePreview(p);
//                 }

//                 if (root._scrollTier === 0) {
//                     root._navStepCount = 0;
//                     stop();
//                 }
//             }
//         }
//     // Timer {
//     //     id: _tierDecay
//     //     interval: root._isRapid ? 250 : 500
//     //     repeat: true
//     //     onTriggered: {
//     //         if (root._scrollTier > 0) root._scrollTier--;
//     //         if (root._scrollTier === 0) {
//     //             root._navStepCount = 0;
//     //             stop();
//     //             // if (!root.skipThemeGen) {
//     //             //     let p = root._currentItemPath();
//     //             //     if (p) root.livePreview(p);
//     //             // }
//     //         }
//     //     }
//     // }

//     function _navStep(dir) {
//         if (!carousel || _navThrottled) return;
//         _navThrottled = true;
//         _navThrottle.restart();
//         _navStepCount++;

//         if (_navStepCount >= 4) {
//             _scrollTier = 2;
//         } else if (_scrollTier < 1) {
//             _scrollTier = 1;
//         }

//         _tierDecay.restart();
//         root._scrollDirection = dir;

//         if (dir < 0) carousel.decrementCurrentIndex();
//         else carousel.incrementCurrentIndex();
//     }

//     function navigateUp() { _navStep(-1); }
//     function navigateDown() { _navStep(1); }

//     function cycleVisMode() {
//         visMode = (visMode + 1) % 3;
//         reloadDebounce.stop();
//         modifierDebounce.stop();
//         reloadModel();
//     }

//     function _currentItemPath() {
//         if (!carousel || carousel.currentIndex < 0 || carousel.currentIndex >= galleryModel.count) return "";
//         return galleryModel.get(carousel.currentIndex).path || "";
//     }

//     // ─── DEFERRED GARBAGE COLLECTION ───
//     Timer {
//         id: gcTimer
//         interval: 600
//         onTriggered: {
//             let currentPath = root._currentItemPath();
//             let removedAny = false;

//             for (let i = galleryModel.count - 1; i >= 0; i--) {
//                 if (galleryModel.get(i).removing) {
//                     galleryModel.remove(i);
//                     removedAny = true;
//                 }
//             }

//             if (removedAny && carousel && currentPath) {
//                 let safeIdx = root._findIndexByPath(currentPath);
//                 if (safeIdx >= 0) carousel.currentIndex = safeIdx;
//             }
//         }
//     }

//     function _removeItemLocally(idx) {
//         if (idx < 0 || idx >= galleryModel.count) return;

//         galleryModel.setProperty(idx, "removing", true);

//         let nextIdx = idx;
//         if (root._scrollDirection >= 0) {
//             nextIdx = Math.min(idx + 1, galleryModel.count - 1);
//         } else {
//             nextIdx = Math.max(idx - 1, 0);
//         }

//         if (carousel && nextIdx !== idx && galleryModel.count > 1) {
//             carousel.currentIndex = nextIdx;
//         }

//         gcTimer.restart();
//     }

//     function modifyCurrentItem(action) {
//         let idx = carousel ? carousel.currentIndex : -1;
//         if (idx < 0 || idx >= galleryModel.count) return;
//         let item = galleryModel.get(idx);

//         if (item.removing) return;

//         if (action === "fav_add") {
//             galleryModel.setProperty(idx, "isFav", true);
//             sendIpc(["wallpaper", "fav", "add", item.path]);
//         } else if (action === "fav_rm") {
//             if (root.isShiftPressed && !root.isCtrlPressed) {
//                 sendIpc(["wallpaper", "fav", "rm", item.path]);
//                 _removeItemLocally(idx);
//             } else {
//                 galleryModel.setProperty(idx, "isFav", false);
//                 sendIpc(["wallpaper", "fav", "rm", item.path]);
//             }
//         } else if (action === "toggle_hidden") {
//             sendIpc(["wallpaper", "toggle-hidden", item.path]);
//             if (visMode === 1) _mutationReloadTimer.restart();
//             else _removeItemLocally(idx);
//         }
//     }

//     function toggleFavForIndex(idx) {
//         if (idx < 0 || idx >= galleryModel.count) return;
//         let item = galleryModel.get(idx);
//         if (item.removing) return;

//         if (item.isFav) {
//             if (root.isShiftPressed && !root.isCtrlPressed) {
//                 sendIpc(["wallpaper", "fav", "rm", item.path]);
//                 _removeItemLocally(idx);
//             } else {
//                 galleryModel.setProperty(idx, "isFav", false);
//                 sendIpc(["wallpaper", "fav", "rm", item.path]);
//             }
//         } else {
//             galleryModel.setProperty(idx, "isFav", true);
//             sendIpc(["wallpaper", "fav", "add", item.path]);
//         }
//     }

//     function onModifierPressed(key) {
//         if (key === Qt.Key_Control) {
//             root.isCtrlPressed = true;
//         } else if (key === Qt.Key_Alt && !root.isAltPressed) {
//             root.isAltPressed = true;
//             if (!root.isCtrlPressed) modifierDebounce.restart();
//         } else if (key === Qt.Key_Shift && !root.isShiftPressed) {
//             root.isShiftPressed = true;
//             if (!root.isCtrlPressed) modifierDebounce.restart();
//         }
//     }

//     function onModifierReleased(key) {
//         if (key === Qt.Key_Control) {
//             root.isCtrlPressed = false;
//         } else if (key === Qt.Key_Alt && root.isAltPressed) {
//             root.isAltPressed = false;
//             modifierDebounce.restart();
//         } else if (key === Qt.Key_Shift && root.isShiftPressed) {
//             root.isShiftPressed = false;
//             modifierDebounce.restart();
//         }
//     }

//     // ==========================================
//     // ТАЙМЕРЫ
//     // ==========================================
//     Timer {
//         id: reloadDebounce
//         interval: 120
//         onTriggered: root.reloadModel()
//     }

//     Timer {
//         id: modifierDebounce
//         interval: 250
//         onTriggered: {
//             if (Date.now() - root._lastShortcutTick < 600) return;
//             root.reloadModel();
//         }
//     }

//     // Timer {
//     //     id: previewDebounceTimer
//     //     interval: root._isRapid ? 800 : root._isActive ? 500 : 400
//     //     property string pendingPath: ""
//     //     onTriggered: {
//     //         if (pendingPath !== "") root.livePreview(pendingPath);
//     //     }
//     // }

//     Timer {
//         id: _mutationReloadTimer
//         interval: 200
//         onTriggered: root.reloadModel()
//     }

//     // ==========================================
//     // UI EXTENSIONS
//     // ==========================================
//     inputExtensionComponent: Component {
//         Item {
//             implicitWidth: settingsBtn.implicitWidth
//             implicitHeight: settingsBtn.implicitHeight

//             IconButton {
//                 id: settingsBtn
//                 icon: "\ue8b8"
//                 type: IconButton.Tonal
//                 toggle: true
//                 checked: root.isSettingsOpen
//                 onClicked: root.toggleSettings()

//                 Tooltip { target: settingsBtn; text: "Settings (Ctrl+I)" }
//             }
//         }
//     }

//     shortcutsComponent: Component {
//         Item {
//             Shortcut {
//                 sequence: "Ctrl+I"
//                 onActivated: {
//                     root.markShortcut();
//                     root.toggleSettings();
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+M"
//                 onActivated: {
//                     root.markShortcut();
//                     root.sendIpc(["theme", "mode", "toggle"]);
//                     root.fetchDaemonData();
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+T"
//                 onActivated: {
//                     root.markShortcut();
//                     if (schemeSplitButton.active) {
//                         let idx = root.themeVariants.indexOf(schemeSplitButton.active.val);
//                         let nextVal = root.themeVariants[(idx + 1) % root.themeVariants.length];
//                         root.sendIpc(["theme", "palette", "set", nextVal]);
//                         root.fetchDaemonData();
//                     }
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+H"
//                 onActivated: {
//                     root.markShortcut();
//                     root.cycleVisMode();
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+R"
//                 onActivated: {
//                     root.markShortcut();
//                     root.setRandom();
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+Shift+A"
//                 onActivated: {
//                     root.markShortcut();
//                     root.modifyCurrentItem("fav_add");
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+Shift+D"
//                 onActivated: {
//                     root.markShortcut();
//                     root.modifyCurrentItem("fav_rm");
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+Shift+H"
//                 onActivated: {
//                     root.markShortcut();
//                     root.modifyCurrentItem("toggle_hidden");
//                 }
//             }
//             Shortcut {
//                 sequence: "Alt+Return"
//                 onActivated: {
//                     root.markShortcut();
//                     let p = root._currentItemPath();
//                     if (p) {
//                         // Note: "span" is not a valid resize mode, using "stretch" for Alt+Enter
//                         root.sendIpc(["wallpaper", "set", p, "--resize", "stretch"]);
//                         root.isApplied = true;
//                         root.requestClose(true);
//                     }
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+G"
//                 onActivated: {
//                     root.markShortcut();
//                     root.gameMode = !root.gameMode;
//                     root.sendIpc(root.gameMode ? ["daemon", "pause-all"] : ["daemon", "resume-all"]);
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+["
//                 onActivated: {
//                     root.markShortcut();
//                     root.sendIpcWithResponse(["wallpaper", "history", "prev"], resp => {
//                         if (resp && resp.status === "Ok") {
//                             root.isApplied = true;
//                             root.reloadModel();
//                         }
//                     });
//                 }
//             }
//             Shortcut {
//                 sequence: "Ctrl+]"
//                 onActivated: {
//                     root.markShortcut();
//                     root.sendIpcWithResponse(["wallpaper", "history", "next"], resp => {
//                         if (resp && resp.status === "Ok") {
//                             root.isApplied = true;
//                             root.reloadModel();
//                         }
//                     });
//                 }
//             }
//         }
//     }

//     rightPanelComponent: Component {
//         Item {
//             id: panelContainer
//             anchors.fill: parent

//             StyledRect {
//                 id: modBadge
//                 anchors.top: parent.top
//                 anchors.horizontalCenter: parent.horizontalCenter
//                 anchors.topMargin: Appearance.padding.small
//                 z: 10

//                 color: Colours.alpha(Colours.palette.surface_container_highest, 0.9)
//                 border.width: 1
//                 border.color: Colours.alpha(Colours.palette.outline_variant, 0.5)
//                 radius: Appearance.rounding.full

//                 implicitWidth: badgeLayout.implicitWidth + Appearance.padding.large * 2
//                 implicitHeight: badgeLayout.implicitHeight + Appearance.padding.small * 2

//                 property bool shouldShow: (!root.isCtrlPressed && (root.isAltPressed || root.isShiftPressed)) || root.visMode > 0
//                 opacity: shouldShow ? 1.0 : 0.0
//                 scale: shouldShow ? 1.0 : 0.85
//                 visible: opacity > 0

//                 Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.small } }
//                 Behavior on scale { ScaleAnimator { duration: Appearance.anim.durations.small } }

//                 RowLayout {
//                     id: badgeLayout
//                     anchors.centerIn: parent
//                     spacing: Appearance.spacing.large

//                     StyledIcon {
//                         visible: root.isAltPressed && !root.isCtrlPressed
//                         text: "\ue8b5"
//                         color: Colours.palette.primary
//                         font.pointSize: Appearance.font.size.large
//                     }
//                     StyledIcon {
//                         visible: root.isShiftPressed && !root.isCtrlPressed
//                         text: "\ue866"
//                         color: Colours.palette.tertiary
//                         font.pointSize: Appearance.font.size.large
//                     }
//                     StyledIcon {
//                         visible: root.visMode > 0
//                         text: root.visMode === 2 ? "\ue8f5" : "\ue8f4"
//                         color: Colours.palette.on_surface
//                         opacity: root.visMode === 1 ? 0.4 : 1.0
//                         font.pointSize: Appearance.font.size.large
//                     }
//                 }
//             }

//             ColumnLayout {
//                 id: emptyState
//                 anchors.centerIn: parent
//                 spacing: Appearance.spacing.medium
//                 z: 5

//                 property bool shouldShow: galleryModel.count === 0
//                 opacity: shouldShow ? 1.0 : 0.0
//                 scale: shouldShow ? 1.0 : 0.92
//                 visible: opacity > 0

//                 Behavior on opacity { OpacityAnimator {} }
//                 Behavior on scale { ScaleAnimator {} }

//                 StyledIcon {
//                     Layout.alignment: Qt.AlignHCenter
//                     text: root.isShiftPressed ? "\ue866" : root.isAltPressed ? "\ue8b5" : root.visMode === 2 ? "\ue8f5" : "\ue8b6"
//                     font.pointSize: Appearance.font.size.extraLarge * 2
//                     color: Colours.alpha(Colours.palette.on_surface_variant, 0.3)
//                 }
//                 StyledText {
//                     Layout.alignment: Qt.AlignHCenter
//                     text: root.isShiftPressed ? "No favorites yet" : root.isAltPressed ? "History is empty" : root.visMode === 2 ? "No hidden wallpapers" : "No wallpapers found"
//                     font.pointSize: Appearance.font.size.large
//                     color: Colours.palette.on_surface_variant
//                 }
//                 StyledText {
//                     Layout.alignment: Qt.AlignHCenter
//                     text: root.isShiftPressed ? "Add wallpapers to favorites with Ctrl+Shift+A" : root.isAltPressed ? "Set a wallpaper first — it will appear here." : root.visMode === 2 ? "Hide wallpapers with Ctrl+Shift+H" : "Try changing filters or your search query."
//                     font.pointSize: Appearance.font.size.small
//                     color: Colours.alpha(Colours.palette.on_surface_variant, 0.6)
//                 }
//             }

//             Item {
//                 id: carouselContainer
//                 anchors.fill: parent
//                 anchors.topMargin: Appearance.padding.medium
//                 anchors.bottomMargin: Appearance.padding.medium
//                 clip: true

//                 readonly property real baseItemWidth: root._baseCardW
//                 readonly property real baseItemHeight: root._baseCardH
//                 readonly property bool showNavButtons: galleryModel.count > 1 && !root.isSettingsOpen

//                 WheelHandler {
//                     target: null
//                     acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
//                     onWheel: (event) => {
//                         // For vertical orientation, use Y axis primarily; for horizontal, use X axis
//                         let primaryDelta = root.isVertical ? event.angleDelta.y : event.angleDelta.x;
//                         let secondaryDelta = root.isVertical ? event.angleDelta.x : event.angleDelta.y;

//                         if (Math.abs(primaryDelta) > Math.abs(secondaryDelta)) {
//                             if (primaryDelta < 0) root.navigateDown();
//                             else root.navigateUp();
//                         } else {
//                             if (secondaryDelta < 0) root.navigateDown();
//                             else root.navigateUp();
//                         }
//                         event.accepted = true;
//                     }
//                 }

//                 // ── Navigation Buttons ──
//                 Item {
//                     id: navPrevBtn
//                     z: 10
//                     visible: carouselContainer.showNavButtons

//                     anchors.left: root.isVertical ? undefined : parent.left
//                     anchors.top: root.isVertical ? parent.top : undefined
//                     anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
//                     anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
//                     anchors.leftMargin: root.isVertical ? 0 : Appearance.padding.small
//                     anchors.topMargin: root.isVertical ? Appearance.padding.small : 0

//                     width: navPrevButton.width
//                     height: navPrevButton.height

//                     property bool hovered: navPrevHover.hovered

//                     IconButton {
//                         id: navPrevButton
//                         anchors.centerIn: parent
//                         icon: root.isVertical ? "\ue5c7" : "\ue5c4"
//                         type: IconButton.Tonal
//                         opacity: navPrevBtn.hovered ? 1.0 : 0.4
//                         Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.smaller } }
//                         onClicked: root.navigateUp()
//                     }

//                     HoverHandler { id: navPrevHover }
//                     Tooltip { target: navPrevBtn; text: root.isVertical ? "Previous (↑)" : "Previous (←)" }
//                 }

//                 Item {
//                     id: navNextBtn
//                     z: 10
//                     visible: carouselContainer.showNavButtons

//                     anchors.right: root.isVertical ? undefined : parent.right
//                     anchors.bottom: root.isVertical ? parent.bottom : undefined
//                     anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
//                     anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
//                     anchors.rightMargin: root.isVertical ? 0 : Appearance.padding.small
//                     anchors.bottomMargin: root.isVertical ? Appearance.padding.small : 0

//                     width: navNextButton.width
//                     height: navNextButton.height

//                     property bool hovered: navNextHover.hovered

//                     IconButton {
//                         id: navNextButton
//                         anchors.centerIn: parent
//                         icon: root.isVertical ? "\ue5c5" : "\ue5c8"
//                         type: IconButton.Tonal
//                         opacity: navNextBtn.hovered ? 1.0 : 0.4
//                         Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.smaller } }
//                         onClicked: root.navigateDown()
//                     }

//                     HoverHandler { id: navNextHover }
//                     Tooltip { target: navNextBtn; text: root.isVertical ? "Next (↓)" : "Next (→)" }
//                 }

//                 PathView {
//                     id: grid
//                     Component.onCompleted: root.carousel = grid
//                     Component.onDestruction: root.carousel = null
//                     anchors.fill: parent
//                     model: galleryModel
//                     pathItemCount: root.visibleItems
//                     cacheItemCount: 15

//                     snapMode: PathView.SnapToItem
//                     preferredHighlightBegin: 0.5
//                     preferredHighlightEnd: 0.5
//                     highlightRangeMode: PathView.StrictlyEnforceRange
//                     flickDeceleration: 2000
//                     maximumFlickVelocity: 2500
//                     interactive: true
//                     dragMargin: carouselContainer.baseItemWidth * 0.4
//                     highlightMoveDuration: root._isRapid ? 0 : root._isActive ? 150 : 350

//                     onCurrentIndexChanged: {
//                         if (currentIndex >= 0 && currentIndex < count) {
//                             let item = galleryModel.get(currentIndex);
//                             if (item && !root._isRapid) root.livePreview(item.path); // ← сразу
//                         }
//                     }
//                     // onCurrentIndexChanged: {
//                     //     if (currentIndex >= 0 && currentIndex < count) {
//                     //         let item = galleryModel.get(currentIndex);
//                     //         if (item) {
//                     //             previewDebounceTimer.pendingPath = item.path;
//                     //             previewDebounceTimer.restart();
//                     //         }
//                     //     }
//                     // }

//                     delegate: Item {
//                         id: cardDelegate
//                         required property int index
//                         required property string name
//                         required property string path
//                         required property string mediaType
//                         required property string tags
//                         required property bool isFav
//                         required property bool removing

//                         Component.onCompleted: {
//                             if (index === 0) {
//                                 console.log("[WP] First card path:", path);
//                             }
//                         }

//                         z: PathView.z ?? 0
//                         implicitWidth: carouselContainer.baseItemWidth
//                         implicitHeight: carouselContainer.baseItemHeight + Appearance.padding.small

//                         readonly property real targetScale: (PathView.itemScale ?? 0.5)
//                         readonly property real targetOpacity: (PathView.itemOpacity ?? 0.6)
//                         readonly property bool isCenterCard: Math.abs(targetScale - 1.0) < 0.05

//                         scale: targetScale
//                         opacity: PathView.onPath ? targetOpacity : 0
//                         visible: opacity > 0

//                         Item {
//                             id: transformContainer
//                             anchors.fill: parent
//                             transformOrigin: Item.Center

//                             scale: 0.0
//                             opacity: 0.0

//                             Component.onCompleted: {
//                                 if (root._isRapid) {
//                                     scale = 1.0;
//                                     opacity = 1.0;
//                                 } else if (!cardDelegate.removing) {
//                                     enterScaleAnim.restart();
//                                     enterOpacityAnim.restart();
//                                 }
//                             }

//                             NumberAnimation {
//                                 id: enterScaleAnim
//                                 target: transformContainer
//                                 property: "scale"
//                                 to: 1.0
//                                 duration: Appearance.anim.durations.expressiveDefaultSpatial
//                                 easing.type: Easing.OutBack
//                             }

//                             NumberAnimation {
//                                 id: enterOpacityAnim
//                                 target: transformContainer
//                                 property: "opacity"
//                                 to: 1.0
//                                 duration: root._isIdle ? Appearance.anim.durations.normal : Appearance.anim.durations.smaller
//                                 easing.type: Easing.OutSine
//                             }

//                             NumberAnimation {
//                                 id: exitScaleAnim
//                                 target: transformContainer
//                                 property: "scale"
//                                 to: 0.0
//                                 duration: Appearance.anim.durations.expressiveDefaultSpatial
//                             }

//                             NumberAnimation {
//                                 id: exitOpacityAnim
//                                 target: transformContainer
//                                 property: "opacity"
//                                 to: 0.0
//                                 duration: Appearance.anim.durations.expressiveDefaultSpatial
//                             }

//                             Item {
//                                 id: cardContent
//                                 anchors.fill: parent

//                                 StyledClippingRect {
//                                     id: imageClip
//                                     anchors.fill: parent
//                                     anchors.margins: Appearance.padding.small
//                                     radius: Appearance.rounding.large
//                                     color: Colours.palette.surface_variant

//                                     CachingImage {
//                                         anchors.fill: parent
//                                         path: cardDelegate.path
//                                         // path: cardDelegate.path.startsWith("file://") || cardDelegate.path.startsWith("http")
//                                         //     ? cardDelegate.path
//                                         //     : "file://" + cardDelegate.path
//                                         asynchronous: true
//                                     }

//                                     Rectangle {
//                                         anchors.bottom: parent.bottom
//                                         width: parent.width
//                                         height: parent.height / 2
//                                         opacity: cardDelegate.isCenterCard ? 1.0 : 0.4
//                                         gradient: Gradient {
//                                             GradientStop { position: 0.0; color: "transparent" }
//                                             GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7) }
//                                         }
//                                     }

//                                     Item {
//                                         id: favArea
//                                         anchors.top: parent.top
//                                         anchors.right: parent.right
//                                         width: 40
//                                         height: 40

//                                         HoverHandler { id: favHover }

//                                         StyledRect {
//                                             id: favButton
//                                             anchors.centerIn: parent
//                                             width: 28
//                                             height: 28
//                                             radius: Appearance.rounding.full
//                                             color: cardDelegate.isFav ? Colours.alpha(Colours.palette.tertiary_container, 0.9) : Colours.alpha(Colours.palette.surface, 0.7)
//                                             opacity: cardDelegate.isFav || favHover.hovered ? 1.0 : 0.0
//                                             visible: opacity > 0
//                                             scale: cardDelegate.isFav || favHover.hovered ? 1.0 : 0.7

//                                             Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.smaller } }
//                                             Behavior on scale { ScaleAnimator { duration: Appearance.anim.durations.smaller; easing.type: Easing.OutBack } }

//                                             StyledIcon {
//                                                 anchors.centerIn: parent
//                                                 text: cardDelegate.isFav ? "\ue866" : "\ue867"
//                                                 font.pointSize: Appearance.font.size.normal
//                                                 color: cardDelegate.isFav ? Colours.palette.tertiary : Colours.palette.on_surface
//                                             }

//                                             MouseArea {
//                                                 anchors.fill: parent
//                                                 cursorShape: Qt.PointingHandCursor
//                                                 onClicked: root.toggleFavForIndex(cardDelegate.index)
//                                             }
//                                         }
//                                     }

//                                     Loader {
//                                         anchors.top: parent.top
//                                         anchors.right: favArea.left
//                                         anchors.topMargin: Appearance.padding.small
//                                         anchors.rightMargin: 2
//                                         active: cardDelegate.mediaType !== "image"

//                                         sourceComponent: StyledRect {
//                                             color: Colours.alpha(Colours.palette.tertiary_container, 0.9)
//                                             radius: Appearance.rounding.small
//                                             implicitWidth: badgeText.implicitWidth + Appearance.padding.small * 2
//                                             implicitHeight: badgeText.implicitHeight + 2

//                                             StyledText {
//                                                 id: badgeText
//                                                 anchors.centerIn: parent
//                                                 text: cardDelegate.mediaType === "video" ? "MP4" : (cardDelegate.mediaType === "gif" ? "GIF" : cardDelegate.mediaType.toUpperCase())
//                                                 font.pointSize: Appearance.font.size.smaller
//                                                 font.weight: Font.DemiBold
//                                                 color: Colours.palette.on_tertiary_container
//                                             }
//                                         }
//                                     }

//                                     ColumnLayout {
//                                         anchors.left: parent.left
//                                         anchors.bottom: parent.bottom
//                                         anchors.right: parent.right
//                                         anchors.margins: Appearance.padding.medium
//                                         spacing: 2
//                                         opacity: cardDelegate.isCenterCard ? 1.0 : 0.0
//                                         visible: opacity > 0

//                                         StyledText {
//                                             Layout.fillWidth: true
//                                             text: cardDelegate.name
//                                             color: "white"
//                                             font.weight: Font.DemiBold
//                                             elide: Text.ElideRight
//                                         }
//                                         StyledText {
//                                             Layout.fillWidth: true
//                                             text: cardDelegate.tags || cardDelegate.path
//                                             color: "lightgray"
//                                             font.pointSize: Appearance.font.size.smaller
//                                             elide: Text.ElideRight
//                                         }
//                                     }

//                                     StateLayer {
//                                         anchors.fill: parent
//                                         radius: Appearance.rounding.large
//                                         function onClicked() { root.execute("", false); }
//                                     }
//                                 }
//                             }
//                         }

//                         onRemovingChanged: {
//                             if (removing) {
//                                 exitScaleAnim.restart();
//                                 exitOpacityAnim.restart();
//                             }
//                         }
//                     }

//                     path: root.isVertical ? verticalPath : horizontalPath

//                     Path {
//                         id: horizontalPath
//                         startX: 0
//                         startY: grid.height / 2

//                         PathAttribute { name: "itemScale"; value: 0.45 }
//                         PathAttribute { name: "itemOpacity"; value: 0.4 }
//                         PathAttribute { name: "z"; value: 0 }
//                         PathLine { x: grid.width * 0.15; relativeY: 0 }

//                         PathAttribute { name: "itemScale"; value: 0.68 }
//                         PathAttribute { name: "itemOpacity"; value: 0.6 }
//                         PathAttribute { name: "z"; value: 1 }
//                         PathLine { x: grid.width * 0.32; relativeY: 0 }

//                         PathAttribute { name: "itemScale"; value: 0.84 }
//                         PathAttribute { name: "itemOpacity"; value: 0.8 }
//                         PathAttribute { name: "z"; value: 2 }
//                         PathLine { x: grid.width * 0.5; relativeY: 0 }

//                         PathAttribute { name: "itemScale"; value: 1.0 }
//                         PathAttribute { name: "itemOpacity"; value: 1.0 }
//                         PathAttribute { name: "z"; value: 3 }
//                         PathLine { x: grid.width * 0.68; relativeY: 0 }

//                         PathAttribute { name: "itemScale"; value: 0.84 }
//                         PathAttribute { name: "itemOpacity"; value: 0.8 }
//                         PathAttribute { name: "z"; value: 2 }
//                         PathLine { x: grid.width * 0.85; relativeY: 0 }

//                         PathAttribute { name: "itemScale"; value: 0.68 }
//                         PathAttribute { name: "itemOpacity"; value: 0.6 }
//                         PathAttribute { name: "z"; value: 1 }
//                         PathLine { x: grid.width; relativeY: 0 }

//                         PathAttribute { name: "itemScale"; value: 0.45 }
//                         PathAttribute { name: "itemOpacity"; value: 0.4 }
//                         PathAttribute { name: "z"; value: 0 }
//                     }

//                     Path {
//                         id: verticalPath
//                         startX: grid.width / 2
//                         startY: 0

//                         PathAttribute { name: "itemScale"; value: 0.45 }
//                         PathAttribute { name: "itemOpacity"; value: 0.4 }
//                         PathAttribute { name: "z"; value: 0 }
//                         PathLine { relativeX: 0; y: grid.height * 0.15 }

//                         PathAttribute { name: "itemScale"; value: 0.68 }
//                         PathAttribute { name: "itemOpacity"; value: 0.6 }
//                         PathAttribute { name: "z"; value: 1 }
//                         PathLine { relativeX: 0; y: grid.height * 0.32 }

//                         PathAttribute { name: "itemScale"; value: 0.84 }
//                         PathAttribute { name: "itemOpacity"; value: 0.8 }
//                         PathAttribute { name: "z"; value: 2 }
//                         PathLine { relativeX: 0; y: grid.height * 0.5 }

//                         PathAttribute { name: "itemScale"; value: 1.0 }
//                         PathAttribute { name: "itemOpacity"; value: 1.0 }
//                         PathAttribute { name: "z"; value: 3 }
//                         PathLine { relativeX: 0; y: grid.height * 0.68 }

//                         PathAttribute { name: "itemScale"; value: 0.84 }
//                         PathAttribute { name: "itemOpacity"; value: 0.8 }
//                         PathAttribute { name: "z"; value: 2 }
//                         PathLine { relativeX: 0; y: grid.height * 0.85 }

//                         PathAttribute { name: "itemScale"; value: 0.68 }
//                         PathAttribute { name: "itemOpacity"; value: 0.6 }
//                         PathAttribute { name: "z"; value: 1 }
//                         PathLine { relativeX: 0; y: grid.height }

//                         PathAttribute { name: "itemScale"; value: 0.45 }
//                         PathAttribute { name: "itemOpacity"; value: 0.4 }
//                         PathAttribute { name: "z"; value: 0 }
//                     }
//                 }
//             }

//             StyledText {
//                 anchors.bottom: parent.bottom
//                 anchors.horizontalCenter: parent.horizontalCenter
//                 anchors.bottomMargin: 4
//                 text: "Hold[Alt]: History  •  Hold [Shift]: Favorites  •  [Ctrl+H]: Dot-files  •  [←→]: Navigate"
//                 font.pointSize: Appearance.font.size.smaller
//                 color: Colours.alpha(Colours.palette.on_surface_variant, 0.5)
//                 z: 5
//             }

//             // ══════════════════════════════════════════════════════════════════════════════
//             //  SETTINGS PANEL (Tabbed)
//             // ══════════════════════════════════════════════════════════════════════════════
//             StyledRect {
//                 id: settingsOverlay
//                 anchors.fill: parent
//                 z: 20

//                 color: Colours.palette.surface_container
//                 radius: Appearance.rounding.large
//                 // Note: clip is handled by parent (rightPanel in LauncherWrapper)
//                 // Don't add clip here as it would cut off dropdown menus

//                 opacity: root.isSettingsOpen ? 1.0 : 0.0
//                 visible: opacity > 0

//                 Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.normal } }

//                 // Block all mouse/wheel events from passing through to carousel
//                 MouseArea {
//                     anchors.fill: parent
//                     enabled: root.isSettingsOpen
//                     hoverEnabled: true
//                     acceptedButtons: Qt.AllButtons
//                     onWheel: (wheel) => wheel.accepted = true  // Block wheel events
//                 }

//                 RowLayout {
//                     anchors.fill: parent
//                     spacing: 0

//                     // ── Navigation Rail ──
//                     StyledRect {
//                         id: navRail
//                         Layout.fillHeight: true
//                         Layout.preferredWidth: 72
//                         color: Colours.palette.surface_container_low
//                         radius: Appearance.rounding.large

//                         ColumnLayout {
//                             anchors.fill: parent
//                             anchors.topMargin: Appearance.padding.medium
//                             anchors.bottomMargin: Appearance.padding.medium
//                             spacing: Appearance.spacing.small

//                             Repeater {
//                                 model: [
//                                     { icon: "\ue30d", label: "Display", index: 0 },
//                                     { icon: "\ue40a", label: "Theme", index: 1 },
//                                     { icon: "\ue3b6", label: "Gallery", index: 2 },
//                                     { icon: "\ue41b", label: "Slideshow", index: 3 },
//                                     { icon: "\ue8b8", label: "System", index: 4 },
//                                     { icon: "\ue312", label: "Keys", index: 5 }
//                                 ]

//                                 delegate: Item {
//                                     Layout.fillWidth: true
//                                     Layout.preferredHeight: 56

//                                     property bool isActive: root.settingsTabIndex === modelData.index

//                                     StyledRect {
//                                         anchors.centerIn: parent
//                                         width: 56
//                                         height: 48
//                                         radius: Appearance.rounding.full
//                                         color: parent.isActive
//                                             ? Colours.palette.secondary_container
//                                             : navItemHover.hovered
//                                                 ? Colours.alpha(Colours.palette.on_surface, 0.08)
//                                                 : "transparent"

//                                         Behavior on color { ColorAnimation { duration: Appearance.anim.durations.smaller } }

//                                         ColumnLayout {
//                                             anchors.centerIn: parent
//                                             spacing: 2

//                                             StyledIcon {
//                                                 Layout.alignment: Qt.AlignHCenter
//                                                 text: modelData.icon
//                                                 font.pointSize: Appearance.font.size.large
//                                                 color: parent.parent.parent.isActive
//                                                     ? Colours.palette.on_secondary_container
//                                                     : Colours.palette.on_surface_variant
//                                             }

//                                             StyledText {
//                                                 Layout.alignment: Qt.AlignHCenter
//                                                 text: modelData.label
//                                                 font.pointSize: Appearance.font.size.smaller
//                                                 font.weight: parent.parent.parent.isActive ? Font.DemiBold : Font.Normal
//                                                 color: parent.parent.parent.isActive
//                                                     ? Colours.palette.on_secondary_container
//                                                     : Colours.palette.on_surface_variant
//                                             }
//                                         }

//                                         HoverHandler { id: navItemHover }
//                                         TapHandler {
//                                             onTapped: root.settingsTabIndex = modelData.index
//                                         }
//                                     }
//                                 }
//                             }

//                             Item { Layout.fillHeight: true }
//                         }
//                     }

//                     // ── Content Area ──
//                     Item {
//                         Layout.fillWidth: true
//                         Layout.fillHeight: true
//                         clip: true

//                         StackLayout {
//                             id: settingsStack
//                             anchors.fill: parent
//                             anchors.margins: Appearance.padding.medium
//                             currentIndex: root.settingsTabIndex

//                             // ══════════════════════════════════════════════════════════════
//                             //  TAB 0: Display
//                             // ══════════════════════════════════════════════════════════════
//                             StyledFlickable {
//                                 id: displayScroll
//                                 contentWidth: width
//                                 contentHeight: displayCol.height
//                                 clip: true

//                                 ColumnLayout {
//                                     id: displayCol
//                                     width: parent.width
//                                     spacing: Appearance.spacing.small

//                                     // ── Target Section ──
//                                     SectionHeader { title: "Target" }

//                                     SplitButtonRow {
//                                         label: "Monitor"
//                                         menuItems: {
//                                             let items = [
//                                                 Qt.createQmlObject('import qs.components.controls; MenuItem { text: "All"; icon: "desktop_windows"; property string val: "All" }', displayCol)
//                                             ];
//                                             for (let m of root.monitorsList) {
//                                                 let name = m.name || m;
//                                                 items.push(Qt.createQmlObject(`import qs.components.controls; MenuItem { text: "${name}"; icon: "monitor"; property string val: "${name}" }`, displayCol));
//                                             }
//                                             return items;
//                                         }
//                                         Component.onCompleted: {
//                                             for (let i = 0; i < menuItems.length; i++) {
//                                                 if (menuItems[i].val === root.targetMonitor) active = menuItems[i];
//                                             }
//                                         }
//                                         onSelected: item => root.targetMonitor = item.val
//                                     }

//                                     // ── Resize Section ──
//                                     SectionHeader { title: "Resize" }

//                                     SplitButtonRow {
//                                         label: "Mode"
//                                         menuItems: root.resizeModes.map(m =>
//                                             Qt.createQmlObject(`import qs.components.controls; MenuItem { text: "${m.charAt(0).toUpperCase() + m.slice(1)}"; property string val: "${m}" }`, displayCol)
//                                         )
//                                         Component.onCompleted: {
//                                             for (let i = 0; i < menuItems.length; i++) {
//                                                 if (menuItems[i].val === root.resizeMode) active = menuItems[i];
//                                             }
//                                         }
//                                         onSelected: item => {
//                                             root.resizeMode = item.val;
//                                             root.displayMode = item.val;
//                                             root.saveTransitionConfig("resize", item.val);
//                                         }
//                                     }

//                                     RowLayout {
//                                         Layout.fillWidth: true
//                                         spacing: Appearance.spacing.medium

//                                         StyledText {
//                                             text: "Fill Color"
//                                             color: Colours.palette.on_surface
//                                         }

//                                         Item { Layout.fillWidth: true }

//                                         Rectangle {
//                                             width: 24
//                                             height: 24
//                                             radius: 4
//                                             color: "#" + root.fillColor.substring(0, 6)
//                                             border.width: 1
//                                             border.color: Colours.palette.outline
//                                         }

//                                         StyledTextField {
//                                             Layout.preferredWidth: 100
//                                             text: root.fillColor
//                                             onEditingFinished: {
//                                                 let clean = text.replace(/[^0-9a-fA-F]/g, "");
//                                                 if (clean.length >= 6) {
//                                                     let normalized = clean.substring(0, 8).padEnd(8, "f");
//                                                     root.fillColor = normalized;
//                                                     root.saveTransitionConfig("fill_color", normalized);
//                                                 }
//                                             }
//                                         }
//                                     }

//                                     SplitButtonRow {
//                                         label: "Filter"
//                                         menuItems: root.imageFilters.map(f =>
//                                             Qt.createQmlObject(`import qs.components.controls; MenuItem { text: "${f}"; property string val: "${f}" }`, displayCol)
//                                         )
//                                         Component.onCompleted: {
//                                             for (let i = 0; i < menuItems.length; i++) {
//                                                 if (menuItems[i].val === root.imageFilter) active = menuItems[i];
//                                             }
//                                         }
//                                         onSelected: item => {
//                                             root.imageFilter = item.val;
//                                             root.saveTransitionConfig("filter", item.val);
//                                         }
//                                     }

//                                     // ── Transition Section ──
//                                     CollapsibleSection {
//                                         Layout.fillWidth: true
//                                         title: "Transition"
//                                         expanded: false

//                                         SplitButtonRow {
//                                             label: "Type"
//                                             menuItems: root.transitionTypes.map(t =>
//                                                 Qt.createQmlObject(`import qs.components.controls; MenuItem { text: "${t}"; property string val: "${t}" }`, displayCol)
//                                             )
//                                             Component.onCompleted: {
//                                                 for (let i = 0; i < menuItems.length; i++) {
//                                                     if (menuItems[i].val === root.transitionType) active = menuItems[i];
//                                                 }
//                                             }
//                                             onSelected: item => {
//                                                 root.transitionType = item.val;
//                                                 root.saveTransitionConfig("transition_type", item.val);
//                                             }
//                                         }

//                                         SpinBoxRow {
//                                             label: "Duration (s)"
//                                             value: root.transitionDuration
//                                             min: 0.1
//                                             max: 10
//                                             step: 0.1
//                                             onValueModified: v => {
//                                                 root.transitionDuration = v;
//                                                 root.saveTransitionConfig("transition_duration", v);
//                                             }
//                                         }

//                                         SpinBoxRow {
//                                             label: "FPS"
//                                             value: root.transitionFps
//                                             min: 10
//                                             max: 144
//                                             step: 5
//                                             onValueModified: v => {
//                                                 root.transitionFps = v;
//                                                 root.saveTransitionConfig("transition_fps", v);
//                                             }
//                                         }

//                                         SpinBoxRow {
//                                             visible: root.transitionType === "simple"
//                                             label: "Step"
//                                             value: root.transitionStep
//                                             min: 1
//                                             max: 255
//                                             step: 1
//                                             onValueModified: v => {
//                                                 root.transitionStep = v;
//                                                 root.saveTransitionConfig("transition_step", v);
//                                             }
//                                         }

//                                         SpinBoxRow {
//                                             visible: root.transitionType === "wipe" || root.transitionType === "wave"
//                                             label: "Angle (°)"
//                                             value: root.transitionAngle
//                                             min: 0
//                                             max: 360
//                                             step: 15
//                                             onValueModified: v => {
//                                                 root.transitionAngle = v;
//                                                 root.saveTransitionConfig("transition_angle", v);
//                                             }
//                                         }

//                                         RowLayout {
//                                             visible: root.transitionType === "grow" || root.transitionType === "outer" || root.transitionType === "any"
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Position"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             Item { Layout.fillWidth: true }

//                                             StyledTextField {
//                                                 Layout.preferredWidth: 120
//                                                 text: root.transitionPos
//                                                 onEditingFinished: {
//                                                     root.transitionPos = text;
//                                                     root.saveTransitionConfig("transition_pos", text);
//                                                 }
//                                             }
//                                         }

//                                         RowLayout {
//                                             visible: root.transitionType === "fade"
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Bezier"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             Item { Layout.fillWidth: true }

//                                             StyledTextField {
//                                                 Layout.preferredWidth: 140
//                                                 text: root.transitionBezier
//                                                 onEditingFinished: {
//                                                     root.transitionBezier = text;
//                                                     root.saveTransitionConfig("transition_bezier", text);
//                                                 }
//                                             }
//                                         }

//                                         RowLayout {
//                                             visible: root.transitionType === "wave"
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Wave (W,H)"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             Item { Layout.fillWidth: true }

//                                             StyledTextField {
//                                                 Layout.preferredWidth: 80
//                                                 text: root.transitionWave
//                                                 onEditingFinished: {
//                                                     root.transitionWave = text;
//                                                     root.saveTransitionConfig("transition_wave", text);
//                                                 }
//                                             }
//                                         }

//                                         SwitchRow {
//                                             visible: root.transitionType === "grow" || root.transitionType === "outer" || root.transitionType === "any"
//                                             label: "Invert Y"
//                                             checked: root.transitionInvertY
//                                             onToggled: function() {
//                                                 root.transitionInvertY = !root.transitionInvertY;
//                                                 root.saveTransitionConfig("invert_y", root.transitionInvertY);
//                                             }
//                                         }
//                                     }

//                                     // ── Per-wallpaper Options Section ──
//                                     CollapsibleSection {
//                                         Layout.fillWidth: true
//                                         title: "Per-wallpaper Options"
//                                         expanded: false

//                                         PropertyRow {
//                                             label: "Current wallpaper"
//                                             value: root.originalWallpaper ? root._fileNameFromPath(root.originalWallpaper) : "None"
//                                         }

//                                         RowLayout {
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             TextButton {
//                                                 text: "Save Current"
//                                                 onClicked: {
//                                                     let args = ["wallpaper", "options", "set"];
//                                                     if (root.resizeMode !== "fill") args.push("--resize", root.resizeMode);
//                                                     if (root.fillColor !== "000000ff") args.push("--fill-color", root.fillColor);
//                                                     if (root.imageFilter !== "lanczos3") args.push("--filter", root.imageFilter);
//                                                     if (root.transitionType !== "fade") args.push("--transition-type", root.transitionType);
//                                                     if (root.transitionDuration !== 1.0) args.push("--transition-duration", String(root.transitionDuration));
//                                                     if (root.transitionFps !== 30) args.push("--transition-fps", String(root.transitionFps));
//                                                     root.sendIpc(args);
//                                                 }
//                                             }

//                                             TextButton {
//                                                 text: "Clear Options"
//                                                 onClicked: root.sendIpc(["wallpaper", "options", "clear"])
//                                             }
//                                         }
//                                     }

//                                     Item { Layout.preferredHeight: Appearance.padding.large }
//                                 }

//                                 StyledScrollBar { flickable: displayScroll; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }
//                             }

//                             // ══════════════════════════════════════════════════════════════
//                             //  TAB 1: Theme
//                             // ══════════════════════════════════════════════════════════════
//                             StyledFlickable {
//                                 id: themeScroll
//                                 contentWidth: width
//                                 contentHeight: themeCol.height
//                                 clip: true

//                                 ColumnLayout {
//                                     id: themeCol
//                                     width: parent.width
//                                     spacing: Appearance.spacing.small

//                                     // ── Mode Section ──
//                                     SectionHeader { title: "Mode" }

//                                     RowLayout {
//                                         Layout.fillWidth: true
//                                         spacing: Appearance.spacing.large

//                                         ToggleButton {
//                                             id: modeDarkToggle
//                                             label: "Dark"
//                                             toggled: false
//                                             onClicked: {
//                                                                                                 root.sendIpc(["theme", "mode", "set", "dark"]);
//                                             }
//                                         }

//                                         ToggleButton {
//                                             id: modeLightToggle
//                                             label: "Light"
//                                             toggled: false
//                                             onClicked: {
//                                                                                                 root.sendIpc(["theme", "mode", "set", "light"]);
//                                             }
//                                         }
//                                     }

//                                     SwitchRow {
//                                         id: themeAutoSwitch
//                                         label: "Auto (time-of-day)"
//                                         checked: false
//                                         onToggled: function() {
//                                             if (themeAutoSwitch.checked) root.sendIpc(["theme", "mode", "auto"]);
//                                             // else send IPC to disable auto?
//                                         }
//                                     }

//                                     PropertyRow {
//                                         label: "Current mode"
//                                         value: modeDarkToggle.toggled ? "dark" : "light"
//                                     }

//                                     // ── Palette Section ──
//                                     SectionHeader { title: "Palette" }

//                                     SplitButtonRow {
//                                         id: schemeSplitButton
//                                         label: "Scheme"
//                                         menuItems: root.themeVariants.map(v =>
//                                             Qt.createQmlObject(`import qs.components.controls; MenuItem { text: "${v.replace('scheme-', '')}"; property string val: "${v}" }`, themeCol)
//                                         )
//                                         Component.onCompleted: {
//                                             for (let i = 0; i < menuItems.length; i++) {

//                                             }
//                                         }
//                                         onSelected: item => {
//                                                                                         root.sendIpc(["theme", "palette", "set", item.val]);
//                                         }
//                                     }

//                                     PropertyRow {
//                                         label: "Active scheme"
//                                         value: schemeSplitButton.active ? schemeSplitButton.active.val.replace("scheme-", "") : ""
//                                     }

//                                     // ── Fine-tune Section ──
//                                     CollapsibleSection {
//                                         Layout.fillWidth: true
//                                         title: "Fine-tune"
//                                         expanded: true

//                                         RowLayout {
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Contrast"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             StyledSlider {
//                                                 Layout.fillWidth: true
//                                                 from: -1.0
//                                                 to: 1.0
//                                                 id: contrastSlider
//                                                 value: 0.0
//                                                 stepSize: 0.05
//                                                 onValueChanged: {
//                                                     root.sendIpc(["theme", "set", "contrast", String(value)]);
//                                                     themeRegenerateDebounce.restart();
//                                                 }
//                                             }

//                                             StyledText {
//                                                 text: contrastSlider.value.toFixed(2)
//                                                 color: Colours.palette.on_surface_variant
//                                                 Layout.preferredWidth: 40
//                                             }
//                                         }

//                                         RowLayout {
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Dark brightness"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             StyledSlider {
//                                                 Layout.fillWidth: true
//                                                 from: 0.0
//                                                 to: 1.0
//                                                 id: lightnessDarkSlider
//                                                 value: 0.5
//                                                 stepSize: 0.05
//                                                 onValueChanged: {
//                                                                                                         root.sendIpc(["theme", "set", "lightness-dark", String(value)]);
//                                                     themeRegenerateDebounce.restart();
//                                                 }
//                                             }

//                                             StyledText {
//                                                 text: lightnessDarkSlider.value.toFixed(2)
//                                                 color: Colours.palette.on_surface_variant
//                                                 Layout.preferredWidth: 40
//                                             }
//                                         }

//                                         RowLayout {
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Light brightness"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             StyledSlider {
//                                                 Layout.fillWidth: true
//                                                 from: 0.0
//                                                 to: 1.0
//                                                 id: lightnessLightSlider
//                                                 value: 0.5
//                                                 stepSize: 0.05
//                                                 onValueChanged: {
//                                                                                                         root.sendIpc(["theme", "set", "lightness-light", String(value)]);
//                                                     themeRegenerateDebounce.restart();
//                                                 }
//                                             }

//                                             StyledText {
//                                                 text: lightnessLightSlider.value.toFixed(2)
//                                                 color: Colours.palette.on_surface_variant
//                                                 Layout.preferredWidth: 40
//                                             }
//                                         }

//                                         RowLayout {
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Opacity"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             StyledSlider {
//                                                 Layout.fillWidth: true
//                                                 from: 0.0
//                                                 to: 1.0
//                                                 id: opacitySlider
//                                                 value: 1.0
//                                                 stepSize: 0.05
//                                                 onValueChanged: {
//                                                                                                         root.sendIpc(["theme", "set", "opacity", String(value)]);
//                                                     themeRegenerateDebounce.restart();
//                                                 }
//                                             }

//                                             StyledText {
//                                                 text: opacitySlider.value.toFixed(2)
//                                                 color: Colours.palette.on_surface_variant
//                                                 Layout.preferredWidth: 40
//                                             }
//                                         }

//                                         SpinBoxRow {
//                                             id: colorIndexSpinBox
//                                             label: "Color index (0-4)"
//                                             value: 0
//                                             min: 0
//                                             max: 4
//                                             step: 1
//                                             onValueModified: v => {
//                                                                                                 root.sendIpc(["theme", "set", "source-color-index", String(v)]);
//                                                 themeRegenerateDebounce.restart();
//                                             }
//                                         }

//                                         SplitButtonRow {
//                                             label: "Prefer"
//                                             menuItems: root.colorPreferences.map(p =>
//                                                 Qt.createQmlObject(`import qs.components.controls; MenuItem { text: "${p}"; property string val: "${p}" }`, themeCol)
//                                             )
//                                             Component.onCompleted: {
//                                                 for (let i = 0; i < menuItems.length; i++) {

//                                                 }
//                                             }
//                                             onSelected: item => {
//                                                                                                 root.sendIpc(["theme", "set", "prefer", item.val]);
//                                                 themeRegenerateDebounce.restart();
//                                             }
//                                         }

//                                         RowLayout {
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Fallback color"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             Item { Layout.fillWidth: true }

//                                             Rectangle {
//                                                 width: 24
//                                                 height: 24
//                                                 radius: 4
//                                                 color: "#" + (fallbackColorField.text ? fallbackColorField.text.substring(0, 6) : "4285f4")
//                                                 border.width: 1
//                                                 border.color: Colours.palette.outline
//                                             }

//                                             StyledTextField {
//                                                 id: fallbackColorField
//                                                 Layout.preferredWidth: 100

//                                                 onEditingFinished: {
//                                                     let clean = text.replace(/[^0-9a-fA-F]/g, "");
//                                                     if (clean.length >= 6) {
//                                                         root.sendIpc(["theme", "set", "fallback-color", clean.substring(0, 8).padEnd(8, "f")]);
//                                                         themeRegenerateDebounce.restart();
//                                                     }
//                                                 }

//                                             }
//                                         }
//                                     }

//                                     TextButton {
//                                         text: "Regenerate from current wallpaper"
//                                         onClicked: {
//                                             if (root.originalWallpaper) {
//                                                 root.sendIpc(["theme", "generate", root.originalWallpaper]);
//                                             }
//                                         }
//                                     }

//                                     Item { Layout.preferredHeight: Appearance.padding.large }
//                                 }

//                                 StyledScrollBar { flickable: themeScroll; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }
//                             }

//                             // ══════════════════════════════════════════════════════════════
//                             //  TAB 2: Gallery
//                             // ══════════════════════════════════════════════════════════════
//                             StyledFlickable {
//                                 id: galleryScroll
//                                 contentWidth: width
//                                 contentHeight: galleryCol.height
//                                 clip: true

//                                 ColumnLayout {
//                                     id: galleryCol
//                                     width: parent.width
//                                     spacing: Appearance.spacing.small

//                                     // ── Index Section ──
//                                     SectionHeader { title: "Index" }

//                                     RowLayout {
//                                         Layout.fillWidth: true
//                                         spacing: Appearance.spacing.medium

//                                         StyledText {
//                                             text: "Directory"
//                                             color: Colours.palette.on_surface
//                                         }

//                                         StyledTextField {
//                                             Layout.fillWidth: true
//                                             text: root.indexDir
//                                             onTextChanged: root.indexDir = text
//                                         }
//                                     }

//                                     SwitchRow {
//                                         label: "Force re-index"
//                                         checked: root.indexForce
//                                         onToggled: function() { root.indexForce = !root.indexForce }
//                                     }

//                                     TextButton {
//                                         text: "Index Now"
//                                         onClicked: {
//                                             let args = ["wallpaper", "index", root.indexDir];
//                                             if (root.indexForce) args.push("--force");
//                                             root.sendIpc(args);
//                                         }
//                                     }

//                                     // ── History Section ──
//                                     SectionHeader { title: "History" }

//                                     PropertyRow {
//                                         label: "Entries"
//                                         value: String(root.historyCount)
//                                     }

//                                     TextButton {
//                                         text: "Clear History"
//                                         onClicked: {
//                                             root.sendIpc(["wallpaper", "history", "clear"]);
//                                             root.historyCount = 0;
//                                         }
//                                     }

//                                     // ── Favorites Section ──
//                                     SectionHeader { title: "Favorites" }

//                                     PropertyRow {
//                                         label: "Entries"
//                                         value: String(root.favoritesCount)
//                                     }

//                                     TextButton {
//                                         text: "Clear All Favorites"
//                                         onClicked: {
//                                             // TODO: Add confirmation dialog
//                                             root.sendIpcWithResponse(["wallpaper", "fav", "list", "--limit", "1000"], resp => {
//                                                 if (resp && resp.status === "Ok" && resp.data) {
//                                                     let entries = resp.data.value || [];
//                                                     for (let e of entries) {
//                                                         if (e.path) root.sendIpc(["wallpaper", "fav", "rm", e.path]);
//                                                     }
//                                                     root.favoritesCount = 0;
//                                                 }
//                                             });
//                                         }
//                                     }

//                                     // ── Random & Sort Section ──
//                                     SectionHeader { title: "Random & Sort" }

//                                     SplitButtonRow {
//                                         label: "Sort by"
//                                         menuItems: root.sortFields.map(f =>
//                                             Qt.createQmlObject(`import qs.components.controls; MenuItem { text: "${f.charAt(0).toUpperCase() + f.slice(1)}"; property string val: "${f}" }`, galleryCol)
//                                         )
//                                         Component.onCompleted: {
//                                             for (let i = 0; i < menuItems.length; i++) {
//                                                 if (menuItems[i].val === root.sortBy) active = menuItems[i];
//                                             }
//                                         }
//                                         onSelected: item => root.sortBy = item.val
//                                     }

//                                     SwitchRow {
//                                         label: "Reverse order"
//                                         checked: root.sortReverse
//                                         onToggled: function() { root.sortReverse = !root.sortReverse }
//                                     }

//                                     Item { Layout.preferredHeight: Appearance.padding.large }
//                                 }

//                                 StyledScrollBar { flickable: galleryScroll; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }
//                             }

//                             // ══════════════════════════════════════════════════════════════
//                             //  TAB 3: Slideshow
//                             // ══════════════════════════════════════════════════════════════
//                             StyledFlickable {
//                                 id: slideshowScroll
//                                 contentWidth: width
//                                 contentHeight: slideshowCol.height
//                                 clip: true

//                                 ColumnLayout {
//                                     id: slideshowCol
//                                     width: parent.width
//                                     spacing: Appearance.spacing.small

//                                     // ── Slideshow Section ──
//                                     SectionHeader { title: "Slideshow" }

//                                     SwitchRow {
//                                         label: "Active"
//                                         checked: root.slideshowActive
//                                         onToggled: function() {
//                                             root.slideshowActive = !root.slideshowActive;
//                                             if (root.slideshowActive) {
//                                                 let args = ["daemon", "slideshow", "start", root.slideshowDir, "-i", String(Math.round(root.slideshowInterval))];
//                                                 if (root.slideshowTextFilter) args.push("--query", root.slideshowTextFilter);
//                                                 if (root.slideshowIncludeHidden) args.push("--include-dot");
//                                                 if (root.slideshowOnlyHidden) args.push("--only-dot");
//                                                 if (root.slideshowOnlyFavorites) args.push("--favorites");
//                                                 root.sendIpc(args);
//                                             } else {
//                                                 root.sendIpc(["daemon", "slideshow", "stop"]);
//                                             }
//                                         }
//                                     }

//                                     SpinBoxRow {
//                                         label: "Interval (sec)"
//                                         value: root.slideshowInterval
//                                         min: 10
//                                         max: 86400
//                                         step: 60
//                                         onValueModified: v => {
//                                             root.slideshowInterval = v;
//                                             root.saveSlideshowConfig("interval", v);
//                                         }
//                                     }

//                                     RowLayout {
//                                         Layout.fillWidth: true
//                                         spacing: Appearance.spacing.medium

//                                         StyledText {
//                                             text: "Directory"
//                                             color: Colours.palette.on_surface
//                                         }

//                                         StyledTextField {
//                                             Layout.fillWidth: true
//                                             text: root.slideshowDir
//                                             onEditingFinished: {
//                                                 root.slideshowDir = text;
//                                                 root.saveSlideshowConfig("dir", text);
//                                             }
//                                         }
//                                     }

//                                     // ── Filters Section ──
//                                     CollapsibleSection {
//                                         Layout.fillWidth: true
//                                         title: "Filters"
//                                         expanded: false

//                                         SwitchRow {
//                                             label: "Include hidden files"
//                                             checked: root.slideshowIncludeHidden
//                                             onToggled: function() {
//                                                 root.slideshowIncludeHidden = !root.slideshowIncludeHidden;
//                                                 if (root.slideshowIncludeHidden) root.slideshowOnlyHidden = false;
//                                                 root.saveSlideshowConfig("include_hidden", root.slideshowIncludeHidden);
//                                                 if (root.slideshowIncludeHidden) root.saveSlideshowConfig("only_hidden", false);
//                                             }
//                                         }

//                                         SwitchRow {
//                                             label: "Only hidden files"
//                                             checked: root.slideshowOnlyHidden
//                                             onToggled: function() {
//                                                 root.slideshowOnlyHidden = !root.slideshowOnlyHidden;
//                                                 if (root.slideshowOnlyHidden) root.slideshowIncludeHidden = false;
//                                                 root.saveSlideshowConfig("only_hidden", root.slideshowOnlyHidden);
//                                                 if (root.slideshowOnlyHidden) root.saveSlideshowConfig("include_hidden", false);
//                                             }
//                                         }

//                                         SwitchRow {
//                                             label: "Only favorites"
//                                             checked: root.slideshowOnlyFavorites
//                                             onToggled: function() {
//                                                 root.slideshowOnlyFavorites = !root.slideshowOnlyFavorites;
//                                                 root.saveSlideshowConfig("only_favorites", root.slideshowOnlyFavorites);
//                                             }
//                                         }

//                                         RowLayout {
//                                             Layout.fillWidth: true
//                                             spacing: Appearance.spacing.medium

//                                             StyledText {
//                                                 text: "Text filter"
//                                                 color: Colours.palette.on_surface
//                                             }

//                                             StyledTextField {
//                                                 Layout.fillWidth: true
//                                                 placeholderText: "name, tags, or color..."
//                                                 text: root.slideshowTextFilter
//                                                 onEditingFinished: {
//                                                     root.slideshowTextFilter = text;
//                                                     root.saveSlideshowConfig("text_filter", text || "");
//                                                 }
//                                             }
//                                         }
//                                     }

//                                     Item { Layout.preferredHeight: Appearance.padding.large }
//                                 }

//                                 StyledScrollBar { flickable: slideshowScroll; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }
//                             }

//                             // ══════════════════════════════════════════════════════════════
//                             //  TAB 4: System
//                             // ══════════════════════════════════════════════════════════════
//                             StyledFlickable {
//                                 id: systemScroll
//                                 contentWidth: width
//                                 contentHeight: systemCol.height
//                                 clip: true

//                                 ColumnLayout {
//                                     id: systemCol
//                                     width: parent.width
//                                     spacing: Appearance.spacing.small

//                                     // ── Daemon Section ──
//                                     SectionHeader { title: "Daemon" }

//                                     PropertyRow {
//                                         label: "Status"
//                                         value: root.daemonStatus
//                                     }

//                                     TextButton {
//                                         text: "Restart Daemon"
//                                         onClicked: {
//                                             root.sendIpc(["daemon", "stop"]);
//                                             root.daemonStatus = "restarting...";
//                                             // Daemon start is blocking, need to spawn it via shell
//                                             Qt.callLater(() => {
//                                                 Quickshell.execDetached([root.walltoolBin, "daemon", "start"]);
//                                                 Qt.callLater(() => root.fetchDaemonData(), 1000);
//                                             });
//                                         }
//                                     }

//                                     // ── Game Mode Section ──
//                                     SectionHeader { title: "Game Mode" }

//                                     SwitchRow {
//                                         label: "Game Mode (pause all)"
//                                         checked: root.gameMode
//                                         onToggled: function() {
//                                             root.gameMode = !root.gameMode;
//                                             root.sendIpc(root.gameMode ? ["daemon", "pause-all"] : ["daemon", "resume-all"]);
//                                         }
//                                     }

//                                     // ── Monitors Section ──
//                                     SectionHeader { title: "Monitors" }

//                                     Repeater {
//                                         model: root.monitorsList

//                                         delegate: PropertyRow {
//                                             label: modelData.name || modelData
//                                             value: modelData.resolution || ""
//                                         }
//                                     }

//                                     TextButton {
//                                         text: "Identify Monitors"
//                                         onClicked: root.sendIpc(["monitor", "identify"])
//                                     }

//                                     // ── Config Section ──
//                                     SectionHeader { title: "Config" }

//                                     TextButton {
//                                         text: "Edit config.toml"
//                                         onClicked: root.sendIpc(["config", "edit"])
//                                     }

//                                     SplitButtonRow {
//                                         label: "Profile"
//                                         menuItems: root.profilesList.map(p =>
//                                             Qt.createQmlObject(`import qs.components.controls; MenuItem { text: "${p}"; property string val: "${p}" }`, systemCol)
//                                         )
//                                         Component.onCompleted: {
//                                             for (let i = 0; i < menuItems.length; i++) {
//                                                 if (menuItems[i].val === root.currentProfile) active = menuItems[i];
//                                             }
//                                         }
//                                         onSelected: item => root.currentProfile = item.val
//                                     }

//                                     RowLayout {
//                                         Layout.fillWidth: true
//                                         spacing: Appearance.spacing.medium

//                                         TextButton {
//                                             text: "Save"
//                                             enabled: root.currentProfile !== ""
//                                             onClicked: root.sendIpc(["config", "profile", "save", root.currentProfile])
//                                         }

//                                         TextButton {
//                                             text: "Load"
//                                             enabled: root.currentProfile !== ""
//                                             onClicked: root.sendIpc(["config", "profile", "load", root.currentProfile])
//                                         }

//                                         TextButton {
//                                             text: "Delete"
//                                             enabled: root.currentProfile !== ""
//                                             onClicked: root.sendIpc(["config", "profile", "rm", root.currentProfile])
//                                         }
//                                     }

//                                     Item { Layout.preferredHeight: Appearance.padding.large }
//                                 }

//                                 StyledScrollBar { flickable: systemScroll; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }
//                             }

//                             // ══════════════════════════════════════════════════════════════
//                             //  TAB 5: Keys (Shortcuts Reference)
//                             // ══════════════════════════════════════════════════════════════
//                             StyledFlickable {
//                                 id: keysScroll
//                                 contentWidth: width
//                                 contentHeight: keysCol.height
//                                 clip: true

//                                 ColumnLayout {
//                                     id: keysCol
//                                     width: parent.width
//                                     spacing: Appearance.spacing.small

//                                     SectionHeader { title: "Navigation" }
//                                     PropertyRow { label: "← / → (or ↑ / ↓)"; value: "Navigate carousel" }
//                                     PropertyRow { label: "Enter"; value: "Apply wallpaper" }
//                                     PropertyRow { label: "Esc"; value: "Cancel and close" }
//                                     PropertyRow { label: "Alt+Enter"; value: "Apply in Span mode" }

//                                     SectionHeader { title: "Settings & Modes" }
//                                     PropertyRow { label: "Ctrl+I"; value: "Open / close settings" }
//                                     PropertyRow { label: "Ctrl+M"; value: "Toggle dark / light" }
//                                     PropertyRow { label: "Ctrl+T"; value: "Next palette" }
//                                     PropertyRow { label: "Ctrl+H"; value: "Cycle dot-file modes" }
//                                     PropertyRow { label: "Ctrl+R"; value: "Set random wallpaper" }
//                                     PropertyRow { label: "Ctrl+G"; value: "Toggle Game Mode" }

//                                     SectionHeader { title: "Favorites & Hidden" }
//                                     PropertyRow { label: "Ctrl+Shift+A"; value: "Add to favorites" }
//                                     PropertyRow { label: "Ctrl+Shift+D"; value: "Remove from favorites" }
//                                     PropertyRow { label: "Ctrl+Shift+H"; value: "Toggle hidden status" }

//                                     SectionHeader { title: "History" }
//                                     PropertyRow { label: "Ctrl+["; value: "Previous in history" }
//                                     PropertyRow { label: "Ctrl+]"; value: "Next in history" }

//                                     SectionHeader { title: "View Modes (Hold)" }
//                                     PropertyRow { label: "Alt (hold)"; value: "View history" }
//                                     PropertyRow { label: "Shift (hold)"; value: "View favorites" }

//                                     Item { Layout.preferredHeight: Appearance.padding.large }
//                                 }

//                                 StyledScrollBar { flickable: keysScroll; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }
