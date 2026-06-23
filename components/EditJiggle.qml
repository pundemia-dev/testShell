import QtQuick
import qs.config

// iOS-style "wobble" wrapper for edit mode. Put the thing to jiggle directly
// inside it (it becomes a child) — EditJiggle sizes itself to that child and
// oscillates a small rotation about its own centre while `active`. `seed`
// (usually the delegate index) desyncs neighbouring instances so they don't
// shake in lockstep. The rotation is a render transform, so it never disturbs
// layout / implicit sizing of surrounding widgets.
Item {
    id: root

    property bool active: false
    property int seed: 0

    // Amplitude shrinks with elongation: a long widget rotating by a fixed
    // angle would sweep a big arc at its far end, so divide the base amplitude
    // by the aspect ratio (long side / short side), clamped to a gentle floor.
    readonly property real _aspect: {
        const w = implicitWidth;
        const h = implicitHeight;
        if (w <= 0 || h <= 0)
            return 1;
        return Math.max(w, h) / Math.min(w, h);
    }
    readonly property real _amp: Math.max(0.9, 3.0 / _aspect)
    readonly property int _dur: Appearance.anim.durations.small + (seed % 5) * 12
    property real _angle: 0

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height

    transform: Rotation {
        origin.x: root.width / 2
        origin.y: root.height / 2
        angle: root._angle
    }

    SequentialAnimation {
        running: root.active
        loops: Animation.Infinite
        NumberAnimation {
            target: root
            property: "_angle"
            to: root._amp
            duration: root._dur
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "_angle"
            to: -root._amp
            duration: root._dur
            easing.type: Easing.InOutSine
        }
    }

    onActiveChanged: {
        if (active)
            _angle = (seed % 2 ? _amp : -_amp) * Math.random(); // desync start phase
        else
            _angle = 0;
    }
}
