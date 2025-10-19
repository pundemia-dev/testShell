pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects

import "exclusions"
import "backgrounds"
import "border"
import "wallpaper" 
import "corners"
import "panels"
import qs.modules.bar

import qs.config
import qs.widgets
import qs.utils

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        // Shell's mouse area
        readonly property int border_area: Config.border.enabled || Config.border.thickness < 1 ? Config.border.thickness : 0
        readonly property int bar_area: Config.bar.enabled && !Config.bar.autoHide ? Config.bar.thickness + Config.bar.longSideMargin: border_area;
        readonly property int left_area: !Config.bar.orientation && !Config.bar.position ? bar_area : border_area;
        readonly property int top_area: Config.bar.orientation && !Config.bar.position ? bar_area : border_area;
        readonly property int right_area: !Config.bar.orientation && Config.bar.position ? bar_area : border_area;
        readonly property int bottom_area: Config.bar.orientation && Config.bar.position ? bar_area : border_area;

        Exclusions {
            screen: scope.modelData
            left_area: scope.left_area
            top_area: scope.top_area
            right_area: scope.right_area
            bottom_area: scope.bottom_area
        }

        StyledWindow {
            id: win

            screen: scope.modelData
            name: "drawers"

            // Hyprland settings
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            
            HyprlandFocusGrab {
                active: visibilities.launcher || visibilities.session
                windows: [win]
                onCleared: {
                    visibilities.launcher = false;
                    visibilities.session = false;
                }
            }


            mask: Region {
                x: scope.left_area
                y: scope.top_area
                width: win.width - scope.left_area - scope.right_area
                height: win.height - scope.top_area - scope.bottom_area
                intersection: Intersection.Xor

                regions: regions.instances
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Variants {
                id: regions

                model: panels.children

                Region {
                    required property Item modelData

                    x: modelData.x + scope.left_area // FIXME: maybe delete modeldata.x or y if popouts autohide
                    y: modelData.y + scope.top_area // attention - may affect to detach panels
                    width: modelData.width
                    height: modelData.height
                    intersection: Intersection.Subtract
                }
            }

            // Darker overlay
            StyledRect {
                anchors.fill: parent
                opacity: visibilities.session ? 0.5 : 0
                color: Colours.palette.m3scrim

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
                    shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
                }

                Border {
                    border_area: scope.border_area 
                    left_area: scope.left_area
                    top_area: scope.top_area
                    right_area: scope.right_area
                    bottom_area: scope.bottom_area
                }

                Corners {

                }

                Backgrounds {
                    border_area: scope.border_area 
                    left_area: scope.left_area
                    top_area: scope.top_area
                    right_area: scope.right_area
                    bottom_area: scope.bottom_area
                }
            }

            PersistentProperties {
                id: visibilities

                property bool bar
                property bool osd
                property bool session
                property bool launcher
                property bool dashboard
                property bool utilities

                Component.onCompleted: Visibilities.load(scope.modelData, this)
            }

            // Interactions {
            //     screen: scope.modelData
            //     popouts: panels.popouts
            //     visibilities: visibilities
            //     panels: panels
            //     bar: bar

                Panels {
                    id: panels

                    screen: scope.modelData
                    visibilities: visibilities
                    // bar: bar
                    border_area: scope.border_area 
                    left_area: scope.left_area
                    top_area: scope.top_area
                    right_area: scope.right_area
                    bottom_area: scope.bottom_area
                }
                BarWrapper {
                    id: bar
                    anchors.left: !Config.bar.orientation && Config.bar.position ? undefined : parent.left
                    anchors.top:  Config.bar.orientation && Config.bar.position ? undefined : parent.top
                    anchors.right: !Config.bar.orientation && !Config.bar.position ? undefined : parent.right
                    anchors.bottom: Config.bar.orientation && !Config.bar.position ? undefined : parent.bottom
                    screenWidth: scope.modelData.width
                    screenHeight: scope.modelData.height

                }
            // }
        }
    }
}
