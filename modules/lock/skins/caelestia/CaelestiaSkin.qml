pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.components
import qs.components.images
import qs.services
import qs.config

// Caelestia lock skin (1:1 port of caelestia's LockSurface visuals): blurred
// screencopy background + a lock-icon card that spins in and unfolds into the
// full dashboard Content; unlockAnim runs it in reverse and hands the session
// back via lock.finishUnlock().
Item {
    id: root

    required property var lock
    required property var pam
    required property var screen

    readonly property alias unlocking: unlockAnim.running

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }

        target: root.lock
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            Anim {
                target: lockContent
                properties: "implicitWidth,implicitHeight"
                to: lockContent.size
            }
            Anim {
                target: lockBg
                property: "radius"
                to: lockContent.radius
            }
            Anim {
                target: content
                property: "scale"
                to: 0
            }
            Anim {
                target: content
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
            Anim {
                target: lockIcon
                property: "opacity"
                to: 1
                type: Anim.StandardLarge
            }
            Anim {
                target: background
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Appearance.anim.durations.small
                }
                Anim {
                    type: Anim.Standard
                    target: lockContent
                    property: "opacity"
                    to: 0
                }
            }
        }
        ScriptAction {
            script: root.lock.finishUnlock()
        }
    }

    ParallelAnimation {
        id: initAnim

        running: true

        Anim {
            target: background
            property: "opacity"
            to: 1
            type: Anim.StandardLarge
        }
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: lockContent
                    property: "scale"
                    to: 1
                    type: Anim.FastSpatial
                }
                Anim {
                    target: lockContent
                    property: "rotation"
                    to: 360
                    duration: Appearance.anim.durations.expressiveFastSpatial
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
            }
            ParallelAnimation {
                Anim {
                    target: lockIcon
                    property: "rotation"
                    to: 360
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: lockIcon
                    property: "opacity"
                    to: 0
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: content
                    property: "opacity"
                    to: 1
                }
                Anim {
                    target: content
                    property: "scale"
                    to: 1
                }
                Anim {
                    target: lockBg
                    property: "radius"
                    to: Appearance.rounding.extraLarge * 1.5
                }
                Anim {
                    target: lockContent
                    property: "implicitWidth"
                    to: (root.screen?.height ?? 0) * Config.lock.sizes.heightMult * Config.lock.sizes.ratio
                }
                Anim {
                    target: lockContent
                    property: "implicitHeight"
                    to: (root.screen?.height ?? 0) * Config.lock.sizes.heightMult
                }
            }
        }
    }

    // Blurred wallpaper background. caelestia used a ScreencopyView here, but
    // niri refuses screen capture while the session is locked — the capture
    // stays empty and niri's red backdrop bleeds through. Opaque surface fill
    // + the wallpaper image (when one is set) instead.
    Item {
        id: background

        anchors.fill: parent
        opacity: 0

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.surface
        }

        CachingImage {
            anchors.fill: parent
            path: Colours.wallpaperPath
            visible: Colours.wallpaperPath !== ""
            fillMode: Image.PreserveAspectCrop

            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
                blurMultiplier: 1
            }
        }
    }

    Item {
        id: lockContent

        readonly property int size: lockIcon.implicitHeight + Appearance.padding.large * 4
        readonly property int radius: size / 4 * Appearance.rounding.scale

        anchors.centerIn: parent
        implicitWidth: size
        implicitHeight: size

        rotation: 180
        scale: 0

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: Colours.palette.surface
            radius: parent.radius
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.shadow, 0.7)
            }
        }

        StyledIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "" // tabler lock
            font.pointSize: Appearance.font.icon.extraLarge.pointSize * 4
            font.weight: Font.Bold
            rotation: 180
        }

        Content {
            id: content

            anchors.centerIn: parent
            width: (root.screen?.height ?? 0) * Config.lock.sizes.heightMult * Config.lock.sizes.ratio - Appearance.padding.extraLargeIncreased
            height: (root.screen?.height ?? 0) * Config.lock.sizes.heightMult - Appearance.padding.extraLargeIncreased

            lock: root
            opacity: 0
            scale: 0
        }
    }
}
