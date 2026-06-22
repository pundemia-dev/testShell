import ".."
import qs.services
import qs.config
import QtQuick

// Small info glyph that reveals a Hint popup. Shown only when a hint exists
// (so optionality is free). Hover opens after a short delay; click pins it
// open (handy for inspecting GIFs); click again or leave (when unpinned)
// closes. See docs/development/settings.md.
Item {
    id: root

    property string text: ""
    property url media: ""
    property int delay: 350

    readonly property bool hasHint: text !== "" || String(media) !== ""
    property bool pinned: false

    visible: hasHint
    implicitWidth: visible ? glyph.implicitWidth : 0
    implicitHeight: visible ? glyph.implicitHeight : 0

    StyledText {
        id: glyph
        anchors.centerIn: parent
        text: "\ueac5" // tabler info-circle
        font.family: Appearance.font.family.tabler
        font.pointSize: Appearance.font.size.normal
        color: (hover.hovered || root.pinned)
            ? Colours.palette.primary
            : Colours.palette.on_surface_variant

        Behavior on color {
            CAnim {}
        }
    }

    HoverHandler {
        id: hover
    }
    TapHandler {
        onTapped: root.pinned = !root.pinned
    }

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: hint.open()
    }

    // Grace before closing: the popup covers the icon once open, so the icon's
    // HoverHandler drops as hint.hovered picks up — close only when both (and
    // the pin) are clear, after a short transit grace.
    Timer {
        id: closeTimer
        interval: 120
        onTriggered: {
            if (!root.pinned && !hover.hovered && !hint.hovered)
                hint.close();
        }
    }

    onPinnedChanged: {
        if (pinned)
            hint.open();
        else if (!hover.hovered && !hint.hovered)
            hint.close();
    }

    Connections {
        target: hover
        function onHoveredChanged() {
            if (hover.hovered) {
                closeTimer.stop();
                showTimer.restart();
            } else {
                showTimer.stop();
                if (!root.pinned)
                    closeTimer.restart();
            }
        }
    }

    Connections {
        target: hint
        function onHoveredChanged() {
            if (hint.hovered)
                closeTimer.stop();
            else if (!root.pinned)
                closeTimer.restart();
        }
        function onTapped() {
            root.pinned = !root.pinned;
        }
    }

    Hint {
        id: hint
        target: root
        text: root.text
        media: root.media
    }
}
