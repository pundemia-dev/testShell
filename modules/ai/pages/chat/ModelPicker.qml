pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import QtQuick.Window

// Two-level model picker.
// Level 1: API models | separator | Local (Ollama) | separator | "Free (G4F)"
// Level 2 (visible when G4F selected): g4f-specific model sub-picker
// ColumnLayout {
RowLayout {
    id: root
    spacing: Appearance.spacing.small

    // Overlay item (page root) that hosts the dropdowns — see SplitButton.
    property Item menuHost: null

    readonly property bool anyMenuExpanded: mainPicker.expanded || g4fPicker.expanded

    // Cap dropdown height to 1/3 of the screen so the list never overflows.
    readonly property real _menuMaxH: Screen.height / 3

    // ── Main picker ───────────────────────────────────────────────────
    SplitButton {
        id: mainPicker
        // Layout.fillWidth: true
        fallbackIcon: "\uf59f"   // brain
        fallbackText: root._mainLabel

        menuOnTop: true
        menuHost: root.menuHost

        readonly property list<var> _menuModel: {
            const items = [];

            // API models
            Ai.builtinModels.forEach(m => {
                items.push({
                    text: m.name,
                    icon: root._iconFor(m),
                    value: m.id,
                    isG4fGroup: false,
                    trailingText: Ai.getApiKey(m.keyId) ? "" : "no key"
                });
            });

            // Separator + local
            if (Ai.ollamaModels.length > 0) {
                items.push({
                    separator: true
                });
                Ai.ollamaModels.forEach(m => {
                    items.push({
                        text: m.name,
                        icon: "\ueb1f"   // server
                        ,
                        value: m.id,
                        isG4fGroup: false
                    });
                });
            }

            // Separator + G4F group entry
            items.push({
                separator: true
            });
            items.push({
                text: "Free (G4F)",
                icon: "\uf00b"   // robot
                ,
                value: "__g4f__",
                isG4fGroup: true,
                trailingIcon: "\uea61"  // chevron-right
            });

            return items;
        }

        // Feed the Menu through `model` (plain JS objects) — never through
        // `menuItems`, which is list<MenuItem> and nulls out plain objects.
        menu.model: _menuModel
        menu.maxHeight: root._menuMaxH

        // The text half has no meaningful action for plain-object entries
        // (SplitButton would call active.clicked(), which doesn't exist).
        stateLayer.disabled: true

        // active reflects the currently selected non-G4F model
        active: {
            if (Ai.useG4f)
                return _menuModel.find(it => it.isG4fGroup) ?? null;
            return _menuModel.find(it => it.value === Ai.currentModelId) ?? _menuModel[0] ?? null;
        }

        Connections {
            target: mainPicker.menu
            function onItemSelected(item) {
                if (!item || item.separator)
                    return;
                if (item.isG4fGroup) {
                    Ai.useG4f = true;
                } else {
                    Ai.setModel(item.value);
                }
            }
        }
    }

    // ── G4F sub-picker ────────────────────────────────────────────────
    SplitButton {
        id: g4fPicker
        visible: Ai.useG4f
        // Layout.fillWidth: true
        fallbackIcon: "\uf6d7"   // sparkles
        fallbackText: Ai.currentG4fModel.length > 0 ? Ai.currentG4fModel : "Pick model"
        menuOnTop: true
        menuHost: root.menuHost

        readonly property list<var> _g4fMenuModel: Ai.g4fModels.map(m => ({
                    text: m.name,
                    icon: "",
                    value: m.id
                }))

        active: _g4fMenuModel.find(it => it?.value === Ai.currentG4fModel) ?? (_g4fMenuModel[0] ?? null)

        menu.model: _g4fMenuModel
        menu.maxHeight: root._menuMaxH
        stateLayer.disabled: true

        Connections {
            target: g4fPicker.menu
            function onItemSelected(item) {
                if (item)
                    Ai.setG4fModel(item.value);
            }
        }

        // When g4f models arrive, default to first
        Connections {
            target: Ai
            function onG4fModelsChanged() {
                if (Ai.g4fModels.length > 0 && Ai.currentG4fModel === "")
                    Ai.setG4fModel(Ai.g4fModels[0].id);
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────
    readonly property string _mainLabel: {
        if (Ai.useG4f)
            return "Free (G4F)";
        return Ai.currentModel?.name ?? "Select model";
    }

    function _iconFor(model: var): string {
        const kid = model.keyId ?? "";
        if (kid === "gemini")
            return "\uf6d7";   // sparkles
        if (kid === "anthropic")
            return "\uf59f";   // brain
        if (kid === "openai")
            return "\ufcbe";   // robot-face
        if (kid === "mistral")
            return "\uebcb";   // wand
        if (kid === "deepseek")
            return "\uebd2";   // flask
        if (kid === "groq")
            return "\uef8e";   // cpu
        if (kid === "xai")
            return "\uebdf";   // atom-2
        if (kid === "perplexity")
            return "\uf6d7";   // sparkles
        if (kid === "openrouter")
            return "\uea91";   // dots-circle
        return "\uf59f";   // brain fallback
    }
}
