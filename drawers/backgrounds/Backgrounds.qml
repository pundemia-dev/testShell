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

    BlobGroup {
        id: blobGroup
        color: Colours.palette.surface
        smoothing: 32
    }

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
