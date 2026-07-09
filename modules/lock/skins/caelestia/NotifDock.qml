pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config

ColumnLayout {
    id: root

    required property var lock

    anchors.fill: parent
    anchors.margins: Appearance.padding.large

    spacing: Appearance.spacing.medium

    StyledText {
        Layout.fillWidth: true
        text: Notifs.list.length > 0 ? qsTr("%1 notification%2").arg(Notifs.list.length).arg(Notifs.list.length === 1 ? "" : "s") : qsTr("Notifications")
        color: Colours.palette.outline
        font.family: Appearance.font.family.mono
        font.pointSize: Appearance.font.mono.small.pointSize
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    ClippingRectangle {
        id: clipRect

        Layout.fillWidth: true
        Layout.fillHeight: true

        radius: Appearance.rounding.medium
        color: "transparent"

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            active: opacity > 0
            opacity: Notifs.list.length > 0 && !Config.lock.hideNotifs ? 0 : 1

            sourceComponent: ColumnLayout {
                spacing: Appearance.spacing.largeIncreased

                Loader {
                    Layout.alignment: Qt.AlignHCenter
                    active: Config.lock.noNotifsPic !== ""
                    visible: active
                    asynchronous: true

                    sourceComponent: Image {
                        asynchronous: true
                        source: Qt.resolvedUrl(Paths.absolutePath(Config.lock.noNotifsPic))
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: clipRect.width * 0.8 * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)

                        layer.enabled: true
                        layer.effect: Colouriser {
                            colorizationColor: Colours.palette.outline_variant
                            brightness: 1
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Config.lock.hideNotifs ? qsTr("Unlock for Notifications") : qsTr("No Notifications")
                    color: Colours.palette.outline_variant
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.mono.large.pointSize
                    font.weight: Font.Medium
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardExtraLarge
                }
            }
        }

        StyledListView {
            anchors.fill: parent
            visible: !Config.lock.hideNotifs
            spacing: Appearance.spacing.small
            clip: true

            model: ScriptModel {
                values: {
                    const list = Notifs.notClosed.map(n => [n.appName, null]);
                    return [...new Map(list).keys()];
                }
            }

            delegate: NotifGroup {}

            add: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    from: 0
                    to: 1
                }
                Anim {
                    property: "scale"
                    from: 0
                    to: 1
                }
            }

            remove: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    to: 0
                }
                Anim {
                    property: "scale"
                    to: 0.6
                }
            }

            move: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    properties: "opacity,scale"
                    to: 1
                }
                Anim {
                    property: "y"
                }
            }

            displaced: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    properties: "opacity,scale"
                    to: 1
                }
                Anim {
                    property: "y"
                }
            }
        }
    }
}
