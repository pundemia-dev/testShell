pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell.Services.SystemTray
import QtQuick.Layouts
import QtQuick

Item {
    id: root

    readonly property alias items: items
    readonly property alias expandIcon: expandIcon

    readonly property int padding: Config.getCustom("tray", "background", false) ? Appearance.padding.medium : Appearance.padding.small
    readonly property int itemSpacing: parent.parent.gap
    readonly property int itemSize: Appearance.font.size.small * 2
    readonly property bool isHorizontal: Config.bar.orientation

    property bool expanded

    width: implicitWidth
    height: implicitHeight
    implicitWidth: isHorizontal ? (items.count * itemSize + Math.max(0, items.count - 1) * itemSpacing) : itemSize
    implicitHeight: isHorizontal ? itemSize : (items.count * itemSize + Math.max(0, items.count - 1) * itemSpacing)

    Repeater {
        id: items

        model: SystemTray.items

        TrayItem {
            id: trayItem

            required property int index

            x: root.isHorizontal ? trayItem.index * (root.itemSize + root.itemSpacing) : 0
            y: root.isHorizontal ? 0 : trayItem.index * (root.itemSize + root.itemSpacing)

            Behavior on x {
                Anim {}
            }

            Behavior on y {
                Anim {}
            }
        }
    }

    Loader {
        id: expandIcon

        active: Config.getCustom("tray", "compact", false)

        sourceComponent: Item {
            implicitWidth: expandIconInner.implicitWidth
            implicitHeight: expandIconInner.implicitHeight - Appearance.padding.small * 2

            StyledIcon {
                id: expandIconInner

                text: "expand_less"
                font.pointSize: Appearance.font.size.large
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    Anim {}
                }

                Behavior on anchors.bottomMargin {
                    Anim {}
                }
            }
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }
}
