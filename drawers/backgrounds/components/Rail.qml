pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Blobs

// One rail = one anchor position. Renders its slice of manager.rails as
// WindowSlots, sorted pinned (by seq) → push (by seq) → overlay (by seq).
// Position math + L-step lives in WindowSlot.qml.
//
// Why TWO repeaters (pinned / dynamic) instead of one:
//   A QML Repeater driven by a JS-array model destroys + recreates EVERY
//   delegate whenever the model array is reassigned. The manager reassigns
//   `rails` on every requestBackground/removeBackground, so a single repeater
//   would tear down the pinned bar segment each time a popout (a dynamic,
//   non-pinned slot sharing this rail) opens or closes — re-seeding its size
//   (visible "resize from zero") and destroying its content, including any
//   PopoutHandle hover chain (which makes popouts flicker/close). Splitting
//   pinned from dynamic, and only reassigning each model when ITS entry set
//   actually changes (identity-stable memo), keeps the pinned delegates alive
//   across dynamic add/remove. The layerIdx/prevSlot math is unified across
//   both repeaters so the position chain (pinned = layer 1, dynamic stacks
//   above) is identical to the single-repeater behaviour.
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

    // Memoised split models. Each is only reassigned when its own entry set
    // changes (by arrivalSeq + dying flag + order) — so a change confined to
    // the other group preserves this one's array identity, and its Repeater
    // keeps its existing delegates instead of resetting them.
    property var _pinnedModel: []
    property var _dynamicModel: []

    function _sameEntries(a, b) {
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i].arrivalSeq !== b[i].arrivalSeq)
                return false;
            if ((a[i].dying ?? false) !== (b[i].dying ?? false))
                return false;
            // deathRect identity matters only for a freshly-dying entry; the
            // dying-flag check above already catches the transition.
        }
        return true;
    }

    function _resync() {
        const sw = sortedWindows;
        const pinned = sw.filter(e => e.wrapper && e.wrapper.pinned);
        const dynamic = sw.filter(e => !(e.wrapper && e.wrapper.pinned));
        if (!_sameEntries(pinned, _pinnedModel))
            _pinnedModel = pinned;
        if (!_sameEntries(dynamic, _dynamicModel))
            _dynamicModel = dynamic;
    }

    onSortedWindowsChanged: _resync()
    Component.onCompleted: _resync()

    Component {
        id: slotDelegate
        WindowSlot {
            required property var modelData
            required property int index

            anchor: rail.anchor
            wrapper: modelData.wrapper
            arrivalSeq: modelData.arrivalSeq
            dying: modelData.dying ?? false
            deathRect: modelData.deathRect ?? null
            // Unified layer index: pinned slots occupy layers 1..P (their own
            // repeater index), dynamic slots stack directly above the pinned
            // block at P+1.. . prevSlot() below resolves across both repeaters.
            layerIdx: (modelData.wrapper && modelData.wrapper.pinned)
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
        model: rail._pinnedModel
        delegate: slotDelegate
    }
    Repeater {
        id: dynamicRepeater
        model: rail._dynamicModel
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
