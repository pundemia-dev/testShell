pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts
import "blocks"

// Single message bubble: header + block chain (text / code / think).
StyledRect {
    id: root

    required property string msgId
    readonly property var msg: Ai.messageById[msgId]

    // Blocks parsed from msg.content
    readonly property list<var> blocks: {
        if (!msg?.content) return []
        return parseBlocks(msg.content)
    }

    property bool renderMarkdown: true

    // Width comes from Layout.fillWidth at the usage site — anchors on a
    // layout-managed item are undefined behaviour.
    radius: Appearance.rounding.medium
    color:  {
        if (!msg) return "transparent"
        if (msg.role === "user")      return Colours.tPalette.surface_container
        if (msg.role === "interface") return "transparent"
        return Colours.tPalette.surface
    }
    implicitHeight: col.implicitHeight + Appearance.padding.medium * 2

    // ── Block parser (no regex look-behind for broad JS compat) ──────
    function parseBlocks(content: string): list<var> {
        const result = []
        let remaining = content
        while (remaining.length > 0) {
            const thinkOpen  = remaining.indexOf("<think>")
            const thinkClose = remaining.indexOf("</think>")
            const codeOpen   = remaining.indexOf("```")

            let nextSpecial = -1
            let specialType = ""
            if (thinkOpen >= 0) { nextSpecial = thinkOpen;  specialType = "think" }
            if (codeOpen  >= 0 && (nextSpecial < 0 || codeOpen < nextSpecial))
                { nextSpecial = codeOpen; specialType = "code" }

            if (nextSpecial < 0) {
                if (remaining.length > 0) result.push({ type: "text", content: remaining })
                break
            }

            if (nextSpecial > 0)
                result.push({ type: "text", content: remaining.slice(0, nextSpecial) })

            if (specialType === "think") {
                const end = remaining.indexOf("</think>", thinkOpen + 7)
                if (end < 0) {
                    // Still streaming — rest is think content
                    result.push({ type: "think", content: remaining.slice(thinkOpen + 7), completed: false })
                    remaining = ""
                } else {
                    result.push({ type: "think", content: remaining.slice(thinkOpen + 7, end), completed: true })
                    remaining = remaining.slice(end + 8)
                }
            } else {
                // Code block
                const afterOpen = remaining.slice(codeOpen + 3)
                const nl = afterOpen.indexOf("\n")
                const lang = nl >= 0 ? afterOpen.slice(0, nl) : ""
                const codeStart = codeOpen + 3 + (nl >= 0 ? nl + 1 : 0)
                const closePos  = remaining.indexOf("\n```", codeStart)
                if (closePos < 0) {
                    // Still streaming
                    result.push({ type: "code", lang: lang.trim(),
                                  content: remaining.slice(codeStart), completed: false })
                    remaining = ""
                } else {
                    result.push({ type: "code", lang: lang.trim(),
                                  content: remaining.slice(codeStart, closePos + 1), completed: true })
                    remaining = remaining.slice(closePos + 4)
                    if (remaining.startsWith("\n")) remaining = remaining.slice(1)
                }
            }
        }
        return result
    }

    ColumnLayout {
        id: col
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            margins: Appearance.padding.medium
        }
        spacing: Appearance.spacing.small

        // ── Header ────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small
            visible: root.msg?.role !== "interface"

            // Role / model icon
            StyledIcon {
                text: {
                    if (!root.msg) return ""
                    if (root.msg.role === "assistant") return "\uf00b"   // robot
                    if (root.msg.role === "user")      return "\ueb4d"   // user
                    return ""
                }
                color: Colours.palette.on_surface_variant
                font.pointSize: Appearance.font.icon.small.pointSize
            }

            StyledText {
                Layout.fillWidth: true
                font:  Appearance.font.label.small
                color: Colours.palette.on_surface_variant
                text: {
                    if (!root.msg) return ""
                    if (root.msg.role === "user")      return "You"
                    if (root.msg.role === "assistant") {
                        const m = Ai.allModels.find(m => m.id === root.msg.model)
                        return m?.name ?? root.msg.model ?? "Assistant"
                    }
                    return "Shell"
                }
                elide: Text.ElideRight
            }

            // Loading indicator while thinking
            LoadingIndicator {
                visible: root.msg?.thinking ?? false
                implicitSize: Appearance.font.icon.small.pointSize
                color:   Colours.palette.on_surface_variant
            }

            // Action buttons (copy + delete)
            Row {
                spacing: 2
                visible: root.msg?.done ?? false

                IconButton {
                    id: copyBtn
                    property bool _copied: false
                    icon: _copied ? "\uea5e" : "\uea7a"   // check : copy
                    onClicked: {
                        Quickshell.clipboardText = root.msg?.content ?? ""
                        _copied = true
                        copyT.restart()
                    }
                    Timer { id: copyT; interval: 1500; onTriggered: copyBtn._copied = false }
                }

                IconButton {
                    icon: "\ueb13"   // refresh
                    visible: root.msg?.role === "assistant"
                    onClicked: Ai.regenerate(root.msgId)
                }

                IconButton {
                    icon: "\ueb41"   // trash
                    onClicked: Ai.removeMessage(root.msgId)
                }
            }
        }

        // ── Content blocks ────────────────────────────────────────────
        // Fallback spinner when no blocks yet
        LoadingIndicator {
            visible: (root.blocks.length === 0) && (root.msg?.thinking ?? false)
            implicitSize: Appearance.font.icon.medium.pointSize
            color:   Colours.palette.on_surface_variant
            Layout.alignment: Qt.AlignHCenter
        }

        Repeater {
            model: root.blocks

            delegate: Loader {
                id: blkLoader
                required property var modelData
                Layout.fillWidth: true

                sourceComponent: {
                    if (modelData.type === "code")  return codeComp
                    if (modelData.type === "think") return thinkComp
                    return textComp
                }

                // Push segment data into the loaded block. Never redeclare
                // the target properties inside the components below — a
                // same-named declaration shadows the block's own property and
                // its internal bindings keep reading the (empty) original.
                Binding {
                    target: blkLoader.item
                    property: "segmentContent"
                    value: blkLoader.modelData.content
                }
                Binding {
                    target: blkLoader.item
                    property: "segmentLang"
                    value: blkLoader.modelData.lang ?? ""
                    when: blkLoader.modelData.type === "code"
                }
                Binding {
                    target: blkLoader.item
                    property: "completed"
                    value: blkLoader.modelData.completed ?? false
                    when: blkLoader.modelData.type === "think"
                }
            }
        }
    }

    // ── Block components ──────────────────────────────────────────────
    // Segment data (segmentContent/segmentLang/completed) is pushed by the
    // Binding objects in the delegate Loader above.
    Component {
        id: textComp
        TextBlock {
            done:     root.msg?.done ?? false
            thinking: root.msg?.thinking ?? false
            renderMarkdown: root.renderMarkdown
            forceDisableChunkSplitting: root.blocks.some(b => b.type === "code")
        }
    }

    Component {
        id: codeComp
        CodeBlock {
            thinking: root.msg?.thinking ?? false
        }
    }

    Component {
        id: thinkComp
        ThinkBlock {
            done:     root.msg?.done ?? false
            thinking: root.msg?.thinking ?? false
        }
    }
}
