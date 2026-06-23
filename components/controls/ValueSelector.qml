pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

// Dropdown value picker for config fields whose `undefined`/`null` carries
// meaning (inherit / "total" layout mode). The button is the shared SplitButton;
// its dropdown is the shared Menu component, but hosted in a Popup (window
// overlay) so it isn't clipped by the settings pane / collapsible section (both
// clip: true). Picking "Custom" reveals a wavy slider.
//
// Options are plain objects, in declaration order — separators draw a divider so
// preset groups (e.g. Appearance tokens) read apart from Auto/Custom:
//   { label: "Auto",   value: undefined }      // writes undefined (unset)
//   { separator: true }                        // visual divider
//   { label: "Normal", value: Appearance.padding.normal }
//   { label: "Custom", custom: true }          // reveals the slider
RowLayout {
    id: root

    property var value                 // current value: number | null | undefined
    property var options: []
    property real min: 0
    property real max: 100
    property real step: 1
    property real fallback: 0          // seed for Custom when value is unset
    property bool menuOnTop: false     // open the dropdown upward (for bottom rows)

    signal picked(value: var)

    // Sticky once the user explicitly chooses Custom: lets them open the slider
    // even when the seeded value happens to equal a preset. Cleared when a preset
    // or Auto is picked. (Inference from `value` alone can't tell "44 = the
    // Normal preset" from "44 = a custom number".)
    property bool _customMode: false

    readonly property alias expanded: sb.expanded

    spacing: Appearance.spacing.small

    function _isUnset(v): bool {
        return v === undefined || v === null;
    }
    function _presetIndex(v): int {
        for (let i = 0; i < options.length; i++) {
            const o = options[i];
            if (o.separator || o.custom)
                continue;
            if (_isUnset(o.value) && _isUnset(v))
                return i;
            if (!_isUnset(o.value) && o.value === v)
                return i;
        }
        return -1;
    }
    function _select(item: var): void {
        if (!item || item.separator)
            return;
        if (item.custom) {
            root._customMode = true;
            root.picked(_isUnset(value) ? fallback : value);
        } else {
            root._customMode = false;
            root.picked(item.value);
        }
        sb.expanded = false;
    }

    readonly property bool customActive: _customMode || (!_isUnset(value) && _presetIndex(value) < 0)
    readonly property var _activeOption: {
        if (customActive)
            return options.find(o => o.custom) ?? null;
        const i = _presetIndex(value);
        if (i >= 0)
            return options[i];
        return null;
    }
    readonly property string currentLabel: _activeOption?.label ?? qsTr("Custom")

    SplitButton {
        id: sb

        Layout.alignment: Qt.AlignVCenter
        type: SplitButton.Tonal
        fallbackText: root.currentLabel
        fallbackIcon: ""

        // The inline menu stays empty (it would clip inside the settings pane);
        // the real list lives in the Popup below. Clicking either pill toggles it.
        stateLayer.onClicked: sb.expanded = !sb.expanded

        // Keep the Popup's open state in sync with the button's expand state.
        onExpandedChanged: sb.expanded ? pop.open() : pop.close()

        Controls.Popup {
            id: pop

            parent: sb
            x: 0
            y: root.menuOnTop ? -implicitHeight - Appearance.spacing.small : sb.height + Appearance.spacing.small
            padding: 0
            // Modal (no dim) so an outside click is swallowed by the overlay and
            // never reaches the button — otherwise the closing press also toggled
            // the button, racing the state and wedging it shut after one use.
            modal: true
            dim: false
            closePolicy: Controls.Popup.CloseOnPressOutside | Controls.Popup.CloseOnEscape
            background: Item {}

            // Instant open/close — the visible animation is the Menu's own
            // expand (height/opacity). A non-instant Popup exit transition raced
            // the next open(), so reopening sometimes silently no-op'd.
            enter: Transition {}
            exit: Transition {}

            onClosed: sb.expanded = false

            contentItem: Menu {
                id: menu
                model: root.options
                active: root._activeOption
                onItemSelected: item => root._select(item)

                // Drive `expanded` via a Binding (not an inline `expanded:
                // pop.visible`): Menu.onClicked imperatively sets its own
                // `expanded = false` on selection, which would permanently
                // destroy an inline binding and leave the menu wedged shut
                // (button still animates, but the list never reappears). A
                // Binding re-asserts on every pop.visible change, so it
                // recovers after that imperative write.
                Binding {
                    target: menu
                    property: "expanded"
                    value: pop.visible
                }
            }
        }
    }

    // ── Custom spinbox (visible while Custom is active) ───────────────────
    // The SplitButton label still flips to a matching preset the instant the
    // value lines up (unchanged); but the spinbox itself lingers while the
    // cursor is still over it (or while it's being edited), so it doesn't
    // yank out from under the pointer mid-adjust. It clears once the cursor
    // leaves the whole control.
    CustomSpinBox {
        id: spin

        // Target state: shown while Custom is active, or while the cursor
        // lingers over it / it's being edited.
        readonly property bool shown: root.customActive || spinHover.hovered || spin.isEditing

        // Stay laid out (clipped) until the fade finishes, so the row reflows
        // with the collapse instead of snapping when `shown` drops.
        visible: shown || opacity > 0
        clip: true
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: shown ? implicitWidth : 0
        opacity: shown ? 1 : 0

        value: root._isUnset(root.value) ? root.fallback : root.value
        min: root.min
        max: root.max
        step: root.step
        onValueModified: v => root.picked(v)

        // MD3 motion: the container width animates on the emphasized curve
        // (medium duration); opacity is fade-through — decelerate in on show,
        // accelerate out on hide — at the shorter duration.
        Behavior on Layout.preferredWidth {
            Anim {
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: spin.shown ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.emphasizedAccel
            }
        }

        HoverHandler {
            id: spinHover
        }
    }
}
