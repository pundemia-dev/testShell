import QtQuick

// Ported from caelestia: a Loader that crossfades (opacity out → swap → in)
// whenever `sourceComp` changes. Assign the desired component to `sourceComp`
// instead of `sourceComponent`.
Loader {
    id: root

    property Component sourceComp
    property bool isComplete
    property int outAnimType: Anim.FastEffects
    property int inAnimType: Anim.DefaultEffects

    asynchronous: true
    Component.onCompleted: {
        isComplete = true;
        sourceComponent = sourceComp;
    }
    onSourceCompChanged: {
        if (isComplete)
            anim.restart();
    }

    SequentialAnimation {
        id: anim

        running: false

        Anim {
            target: root
            property: "opacity"
            to: 0
            type: root.outAnimType
        }
        ScriptAction {
            script: root.sourceComponent = root.sourceComp
        }
        Anim {
            target: root
            property: "opacity"
            to: 1
            type: root.inAnimType
        }
    }
}
