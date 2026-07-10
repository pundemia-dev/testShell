pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.modules.settings.components
import QtQuick
import QtQuick.Layouts
import "../pages/translator/languages.js" as Languages

// Config.ai → modules/ai/config/AiConfig.qml
// Panel size/position, AI defaults, and the translator page's engine, default
// languages, debounce and prompt.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    readonly property var languages: Languages.list

    readonly property var engines: [
        { id: "google", name: qsTr("Google") },
        { id: "ai", name: qsTr("AI") },
        { id: "deepl", name: qsTr("DeepL") },
        { id: "duckduckgo", name: qsTr("DuckDuckGo") }
    ]

    // ── A compact multi-line text field bound to a config string ────────────
    component MultilineField: StyledRect {
        id: mf
        property string text: ""
        signal edited(string value)

        // The SettingRow control slot is a plain Item sized by childrenRect,
        // so the field needs an intrinsic size (Layout.* would be ignored).
        implicitWidth: 260
        implicitHeight: 120
        radius: Appearance.rounding.small
        color: Colours.palette.surface_container_high

        Flickable {
            anchors.fill: parent
            anchors.margins: Appearance.padding.small
            clip: true
            contentWidth: width
            contentHeight: te.height
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: te
                width: parent.width
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                font: Appearance.font.body.small
                color: Colours.palette.on_surface
                selectionColor: Colours.palette.primary
                selectedTextColor: Colours.palette.on_primary
                selectByMouse: true
                text: mf.text
                onTextChanged: if (activeFocus) mf.edited(text)
            }
        }
    }

    // ── A pill selector (edge / engine) ─────────────────────────────────────
    component PillRow: Flow {
        id: pillRow
        property var model: []
        property string current: ""
        signal picked(string key)

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Repeater {
            model: pillRow.model

            delegate: StyledRect {
                id: pill
                required property var modelData
                readonly property bool active: pillRow.current === modelData.key

                implicitWidth: pillLabel.implicitWidth + Appearance.padding.medium * 2
                implicitHeight: pillLabel.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.small
                color: active ? Colours.palette.secondary_container : Colours.palette.surface_container_high

                StyledText {
                    id: pillLabel
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    font.pointSize: Appearance.font.size.small
                    color: pill.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pillRow.picked(pill.modelData.key)
                }
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("AI")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        // ── Panel ───────────────────────────────────────────────────────────
        SettingSection {
            title: qsTr("Panel")
            icon: "" // tabler brain

            SpinBoxRow {
                label: qsTr("Width")
                value: Config.ai.pageWidth
                min: 300
                max: 1400
                step: 10
                onValueModified: v => Config.ai.pageWidth = v
            }

            SpinBoxRow {
                label: qsTr("Height")
                value: Config.ai.pageHeight
                min: 300
                max: 1800
                step: 10
                onValueModified: v => Config.ai.pageHeight = v
            }

            SettingRow {
                label: qsTr("Temperature")
                description: qsTr("Sampling temperature for chat and AI translation.")
                advanced: true

                RowLayout {
                    spacing: Appearance.spacing.medium

                    StyledSlider {
                        implicitWidth: 160
                        implicitHeight: 20
                        from: 0
                        to: 2
                        stepSize: 0.1
                        value: Config.ai.temperature
                        onInteraction: v => Config.ai.temperature = v
                    }
                    StyledText {
                        text: Config.ai.temperature.toFixed(1)
                        color: Colours.palette.on_surface_variant
                    }
                }
            }

            SettingRow {
                label: qsTr("System prompt")
                description: qsTr("Prepended to every chat conversation.")
                showSeparator: false
                advanced: true

                MultilineField {
                    text: Config.ai.systemPrompt
                    onEdited: t => Config.ai.systemPrompt = t
                }
            }
        }

        BackgroundCard {
            cfg: Config.ai
        }

        // ── Translator ───────────────────────────────────────────────────────
        SettingSection {
            title: qsTr("Translator")
            icon: "" // tabler language

            SettingRow {
                label: qsTr("Engine")
                description: qsTr("Backend used to translate text.")

                PillRow {
                    model: root.engines.map(e => ({ key: e.id, label: e.name }))
                    current: Config.ai.translator.engine
                    onPicked: key => Config.ai.translator.engine = key
                }
            }

            SettingRow {
                label: qsTr("DeepL API key")
                description: qsTr("Add \"deepl\": \"<key>\" to ~/.config/pShell/apikeys.json.")
                visible: Config.ai.translator.engine === "deepl"
                StyledText {
                    text: Ai.getApiKey("deepl").length > 0 ? qsTr("Key present") : qsTr("Missing")
                    color: Ai.getApiKey("deepl").length > 0 ? Colours.palette.primary : Colours.palette.error
                }
            }

            SettingRow {
                label: qsTr("Source language")
                description: qsTr("Default language to translate from (Auto detects).")

                SplitButton {
                    id: srcSel
                    type: SplitButton.Tonal
                    fallbackIcon: ""
                    fallbackText: Languages.name(Config.ai.translator.sourceLanguage)
                    stateLayer.disabled: true

                    readonly property var _m: root.languages.map(l => ({ text: l.name, value: l.code, icon: "" }))
                    menu.model: _m
                    menu.maxHeight: 320
                    active: _m.find(it => it.value === Config.ai.translator.sourceLanguage) ?? _m[0]

                    Connections {
                        target: srcSel.menu
                        function onItemSelected(item) {
                            if (item)
                                Config.ai.translator.sourceLanguage = item.value;
                        }
                    }
                }
            }

            SettingRow {
                label: qsTr("Target language")
                description: qsTr("Default language to translate into.")

                SplitButton {
                    id: tgtSel
                    type: SplitButton.Tonal
                    fallbackIcon: ""
                    fallbackText: Languages.name(Config.ai.translator.targetLanguage)
                    stateLayer.disabled: true

                    readonly property var _m: root.languages.filter(l => l.code !== "auto").map(l => ({ text: l.name, value: l.code, icon: "" }))
                    menu.model: _m
                    menu.maxHeight: 320
                    active: _m.find(it => it.value === Config.ai.translator.targetLanguage) ?? _m[0]

                    Connections {
                        target: tgtSel.menu
                        function onItemSelected(item) {
                            if (item)
                                Config.ai.translator.targetLanguage = item.value;
                        }
                    }
                }
            }

            SpinBoxRow {
                label: qsTr("Auto-translate delay")
                value: Config.ai.translator.debounceMs
                min: 0
                max: 3000
                step: 50
                onValueModified: v => Config.ai.translator.debounceMs = v
            }

            SettingRow {
                label: qsTr("AI prompt")
                description: qsTr("Used when the engine is AI. Placeholders: {{from-language}}, {{to-language}}, {{text-to-translate}}.")
                showSeparator: false
                advanced: true

                MultilineField {
                    text: Config.ai.translator.prompt
                    onEdited: t => Config.ai.translator.prompt = t
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
