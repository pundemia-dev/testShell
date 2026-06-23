pragma ComponentBehavior: Bound

import ".."
import "../effects"
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Dropdown menu list. Two ways to feed it:
//   • `items`  — a list<MenuItem> (declarative; used by SplitButton/TrayMenu).
//   • `model`  — a plain JS array of entries (used by ValueSelector). Each entry
//                may carry { text|label, icon, trailingIcon, trailingText,
//                separator, value }.
// Entries with `separator: true` render a non-interactive divider. `itemSelected`
// emits the chosen entry (a MenuItem or a plain object). `active` (compared by
// identity) gets the selected-row highlight.
Elevation {
    id: root

    property list<MenuItem> items
    property var model: null
    property var active: items[0] ?? null
    property bool expanded

    signal itemSelected(item: var)

    readonly property var _model: model ?? items

    radius: Appearance.rounding.small / 2
    level: 2

    implicitWidth: Math.max(200, column.implicitWidth)
    implicitHeight: root.expanded ? column.implicitHeight : 0
    opacity: root.expanded ? 1 : 0

    StyledClippingRect {
        anchors.fill: parent
        radius: parent.radius
        color: Colours.palette.surface_container

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Repeater {
                model: root._model

                delegate: Item {
                    id: del

                    required property var modelData
                    readonly property bool isSep: modelData.separator === true
                    readonly property bool active: !isSep && modelData === root.active

                    Layout.fillWidth: true
                    implicitHeight: isSep ? sep.implicitHeight : item.implicitHeight

                    // Divider.
                    Item {
                        id: sep
                        visible: del.isSep
                        anchors.left: parent.left
                        anchors.right: parent.right
                        implicitHeight: Appearance.spacing.small

                        StyledRect {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.rightMargin: Appearance.padding.normal
                            implicitHeight: 1
                            color: Colours.palette.outline_variant
                            opacity: 0.5
                        }
                    }

                    // Selectable row.
                    StyledRect {
                        id: item
                        visible: !del.isSep
                        anchors.left: parent.left
                        anchors.right: parent.right
                        implicitHeight: menuOptionRow.implicitHeight + Appearance.padding.normal * 2

                        color: Qt.alpha(Colours.palette.secondary_container, del.active ? 1 : 0)

                        StateLayer {
                            color: del.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface
                            disabled: !root.expanded

                            function onClicked(): void {
                                root.itemSelected(del.modelData);
                                root.active = del.modelData;
                                root.expanded = false;
                            }
                        }

                        RowLayout {
                            id: menuOptionRow

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.small

                            StyledIcon {
                                visible: text !== ""
                                Layout.alignment: Qt.AlignVCenter
                                text: del.modelData.icon ?? ""
                                color: del.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                text: del.modelData.text ?? del.modelData.label ?? ""
                                color: del.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                visible: text !== ""
                                text: del.modelData.trailingText ?? ""
                                color: Colours.palette.on_surface_variant
                                font.pointSize: Appearance.font.size.small
                            }

                            Loader {
                                Layout.alignment: Qt.AlignVCenter
                                active: (del.modelData.trailingIcon ?? "").length > 0
                                visible: active

                                sourceComponent: StyledIcon {
                                    text: del.modelData.trailingIcon
                                    color: del.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }
}
