pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Blobs
import qs.config
import qs.services
import "components"

// Per-screen background container. One BlobGroup for SDF rendering, one
// RailBorder (BlobInvertedRect) for the screen-edge frame, and 9 Rails (one
// per anchor position). Each Rail owns a Repeater over manager.rails[index].
Item {
    id: root

    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area
    required property var manager

    anchors.fill: parent

    readonly property var _anchors: [
        "topLeft", "top", "topRight",
        "left", "center", "right",
        "bottomLeft", "bottom", "bottomRight"
    ]

    // BlobGroup is a QObject (configuration holder, not a QQuickItem) —
    // the actual SDF compositing happens in scene-graph nodes attached
    // to each BlobShape (BlobRect / BlobInvertedRect). To capture the
    // *union* of all bg shapes as a single texture (for halo masking),
    // we host all bg-rendering items in `bgRenderHost` Item with
    // `layer.enabled: true`. That Item's FBO contains the merged SDF.
    BlobGroup {
        id: blobGroup
        color: Colours.palette.surface
        smoothing: 32
    }

    Item {
        id: bgRenderHost
        anchors.fill: parent
        layer.enabled: true

        RailBorder {
            id: railBorder
            anchors.fill: parent
            group: blobGroup
            zWidth: root.width
            zHeight: root.height
            left_area: root.left_area
            top_area: root.top_area
            right_area: root.right_area
            bottom_area: root.bottom_area
        }

        Repeater {
            id: rails
            model: 9
            delegate: Rail {
                required property int index
                railIndex: index
                anchor: root._anchors[index]
                windows: root.manager.rails[index]
                group: blobGroup
                groupHost: bgRenderHost
                contentLayer: contentLayer
                zWidth: root.width
                zHeight: root.height
                left_area: root.left_area
                top_area: root.top_area
                right_area: root.right_area
                bottom_area: root.bottom_area
                manager: root.manager
            }
        }
    }

    // All window content (and overlay bgs) get reparented here. Sits above
    // the BlobGroup's painted bg layer, so content of any window is always
    // drawn above any bg — and z=arrivalSeq inside this layer gives true
    // cross-rail arrival ordering for content.
    Item {
        id: contentLayer
        anchors.fill: parent
        z: 100
    }
}
