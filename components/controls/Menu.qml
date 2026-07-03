pragma ComponentBehavior: Bound

import ".."
import "../effects"
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
// Qualified: an unqualified QtQuick.Controls import shadows this directory's
// MenuItem with the Controls type, silently breaking `items`/`menuItems`.
import QtQuick.Controls as QQC

// Dropdown menu list. Two ways to feed it:
//   • `items`  — a list<MenuItem> (declarative; used by SplitButton/TrayMenu).
//   • `model`  — a plain JS array of entries (used by ValueSelector). Each entry
//                may carry { text|label, icon, trailingIcon, trailingText,
//                separator, value }.
// Entries with `separator: true` render a non-interactive divider. `itemSelected`
// emits the chosen entry (a MenuItem or a plain object). `active` (compared by
// identity) gets the selected-row highlight.
// `maxHeight` caps the visible list height (0 = unlimited); a ScrollView handles
// overflow so the list never clips content or spills off-screen.
Elevation {
    id: root

    property list<MenuItem> items
    property var model: null
    property var active: items[0] ?? null
    property bool expanded
    property real maxHeight: 0   // 0 = no limit; set by parent for bounded dropdowns

    signal itemSelected(item: var)

    readonly property var _model: model ?? items

    radius: Appearance.rounding.small / 2
    level: 2

    readonly property real _contentHeight: column.implicitHeight
    readonly property real _visibleHeight: maxHeight > 0
        ? Math.min(_contentHeight, maxHeight)
        : _contentHeight

    implicitWidth: Math.max(200, column.implicitWidth)
    implicitHeight: root.expanded ? _visibleHeight : 0
    opacity: root.expanded ? 1 : 0

    StyledClippingRect {
        anchors.fill: parent
        radius: parent.radius
        color: Colours.palette.surface_container

        // Scrollable when content exceeds maxHeight
        Flickable {
            id: menuFlick
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: column.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            interactive: column.implicitHeight > root._visibleHeight

            QQC.ScrollBar.vertical: QQC.ScrollBar {
                policy: menuFlick.interactive ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff
            }

            ColumnLayout {
                id: column
                width: menuFlick.width
                spacing: 0

                Repeater {
                    id: rowRep
                    model: (root._model ?? []).filter(m => m !== null && m !== undefined)

                    delegate: Item {
                        id: del

                        required property var modelData
                        readonly property bool isSep: (modelData?.separator ?? false) === true
                        readonly property bool isActive: !isSep && modelData !== null && modelData === root.active

                        Layout.fillWidth: true
                        implicitHeight: isSep ? sep.implicitHeight : menuRow.implicitHeight

                        // Divider
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
                                anchors.leftMargin: Appearance.padding.medium
                                anchors.rightMargin: Appearance.padding.medium
                                implicitHeight: 1
                                color: Colours.palette.outline_variant
                                opacity: 0.5
                            }
                        }

                        // Selectable row
                        StyledRect {
                            id: menuRow
                            visible: !del.isSep
                            anchors.left: parent.left
                            anchors.right: parent.right
                            implicitHeight: rowContent.implicitHeight + Appearance.padding.medium * 2
                            color: Qt.alpha(Colours.palette.secondary_container, del.isActive ? 1 : 0)

                            StateLayer {
                                color: del.isActive
                                    ? Colours.palette.on_secondary_container
                                    : Colours.palette.on_surface
                                disabled: !root.expanded || del.modelData === null

                                function onClicked(): void {
                                    if (del.modelData === null) return
                                    root.itemSelected(del.modelData)
                                    root.active = del.modelData
                                    root.expanded = false
                                }
                            }

                            RowLayout {
                                id: rowContent
                                anchors.fill: parent
                                anchors.margins: Appearance.padding.medium
                                spacing: Appearance.spacing.small

                                StyledIcon {
                                    visible: (del.modelData?.icon ?? "") !== ""
                                    Layout.alignment: Qt.AlignVCenter
                                    text: del.modelData?.icon ?? ""
                                    color: del.isActive
                                        ? Colours.palette.on_secondary_container
                                        : Colours.palette.on_surface_variant
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: del.modelData?.text ?? del.modelData?.label ?? ""
                                    color: del.isActive
                                        ? Colours.palette.on_secondary_container
                                        : Colours.palette.on_surface
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: (del.modelData?.trailingText ?? "") !== ""
                                    text: del.modelData?.trailingText ?? ""
                                    color: Colours.palette.on_surface_variant
                                    font: Appearance.font.label.small
                                }

                                Loader {
                                    Layout.alignment: Qt.AlignVCenter
                                    active: (del.modelData?.trailingIcon ?? "") !== ""
                                    visible: active

                                    sourceComponent: StyledIcon {
                                        text: del.modelData?.trailingIcon ?? ""
                                        color: del.isActive
                                            ? Colours.palette.on_secondary_container
                                            : Colours.palette.on_surface
                                    }
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
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
}
