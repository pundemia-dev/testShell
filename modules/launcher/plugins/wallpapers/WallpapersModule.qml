import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.content

// Wallpaper Engine: state + walltool IPC + gallery model + lifecycle.
// The visual half lives in WallPanel (carousel + settings overlay).
LauncherModule {
    id: root

    hasLeftPanel: false
    hasRightPanel: true

    // ── Orientation ──
    property bool isVertical: false

    // ── Sizing ──
    readonly property real imageScale:    Config.getCustom("wallpapers", "imageScale", 2.0) ?? 2.0
    readonly property int  visibleItems:  Config.getCustom("wallpapers", "visibleItems", 5) ?? 5
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

    // Читается компонентами панели (WallPanel/WallCarousel) через mod.galleryModel
    readonly property ListModel galleryModel: ListModel {}

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
            if (root.carousel && root.galleryModel.count > 0) {
                root.carousel.currentIndex = targetIndex;
                root.carousel.positionViewAtIndex(targetIndex, PathView.Center);
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

    // Дебаунс регенерации темы — дергается ползунками Theme-таба
    function restartThemeDebounce() { themeDebounce.restart(); }

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
            for (let i = root.galleryModel.count - 1; i >= 0; i--) {
                if (root.galleryModel.get(i).removing) { root.galleryModel.remove(i); removed = true; }
            }
            if (removed && root.carousel && cur) {
                let idx = root._findIndexByPath(cur);
                if (idx >= 0) root.carousel.currentIndex = idx;
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
                icon: ""
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
        WallPanel {
            mod: root
        }
    }
}
