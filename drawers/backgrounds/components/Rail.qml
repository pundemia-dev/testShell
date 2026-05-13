pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Blobs

// One rail = one anchor position. Owns a Repeater over its slice of
// manager.rails. Sorts windows as: pinned (by seq) → push (by seq) → overlay
// (by seq). Position math + L-step lives in WindowSlot.qml.
Item {
    id: rail

    required property int railIndex
    required property string anchor
    required property var windows           // alias to manager.rails[railIndex]
    required property BlobGroup group
    required property Item contentLayer
    required property int zWidth
    required property int zHeight
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area
    required property var manager

    anchors.fill: parent

    readonly property var sortedWindows: {
        if (!windows || windows.length === 0) return [];
        const arr = windows.slice();
        const pinned = arr.filter(e => e.wrapper && e.wrapper.pinned)
                          .sort((a, b) => a.arrivalSeq - b.arrivalSeq);
        const push = arr.filter(e => e.wrapper && !e.wrapper.pinned && (e.wrapper.mode ?? "push") !== "overlay")
                        .sort((a, b) => a.arrivalSeq - b.arrivalSeq);
        const overlay = arr.filter(e => e.wrapper && !e.wrapper.pinned && e.wrapper.mode === "overlay")
                           .sort((a, b) => a.arrivalSeq - b.arrivalSeq);
        return pinned.concat(push, overlay);
    }

    Repeater {
        id: slotsRepeater
        model: rail.sortedWindows
        delegate: WindowSlot {
            required property var modelData
            required property int index

            anchor: rail.anchor
            wrapper: modelData.wrapper
            arrivalSeq: modelData.arrivalSeq
            layerIdx: index + 1
            railRef: rail
            group: rail.group
            contentLayer: rail.contentLayer
            zWidth: rail.zWidth
            zHeight: rail.zHeight
            left_area: rail.left_area
            top_area: rail.top_area
            right_area: rail.right_area
            bottom_area: rail.bottom_area
            manager: rail.manager
        }
    }

    function prevSlot(layerIdx) {
        if (layerIdx <= 0) return null;
        return slotsRepeater.itemAt(layerIdx - 1);
    }
}
