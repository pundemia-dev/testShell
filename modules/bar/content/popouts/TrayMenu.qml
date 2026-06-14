pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls

// Tray-item context menu popout. Renders a QsMenuHandle as a navigable column;
// entries with children push a sub-menu onto the stack. Ported from the
// upstream caelestia TrayMenu onto pShell's styled primitives.
StackView {
    id: root

    required property QsMenuHandle trayItem
    readonly property real menuWidth: Appearance.font.size.normal * 16

    implicitWidth: currentItem?.implicitWidth ?? 0
    implicitHeight: currentItem?.implicitHeight ?? 0

    initialItem: SubMenu {
        handle: root.trayItem
    }

    pushEnter: NoAnim {}
    pushExit: NoAnim {}
    popEnter: NoAnim {}
    popExit: NoAnim {}

    Component {
        id: subMenuComp
        SubMenu {}
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: Column {
        id: menu

        required property QsMenuHandle handle
        property bool isSubMenu
        property bool shown

        spacing: Appearance.spacing.smaller

        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.9

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        Behavior on opacity {
            Anim {}
        }
        Behavior on scale {
            Anim {}
        }

        QsMenuOpener {
            id: opener
            menu: menu.handle
        }

        Repeater {
            model: opener.children

            StyledRect {
                id: item

                required property QsMenuEntry modelData

                implicitWidth: root.menuWidth
                implicitHeight: modelData.isSeparator ? 1 : Math.max(label.implicitHeight, Appearance.font.size.normal + Appearance.padding.small * 2)
                radius: Appearance.rounding.small
                color: modelData.isSeparator ? Colours.palette.outline_variant : "transparent"

                StateLayer {
                    radius: parent.radius
                    disabled: item.modelData.isSeparator || !item.modelData.enabled
                    function onClicked(): void {
                        const entry = item.modelData;
                        if (entry.hasChildren)
                            root.push(subMenuComp.createObject(null, {
                                handle: entry,
                                isSubMenu: true
                            }));
                        else
                            entry.triggered();
                    }
                }

                IconImage {
                    id: icon
                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.padding.small
                    anchors.verticalCenter: parent.verticalCenter
                    visible: item.modelData.icon !== ""
                    implicitSize: label.implicitHeight
                    source: item.modelData.icon
                }

                StyledText {
                    id: label
                    anchors.left: icon.visible ? icon.right : parent.left
                    anchors.leftMargin: Appearance.padding.small
                    anchors.right: expand.visible ? expand.left : parent.right
                    anchors.rightMargin: Appearance.padding.small
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !item.modelData.isSeparator
                    text: item.modelData.text
                    elide: Text.ElideRight
                    color: item.modelData.enabled ? Colours.palette.on_surface : Colours.palette.outline
                }

                StyledIcon {
                    id: expand
                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.padding.small
                    anchors.verticalCenter: parent.verticalCenter
                    visible: item.modelData.hasChildren
                    text: "" // chevron-right
                    font.pointSize: Appearance.font.size.small
                    color: item.modelData.enabled ? Colours.palette.on_surface : Colours.palette.outline
                }
            }
        }

        // Back row for sub-menus.
        StyledRect {
            visible: menu.isSubMenu
            implicitWidth: root.menuWidth
            implicitHeight: visible ? backRow.implicitHeight + Appearance.padding.small * 2 : 0
            radius: Appearance.rounding.small
            color: Colours.palette.secondary_container

            StateLayer {
                radius: parent.radius
                color: Colours.palette.on_secondary_container
                function onClicked(): void {
                    root.pop();
                }
            }

            Row {
                id: backRow
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.small
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.smaller

                StyledIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "" // chevron-left
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.on_secondary_container
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Back")
                    color: Colours.palette.on_secondary_container
                }
            }
        }
    }
}
