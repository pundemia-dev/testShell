pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

import "exclusions"
import "backgrounds"
// import "wallpaper"
import "border"
import "corners"
import "panels"
import qs.modules.bar
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.stash
import qs.modules.dashboard
import qs.modules.capture
import qs.modules.ai
import qs.modules.quicksettings

import qs.config
import qs.components
import qs.components.containers
import qs.services

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        property var backgroundsManager: BackgroundsManager {}

        // InteractionManager is a global singleton, but its stack-reset
        // connection needs to know which BackgroundsManager to watch. Last
        // scope to load wins — for multi-monitor setups, modules registering
        // hover handlers should still work, but counters/state are global.
        // TODO: per-screen InteractionManager state once multi-monitor is
        // exercised.
        Component.onCompleted: InteractionManager.backgroundsManager = backgroundsManager

        // Border thickness (shell-level frame), used as a floor for *_area
        // when no pinned window reserves space on that side.
        readonly property int border_area: Config.border.enabled || Config.border.thickness < 1 ? Config.border.thickness : 0

        // Edge offsets driven by pinned+reservesSpace windows on each side
        // (computed by BackgroundsManager). Fallback to border_area when no
        // reservation exists, so the screen border still pushes content in.
        readonly property int left_area: Math.max(backgroundsManager.reservedEdge("left"), border_area)
        readonly property int top_area: Math.max(backgroundsManager.reservedEdge("top"), border_area)
        readonly property int right_area: Math.max(backgroundsManager.reservedEdge("right"), border_area)
        readonly property int bottom_area: Math.max(backgroundsManager.reservedEdge("bottom"), border_area)
        PerMonitorVisibilities {
            id: visibilities
            screen: scope.modelData
        }

        Exclusions {
            screen: scope.modelData
            left_area: scope.left_area
            top_area: scope.top_area
            right_area: scope.right_area
            bottom_area: scope.bottom_area
        }

        // ── Wallpaper background layer ──────────────────────────────
        // StyledWindow {
        //     id: bgWin

        //     screen: scope.modelData
        //     name: "background"

        //     WlrLayershell.exclusionMode: ExclusionMode.Ignore
        //     WlrLayershell.layer: WlrLayer.Background
        //     WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        //     color: "black"

        //     anchors.top: true
        //     anchors.bottom: true
        //     anchors.left: true
        //     anchors.right: true

        //     mask: Region {}

        //     // Wallpaper {
        //     //     monitorName: scope.modelData.name
        //     // }
        // }

        // ── Main drawers layer ──────────────────────────────────────
        StyledWindow {
            id: win

            screen: scope.modelData
            name: "drawers"

            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            mask: Region {
                x: scope.left_area
                y: scope.top_area
                width: win.width - scope.left_area - scope.right_area
                height: win.height - scope.top_area - scope.bottom_area
                intersection: Intersection.Xor

                regions: InputManager.regions
            }

            // Compositor-side background blur (niri ext-background-effect-v1).
            // The union of all settled panels' blur sub-regions is committed
            // with this surface, so niri blurs exactly the panel shapes with no
            // lag (and auto-enables xray inside them). See services/BlurManager.qml,
            // WindowSlot.qml.
            //
            // BackgroundEffect.blurRegion must be RE-applied imperatively on
            // every change: a declarative binding commits the region object once
            // and never re-reads it when its child list mutates, so the blur
            // freezes at the first shape (stale blur lingers under shrinking
            // panels and in vacated gaps). The null→region "kick" forces niri to
            // re-read the current union each time the slot set / settle state
            // changes (mirrors DMS's WindowBlur.kick()).
            Region {
                id: blurRegion
                // Empty base; children combine (union) into the blur shape.
                regions: BlurManager.regions
            }
            function _kickBlur(): void {
                win.BackgroundEffect.blurRegion = null;
                win.BackgroundEffect.blurRegion = BlurManager.enabled ? blurRegion : null;
            }
            Component.onCompleted: win._kickBlur()
            Connections {
                target: BlurManager
                function onRevisionChanged(): void { win._kickBlur(); }
                function onEnabledChanged(): void { win._kickBlur(); }
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // Darker overlay
            StyledRect {
                anchors.fill: parent
                opacity: visibilities.session ? 0.5 : 0
                color: Colours.palette.scrim

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            // Shell content. NOTE: deliberately NOT wrapped in a
            // `layer.enabled` Item. A full-screen offscreen layer gets
            // bilinearly resampled when composited at a fractional output
            // scale (e.g. niri `scale 1.48`), softening *all* content —
            // text, icons, SDF edges. The panel drop-shadow that used to
            // live here now sits on `bgRenderHost` inside Backgrounds, so
            // it's cast from the panel shapes only and content (contentLayer
            // text) renders straight to the framebuffer → crisp.
            Item {
                anchors.fill: parent

                // Visible border chrome — FIRST child so it renders BELOW all
                // panel content (contentLayer z=100 inside Backgrounds). Pinned/
                // overlay panels sit at edge=0, i.e. into the border strip;
                // keeping the chrome at the bottom means their content always
                // paints above it and is never covered. The BorderZone input
                // strips stay in Borders (instantiated last) so they keep
                // catching hover/click above content.
                Border {
                    border_area: scope.border_area
                    left_area: scope.left_area
                    top_area: scope.top_area
                    right_area: scope.right_area
                    bottom_area: scope.bottom_area
                }

                Backgrounds {
                    manager: scope.backgroundsManager
                    border_area: scope.border_area
                    left_area: scope.left_area
                    top_area: scope.top_area
                    right_area: scope.right_area
                    bottom_area: scope.bottom_area
                }
                BarWrapper {
                    id: bar
                    manager: scope.backgroundsManager
                    anchors.left: !Config.bar.orientation && Config.bar.position ? undefined : parent.left
                    anchors.top: Config.bar.orientation && Config.bar.position ? undefined : parent.top
                    anchors.right: !Config.bar.orientation && !Config.bar.position ? undefined : parent.right
                    anchors.bottom: Config.bar.orientation && !Config.bar.position ? undefined : parent.bottom
                    screenWidth: scope.modelData.width
                    screenHeight: scope.modelData.height
                    screen: scope.modelData //.screen
                }
                LauncherWrapper {
                    id: launcher
                    manager: scope.backgroundsManager
                    // anchors.left: !Config.bar.orientation && Config.bar.position ? undefined : parent.left
                    // anchors.top: Config.bar.orientation && Config.bar.position ? undefined : parent.top
                    // anchors.right: !Config.bar.orientation && !Config.bar.position ? undefined : parent.right
                    // anchors.bottom: Config.bar.orientation && !Config.bar.position ? undefined : parent.bottom
                    // screenWidth: scope.modelData.width
                    // screenHeight: scope.modelData.height
                    screen: scope.modelData //.screen
                }
                NotificationsWrapper {
                    id: notifications
                    manager: scope.backgroundsManager
                    screen: scope.modelData
                }
                StashWrapper {
                    id: stash
                    manager: scope.backgroundsManager
                    screen: scope.modelData
                    anchors.fill: parent
                }
                DashboardWrapper {
                    id: dashboard
                    manager: scope.backgroundsManager
                    screen: scope.modelData
                    anchors.fill: parent
                }
                RecordWrapper {
                    manager: scope.backgroundsManager
                    screen: scope.modelData
                }
                AiWrapper {
                    manager: scope.backgroundsManager
                    screen: scope.modelData
                }
                QuicksettingsWrapper {
                    manager: scope.backgroundsManager
                    screen: scope.modelData
                    anchors.fill: parent
                }

                // Popout coordinator (bar/dock widget popouts). Non-visual:
                // renders reused backgrounds via the manager; widgets trigger
                // it through the Popouts singleton + PopoutHandle.
                PopoutsManager {
                    manager: scope.backgroundsManager
                    screen: scope.modelData
                }

                // Border zone INPUT strips — last so the MouseAreas sit above
                // all wrapper content in z-order. The visible chrome moved to
                // the bottom (see Border above) so it no longer covers content.
                Borders {
                    manager: scope.backgroundsManager
                    left_area: scope.left_area
                    top_area: scope.top_area
                    right_area: scope.right_area
                    bottom_area: scope.bottom_area
                }

                // BLACK screen-corner rounding — topmost, so neither the
                // SDF frame (border rounding, bg-coloured, with присасывание)
                // nor any panel can paint over it. Purely visual chrome, no
                // input handling, so sitting above the BorderZone strips is
                // harmless.
                Corners {}

            }
        }

        NiriFocusGrab {
            active: FocusManager.focusActive
            window: win
            screen: scope.modelData
            onCleared: FocusManager.onGrabCleared()
        }
    }
}
