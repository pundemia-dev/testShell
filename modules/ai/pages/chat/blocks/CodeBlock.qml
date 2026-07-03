pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Code block with header bar (language + copy/save), line numbers,
// horizontal scroll. No KSyntaxHighlighting — plain monospace.
ColumnLayout {
    id: root

    // Not `required`: instantiated via Loader + Binding push (MessageItem).
    property string segmentContent: ""
    property string segmentLang: ""
    required property bool thinking

    spacing: 2

    Layout.fillWidth: true

    // ── Header ────────────────────────────────────────────────────────
    StyledRect {
        Layout.fillWidth: true
        radius: Appearance.rounding.small
        bottomLeftRadius:  Appearance.rounding.extraSmall / 2
        bottomRightRadius: Appearance.rounding.extraSmall / 2
        color: Colours.tPalette.surface_variant
        implicitHeight: headerRow.implicitHeight + Appearance.padding.small * 2

        RowLayout {
            id: headerRow
            anchors {
                fill: parent
                leftMargin:  Appearance.padding.medium
                rightMargin: Appearance.padding.small
                topMargin:   Appearance.padding.small
                bottomMargin: Appearance.padding.small
            }
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text:  root.segmentLang.length > 0 ? root.segmentLang : "plain"
                font:  Appearance.font.label.small
                color: Colours.palette.on_surface_variant
            }

            // Copy button
            IconButton {
                id: copyBtn
                property bool _copied: false
                icon: _copied ? "" : ""   // check : copy
                onClicked: {
                    Quickshell.clipboardText = root.segmentContent
                    _copied = true
                    copyTimer.restart()
                }
                Timer {
                    id: copyTimer
                    interval: 1500
                    onTriggered: copyBtn._copied = false
                }
            }
        }
    }

    // ── Body ──────────────────────────────────────────────────────────
    RowLayout {
        spacing: 2
        Layout.fillWidth: true

        // Line numbers
        StyledRect {
            Layout.fillHeight: true
            implicitWidth:  lineNums.implicitWidth + Appearance.padding.small * 2
            implicitHeight: body.implicitHeight
            radius: Appearance.rounding.extraSmall / 2
            color: Colours.tPalette.surface_variant

            ColumnLayout {
                id: lineNums
                anchors {
                    top: parent.top; bottom: parent.bottom
                    left: parent.left; right: parent.right
                    margins: Appearance.padding.small
                    topMargin: Appearance.padding.small + 2
                }
                spacing: 0

                Repeater {
                    model: root.segmentContent.split("\n").length
                    Text {
                        required property int index
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text:  index + 1
                        font:  Appearance.font.mono.small
                        color: Colours.palette.on_surface_variant
                    }
                }
            }
        }

        // Code text
        StyledRect {
            id: body
            Layout.fillWidth: true
            radius: Appearance.rounding.extraSmall / 2
            bottomLeftRadius:  Appearance.rounding.small
            bottomRightRadius: Appearance.rounding.small
            color: Colours.tPalette.surface_variant
            implicitHeight: codeCol.implicitHeight

            ColumnLayout {
                id: codeCol
                anchors.fill: parent
                spacing: 0

                ScrollView {
                    Layout.fillWidth: true
                    implicitHeight: codeArea.implicitHeight + 4
                    clip: true
                    ScrollBar.vertical.policy:   ScrollBar.AlwaysOff
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                    TextArea {
                        id: codeArea
                        readOnly:    true
                        selectByMouse: true
                        wrapMode:    TextEdit.NoWrap
                        textFormat:  TextEdit.PlainText
                        text:        root.segmentContent
                        font:        Appearance.font.mono.small
                        color:       root.thinking
                                         ? Colours.palette.on_surface_variant
                                         : Colours.palette.on_surface
                        selectedTextColor:   Colours.palette.on_secondary_container
                        selectionColor:      Colours.palette.secondary_container
                        renderType:          Text.QtRendering
                        topPadding:    Appearance.padding.small + 2
                        bottomPadding: Appearance.padding.small
                        leftPadding:   Appearance.padding.small
                        rightPadding:  Appearance.padding.small
                        background: Item {}
                    }
                }
            }
        }
    }
}
