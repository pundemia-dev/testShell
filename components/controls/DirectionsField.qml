pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import qs.components.containers

// One collapsible group for a background `EdgesData` value (all / left / right /
// top / bottom). `all` is the base; each side overrides it and, when set to
// "all" (the default), inherits `all`. "Global" (null) drops the value so the
// rails contract falls back to its automatic default. Two-way bound to the
// JsonObject so edits persist to shell.json.
//
// The `all` row itself has no "All" option (it can't inherit from itself) — its
// unset state is "Global". Presets come from an Appearance token group.
CollapsibleSection {
    id: root

    required property var data          // an EdgesData JsonObject
    property var presetGroup: null      // Appearance token group → presets
    property real min: 0
    property real max: 400
    property real step: 1
    property real fallback: 0

    // Pull every numeric property of `presetGroup` into preset entries.
    readonly property var _presets: {
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

    showBackground: true
    nested: true

    readonly property var _global: ({
            label: qsTr("Global"),
            value: null
        })
    readonly property var _all: ({
            label: qsTr("All"),
            value: "all"
        })
    readonly property var _custom: ({
            label: qsTr("Custom"),
            custom: true
        })
    readonly property var _sep: ({
            separator: true
        })

    readonly property var _presetBlock: _presets.length ? _presets.concat([_sep]) : []
    readonly property var allOptions: [_global, _sep].concat(_presetBlock).concat([_custom])
    readonly property var sideOptions: [_all, _global, _sep].concat(_presetBlock).concat([_custom])

    SettingRow {
        label: qsTr("All")
        description: qsTr("Base value for every side unless overridden below.")
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
        label: qsTr("Left")
        z: selLeft.expanded ? 10 : 0
        ValueSelector {
            id: selLeft
            options: root.sideOptions
            value: root.data.left
            min: root.min
            max: root.max
            step: root.step
            fallback: root.fallback
            onPicked: v => root.data.left = v
        }
    }
    SettingRow {
        label: qsTr("Right")
        z: selRight.expanded ? 10 : 0
        ValueSelector {
            id: selRight
            options: root.sideOptions
            value: root.data.right
            min: root.min
            max: root.max
            step: root.step
            fallback: root.fallback
            onPicked: v => root.data.right = v
        }
    }
    SettingRow {
        label: qsTr("Top")
        z: selTop.expanded ? 10 : 0
        ValueSelector {
            id: selTop
            menuOnTop: true
            options: root.sideOptions
            value: root.data.top
            min: root.min
            max: root.max
            step: root.step
            fallback: root.fallback
            onPicked: v => root.data.top = v
        }
    }
    SettingRow {
        label: qsTr("Bottom")
        showSeparator: false
        z: selBottom.expanded ? 10 : 0
        ValueSelector {
            id: selBottom
            menuOnTop: true
            options: root.sideOptions
            value: root.data.bottom
            min: root.min
            max: root.max
            step: root.step
            fallback: root.fallback
            onPicked: v => root.data.bottom = v
        }
    }
}
