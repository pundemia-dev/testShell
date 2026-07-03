pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Renders a markdown text segment. Chunk-splits on double newlines during
// streaming for a typewriter-like fade-in effect.
ColumnLayout {
    id: root

    // Not `required`: instantiated via Loader + Binding push (MessageItem),
    // which can't satisfy required properties at creation time.
    property string segmentContent: ""
    required property bool done
    required property bool thinking

    property bool renderMarkdown: true

    // Whether to split into chunks (disabled while code blocks are present
    // and while editing — caller sets forceDisableChunkSplitting).
    property bool forceDisableChunkSplitting: false
    readonly property bool fadeChunks: !forceDisableChunkSplitting && !thinking

    Layout.fillWidth: true
    spacing: 0

    // Pure binding — no side effects here: mutating rep.opacities from
    // inside the model binding is a binding loop (model → opacities → model).
    readonly property list<string> _chunks: fadeChunks
        ? segmentContent.split(/\n\n(?= {0,2})|\n(?= {0,2}[-*])/g)
              .filter(s => s.trim() !== "")
        : [segmentContent]

    // Opacity ledger kept imperatively: new chunks start hidden (fade in),
    // all-but-last become fully visible as soon as a newer chunk exists.
    on_ChunksChanged: {
        const ops = [...rep.opacities]
        while (ops.length < _chunks.length)
            ops.push(done ? 1 : 0)
        for (let i = 0; i < _chunks.length - 1; i++)
            ops[i] = 1
        rep.opacities = ops
    }

    onDoneChanged: {
        if (done)
            rep.opacities = rep.opacities.map(() => 1)
    }

    Repeater {
        id: rep

        property list<real> opacities: []

        model: root._chunks

        delegate: TextArea {
            id: ta
            required property int    index
            required property string modelData

            Layout.fillWidth: true

            visible:    opacity > 0
            opacity:    root.fadeChunks ? (rep.opacities[index] ?? (root.done ? 1 : 0)) : 1
            readOnly:   true
            wrapMode:   TextEdit.Wrap
            textFormat: root.renderMarkdown ? TextEdit.MarkdownText : TextEdit.PlainText
            text:       modelData

            font:            Appearance.font.body.small
            color:           root.thinking
                                 ? Colours.palette.on_surface_variant
                                 : Colours.palette.on_surface
            selectedTextColor:   Colours.palette.on_secondary_container
            selectionColor:      Colours.palette.secondary_container
            renderType:          Text.QtRendering

            selectByMouse: true

            background: Item {}

            onLinkActivated: link => Qt.openUrlExternally(link)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            Behavior on opacity {
                NumberAnimation {
                    duration:    Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }
    }

}
