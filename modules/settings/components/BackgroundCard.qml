pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import QtQuick
import QtQuick.Layouts

// Reusable "background" settings block shared by every module that registers a
// rails background (ai, dashboard, launcher, notifications, osd, quicksettings,
// session, stash, toasts). Bind `cfg` to the module's config object; it must
// expose:
//   anchors           AnchorsData (left/right/top/bottom/horizontalCenter/verticalCenter)
//   margins/paddings  EdgesData   (all + left/right/top/bottom)
//   hCenterOffset     int (may be negative)
//   vCenterOffset     int (may be negative)
//   mode              "push" | "overlay" | "replace"
//   layer             int
//   rounding          number | null (null = follow Config.backgrounds.rounding)
ColumnLayout {
    id: root

    required property var cfg

    Layout.fillWidth: true
    spacing: Appearance.spacing.medium

    // ── Anchor position ↔ the six anchor bools ────────────────────────────
    readonly property var _positions: [
        { key: "topLeft", icon: "" },
        { key: "top", icon: "" },
        { key: "topRight", icon: "" },
        { key: "left", icon: "" },
        { key: "center", icon: "" },
        { key: "right", icon: "" },
        { key: "bottomLeft", icon: "" },
        { key: "bottom", icon: "" },
        { key: "bottomRight", icon: "" }
    ]

    readonly property string currentPos: {
        const a = cfg.anchors;
        void a.left; void a.right; void a.top; void a.bottom;
        void a.horizontalCenter; void a.verticalCenter;
        if (a.top && a.left) return "topLeft";
        if (a.top && a.horizontalCenter) return "top";
        if (a.top && a.right) return "topRight";
        if (a.verticalCenter && a.left) return "left";
        if (a.horizontalCenter && a.verticalCenter) return "center";
        if (a.verticalCenter && a.right) return "right";
        if (a.bottom && a.left) return "bottomLeft";
        if (a.bottom && a.horizontalCenter) return "bottom";
        if (a.bottom && a.right) return "bottomRight";
        return "";
    }
    function setPos(key: string): void {
        const a = cfg.anchors;
        a.left = key === "topLeft" || key === "left" || key === "bottomLeft";
        a.right = key === "topRight" || key === "right" || key === "bottomRight";
        a.top = key === "topLeft" || key === "top" || key === "topRight";
        a.bottom = key === "bottomLeft" || key === "bottom" || key === "bottomRight";
        a.horizontalCenter = key === "top" || key === "center" || key === "bottom";
        a.verticalCenter = key === "left" || key === "center" || key === "right";
    }

    SettingSection {
        title: qsTr("Position")
        icon: "" // tabler box-align-top-left

        SettingRow {
            label: qsTr("Anchor")
            description: qsTr("Where the panel docks on the screen.")
            showSeparator: false

            GridLayout {
                columns: 3
                rowSpacing: Appearance.spacing.small
                columnSpacing: Appearance.spacing.small

                Repeater {
                    model: root._positions
                    delegate: ToggleButton {
                        required property var modelData
                        accent: "Primary"
                        icon: modelData.icon
                        toggled: root.currentPos === modelData.key
                        onClicked: root.setPos(modelData.key)
                    }
                }
            }
        }
    }

    SettingSection {
        title: qsTr("Margins")
        icon: "" // tabler box-margin

        DirectionsField {
            title: qsTr("Margin")
            data: root.cfg.margins
            min: 0
            max: 400
            fallback: Appearance.padding.medium
            presetGroup: Appearance.padding
        }

        SettingRow {
            label: qsTr("Horizontal offset")
            description: qsTr("Shift along the horizontal centre (may be negative).")
            CustomSpinBox {
                value: root.cfg.hCenterOffset
                min: -2000
                max: 2000
                onValueModified: v => root.cfg.hCenterOffset = v
            }
        }
        SettingRow {
            label: qsTr("Vertical offset")
            description: qsTr("Shift along the vertical centre (may be negative).")
            showSeparator: false
            CustomSpinBox {
                value: root.cfg.vCenterOffset
                min: -2000
                max: 2000
                onValueModified: v => root.cfg.vCenterOffset = v
            }
        }
    }

    SettingSection {
        title: qsTr("Padding")
        icon: "" // tabler box-margin

        DirectionsField {
            title: qsTr("Padding")
            data: root.cfg.paddings
            min: 0
            max: 200
            fallback: Appearance.padding.medium
            presetGroup: Appearance.padding
        }
    }

    SettingSection {
        title: qsTr("Behaviour")
        icon: "" // tabler stack

        SettingRow {
            label: qsTr("Mode")
            description: qsTr("Push shifts siblings aside; Overlay draws on top of them; Replace borrows an existing background on the rail and morphs it into this panel.")

            RowLayout {
                spacing: Appearance.spacing.small

                Repeater {
                    model: [
                        { key: "push", label: qsTr("Push") },
                        { key: "overlay", label: qsTr("Overlay") },
                        { key: "replace", label: qsTr("Replace") }
                    ]
                    delegate: ToggleButton {
                        required property var modelData
                        accent: "Primary"
                        label: modelData.label
                        toggled: (root.cfg.mode ?? "push") === modelData.key
                        onClicked: root.cfg.mode = modelData.key
                    }
                }
            }
        }

        SettingRow {
            label: qsTr("Stick to neighbours")
            description: qsTr("SDF-merge this background into adjacent ones on the rail.")
            StyledSwitch {
                checked: root.cfg.sticks
                onToggled: root.cfg.sticks = checked
            }
        }

        SettingRow {
            label: qsTr("Layer")
            description: qsTr("Chain depth on the anchor rail — lower sits nearer the screen edge. For Replace: which slot (by depth) to borrow.")
            CustomSpinBox {
                value: root.cfg.layer
                min: 0
                max: 5
                onValueModified: v => root.cfg.layer = v
            }
        }

        SettingRow {
            label: qsTr("Rounding")
            description: qsTr("Corner radius. Global follows the backgrounds setting.")
            showSeparator: false
            z: roundSel.expanded ? 10 : 0
            ValueSelector {
                id: roundSel
                menuOnTop: true
                options: [
                    { label: qsTr("Global"), value: null },
                    { separator: true },
                    { label: qsTr("Small"), value: Appearance.rounding.small },
                    { label: qsTr("Medium"), value: Appearance.rounding.medium },
                    { label: qsTr("Large"), value: Appearance.rounding.large },
                    { label: qsTr("Extra large"), value: Appearance.rounding.extraLarge },
                    { separator: true },
                    { label: qsTr("Custom"), custom: true }
                ]
                value: root.cfg.rounding
                min: 0
                max: 120
                fallback: Appearance.rounding.large
                onPicked: v => root.cfg.rounding = v
            }
        }
    }
}
