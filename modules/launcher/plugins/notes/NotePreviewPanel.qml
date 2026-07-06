pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Right panel of the notes module: previews the highlighted note. Regular notes
// render as read-only markdown (frontmatter stripped, [[wikilinks]] rewritten to
// clickable obsidian:// links); the daily note is instead an editable source
// buffer that saves back to disk on the fly. `mod` = NotesModule, `svc` = its
// NotesService (named `svc` to avoid shadowing the `svc: service` binding).
Item {
    id: panelRoot

    anchors.fill: parent

    required property var mod
    required property var svc

    readonly property var note: mod.selectedNote
    readonly property bool isDaily: note?.isDaily ?? false

    // Literal term to highlight/scroll-to in the rendered preview, taken from a
    // full-text ("/…") query. Empty otherwise.
    readonly property string highlightTerm: {
        const q = mod.query ?? "";
        return q.startsWith("/") ? q.slice(1).trim() : "";
    }

    property string body: ""
    property bool _loading: false

    onNoteChanged: _reload()
    Component.onCompleted: _reload()

    function _reload() {
        _loading = true;
        noteFile.path = note?.path ?? "";
        // A brand-new (virtual) daily note has no file yet → start empty.
        if (note?.isVirtual)
            body = "";
        _loading = false;
    }

    // Drop a leading YAML frontmatter block from the rendered view (kept in the
    // editable daily source, which shows raw markdown).
    function _stripFrontmatter(src) {
        const m = src.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/);
        return m ? src.slice(m[0].length) : src;
    }

    // Rewrite [[target]] / [[target|alias]] into markdown links to Obsidian so
    // the rendered preview can follow them (opens the vault).
    function _wikilinks(src) {
        const vault = encodeURIComponent(svc.vaultName);
        return src.replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, (_, target, alias) => {
            const label = (alias || target).trim();
            const uri = "obsidian://open?vault=" + vault + "&file=" + encodeURIComponent(target.trim());
            return "[" + label + "](" + uri + ")";
        });
    }

    // Split the (frontmatter-stripped) note body into prose vs fenced-code
    // segments so code blocks render as standalone, copyable blocks.
    // Each: { type: "text" | "code", content, lang }.
    readonly property var segments: {
        const src = _stripFrontmatter(body);
        const out = [];
        let rem = src;
        while (rem.length > 0) {
            const open = rem.indexOf("```");
            if (open < 0) {
                if (rem.trim().length)
                    out.push({ type: "text", content: rem, lang: "" });
                break;
            }
            if (open > 0 && rem.slice(0, open).trim().length)
                out.push({ type: "text", content: rem.slice(0, open), lang: "" });
            const afterOpen = rem.slice(open + 3);
            const nl = afterOpen.indexOf("\n");
            const lang = nl >= 0 ? afterOpen.slice(0, nl).trim() : "";
            const codeStart = open + 3 + (nl >= 0 ? nl + 1 : 0);
            const close = rem.indexOf("\n```", codeStart);
            if (close < 0) {
                out.push({ type: "code", content: rem.slice(codeStart), lang });
                break;
            }
            out.push({ type: "code", content: rem.slice(codeStart, close + 1).replace(/\n$/, ""), lang });
            rem = rem.slice(close + 4);
            if (rem.startsWith("\n"))
                rem = rem.slice(1);
        }
        return out;
    }

    FileView {
        id: noteFile
        watchChanges: false
        onLoaded: {
            panelRoot._loading = true;
            panelRoot.body = text();
            panelRoot._loading = false;
        }
        onLoadFailed: err => {
            panelRoot._loading = true;
            panelRoot.body = "";
            panelRoot._loading = false;
        }
    }

    // Debounced write-back for the editable daily note.
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: panelRoot.svc.writeDaily(panelRoot.body)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.medium

        // ── Header ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledIcon {
                text: panelRoot.isDaily ? "" : "" // calendar-event : file-text
                font.pointSize: Appearance.font.size.large
                color: Colours.palette.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: panelRoot.note?.name ?? ""
                    font: Appearance.font.title.medium
                    color: Colours.palette.on_surface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: panelRoot.note?.relPath ?? ""
                    font: Appearance.font.label.small
                    color: Colours.alpha(Colours.palette.on_surface, 0.5)
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }

        // ── Body: editable daily source ──────────────────────────────
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: panelRoot.isDaily
            visible: active

            sourceComponent: StyledRect {
                radius: Appearance.rounding.large
                color: Colours.transparency.enabled
                    ? Colours.layer(Colours.palette.surface_container, 2)
                    : Colours.palette.surface_container

                Flickable {
                    id: editFlick
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.medium
                    clip: true

                    TextArea.flickable: TextArea {
                        id: editor
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        text: panelRoot.body
                        font: Appearance.font.mono.small
                        color: Colours.palette.on_surface
                        selectByMouse: true
                        selectedTextColor: Colours.palette.on_secondary_container
                        selectionColor: Colours.palette.secondary_container
                        renderType: Text.QtRendering
                        placeholderText: "Empty daily note — start typing…"
                        placeholderTextColor: Colours.alpha(Colours.palette.on_surface, 0.4)
                        background: Item {}

                        onTextChanged: {
                            if (panelRoot._loading)
                                return;
                            panelRoot.body = text;
                            saveTimer.restart();
                        }
                    }
                }
            }
        }

        // ── Body: rendered markdown (read-only) ──────────────────────
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: !panelRoot.isDaily
            visible: active

            sourceComponent: VerticalFadeFlickable {
                id: renderFlick
                clip: true
                contentWidth: width
                contentHeight: segCol.implicitHeight

                // Highlight the full-text match across the prose segments and
                // scroll it into view. getText/positionToRectangle operate on a
                // segment's *rendered* (formatting-stripped) text, so positions
                // line up even though `text` is markdown source.
                function applyHighlight() {
                    const term = panelRoot.highlightTerm;
                    let target = null;
                    let tIdx = -1;
                    for (let i = 0; i < segRep.count; i++) {
                        const ld = segRep.itemAt(i);
                        const it = ld ? ld.item : null;
                        if (!it || !it.isTextSeg)
                            continue;
                        it.deselect();
                        if (target || !term.length)
                            continue;
                        const plain = it.getText(0, it.length);
                        const idx = plain.toLowerCase().indexOf(term.toLowerCase());
                        if (idx >= 0) {
                            target = it;
                            tIdx = idx;
                        }
                    }
                    if (!target)
                        return;
                    target.select(tIdx, tIdx + term.length);
                    const lr = target.positionToRectangle(tIdx);
                    const p = target.mapToItem(renderFlick.contentItem, 0, lr.y);
                    contentY = Math.max(0, Math.min(p.y - height / 3, Math.max(0, contentHeight - height)));
                }

                // Defer until segments have laid out (positionToRectangle needs
                // geometry); re-run when the note body or term changes.
                Timer {
                    id: hlTimer
                    interval: 40
                    onTriggered: renderFlick.applyHighlight()
                }

                Connections {
                    target: panelRoot
                    function onHighlightTermChanged() { hlTimer.restart(); }
                    function onBodyChanged() { hlTimer.restart(); }
                }

                Component.onCompleted: hlTimer.restart()

                ColumnLayout {
                    id: segCol
                    width: renderFlick.width
                    spacing: Appearance.spacing.small

                    Repeater {
                        id: segRep
                        model: panelRoot.segments

                        delegate: Loader {
                            id: segLoader
                            required property var modelData
                            Layout.fillWidth: true
                            // Prose loads sync (instant, no pop-in for the main
                            // content); the heavier code blocks incubate async so
                            // switching notes doesn't hitch the frame.
                            asynchronous: modelData.type === "code"
                            sourceComponent: modelData.type === "code" ? codeComp : textComp

                            Binding {
                                target: segLoader.item
                                property: "segContent"
                                value: segLoader.modelData.content
                            }
                            Binding {
                                target: segLoader.item
                                property: "segLang"
                                value: segLoader.modelData.lang ?? ""
                                when: segLoader.modelData.type === "code"
                            }
                        }
                    }
                }

                // ── Prose segment ────────────────────────────────────
                Component {
                    id: textComp

                    TextArea {
                        property bool isTextSeg: true
                        property string segContent: ""

                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.MarkdownText
                        text: panelRoot._wikilinks(segContent)
                        font: Appearance.font.body.small
                        color: Colours.palette.on_surface
                        selectByMouse: true
                        // Keep the match highlight visible even though a
                        // read-only preview never holds keyboard focus.
                        persistentSelection: true
                        selectedTextColor: Colours.palette.on_secondary_container
                        selectionColor: Colours.palette.secondary_container
                        renderType: Text.QtRendering
                        background: Item {}

                        onTextChanged: hlTimer.restart()
                        onLinkActivated: link => Qt.openUrlExternally(link)

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                            cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                    }
                }

                // ── Code segment (copyable) ──────────────────────────
                Component {
                    id: codeComp

                    ColumnLayout {
                        id: codeRoot
                        property bool isTextSeg: false
                        property string segContent: ""
                        property string segLang: ""
                        spacing: 2

                        // Header: language + copy button.
                        StyledRect {
                            Layout.fillWidth: true
                            radius: Appearance.rounding.small
                            bottomLeftRadius: Appearance.rounding.extraSmall / 2
                            bottomRightRadius: Appearance.rounding.extraSmall / 2
                            color: Colours.tPalette.surface_variant
                            implicitHeight: hdrRow.implicitHeight + Appearance.padding.small * 2

                            RowLayout {
                                id: hdrRow
                                anchors.fill: parent
                                anchors.leftMargin: Appearance.padding.medium
                                anchors.rightMargin: Appearance.padding.small
                                anchors.topMargin: Appearance.padding.small
                                anchors.bottomMargin: Appearance.padding.small
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.fillWidth: true
                                    text: codeRoot.segLang.length ? codeRoot.segLang : "plain"
                                    font: Appearance.font.label.small
                                    color: Colours.palette.on_surface_variant
                                }

                                IconButton {
                                    id: cpBtn
                                    property bool _copied: false
                                    icon: cpBtn._copied ? "" : "" // check : copy
                                    onClicked: {
                                        Quickshell.clipboardText = codeRoot.segContent;
                                        cpBtn._copied = true;
                                        cpTimer.restart();
                                    }
                                    Timer {
                                        id: cpTimer
                                        interval: 1500
                                        onTriggered: cpBtn._copied = false
                                    }
                                }
                            }
                        }

                        // Body: horizontally-scrollable monospace. The inner
                        // Flickable is non-interactive so it never swallows the
                        // vertical wheel — a MouseArea routes horizontal (or
                        // Shift+) wheel to it and leaves vertical wheel
                        // unaccepted, so it bubbles up to the note flickable.
                        StyledRect {
                            Layout.fillWidth: true
                            radius: Appearance.rounding.extraSmall / 2
                            bottomLeftRadius: Appearance.rounding.small
                            bottomRightRadius: Appearance.rounding.small
                            color: Colours.tPalette.surface_variant
                            implicitHeight: codeArea.implicitHeight

                            Flickable {
                                id: codeFlick
                                anchors.fill: parent
                                interactive: false
                                clip: true
                                contentWidth: codeArea.width
                                contentHeight: codeArea.implicitHeight
                                ScrollBar.horizontal: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                TextArea {
                                    id: codeArea
                                    width: Math.max(implicitWidth, codeFlick.width)
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.NoWrap
                                    textFormat: TextEdit.PlainText
                                    text: codeRoot.segContent
                                    font: Appearance.font.mono.small
                                    color: Colours.palette.on_surface
                                    selectedTextColor: Colours.palette.on_secondary_container
                                    selectionColor: Colours.palette.secondary_container
                                    renderType: Text.QtRendering
                                    topPadding: Appearance.padding.small
                                    bottomPadding: Appearance.padding.small
                                    leftPadding: Appearance.padding.small
                                    rightPadding: Appearance.padding.small
                                    background: Item {}
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: wheel => {
                                    let dx = wheel.angleDelta.x;
                                    if (dx === 0 && (wheel.modifiers & Qt.ShiftModifier))
                                        dx = wheel.angleDelta.y;
                                    const max = codeFlick.contentWidth - codeFlick.width;
                                    if (dx !== 0 && max > 0) {
                                        codeFlick.contentX = Math.max(0, Math.min(codeFlick.contentX - dx, max));
                                        wheel.accepted = true;
                                    } else {
                                        wheel.accepted = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Hint ─────────────────────────────────────────────────────
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: panelRoot.isDaily
                ? "Enter — open in Obsidian   ·   edits save automatically"
                : "Enter — open in Obsidian"
            font: Appearance.font.label.medium
            color: Colours.alpha(Colours.palette.on_surface, 0.45)
        }
    }
}
