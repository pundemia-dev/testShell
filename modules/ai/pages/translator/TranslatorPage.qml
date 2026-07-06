pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../chat"
import "languages.js" as Languages

// Translator page. Two layouts driven by the panel's anchor contract:
//   • horizontalCenter anchor (top/bottom edge or a free-floating centre) →
//     HORIZONTAL: the two panes sit side-by-side, quick-settings on top.
//   • otherwise (left/right edge incl. corners) → VERTICAL: panes stacked,
//     quick-settings between them.
// Page contract: the root exposes implicitWidth/implicitHeight for the
// swipeable AiContent view.
Item {
    id: root

    // Track purely by horizontalCenter, per the anchor contract.
    readonly property bool isHorizontal: Config.ai.anchors.horizontalCenter ?? false

    // Vertical footprint is the shared AI page size; horizontal swaps the axes
    // (wide + short) so a top/bottom-mounted panel reads naturally.
    implicitWidth: isHorizontal ? Config.ai.pageHeight : Config.ai.pageWidth
    implicitHeight: isHorizontal ? Config.ai.pageWidth : Config.ai.pageHeight

    // Keeps the AI panel alive while the user is typing / editing the prompt.
    property bool inputFocused: inputPane.edit.activeFocus || promptFocused
    property bool promptFocused: false

    // ── Translation state ─────────────────────────────────────────────────
    property string outputText: ""
    property string errorText: ""
    property bool translating: false
    // Source language the last translation actually detected (script engines
    // report it; AI does not). Lets swap flip the target even when source=auto.
    property string detectedSource: ""

    readonly property string engine: Config.ai.translator.engine
    readonly property string source: Config.ai.translator.sourceLanguage
    readonly property string target: Config.ai.translator.targetLanguage

    property bool settingsOpen: false

    // Nested-on-panel surface → layer 2 when translucent (see tPalette rule).
    readonly property color paneColor: Colours.transparency.enabled
        ? Colours.layer(Colours.palette.surface_container, 2)
        : Colours.palette.surface_container

    readonly property string scriptsDir: (Quickshell.env("HOME") || "/home/user") + "/.config/quickshell/pShell/scripts"

    // ── Language table (shared with the AI settings page) ─────────────────
    readonly property var languages: Languages.list

    readonly property var engines: [
        { id: "google", name: "Google", icon: "" },       // world
        { id: "ai", name: "AI", icon: "" },               // robot
        { id: "deepl", name: "DeepL", icon: "" },         // language
        { id: "duckduckgo", name: "DuckDuckGo", icon: "裏" } // world-search
    ]

    function langName(code: string): string {
        const l = root.languages.find(x => x.code === code);
        return l ? l.name : code;
    }
    // For the AI prompt an "auto" source has no concrete name.
    function aiSourceName(): string {
        return root.source === "auto" ? "the source language (auto-detect)" : root.langName(root.source);
    }

    // ── Translation trigger ───────────────────────────────────────────────
    // Re-translate when the engine or either language changes.
    readonly property string _trigger: root.engine + "|" + root.source + "|" + root.target
    on_TriggerChanged: if (inputPane.edit.text.trim().length > 0) debounce.restart()

    Timer {
        id: debounce
        interval: Config.ai.translator.debounceMs
        onTriggered: root.doTranslate()
    }

    function doTranslate(): void {
        const text = inputPane.edit.text;
        root.errorText = "";
        if (text.trim().length === 0) {
            root.outputText = "";
            root.translating = false;
            return;
        }
        root.translating = true;
        if (root.engine === "ai")
            root._runAi(text);
        else
            root._runScript(text);
    }

    function _runScript(text: string): void {
        transProc.running = false;
        transProc.reqText = text;
        transProc.buffer = "";
        transProc.running = true;
    }

    function _runAi(text: string): void {
        if (!Ai.serverReady) {
            root.errorText = "AI server is starting up…";
            root.translating = false;
            return;
        }
        const model = Ai.currentModel;
        const apiKey = model.keyId ? Ai.getApiKey(model.keyId) : "";
        if (model.keyId && !apiKey) {
            root.errorText = `No API key for "${model.keyId}". Add it to ~/.config/pShell/apikeys.json.`;
            root.translating = false;
            return;
        }
        const prompt = Config.ai.translator.prompt.replace(/\{\{from-language\}\}/g, root.aiSourceName()).replace(/\{\{to-language\}\}/g, root.langName(root.target)).replace(/\{\{text-to-translate\}\}/g, text);
        root.outputText = "";
        root.detectedSource = ""; // AI doesn't report a detected source
        aiProc.pendingRequest = JSON.stringify({
            action: "chat",
            format: model.format,
            model: model.model ?? model.id,
            endpoint: model.endpoint ?? "",
            apiKey: apiKey,
            messages: [{ role: "user", content: prompt }],
            temperature: Config.ai.temperature
        });
        aiProc.running = false;
        aiProc.running = true;
    }

    // Swap output → input and flip the languages (keep "auto" as-is).
    function swap(): void {
        const out = root.outputText;
        if (root.source !== "auto") {
            const t = root.source;
            Config.ai.translator.sourceLanguage = root.target;
            Config.ai.translator.targetLanguage = t;
        } else if (root.detectedSource.length > 0 && root.detectedSource !== root.target) {
            // Source stays "auto"; translate the result back into whatever
            // language the last translation detected.
            Config.ai.translator.targetLanguage = root.detectedSource;
        }
        inputPane.edit.text = out;
    }

    // ── Backends ──────────────────────────────────────────────────────────
    Process {
        id: transProc
        property string buffer: ""
        property string reqText: ""
        command: ["python3", root.scriptsDir + "/translate.py"]
        stdinEnabled: true
        onStarted: write(JSON.stringify({
            engine: root.engine,
            source: root.source,
            target: root.target,
            text: transProc.reqText,
            apiKey: Ai.getApiKey("deepl")
        }) + "\n")
        stdout: SplitParser {
            onRead: line => {
                if (line)
                    transProc.buffer = line;
            }
        }
        onExited: {
            root.translating = false;
            try {
                const obj = JSON.parse(transProc.buffer);
                if (obj.ok) {
                    root.outputText = obj.text;
                    if (obj.detected)
                        root.detectedSource = obj.detected;
                } else
                    root.errorText = obj.error ?? "Translation failed";
            } catch (e) {
                root.errorText = "Could not read translation";
            }
            transProc.buffer = "";
        }
    }

    Process {
        id: aiProc
        property string pendingRequest: ""
        command: ["python3", Ai._clientScript, Ai.socketPath]
        environment: ({ "QS_AI_TOKEN": Ai.sessionToken })
        stdinEnabled: true
        onStarted: write(pendingRequest + "\n")
        stdout: SplitParser {
            onRead: line => {
                if (!line)
                    return;
                try {
                    const obj = JSON.parse(line);
                    if (obj.type === "delta")
                        root.outputText += obj.text;
                    else if (obj.type === "done")
                        root.translating = false;
                    else if (obj.type === "error") {
                        root.errorText = obj.message ?? "AI error";
                        root.translating = false;
                    }
                } catch (e) {}
            }
        }
        onExited: root.translating = false
    }

    // ── Synced scroll: percentage of the two panes is kept aligned ─────────
    property bool _syncing: false
    function _syncScroll(src: Flickable, dst: Flickable): void {
        if (root._syncing)
            return;
        root._syncing = true;
        const sr = src.contentHeight - src.height;
        const dr = dst.contentHeight - dst.height;
        const pct = sr > 0 ? src.contentY / sr : 0;
        dst.contentY = dr > 0 ? pct * dr : 0;
        root._syncing = false;
    }

    Connections {
        target: inputPane.flick
        function onContentYChanged() {
            root._syncScroll(inputPane.flick, outputPane.flick);
        }
    }
    Connections {
        target: outputPane.flick
        function onContentYChanged() {
            root._syncScroll(outputPane.flick, inputPane.flick);
        }
    }
    Connections {
        target: inputPane.edit
        function onTextChanged() {
            debounce.restart();
        }
    }

    // ── A text pane (input or output) ─────────────────────────────────────
    component Pane: StyledRect {
        id: pane

        property bool editable: false
        property string overlayText: ""
        property color overlayColor: Colours.palette.outline
        property alias flick: flick
        property alias edit: edit
        default property alias actionData: actionRow.data

        radius: Appearance.rounding.large
        color: root.paneColor

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Appearance.padding.medium
            anchors.rightMargin: Appearance.padding.medium + Appearance.padding.small
            clip: true
            contentWidth: width
            contentHeight: edit.height
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: edit
                width: flick.width
                readOnly: !pane.editable
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                font: Appearance.font.body.small
                color: Colours.palette.on_surface
                selectionColor: Colours.palette.primary
                selectedTextColor: Colours.palette.on_primary
            }
        }

        StyledText {
            anchors.left: flick.left
            anchors.top: flick.top
            anchors.right: flick.right
            visible: edit.text.length === 0
            text: pane.overlayText
            color: pane.overlayColor
            wrapMode: Text.Wrap
        }

        StyledScrollBar {
            flickable: flick
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.padding.small
        }

        Row {
            id: actionRow
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.padding.small
            spacing: Appearance.spacing.small / 2
        }
    }

    // ── Layout (GridLayout reflows on orientation change) ──────────────────
    GridLayout {
        anchors.fill: parent
        columns: root.isHorizontal ? 2 : 1
        rowSpacing: Appearance.spacing.medium
        columnSpacing: Appearance.spacing.medium

        Pane {
            id: inputPane
            editable: true
            overlayText: qsTr("Enter text to translate…")
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: root.isHorizontal ? 1 : 0
            Layout.column: 0

            IconButton {
                type: IconButton.Text
                icon: "" // eraser
                disabled: inputPane.edit.text.length === 0
                onClicked: inputPane.edit.text = ""
            }
            IconButton {
                type: IconButton.Tonal
                icon: "" // refresh — force translate
                disabled: inputPane.edit.text.trim().length === 0
                onClicked: root.doTranslate()
            }
        }

        // Quick-settings strip. Absolute placement so the swap button centres
        // on the STRIP, not between the two language pickers.
        Item {
            id: quickRow
            implicitHeight: gearBtn.implicitHeight
            Layout.fillWidth: true
            Layout.row: root.isHorizontal ? 0 : 1
            Layout.column: 0
            Layout.columnSpan: root.isHorizontal ? 2 : 1

            SplitButton {
                id: sourcePicker
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                fallbackIcon: "" // language
                fallbackText: root.langName(root.source)
                menuHost: dropdownHost
                stateLayer.disabled: true

                readonly property var _m: root.languages.map(l => ({ text: l.name, value: l.code, icon: "" }))
                menu.model: _m
                menu.maxHeight: root.height * 0.5
                active: _m.find(it => it.value === root.source) ?? _m[0]

                Connections {
                    target: sourcePicker.menu
                    function onItemSelected(item) {
                        if (item)
                            Config.ai.translator.sourceLanguage = item.value;
                    }
                }
            }

            IconButton {
                id: swapBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                type: IconButton.Tonal
                isRound: true
                icon: "" // arrows-left-right (swap)
                disabled: root.outputText.trim().length === 0
                onClicked: root.swap()
            }

            IconButton {
                id: gearBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                type: IconButton.Tonal
                icon: "" // settings
                toggle: true
                checked: root.settingsOpen
                onClicked: root.settingsOpen = !root.settingsOpen
            }

            SplitButton {
                id: targetPicker
                anchors.right: gearBtn.left
                anchors.rightMargin: Appearance.spacing.small
                anchors.verticalCenter: parent.verticalCenter
                fallbackIcon: "" // language
                fallbackText: root.langName(root.target)
                menuHost: dropdownHost
                stateLayer.disabled: true

                readonly property var _m: root.languages.filter(l => l.code !== "auto").map(l => ({ text: l.name, value: l.code, icon: "" }))
                menu.model: _m
                menu.maxHeight: root.height * 0.5
                active: _m.find(it => it.value === root.target) ?? _m[0]

                Connections {
                    target: targetPicker.menu
                    function onItemSelected(item) {
                        if (item)
                            Config.ai.translator.targetLanguage = item.value;
                    }
                }
            }
        }

        Pane {
            id: outputPane
            editable: false
            overlayText: root.errorText.length > 0 ? root.errorText : (root.translating ? "…" : qsTr("Translation will appear here…"))
            overlayColor: root.errorText.length > 0 ? Colours.palette.error : Colours.palette.outline
            edit.text: root.outputText
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: root.isHorizontal ? 1 : 2
            Layout.column: root.isHorizontal ? 1 : 0

            IconButton {
                type: IconButton.Text
                icon: "" // copy
                disabled: root.outputText.trim().length === 0
                onClicked: Quickshell.clipboardText = root.outputText
            }
        }
    }

    // Dropdown host for the language SplitButton menus (pointer events only
    // reach items within their ancestors' bounds in layershell panels).
    Item {
        id: dropdownHost
        anchors.fill: parent
        z: 100
    }

    // ── Settings sheet ────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: root.settingsOpen
        z: 200
        onClicked: root.settingsOpen = false
    }

    StyledRect {
        id: settingsSheet
        visible: root.settingsOpen
        z: 201
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.medium
        width: Math.min(root.width - Appearance.padding.medium * 2, 380)
        implicitHeight: Math.min(root.height - Appearance.padding.medium * 2, settingsCol.implicitHeight + Appearance.padding.large * 2)
        radius: Appearance.rounding.large
        color: Colours.transparency.enabled ? Colours.layer(Colours.palette.surface_container_high, 3) : Colours.palette.surface_container_high

        // Swallow clicks so the scrim MouseArea doesn't close the sheet.
        MouseArea {
            anchors.fill: parent
        }

        VerticalFadeFlickable {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            contentHeight: settingsCol.implicitHeight

            ColumnLayout {
                id: settingsCol
                width: parent.width
                spacing: Appearance.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Translator settings")
                        font: Appearance.font.title.small
                        color: Colours.palette.on_surface
                    }
                    IconButton {
                        type: IconButton.Text
                        icon: "" // x
                        onClicked: root.settingsOpen = false
                    }
                }

                StyledText {
                    text: qsTr("Engine")
                    font: Appearance.font.label.large
                    color: Colours.palette.on_surface_variant
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: root.engines

                        StyledRect {
                            id: engineChip
                            required property var modelData
                            readonly property bool active: root.engine === modelData.id

                            implicitWidth: chipRow.implicitWidth + Appearance.padding.medium * 2
                            implicitHeight: chipRow.implicitHeight + Appearance.padding.small * 2
                            radius: Appearance.rounding.full
                            color: active ? Colours.palette.primary : Colours.palette.surface_container_highest

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: Appearance.spacing.small

                                StyledIcon {
                                    text: engineChip.modelData.icon
                                    color: engineChip.active ? Colours.palette.on_primary : Colours.palette.on_surface_variant
                                    font.pointSize: Appearance.font.icon.small.pointSize
                                }
                                StyledText {
                                    text: engineChip.modelData.name
                                    color: engineChip.active ? Colours.palette.on_primary : Colours.palette.on_surface_variant
                                    font: Appearance.font.label.medium
                                }
                            }

                            StateLayer {
                                color: engineChip.active ? Colours.palette.on_primary : Colours.palette.on_surface
                                function onClicked(): void {
                                    Config.ai.translator.engine = engineChip.modelData.id;
                                }
                            }
                        }
                    }
                }

                // DeepL key hint.
                StyledText {
                    Layout.fillWidth: true
                    visible: root.engine === "deepl"
                    wrapMode: Text.Wrap
                    text: qsTr("DeepL needs an API key: add \"deepl\": \"<key>\" to ~/.config/pShell/apikeys.json.")
                    font: Appearance.font.body.small
                    color: Ai.getApiKey("deepl").length > 0 ? Colours.palette.on_surface_variant : Colours.palette.error
                }

                // AI provider/model picker — the same control as the chat page.
                StyledText {
                    visible: root.engine === "ai"
                    text: qsTr("Model")
                    font: Appearance.font.label.large
                    color: Colours.palette.on_surface_variant
                }
                ModelPicker {
                    visible: root.engine === "ai"
                    Layout.fillWidth: true
                    menuHost: dropdownHost
                }

                StyledText {
                    visible: root.engine === "ai"
                    text: qsTr("Prompt")
                    font: Appearance.font.label.large
                    color: Colours.palette.on_surface_variant
                }
                StyledRect {
                    visible: root.engine === "ai"
                    Layout.fillWidth: true
                    implicitHeight: 130
                    radius: Appearance.rounding.small
                    color: Colours.palette.surface_container_highest

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: Appearance.padding.small
                        clip: true
                        contentWidth: width
                        contentHeight: promptEdit.height
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: promptEdit
                            width: parent.width
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            font: Appearance.font.body.small
                            color: Colours.palette.on_surface
                            selectionColor: Colours.palette.primary
                            selectedTextColor: Colours.palette.on_primary
                            selectByMouse: true
                            text: Config.ai.translator.prompt
                            onActiveFocusChanged: root.promptFocused = activeFocus
                            onTextChanged: if (activeFocus) Config.ai.translator.prompt = text
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.engine === "ai"
                    wrapMode: Text.Wrap
                    text: qsTr("Placeholders: {{from-language}}, {{to-language}}, {{text-to-translate}}")
                    font: Appearance.font.label.small
                    color: Colours.palette.on_surface_variant
                }
            }
        }
    }
}
