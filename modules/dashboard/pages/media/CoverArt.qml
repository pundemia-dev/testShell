pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.images
import M3Shapes
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects

// Cover art clipped to a slowly-rotating M3 shape (exposes `shape` so the
// visualiser can query its edge via distanceAtAngle). Port of caelestia
// components/widgets/CoverArt.qml adapted to pShell (tabler fallback glyph,
// MultiEffect mask instead of the caelestia Mask effect).
Item {
    id: root

    readonly property alias shape: shape
    property color fallbackColour: Colours.layer(Colours.palette.surface_container_highest, 2)

    Behavior on fallbackColour {
        CAnim {}
    }

    // The mask/backdrop shape.
    Item {
        id: shapeWrapper
        anchors.fill: parent
        layer.enabled: true
        visible: false

        MaterialShape {
            id: shape
            implicitSize: root.width
            shape: MaterialShape.Cookie12Sided
            color: "white"

            Anim on rotation {
                running: true
                paused: !(Players.active?.playbackState === MprisPlaybackState.Playing)
                from: 360
                to: 0
                duration: 23500
                easing.type: Easing.Linear
                loops: Animation.Infinite
            }
        }
    }

    // Backdrop fill (visible through the shape when no art).
    MaterialShape {
        anchors.fill: parent
        implicitSize: root.width
        shape: MaterialShape.Cookie12Sided
        rotation: shape.rotation
        color: root.fallbackColour
        opacity: root.fallbackColour.a
    }

    // Fallback glyph.
    StyledText {
        anchors.centerIn: parent
        text: "\ueafc" // tabler music
        font.family: Appearance.font.family.tabler
        font.pointSize: (parent.width * 0.3) || 1
        color: Colours.palette.on_surface_variant
        opacity: image.status === Image.Ready ? 0 : 1
        Behavior on opacity { Anim {} }
    }

    // Cover image, masked to the shape.
    CachingImage {
        id: image
        anchors.fill: parent
        path: Players.artUrl
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: shapeWrapper
        shadowEnabled: true
        blurMax: 1
        shadowColor: Colours.palette.outline
        shadowOpacity: 0.3
        visible: image.status === Image.Ready
    }
}
