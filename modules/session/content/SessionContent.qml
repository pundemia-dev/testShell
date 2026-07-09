pragma ComponentBehavior: Bound

import qs.config
import qs.components
import Quickshell
import QtQuick

// The session menu: a vertical stack of round action buttons, one per active
// manifest (SessionRegistry.active — already ordered & filtered by the user's
// Config.session.order/disabled). Owns the keyboard selection index and all
// key handling; buttons themselves are dumb (see SessionButton).
FocusScope {
    id: root

    required property var registry
    readonly property var actions: registry.active ?? []

    // Stack orientation: "auto" derives from the anchor edge (horizontal when
    // anchored top/bottom or dead-centre, else vertical); otherwise forced by
    // Config.session.orientation.
    readonly property bool horizontal: {
        const o = Config.session.orientation ?? "auto";
        if (o === "horizontal")
            return true;
        if (o === "vertical")
            return false;
        const a = Config.session.anchors;
        return (a.top ?? false) || (a.bottom ?? false) || ((a.verticalCenter ?? false) && (a.horizontalCenter ?? false));
    }

    // Fired when an action runs (host closes the menu) and when the user
    // dismisses it (Escape).
    signal actionTriggered
    signal closeRequested

    property int currentIndex: 0

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()

    function run(i: int): void {
        const a = root.actions[i];
        if (a && a.command && a.command.length > 0)
            Quickshell.execDetached(a.command);
        root.actionTriggered();
    }

    function move(delta: int): void {
        const n = root.actions.length;
        if (n > 0)
            root.currentIndex = (root.currentIndex + delta + n) % n;
    }

    Keys.onUpPressed: root.move(-1)
    Keys.onDownPressed: root.move(1)
    Keys.onLeftPressed: root.move(-1)
    Keys.onRightPressed: root.move(1)
    Keys.onReturnPressed: root.run(root.currentIndex)
    Keys.onEnterPressed: root.run(root.currentIndex)
    Keys.onEscapePressed: root.closeRequested()
    Keys.onPressed: event => {
        if (!Config.session.vimKeybinds || !(event.modifiers & Qt.ControlModifier))
            return;
        if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
            root.move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
            root.move(-1);
            event.accepted = true;
        }
    }

    Grid {
        id: grid

        // A single row (horizontal) or single column (vertical). Both dims are
        // set consistently so N buttons lay out in one line either way.
        readonly property int count: Math.max(1, root.actions.length)
        anchors.centerIn: parent
        rows: root.horizontal ? 1 : count
        columns: root.horizontal ? count : 1
        spacing: Config.session.spacing

        Repeater {
            model: root.actions

            SessionButton {
                id: button

                required property int index
                required property var modelData

                icon: modelData.icon
                selected: root.currentIndex === index

                onClicked: {
                    root.currentIndex = index;
                    root.run(index);
                }
            }
        }
    }
}
