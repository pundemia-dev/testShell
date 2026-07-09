pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.components
import qs.components.effects
import qs.services
import qs.config

StyledRect {
    id: root

    required property string modelData

    readonly property list<var> notifs: Notifs.list.filter(notif => notif.appName === modelData)
    readonly property var props: {
        let img = "";
        let icon = "";
        let hasCritical = false;
        let hasNormal = false;
        for (const n of notifs) {
            if (!img && n.image.length > 0)
                img = n.image;
            if (!icon && n.appIcon.length > 0)
                icon = n.appIcon;
            if (n.urgency === NotificationUrgency.Critical)
                hasCritical = true;
            else if (n.urgency === NotificationUrgency.Normal)
                hasNormal = true;
        }
        return {
            img,
            icon,
            urgency: hasCritical ? "critical" : hasNormal ? "normal" : "low"
        };
    }
    readonly property string image: props.img
    readonly property string appIcon: props.icon
    readonly property string urgency: props.urgency

    property bool expanded

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: content.implicitHeight + Appearance.padding.medium * 2

    clip: true
    radius: Appearance.rounding.large
    color: root.urgency === "critical" ? Colours.palette.secondary_container : Colours.layer(Colours.palette.surface_container_high, 2)

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
                    colour: root.urgency === "critical" ? Colours.palette.on_error : root.urgency === "low" ? Colours.palette.on_surface : Colours.palette.on_secondary_container
                    layer.enabled: root.appIcon.endsWith("symbolic")
                }
            }

            Component {
                id: fallbackIconComp

                StyledIcon {
                    text: Icons.getNotifIcon(root.notifs[0]?.summary ?? "", root.notifs[0]?.urgency ?? NotificationUrgency.Normal)
                    color: root.urgency === "critical" ? Colours.palette.on_error : root.urgency === "low" ? Colours.palette.on_surface : Colours.palette.on_secondary_container
                    font.pointSize: Appearance.font.icon.large.pointSize
                }
            }

            ClippingRectangle {
                anchors.fill: parent
                color: root.urgency === "critical" ? Colours.palette.error : root.urgency === "low" ? Colours.layer(Colours.palette.surface_container_highest, 3) : Colours.palette.secondary_container
                radius: Appearance.rounding.full

                Loader {
                    asynchronous: true
                    anchors.centerIn: parent
                    sourceComponent: root.image ? imageComp : root.appIcon ? appIconComp : fallbackIconComp
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

                    color: root.urgency === "critical" ? Colours.palette.error : root.urgency === "low" ? Colours.palette.surface_container_highest : Colours.palette.secondary_container
                    radius: Appearance.rounding.full

                    ColouredIcon {
                        anchors.centerIn: parent
                        implicitSize: Math.round(Config.notifs.sizes.badge * 0.6)
                        source: Quickshell.iconPath(root.appIcon)
                        colour: root.urgency === "critical" ? Colours.palette.on_error : root.urgency === "low" ? Colours.palette.on_surface : Colours.palette.on_secondary_container
                        layer.enabled: root.appIcon.endsWith("symbolic")
                    }
                }
            }
        }

        ColumnLayout {
            Layout.topMargin: -Appearance.padding.extraSmall
            Layout.bottomMargin: -Appearance.padding.extraSmall / 2 - (root.expanded ? 0 : spacing)
            Layout.fillWidth: true
            spacing: Math.round(Appearance.spacing.extraSmall)

            RowLayout {
                Layout.bottomMargin: -parent.spacing
                Layout.fillWidth: true
                spacing: Appearance.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: root.modelData
                    color: Colours.palette.on_surface_variant
                    font: Appearance.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    animate: true
                    text: root.notifs[0]?.timeStr ?? ""
                    color: Colours.palette.outline
                    font: Appearance.font.body.small
                }

                StyledRect {
                    implicitWidth: expandBtn.implicitWidth + Appearance.padding.large
                    implicitHeight: groupCount.implicitHeight + Appearance.padding.extraSmall

                    color: root.urgency === "critical" ? Colours.palette.error : Colours.layer(Colours.palette.surface_container_highest, 2)
                    radius: Appearance.rounding.full

                    opacity: root.notifs.length > Config.notifs.groupPreviewNum ? 1 : 0
                    Layout.preferredWidth: root.notifs.length > Config.notifs.groupPreviewNum ? implicitWidth : 0

                    StateLayer {
                        color: root.urgency === "critical" ? Colours.palette.on_error : Colours.palette.on_surface

                        function onClicked(): void {
                            root.expanded = !root.expanded;
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
                            text: root.notifs.length
                            color: root.urgency === "critical" ? Colours.palette.on_error : Colours.palette.on_surface
                            font: Appearance.font.body.small
                        }

                        StyledIcon {
                            Layout.rightMargin: -Appearance.padding.extraSmall / 2
                            animate: true
                            text: root.expanded ? "" : "" // tabler chevron-up / chevron-down
                            color: root.urgency === "critical" ? Colours.palette.on_error : Colours.palette.on_surface
                        }
                    }

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on Layout.preferredWidth {
                        Anim {}
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: root.notifs.slice(0, Config.notifs.groupPreviewNum)
                }

                NotifLine {
                    id: notif

                    ParallelAnimation {
                        running: true

                        Anim {
                            type: Anim.DefaultEffects
                            target: notif
                            property: "opacity"
                            from: 0
                            to: 1
                        }
                        Anim {
                            target: notif
                            property: "scale"
                            from: 0.7
                            to: 1
                        }
                        Anim {
                            target: notif.Layout
                            property: "preferredHeight"
                            from: 0
                            to: notif.implicitHeight
                        }
                    }

                    ParallelAnimation {
                        running: notif.modelData.closed
                        onFinished: notif.modelData.unlock(notif)

                        Anim {
                            type: Anim.DefaultEffects
                            target: notif
                            property: "opacity"
                            to: 0
                        }
                        Anim {
                            target: notif
                            property: "scale"
                            to: 0.7
                        }
                        Anim {
                            target: notif.Layout
                            property: "preferredHeight"
                            to: 0
                        }
                    }
                }
            }

            Loader {
                asynchronous: true
                Layout.fillWidth: true

                opacity: root.expanded ? 1 : 0
                Layout.preferredHeight: root.expanded ? implicitHeight : 0
                active: opacity > 0

                sourceComponent: ColumnLayout {
                    Repeater {
                        model: ScriptModel {
                            values: root.notifs.slice(Config.notifs.groupPreviewNum)
                        }

                        NotifLine {}
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    component NotifLine: StyledText {
        id: notifLine

        required property var modelData

        Layout.fillWidth: true
        textFormat: Text.MarkdownText
        text: {
            const summary = modelData.summary.replace(/\n/g, " ");
            const body = modelData.body.replace(/\n/g, " ");
            const colour = root.urgency === "critical" ? Colours.palette.secondary : Colours.palette.outline;

            if (metrics.text === metrics.elidedText)
                return `${summary} <span style='color:${colour}'>${body}</span>`;

            const t = metrics.elidedText.length - 3;
            if (t < summary.length)
                return `${summary.slice(0, t)}...`;

            return `${summary} <span style='color:${colour}'>${body.slice(0, t - summary.length)}...</span>`;
        }
        color: root.urgency === "critical" ? Colours.palette.on_secondary_container : Colours.palette.on_surface

        Component.onCompleted: modelData.lock(this)
        Component.onDestruction: modelData.unlock(this)

        TextMetrics {
            id: metrics

            text: `${notifLine.modelData.summary} ${notifLine.modelData.body}`.replace(/\n/g, " ")
            font: notifLine.font
            elideWidth: notifLine.width
            elide: Text.ElideRight
        }
    }
}
