pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Chat page: message list + model picker + input row. Page contract (see
// modules/dashboard): the root exposes implicitWidth/implicitHeight so the
// swipeable view can size itself.
Item {
    id: root

    implicitWidth: Config.ai.pageWidth
    implicitHeight: Config.ai.pageHeight

    property bool inputFocused: inputField.activeFocus

    // Ambient blob shapes behind the chat: drift + morph while the model is
    // working, decelerate to a standstill once the answer is done.
    DriftingShapes {
        anchors.fill: parent
        active: Ai.requesting
        morphing: Ai.requesting
        count: 10
        maxSize: 96
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Message list ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            VerticalFadeFlickable {
                id: msgFlick
                anchors.fill: parent
                anchors.leftMargin:  Appearance.padding.medium
                anchors.rightMargin: Appearance.padding.medium
                contentHeight: msgCol.implicitHeight

                // Auto-scroll to bottom while streaming
                onContentHeightChanged: {
                    if (Ai.requesting || msgFlick.atYEnd)
                        Qt.callLater(() => msgFlick.contentY =
                            Math.max(0, msgFlick.contentHeight - msgFlick.height))
                }

                ColumnLayout {
                    id: msgCol
                    width: msgFlick.width
                    spacing: Appearance.spacing.medium

                    Item { implicitHeight: Appearance.padding.medium }

                    Repeater {
                        model: Ai.messageIds

                        MessageItem {
                            required property string modelData
                            msgId: modelData
                            Layout.fillWidth: true
                        }
                    }

                    // Empty state
                    Item {
                        visible: Ai.messageIds.length === 0
                        Layout.fillWidth: true
                        implicitHeight: emptyCol.implicitHeight

                        ColumnLayout {
                            id: emptyCol
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Appearance.spacing.medium

                            StyledIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text:  "\uf59f"   // brain
                                color: Colours.palette.on_surface_variant
                                font.pointSize: Appearance.font.icon.extraLarge.pointSize
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text:  "Ask me anything"
                                font:  Appearance.font.title.medium
                                color: Colours.palette.on_surface_variant
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Ai.serverReady ? "Server ready" : "Starting AI server…"
                                font: Appearance.font.label.small
                                color: Colours.palette.on_surface_variant
                            }
                        }
                    }

                    Item { implicitHeight: Appearance.padding.medium }
                }
            }

            // Scroll-to-bottom button
            IconButton {
                anchors { right: parent.right; bottom: parent.bottom
                          margins: Appearance.padding.medium }
                icon: "\uea16"   // arrow-down
                visible: !msgFlick.atYEnd && Ai.messageIds.length > 0
                onClicked: msgFlick.contentY =
                    Math.max(0, msgFlick.contentHeight - msgFlick.height)
            }
        }

        // ── Divider ───────────────────────────────────────────────────
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.outline_variant
            opacity: 0.4
        }

        // ── Bottom toolbar ────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Appearance.padding.medium
            spacing: Appearance.spacing.small

            // Model picker; its dropdowns are hosted by dropdownHost below.
            ModelPicker {
                id: modelPicker
                Layout.fillWidth: true
                menuHost: dropdownHost
            }

            // Input row
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledTextField {
                    id: inputField
                    Layout.fillWidth: true
                    placeholderText: Ai.requesting ? "Waiting for response…"
                                   : !Ai.serverReady ? "Starting server…"
                                   : "Message"
                    enabled: !Ai.requesting && Ai.serverReady

                    Component.onCompleted: Qt.callLater(() => forceActiveFocus())

                    // Single-line TextField: Enter sends (no newline support).
                    Keys.onReturnPressed: event => {
                        root._send()
                        event.accepted = true
                    }
                }

                // Send button
                IconButton {
                    icon: "\ueb1e"   // send
                    disabled: inputField.text.trim().length === 0
                        || Ai.requesting || !Ai.serverReady
                    onClicked: root._send()
                }

                // Clear button
                IconButton {
                    icon: "\ueb41"   // trash
                    disabled: Ai.messageIds.length === 0 || Ai.requesting
                    onClicked: Ai.clearMessages()
                }
            }
        }
    }

    // In-bounds dropdown host. Pointer events never reach items placed outside
    // their ancestors' bounds in the panel environment (a menu anchored above
    // its button renders fine but is unpickable), so SplitButton menus are
    // reparented here: topmost, spanning the whole page.
    Item {
        id: dropdownHost
        anchors.fill: parent
        z: 100
    }

    function _send() {
        const text = inputField.text.trim()
        if (!text) return
        inputField.text = ""
        Ai.addUserMessage(text)
    }
}
