pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

// Numeral-set picker for the workspaces "Custom numerals" setting. Mirrors
// ValueSelector (SplitButton + Popup-hosted Menu) but pairs the dropdown with a
// free-text input instead of a spinbox: pick a hardcoded preset, or choose
// "Custom" to reveal the input and type a comma-separated list of your own
// labels. Presets are baked in here — no files.
//
// `value` is the current list<var> of per-workspace labels ([] = automatic
// numbers). Edits are emitted via picked(); the host writes them back.
RowLayout {
    id: root

    property var value: []
    signal picked(arr: var)

    // Sticky once the user explicitly chooses Custom, so the input stays open
    // even if what they type happens to match a preset. Cleared when a preset
    // (or Auto) is picked. Mirrors ValueSelector._customMode.
    property bool _customMode: false

    spacing: Appearance.spacing.small

    // Baked-in numeral sets (10 entries each — one per workspace slot; extra
    // slots fall back to plain numbers). Not PUA — ordinary Unicode glyphs.
    readonly property var presets: [
        ({ label: qsTr("Auto"), value: [] }),
        ({ separator: true }),
        ({ label: qsTr("Japanese"), value: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"] }),
        ({ label: qsTr("Chinese (formal)"), value: ["壹", "貳", "參", "肆", "伍", "陸", "柒", "捌", "玖", "拾"] }),
        ({ label: qsTr("Roman"), value: ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ"] }),
        ({ label: qsTr("Arabic-Indic"), value: ["١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩", "١٠"] }),
        ({ label: qsTr("Circled"), value: ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"] }),
        ({ separator: true }),
        ({ label: qsTr("Custom"), custom: true })
    ]

    function _arrEq(a: var, b: var): bool {
        if (!a || !b || a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++)
            if (String(a[i]) !== String(b[i]))
                return false;
        return true;
    }

    // The preset whose value matches `value` exactly (Custom/separators excluded).
    readonly property var _matchedPreset: {
        const v = root.value ?? [];
        for (const p of presets)
            if (!p.separator && !p.custom && _arrEq(p.value, v))
                return p;
        return null;
    }
    // Custom when explicitly chosen, or when a non-empty value matches no preset.
    readonly property bool customActive: _customMode || ((root.value?.length ?? 0) > 0 && !_matchedPreset)
    readonly property var _activeOption: customActive ? (presets.find(o => o.custom) ?? null) : _matchedPreset
    readonly property string currentLabel: _activeOption?.label ?? qsTr("Custom")

    function _select(item: var): void {
        if (!item || item.separator)
            return;
        if (item.custom) {
            root._customMode = true;
            input.forceActiveFocus();
        } else {
            root._customMode = false;
            root.picked(item.value);
        }
        sb.expanded = false;
    }

    SplitButton {
        id: sb

        Layout.alignment: Qt.AlignVCenter
        type: SplitButton.Tonal
        fallbackText: root.currentLabel
        fallbackIcon: ""

        stateLayer.onClicked: sb.expanded = !sb.expanded
        onExpandedChanged: sb.expanded ? pop.open() : pop.close()

        Controls.Popup {
            id: pop

            parent: sb
            x: 0
            y: sb.height + Appearance.spacing.small
            padding: 0
            modal: true
            dim: false
            closePolicy: Controls.Popup.CloseOnPressOutside | Controls.Popup.CloseOnEscape
            background: Item {}
            enter: Transition {}
            exit: Transition {}

            onClosed: sb.expanded = false

            contentItem: Menu {
                id: menu

                model: root.presets
                active: root._activeOption
                onItemSelected: item => root._select(item)

                Binding {
                    target: menu
                    property: "expanded"
                    value: pop.visible
                }
            }
        }
    }

    StyledTextField {
        id: input

        // Shown while Custom is active, or while the cursor lingers over it /
        // it's being edited (same reveal logic as ValueSelector's spinbox).
        readonly property bool shown: root.customActive || inputHover.hovered || input.activeFocus

        Layout.alignment: Qt.AlignVCenter
        visible: shown || opacity > 0
        clip: true
        Layout.preferredWidth: shown ? implicitWidth : 0
        opacity: shown ? 1 : 0

        implicitWidth: 200
        placeholderText: qsTr("comma-separated labels")
        padding: Appearance.padding.small
        leftPadding: Appearance.padding.medium
        rightPadding: Appearance.padding.medium

        onEditingFinished: root.picked(text.split(",").map(s => s.trim()).filter(s => s.length > 0))

        // Re-sync from `value` whenever the field isn't being edited, so picking
        // a preset (or an external change) updates the visible text.
        Binding {
            target: input
            property: "text"
            value: (root.value ?? []).join(", ")
            when: !input.activeFocus
        }

        background: StyledRect {
            radius: Appearance.rounding.small
            color: Colours.palette.surface_container_highest
        }

        Behavior on Layout.preferredWidth {
            Anim {
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: input.shown ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.emphasizedAccel
            }
        }

        HoverHandler {
            id: inputHover
        }
    }
}
