import QtQuick
import QtMultimedia
import qs.services
import qs.config
import qs.utils
import qs.components
import qs.components.images

Item {
    id: root
    anchors.fill: parent

    required property string monitorName

    property var mState: WallpaperState.forMonitor(monitorName) || ({})
    property string currentPath: mState.path || ""
    property string currentMediaType: mState.media_type || "image"

    // ── Tier-aware transition durations ──
    readonly property int _tier: WallpaperState.transitionTier
    readonly property bool _isIdle: _tier === 0
    readonly property bool _isActive: _tier === 1
    readonly property bool _isRapid: _tier === 2

    readonly property int _fadeDuration: _isRapid ? 0 : (_isActive ? 100 : Appearance.anim.durations.normal)
    readonly property int _scaleDuration: _isIdle ? Appearance.anim.durations.normal : 0
    readonly property real _initialScale: _isIdle ? 1.03 : 1.0

    // Указатель на текущий активный слот
    property Item activeSlot: slotOne

    Connections {
        target: WallpaperState
        function onStateUpdated() {
            root.mState = WallpaperState.forMonitor(root.monitorName) || ({});
        }
    }

    onCurrentPathChanged: {
        if (!currentPath) {
            slotOne.hide();
            slotTwo.hide();
            return;
        }

        // Переключаем ping-pong слоты
        let nextSlot = (activeSlot === slotOne) ? slotTwo : slotOne;

        // В Rapid-режиме мгновенно глушим старый слот, чтобы не тратить ресурсы GPU
        if (root._isRapid) {
            activeSlot.hide(true);
        }

        activeSlot = nextSlot;
        nextSlot.load(currentPath, currentMediaType, mState);
    }

    // ── Fallback ──
    Loader {
        anchors.fill: parent
        active: !root.currentPath
        asynchronous: true
        sourceComponent: StyledRect {
            color: Colours.palette.background
            StyledIcon {
                anchors.centerIn: parent
                text: "\ue3f4"
                font.pointSize: 48
                color: Colours.alpha(Colours.palette.on_background, 0.1)
            }
        }
    }

    // ── Ping-pong слоты ──
    MediaSlot { id: slotOne }
    MediaSlot { id: slotTwo }

    // ════════════════════════════════════════════════════════════════
        // MEDIA SLOT (Компонент слота)
        // ════════════════════════════════════════════════════════════════
        component MediaSlot: Item {
            id: slot
            anchors.fill: parent
            clip: true

            opacity: 0
            scale: root._initialScale

            // ИСПРАВЛЕНИЕ 1: Animator не меняет opacity в реальном времени,
            // поэтому опираемся на логические состояния слота
            visible: isActive || hideAnim.running || opacity > 0

            property bool isActive: false
            property string loadedPath: ""
            property string mediaType: "image"

            property bool isSpan: false
            property real fillModeCalculated: Image.PreserveAspectCrop

            // ИСПРАВЛЕНИЕ 2: Состояние ошибки вынесено на уровень самого слота
            property bool isError: false

            function load(path, type, stateData) {
                isError = false; // Сбрасываем ошибку при новой загрузке
                isActive = true;
                loadedPath = path;
                mediaType = type;

                isSpan = (stateData.mode === "span");

                let fm = stateData.mode;
                if (fm === "fit") fillModeCalculated = Image.PreserveAspectFit;
                else if (fm === "stretch" || fm === "span") fillModeCalculated = Image.Stretch;
                else if (fm === "center") fillModeCalculated = Image.Pad;
                else fillModeCalculated = Image.PreserveAspectCrop;

                imgPlayer.visible = (type === "image");
                gifPlayer.visible = (type === "gif");

                videoLoader.active = (type === "video");

                if (root._isRapid) {
                    commitShow();
                } else {
                    // ИСПРАВЛЕНИЕ 3: Если медиа закэшировано, onStatusChanged не сработает.
                    // Принудительно проверяем статус сразу после назначения.
                    if (type === "image") imgPlayer.checkStatus();
                    else if (type === "gif") gifPlayer.checkStatus();
                }
            }

            function onMediaReady(pathReady) {
                if (pathReady !== loadedPath || !isActive) return;
                commitShow();
            }

            function commitShow() {
                if (root.activeSlot !== slot) return;

                hideAnim.stop();
                if (root._isRapid) {
                    slot.opacity = 1;
                    slot.scale = 1;
                } else {
                    loadAnim.restart();
                }

                let other = (slot === slotOne) ? slotTwo : slotOne;
                if (other.isActive || other.opacity > 0) {
                    other.hide(root._isRapid);
                }
            }

            function hide(instant) {
                isActive = false;
                loadAnim.stop();

                if (instant) {
                    slot.opacity = 0;
                    slot.scale = root._initialScale;
                    cleanup();
                } else {
                    hideAnim.restart();
                }
            }

            function cleanup() {
                if (!isActive) {
                    loadedPath = "";
                    videoLoader.active = false;
                }
            }

            ParallelAnimation {
                id: loadAnim
                OpacityAnimator { target: slot; to: 1; duration: root._fadeDuration; easing.type: Easing.OutSine }
                ScaleAnimator   { target: slot; to: 1; duration: root._scaleDuration; easing.type: Easing.OutQuart }
            }

            ParallelAnimation {
                id: hideAnim
                OpacityAnimator { target: slot; to: 0; duration: root._fadeDuration; easing.type: Easing.InSine }
                onFinished: slot.cleanup()
            }

            CachingImage {
                id: imgPlayer
                anchors.fill: parent

                scale: slot.isSpan ? Math.max(root.mState.scale_x || 1.0, root.mState.scale_y || 1.0) : 1.0
                transformOrigin: Item.TopLeft
                x: slot.isSpan ? -(width * scale * (root.mState.offset_x || 0.0)) : 0
                y: slot.isSpan ? -(height * scale * (root.mState.offset_y || 0.0)) : 0

                path: imgPlayer.visible ? slot.loadedPath : ""
                fillMode: slot.fillModeCalculated
                asynchronous: true

                function checkStatus() {
                    if (!visible) return;
                    if (status === Image.Ready && path === slot.loadedPath) slot.onMediaReady(path);
                    else if (status === Image.Error) slot.handleLoadError();
                }

                onStatusChanged: checkStatus()
                onPathChanged: checkStatus()
            }

            AnimatedImage {
                id: gifPlayer
                anchors.fill: parent

                scale: slot.isSpan ? Math.max(root.mState.scale_x || 1.0, root.mState.scale_y || 1.0) : 1.0
                transformOrigin: Item.TopLeft
                x: slot.isSpan ? -(width * scale * (root.mState.offset_x || 0.0)) : 0
                y: slot.isSpan ? -(height * scale * (root.mState.offset_y || 0.0)) : 0

                source: (gifPlayer.visible && slot.loadedPath) ? `file://${slot.loadedPath}` : ""
                fillMode: slot.fillModeCalculated
                asynchronous: true
                playing: visible && !(root.mState.paused || false)
                cache: false

                function checkStatus() {
                    if (!visible) return;
                    // AnimatedImage использует source (QUrl), переводим в строку для сравнения
                    let currentSource = String(source).replace("file://", "");
                    if (status === AnimatedImage.Ready && currentSource === slot.loadedPath) {
                        slot.onMediaReady(slot.loadedPath);
                    } else if (status === AnimatedImage.Error) {
                        slot.handleLoadError();
                    }
                }

                onStatusChanged: checkStatus()
                onSourceChanged: checkStatus()
            }

            Loader {
                id: videoLoader
                anchors.fill: parent
                active: false
                asynchronous: true

                sourceComponent: Item {
                    anchors.fill: parent

                    MediaPlayer {
                        id: player
                        source: slot.loadedPath ? `file://${slot.loadedPath}` : ""
                        loops: MediaPlayer.Infinite
                        videoOutput: videoOut
                        audioOutput: AudioOutput {
                            muted: root.mState.muted ?? true
                            volume: (root.mState.volume ?? 50) / 100.0
                        }

                        onMediaStatusChanged: {
                            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
                                slot.onMediaReady(slot.loadedPath);
                                if (!(root.mState.paused || false)) player.play();
                            } else if (mediaStatus === MediaPlayer.InvalidMedia) {
                                slot.handleLoadError();
                            }
                        }
                    }

                    VideoOutput {
                        id: videoOut
                        anchors.fill: parent

                        scale: slot.isSpan ? Math.max(root.mState.scale_x || 1.0, root.mState.scale_y || 1.0) : 1.0
                        transformOrigin: Item.TopLeft
                        x: slot.isSpan ? -(width * scale * (root.mState.offset_x || 0.0)) : 0
                        y: slot.isSpan ? -(height * scale * (root.mState.offset_y || 0.0)) : 0

                        fillMode: (root.mState.mode === "fit" || root.mState.mode === "center")
                                  ? VideoOutput.PreserveAspectFit
                                  : (root.mState.mode === "stretch" || root.mState.mode === "span"
                                     ? VideoOutput.Stretch
                                     : VideoOutput.PreserveAspectCrop)
                    }
                }
            }

            // ── ИСПРАВЛЕНИЕ: Error fallback ──
            Loader {
                anchors.fill: parent
                active: slot.isError
                sourceComponent: StyledRect {
                    color: Colours.palette.background
                    StyledIcon {
                        anchors.centerIn: parent
                        text: "\ue002" // Иконка ошибки
                        font.pointSize: 48
                        color: Colours.alpha(Colours.palette.error, 0.3)
                    }
                }
            }

            function handleLoadError() {
                console.warn("[Wallpaper] Failed to load media:", slot.loadedPath);
                slot.isError = true;
            }
        }
}

// import QtQuick
// import QtMultimedia
// import qs.services
// import qs.config
// import qs.utils
// import qs.components
// import qs.components.images

// Item {
//     id: root

//     anchors.fill: parent

//     required property string monitorName

//     property var mState: WallpaperState.forMonitor(monitorName) || ({})
//     property string currentPath: mState.path || ""
//     property string currentMediaType: mState.media_type || "image"

//     property Item currentSlot: null

//     // ── Tier-aware transition durations ───────────────────────────────
//     readonly property int _tier: WallpaperState.transitionTier
//     readonly property bool _isIdle: _tier === 0
//     readonly property bool _isActive: _tier === 1
//     readonly property bool _isRapid: _tier === 2

//     readonly property int _fadeDuration: _isRapid ? 0 : _isActive ? 100 : Appearance.anim.durations.normal
//     readonly property int _scaleDuration: _isIdle ? Appearance.anim.durations.normal : 0
//     readonly property real _initialScale: _isIdle ? 1.03 : 1.0

//     Connections {
//         target: WallpaperState
//         function onStateUpdated() {
//             root.mState = WallpaperState.forMonitor(root.monitorName) || ({});
//         }
//     }

//     onCurrentPathChanged: {
//         if (!currentPath) {
//             currentSlot = null;
//             return;
//         }

//         if (currentSlot !== slotOne) {
//             slotOne.loadMedia();
//         } else {
//             slotTwo.loadMedia();
//         }
//     }

//     onMStateChanged: {
//         let newPath = mState.path || "";
//         if (newPath !== currentPath) {
//             currentPath = newPath;
//         }
//     }

//     // ── Fallback ─────────────────────────────────────────────────────
//     Loader {
//         anchors.fill: parent
//         active: !root.currentPath
//         asynchronous: true

//         sourceComponent: StyledRect {
//             color: Colours.palette.background

//             StyledIcon {
//                 anchors.centerIn: parent
//                 text: "\ue3f4"
//                 font.pointSize: 48
//                 color: Colours.alpha(Colours.palette.on_background, 0.1)
//             }
//         }
//     }

//     // ── Ping-pong slots ──────────────────────────────────────────────
//     MediaSlot { id: slotOne }
//     MediaSlot { id: slotTwo }

//     // ════════════════════════════════════════════════════════════════
//     component MediaSlot: Item {
//         id: slot

//         anchors.fill: parent
//         clip: true

//         opacity: 0
//         scale: root._initialScale

//         property bool isActive: false
//         property string frozenPath: ""
//         property string frozenMediaType: ""

//         function loadMedia() {
//             isActive = false;
//             frozenPath = root.currentPath;
//             frozenMediaType = root.currentMediaType;

//             // In rapid mode, immediately unload the other slot
//             if (root._isRapid) {
//                 let other = (slot === slotOne) ? slotTwo : slotOne;
//                 if (other.isActive) {
//                     other.isActive = false;
//                     other.opacity = 0;
//                     other.scale = root._initialScale;
//                     other.gcTimer.restart();
//                 }
//             }

//             let mt = frozenMediaType;
//             if (mt === "video") {
//                 innerLoader.sourceComponent = videoComp;
//             } else if (mt === "gif") {
//                 innerLoader.sourceComponent = gifComp;
//             } else {
//                 innerLoader.sourceComponent = imageComp;
//             }
//         }

//         function onMediaReady() {
//             isActive = true;
//             root.currentSlot = slot;
//         }

//         function unloadIfInactive() {
//             if (!isActive) {
//                 gcTimer.restart();
//             }
//         }

//         // Deferred GC to avoid destroying components mid-transition
//         Timer {
//             id: gcTimer
//             interval: root._isRapid ? 16 : root._fadeDuration + 50
//             onTriggered: {
//                 if (!slot.isActive) {
//                     innerLoader.sourceComponent = null;
//                 }
//             }
//         }

//         // ── Opacity transition (all tiers except rapid) ──────────────
//         Behavior on opacity {
//             enabled: !root._isRapid
//             NumberAnimation {
//                 duration: root._fadeDuration
//                 easing.type: Easing.BezierSpline
//                 easing.bezierCurve: slot.opacity > 0.5
//                     ? Appearance.anim.curves.standardAccel
//                     : Appearance.anim.curves.standardDecel
//             }
//         }

//         // ── Scale transition (idle only) ─────────────────────────────
//         Behavior on scale {
//             enabled: root._isIdle
//             NumberAnimation {
//                 duration: root._scaleDuration
//                 easing.type: Easing.BezierSpline
//                 easing.bezierCurve: slot.scale > 1.0
//                     ? Appearance.anim.curves.standardAccel
//                     : Appearance.anim.curves.emphasizedDecel
//             }
//         }

//         // ── State machine ────────────────────────────────────────────
//         states: State {
//             name: "visible"
//             when: root.currentSlot === slot

//             PropertyChanges {
//                 target: slot
//                 opacity: 1
//                 scale: 1
//             }
//         }

//         onStateChanged: {
//             // When leaving visible state, schedule cleanup after transition
//             if (state !== "visible" && !isActive) {
//                 if (root._isRapid) {
//                     // Instant cleanup
//                     opacity = 0;
//                     scale = root._initialScale;
//                     gcTimer.restart();
//                 } else {
//                     // Behavior handles the fade-out animation;
//                     // gcTimer interval already accounts for _fadeDuration
//                     gcTimer.restart();
//                 }
//             }
//         }

//         Loader {
//             id: innerLoader
//             anchors.fill: parent
//             asynchronous: !root._isRapid
//         }

//         readonly property bool isSpan: root.mState.mode === "span"

//         function fillModeForImage() {
//             switch (root.mState.mode) {
//                 case "fit":     return Image.PreserveAspectFit;
//                 case "stretch": return Image.Stretch;
//                 case "center":  return Image.Pad;
//                 default:        return Image.PreserveAspectCrop;
//             }
//         }

//         // ── Static image ─────────────────────────────────────────────
//         Component {
//             id: imageComp

//             CachingImage {
//                 width:  slot.isSpan ? parent.width  * (root.mState.scale_x || 1.0) : parent.width
//                 height: slot.isSpan ? parent.height * (root.mState.scale_y || 1.0) : parent.height
//                 x: slot.isSpan ? -(width  * (root.mState.offset_x || 0.0)) : 0
//                 y: slot.isSpan ? -(height * (root.mState.offset_y || 0.0)) : 0

//                 path: slot.frozenPath
//                 fillMode: slot.isSpan ? Image.Stretch : slot.fillModeForImage()

//                 onStatusChanged: {
//                     if (status === Image.Ready) slot.onMediaReady();
//                     if (status === Image.Error) slot.handleLoadError();
//                 }
//                 Component.onCompleted: {
//                     if (status === Image.Ready) slot.onMediaReady();
//                 }
//             }
//         }

//         // ── Animated GIF ─────────────────────────────────────────────
//         Component {
//             id: gifComp

//             AnimatedImage {
//                 width:  slot.isSpan ? parent.width  * (root.mState.scale_x || 1.0) : parent.width
//                 height: slot.isSpan ? parent.height * (root.mState.scale_y || 1.0) : parent.height
//                 x: slot.isSpan ? -(width  * (root.mState.offset_x || 0.0)) : 0
//                 y: slot.isSpan ? -(height * (root.mState.offset_y || 0.0)) : 0

//                 source:       slot.frozenPath ? `file://${slot.frozenPath}` : ""
//                 fillMode:     slot.isSpan ? AnimatedImage.Stretch : slot.fillModeForImage()
//                 asynchronous: true
//                 playing:      !(root.mState.paused || false)
//                 cache:        false

//                 onStatusChanged: {
//                     if (status === AnimatedImage.Ready) slot.onMediaReady();
//                     if (status === AnimatedImage.Error) slot.handleLoadError();
//                 }
//                 Component.onCompleted: {
//                     if (status === AnimatedImage.Ready) slot.onMediaReady();
//                 }
//             }
//         }

//         // ── Video ─────────────────────────────────────────────────────
//         Component {
//             id: videoComp

//             Item {
//                 id: videoRoot

//                 width: parent.width
//                 height: parent.height

//                 property bool mPaused: root.mState.paused || false

//                 onMPausedChanged: {
//                     if (mPaused)
//                         player.pause();
//                     else if (player.playbackState !== MediaPlayer.PlayingState)
//                         player.play();
//                 }

//                 MediaPlayer {
//                     id: player

//                     source: slot.frozenPath ? `file://${slot.frozenPath}` : ""
//                     loops: MediaPlayer.Infinite
//                     videoOutput: videoOut

//                     audioOutput: AudioOutput {
//                         muted:  root.mState.muted ?? true
//                         volume: (root.mState.volume ?? 50) / 100.0
//                     }

//                     onMediaStatusChanged: {
//                         if (mediaStatus === MediaPlayer.LoadedMedia ||
//                             mediaStatus === MediaPlayer.BufferedMedia) {
//                             slot.onMediaReady();
//                             if (!videoRoot.mPaused) player.play();
//                         }
//                         if (mediaStatus === MediaPlayer.InvalidMedia) {
//                             slot.handleLoadError();
//                         }
//                     }

//                     Component.onCompleted: {
//                         if (root.currentPath && !videoRoot.mPaused)
//                             player.play();
//                     }
//                 }

//                 VideoOutput {
//                     id: videoOut

//                     width:  slot.isSpan ? parent.width  * (root.mState.scale_x || 1.0) : parent.width
//                     height: slot.isSpan ? parent.height * (root.mState.scale_y || 1.0) : parent.height
//                     x: slot.isSpan ? -(width  * (root.mState.offset_x || 0.0)) : 0
//                     y: slot.isSpan ? -(height * (root.mState.offset_y || 0.0)) : 0

//                     fillMode: {
//                         switch (root.mState.mode) {
//                             case "fit":     return VideoOutput.PreserveAspectFit;
//                             case "stretch": return VideoOutput.Stretch;
//                             case "span":    return VideoOutput.Stretch;
//                             case "center":  return VideoOutput.PreserveAspectFit;
//                             default:        return VideoOutput.PreserveAspectCrop;
//                         }
//                     }
//                 }
//             }
//         }

//         // ── Error fallback ────────────────────────────────────────────
//         function handleLoadError() {
//             console.warn("[Wallpaper] Failed to load media:", slot.frozenPath);
//             innerLoader.sourceComponent = errorComp;
//         }

//         Component {
//             id: errorComp

//             StyledRect {
//                 anchors.fill: parent
//                 color: Colours.palette.background

//                 StyledIcon {
//                     anchors.centerIn: parent
//                     text: "\ue002"
//                     font.pointSize: 48
//                     color: Colours.alpha(Colours.palette.error, 0.3)
//                 }
//             }
//         }
//     }
// }
