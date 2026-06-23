import qs.config
import qs.components
import qs.components.controls
import QtQuick
import QtQuick.Layouts

// One collapsible group for a barconfig `SeparatedData` value (all/begin/center/
// end). `all` is the base; begin/center/end override their segment and, when set
// to Auto (undefined), inherit `all` — which for thickness also flips the bar
// into its "total" layout branch (isTotalThickness). Two-way bound to the
// JsonObject so edits persist to shell.json.
//
// The caller supplies just `presets` (e.g. Appearance tokens) + ranges; the Auto
// / Custom entries and separators are composed automatically. `all` only offers
// Auto when `allCanInherit` is true (thickness.all is read raw, so leave it off
// there; paddings/rounding/margins read it via ?? 0, so it's safe).
CollapsibleSection {
    id: root

    required property var data        // a SeparatedData JsonObject
    property var presets: []          // explicit [{ label, value }] entries (optional)
    property var presetGroup: null    // an Appearance token group → presets auto-pulled from its numeric props
    property real min: 0
    property real max: 100
    property real step: 1
    property real fallback: 0
    property bool allCanInherit: false

    // Pull every numeric property of `presetGroup` (e.g. Appearance.padding →
    // small/normal/large/…) into preset entries, label = the property name.
    readonly property var _groupPresets: {
        if (!presetGroup)
            return [];
        const out = [];
        for (const key in presetGroup) {
            const v = presetGroup[key];
            if (typeof v === "number")
                out.push({
                    label: key,
                    value: v
                });
        }
        return out;
    }
    readonly property var _effPresets: presets.length ? presets : _groupPresets

    showBackground: true
    nested: true

    readonly property var _auto: ({
            label: qsTr("Auto"),
            value: undefined
        })
    readonly property var _custom: ({
            label: qsTr("Custom"),
            custom: true
        })
    readonly property var _sep: ({
            separator: true
        })

    readonly property var _presetBlock: _effPresets.length ? _effPresets.concat([_sep]) : []
    readonly property var allOptions: (allCanInherit ? [_auto, _sep] : []).concat(_presetBlock).concat([_custom])
    readonly property var overrideOptions: [_auto, _sep].concat(_presetBlock).concat([_custom])

    // The dropdown is an inline menu — raise the open row above its siblings so
    // the list paints on top of (and stays clickable over) the rows below; the
    // lower two rows open upward so they don't fall past the section's clip.
    SettingRow {
        label: qsTr("All")
        description: qsTr("Base value for every segment unless overridden below.")
        z: selAll.expanded ? 10 : 0
        ValueSelector {
            id: selAll
            options: root.allOptions
            value: root.data.all
            min: root.min
            max: root.max
            step: root.step
            fallback: root.fallback
            onPicked: v => root.data.all = v
        }
    }
    SettingRow {
        label: qsTr("Begin")
        z: selBegin.expanded ? 10 : 0
        ValueSelector {
            id: selBegin
            options: root.overrideOptions
            value: root.data.begin
            min: root.min
            max: root.max
            step: root.step
            fallback: root.fallback
            onPicked: v => root.data.begin = v
        }
    }
    SettingRow {
        label: qsTr("Center")
        z: selCenter.expanded ? 10 : 0
        ValueSelector {
            id: selCenter
            menuOnTop: true
            options: root.overrideOptions
            value: root.data.center
            min: root.min
            max: root.max
            step: root.step
            fallback: root.fallback
            onPicked: v => root.data.center = v
        }
    }
    SettingRow {
        label: qsTr("End")
        showSeparator: false
        z: selEnd.expanded ? 10 : 0
        ValueSelector {
            id: selEnd
            menuOnTop: true
            options: root.overrideOptions
            value: root.data.end
            min: root.min
            max: root.max
            step: root.step
            fallback: root.fallback
            onPicked: v => root.data.end = v
        }
    }
}
