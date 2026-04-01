pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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

import qs.config
import qs.components
import qs.components.containers
import qs.services
import qs.utils

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        property bool barVisible: Config.bar.enabled

        Connections {
            target: VisibilitiesManager
            function onVisibilityChanged(screen, name, state) {
                if (screen === scope.modelData && name === "bar") {
                    scope.barVisible = state;
                }
            }
        }

        // Shell's mouse area
        readonly property int border_area: Config.border.enabled || Config.border.thickness < 1 ? Config.border.thickness : 0
        readonly property int bar_area: barVisible && !Config.bar.autoHide ? (Math.max((Config.bar.thickness.begin ?? Config.bar.thickness.all ?? 0) + (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0), (Config.bar.thickness.center ?? Config.bar.thickness.all ?? 0) + (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0), (Config.bar.thickness.end ?? Config.bar.thickness.all ?? 0) + (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0))) : border_area

        readonly property int left_area: !Config.bar.orientation && !Config.bar.position ? bar_area : border_area
        readonly property int top_area: Config.bar.orientation && !Config.bar.position ? bar_area : border_area
        readonly property int right_area: !Config.bar.orientation && Config.bar.position ? bar_area : border_area
        readonly property int bottom_area: Config.bar.orientation && Config.bar.position ? bar_area : border_area

        property var backgroundsManager: BackgroundsManager {}
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

            // Hyprland settings
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: FocusManager.focusActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                active: FocusManager.focusActive
                windows: [win]
                onCleared: FocusManager.onGrabCleared()
            }

            mask: Region {
                x: scope.left_area
                y: scope.top_area
                width: win.width - scope.left_area - scope.right_area
                height: win.height - scope.top_area - scope.bottom_area
                intersection: Intersection.Xor

                regions: InputManager.regions
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

            // Shell's effects layer
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha(Colours.palette.shadow, 0.7)
                }

                Border {
                    border_area: scope.border_area
                    left_area: scope.left_area
                    top_area: scope.top_area
                    right_area: scope.right_area
                    bottom_area: scope.bottom_area
                }

                Corners {}

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

            }
        }
    }
}
