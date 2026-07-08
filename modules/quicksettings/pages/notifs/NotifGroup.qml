pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.effects
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// Ported from caelestia sidebar/NotifGroup: one card per app holding all its
// notifications. Header row = app name, newest time and a count pill that
// expands/collapses the group; the leading circle shows the notification
// image, the app icon or an urgency glyph.
StyledRect {
    id: root

    required property string modelData
    required property var page

    readonly property list<var> notifs: Notifs.list.filter(n => n.appName === modelData)
    readonly property list<var> activeNotifs: notifs.filter(n => !n.closed)
    readonly property int notifCount: activeNotifs.length
    readonly property string image: activeNotifs.find(n => n.image.length > 0)?.image ?? ""
    readonly property string appIcon: activeNotifs.find(n => n.appIcon.length > 0)?.appIcon ?? ""
    readonly property int urgency: {
        if (activeNotifs.find(n => n.urgency === NotificationUrgency.Critical))
            return NotificationUrgency.Critical;
        if (activeNotifs.find(n => n.urgency === NotificationUrgency.Normal))
            return NotificationUrgency.Normal;
        return NotificationUrgency.Low;
    }

    readonly property int nonAnimHeight: {
        const headerHeight = header.implicitHeight + (root.expanded ? Appearance.spacing.extraSmall : 0);
        const columnHeight = headerHeight + notifList.implicitHeight;
        return Math.round(Math.max(Config.notifs.sizes.image, columnHeight) + Appearance.padding.medium * 2);
    }
    readonly property bool expanded: page.expandedGroups.includes(modelData)

    function toggleExpand(expand: bool): void {
        page.setGroupExpanded(modelData, expand);
    }

    Component.onDestruction: {
        if (notifCount === 0 && expanded)
            page.setGroupExpanded(modelData, false);
    }

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: nonAnimHeight

    clip: true
    radius: Appearance.rounding.large
    color: Colours.tPalette.surface_container

    Behavior on implicitHeight {
        Anim {}
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.medium

        spacing: Appearance.spacing.medium

        Item {
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            implicitWidth: Config.notifs.sizes.image
            implicitHeight: Config.notifs.sizes.image

            Component {
                id: imageComp

                Image {
                    source: Qt.resolvedUrl(root.image)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: {
                        const size = Config.notifs.sizes.image * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1);
                        return Qt.size(size, size);
                    }
                    cache: false
                    asynchronous: true
                    width: Config.notifs.sizes.image
                    height: Config.notifs.sizes.image
                }
            }

            Component {
                id: appIconComp

                ColouredIcon {
                    implicitSize: Math.round(Config.notifs.sizes.image * 0.6)
                    source: Quickshell.iconPath(root.appIcon)
                    colour: root.urgency === NotificationUrgency.Critical ? Colours.palette.on_error : root.urgency === NotificationUrgency.Low ? Colours.palette.on_surface : Colours.palette.on_secondary_container
                    layer.enabled: root.appIcon.endsWith("symbolic")
                }
            }

            Component {
                id: glyphIconComp

                StyledIcon {
                    text: Icons.getNotifIcon(root.activeNotifs[0]?.summary ?? "", root.urgency)
                    color: root.urgency === NotificationUrgency.Critical ? Colours.palette.on_error : root.urgency === NotificationUrgency.Low ? Colours.palette.on_surface : Colours.palette.on_secondary_container
                }
            }

            StyledClippingRect {
                anchors.fill: parent
                color: root.urgency === NotificationUrgency.Critical ? Colours.palette.error : root.urgency === NotificationUrgency.Low ? Colours.layer(Colours.palette.surface_container_high, 3) : Colours.palette.secondary_container
                radius: Appearance.rounding.full

                Loader {
                    asynchronous: true
                    anchors.centerIn: parent
                    sourceComponent: root.image ? imageComp : root.appIcon ? appIconComp : glyphIconComp
                }
            }

            Loader {
                asynchronous: true
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                active: root.appIcon && root.image

                sourceComponent: StyledRect {
                    implicitWidth: Config.notifs.sizes.badge
                    implicitHeight: Config.notifs.sizes.badge

                    color: root.urgency === NotificationUrgency.Critical ? Colours.palette.error : root.urgency === NotificationUrgency.Low ? Colours.palette.surface_container_high : Colours.palette.secondary_container
                    radius: Appearance.rounding.full

                    ColouredIcon {
                        anchors.centerIn: parent
                        implicitSize: Math.round(Config.notifs.sizes.badge * 0.6)
                        source: Quickshell.iconPath(root.appIcon)
                        colour: root.urgency === NotificationUrgency.Critical ? Colours.palette.on_error : root.urgency === NotificationUrgency.Low ? Colours.palette.on_surface : Colours.palette.on_secondary_container
                        layer.enabled: root.appIcon.endsWith("symbolic")
                    }
                }
            }
        }

        Column {
            id: column

            Layout.fillWidth: true
            spacing: root.expanded ? Appearance.spacing.extraSmall : 0

            Behavior on spacing {
                Anim {}
            }

            RowLayout {
                id: header

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.modelData
                    color: Colours.palette.on_surface_variant
                    font: Appearance.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    animate: true
                    text: root.activeNotifs[0]?.timeStr ?? ""
                    color: Colours.palette.outline
                    font: Appearance.font.body.small
                }

                StyledRect {
                    implicitWidth: expandBtn.implicitWidth + Appearance.padding.large
                    implicitHeight: groupCount.implicitHeight + Appearance.padding.extraSmall

                    color: root.urgency === NotificationUrgency.Critical ? Colours.palette.error : Colours.layer(Colours.palette.surface_container_high, 3)
                    radius: Appearance.rounding.full

                    StateLayer {
                        radius: parent.radius
                        color: root.urgency === NotificationUrgency.Critical ? Colours.palette.on_error : Colours.palette.on_surface
                        function onClicked(): void {
                            root.toggleExpand(!root.expanded);
                        }
                    }

                    RowLayout {
                        id: expandBtn

                        anchors.centerIn: parent
                        spacing: Appearance.spacing.extraSmall

                        StyledText {
                            id: groupCount

                            Layout.leftMargin: Appearance.padding.extraSmall / 2
                            animate: true
                            text: root.notifCount
                            color: root.urgency === NotificationUrgency.Critical ? Colours.palette.on_error : Colours.palette.on_surface_variant
                            font: Appearance.font.body.small
                        }

                        StyledIcon {
                            Layout.rightMargin: -Appearance.padding.extraSmall / 2
                            text: "\uea5f" // tabler chevron-down
                            color: root.urgency === NotificationUrgency.Critical ? Colours.palette.on_error : Colours.palette.on_surface_variant
                            rotation: root.expanded ? 180 : 0

                            Behavior on rotation {
                                Anim {}
                            }
                        }
                    }
                }
            }

            NotifGroupList {
                id: notifList

                notifs: root.notifs
                expanded: root.expanded
                onRequestToggleExpand: expand => root.toggleExpand(expand)
            }
        }
    }
}
