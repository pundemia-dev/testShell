pragma ComponentBehavior: Bound

import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Generic settings form rendered from a SettingsSchema (or a plain object with
// the same shape). Each field maps to a styled control inside a SettingRow,
// reading/writing Config.custom[schema.key][field.key]. Seeds defaults on
// first show. See docs/development/settings.md.
ColumnLayout {
    id: root

    property var schema: null
    readonly property string keyName: schema?.key ?? ""

    spacing: Appearance.spacing.smaller

    Component.onCompleted: _seedDefaults()

    function _seedDefaults(): void {
        if (!keyName || !schema?.fields)
            return;
        const c = Object.assign({}, Config.custom);
        const sub = Object.assign({}, c[keyName] ?? {});
        let changed = false;
        for (const f of schema.fields) {
            if (sub[f.key] === undefined && f["default"] !== undefined) {
                sub[f.key] = f["default"];
                changed = true;
            }
        }
        if (changed) {
            c[keyName] = sub;
            Config.custom = c;
        }
    }

    Repeater {
        model: root.schema?.fields ?? []

        delegate: SettingRow {
            id: rowD

            required property var modelData

            readonly property var curVal: Config.getCustom(root.keyName, modelData.key, modelData["default"])
            function write(v: var): void {
                Config.setCustom(root.keyName, modelData.key, v);
            }

            visible: !modelData.advanced || Config.general.advanced
            label: modelData.label ?? modelData.key
            description: modelData.description ?? ""
            hintText: modelData.hint?.text ?? ""
            hintMedia: modelData.hint?.media ?? ""

            Loader {
                sourceComponent: {
                    switch (rowD.modelData.type) {
                    case "bool": return boolC;
                    case "int":
                    case "real": return numC;
                    case "string": return strC;
                    case "enum": return enumC;
                    default: return null;
                    }
                }
            }

            Component {
                id: boolC
                StyledSwitch {
                    checked: rowD.curVal === true
                    onToggled: rowD.write(checked)
                }
            }

            Component {
                id: numC
                CustomSpinBox {
                    value: rowD.curVal ?? 0
                    min: rowD.modelData.min ?? 0
                    max: rowD.modelData.max ?? 100
                    step: rowD.modelData.step ?? (rowD.modelData.type === "real" ? 0.1 : 1)
                    onValueModified: v => rowD.write(v)
                }
            }

            Component {
                id: strC
                StyledTextField {
                    implicitWidth: 180
                    text: rowD.curVal ?? ""
                    onEditingFinished: rowD.write(text)
                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.normal
                    rightPadding: Appearance.padding.normal
                    background: StyledRect {
                        radius: Appearance.rounding.small
                        color: Colours.palette.surface_container_high
                    }
                }
            }

            Component {
                id: enumC
                Row {
                    spacing: Appearance.spacing.small
                    Repeater {
                        model: rowD.modelData.options ?? []
                        delegate: StyledRect {
                            id: chip
                            required property var modelData
                            readonly property bool sel: rowD.curVal === modelData

                            implicitWidth: chipText.implicitWidth + Appearance.padding.normal * 2
                            implicitHeight: chipText.implicitHeight + Appearance.padding.small * 2
                            radius: Appearance.rounding.full
                            color: sel ? Colours.palette.primary : Colours.layer(Colours.palette.surface_container, 2)

                            StyledText {
                                id: chipText
                                anchors.centerIn: parent
                                text: String(chip.modelData)
                                color: chip.sel ? Colours.palette.on_primary : Colours.palette.on_surface
                            }

                            TapHandler {
                                onTapped: rowD.write(chip.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
