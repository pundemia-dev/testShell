pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Blobs

// One rail = one anchor position. Renders its slice of manager.rails as
// WindowSlots, sorted pinned → push → overlay, each group by
// (wrapper.layer, arrivalSeq). Position math + L-step lives in WindowSlot.qml.
//
// The Repeaters run on ScriptModels, NOT raw JS arrays: a Repeater on a JS
// array destroys + recreates EVERY delegate whenever the array is reassigned
// (which happens on each requestBackground/finalizeRemoval), while ScriptModel
// diffs the new array against the old one BY ELEMENT IDENTITY and only
// inserts/removes/moves the rows that actually changed. The manager keeps each
// rail entry object identity-stable for its whole life — dying state lives
// out-of-band in manager.dyingState — so opening or closing one bg touches
// exactly one delegate and never rebuilds its rail siblings.
//
// Why TWO repeaters (pinned / dynamic) instead of one: the pinned block (bar
// segments) must occupy layers 1..P with dynamic slots stacked above at P+1..,
// regardless of arrival interleaving. The layerIdx/prevSlot math is unified
// across both repeaters so the position chain is identical to a single-
// repeater ordering.
Item {
    id: rail

    required property int railIndex
    required property string anchor
    required property var windows           // alias to manager.rails[railIndex]
    required property BlobGroup group
    required property Item groupHost        // QQuickItem wrapping group, with layer.enabled
    required property Item contentLayer
    required property int zWidth
    required property int zHeight
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area
    required property var manager

    anchors.fill: parent

    // Groups + ordering come from the manager (groupEntries/entryOrder):
    // pinned → push → overlay, each sorted by (wrapper.layer, arrivalSeq).
    // wrapper.layer is a live QObject property read, so a config change
    // resorts the rail in place — ScriptModel turns that into row moves,
    // never delegate recreation.
    readonly property var sortedWindows: {
        if (!windows || windows.length === 0) return [];
        const groups = manager.groupEntries(windows.filter(e => e.wrapper));
        return groups.pinned.concat(groups.push, groups.overlay);
    }

    Component {
        id: slotDelegate
        WindowSlot {
            // ScriptModel transiently nulls modelData while removing a row —
            // guard every read (the toasts list hit the same thing).
            required property var modelData
            required property int index

            anchor: rail.anchor
            wrapper: modelData?.wrapper ?? null
            arrivalSeq: modelData?.arrivalSeq ?? -1
            // Dying state is out-of-band (seq-keyed map) so the flip reaches
            // this live delegate as a plain property change instead of a
            // model-row replacement.
            dying: rail.manager.dyingState[arrivalSeq] !== undefined
            deathRect: rail.manager.dyingState[arrivalSeq]?.deathRect ?? null
            // Unified layer index: pinned slots occupy layers 1..P (their own
            // repeater index), dynamic slots stack directly above the pinned
            // block at P+1.. . prevSlot() below resolves across both repeaters.
            layerIdx: (modelData?.wrapper && modelData.wrapper.pinned)
                      ? (index + 1)
                      : (pinnedRepeater.count + index + 1)
            railRef: rail
            group: rail.group
            groupHost: rail.groupHost
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

    Repeater {
        id: pinnedRepeater
        model: ScriptModel {
            values: rail.sortedWindows.filter(e => e.wrapper && e.wrapper.pinned)
        }
        delegate: slotDelegate
    }
    Repeater {
        id: dynamicRepeater
        model: ScriptModel {
            values: rail.sortedWindows.filter(e => !(e.wrapper && e.wrapper.pinned))
        }
        delegate: slotDelegate
    }

    // prevSlot(q): q is the caller's (layerIdx - 1), i.e. its own 0-based
    // position in the global order. Return the slot one position earlier,
    // resolving across the pinned block (0..P-1) and the dynamic block (P..).
    function prevSlot(q) {
        const pos = q - 1;
        if (pos < 0) return null;
        const P = pinnedRepeater.count;
        if (pos < P) return pinnedRepeater.itemAt(pos);
        return dynamicRepeater.itemAt(pos - P);
    }
}
