pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.containers
import qs.components.effects
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Ported from caelestia sidebar/NotifActionList: a horizontal strip of action
// pills for an expanded notification — close + the notification's own actions
// + copy-body. Overflow scrolls horizontally under a gradient edge fade.
Item {
    id: root

    required property var notif

    Layout.fillWidth: true
    implicitHeight: flickable.contentHeight

    layer.enabled: true
    layer.smooth: true
    layer.effect: Mask {
        maskSource: gradientMask
    }

    Item {
        id: gradientMask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0)
                }
                GradientStop {
                    position: 0.1
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: 0.9
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0)
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left

            implicitWidth: parent.width / 2
            opacity: flickable.contentX > 0 ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right

            implicitWidth: parent.width / 2
            opacity: flickable.contentX < flickable.contentWidth - parent.width ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    StyledFlickable {
        id: flickable

        anchors.fill: parent
        contentWidth: Math.max(width, actionList.implicitWidth)
        contentHeight: actionList.implicitHeight

        RowLayout {
            id: actionList

            anchors.fill: parent
            spacing: Appearance.spacing.small

            Repeater {
                model: [
                    {
                        isClose: true
                    },
                    ...(root.notif?.actions ?? []),
                    {
                        isCopy: true
                    }
                ]

                StyledRect {
                    id: action

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitWidth: actionInner.implicitWidth + Appearance.padding.medium * 2
                    implicitHeight: actionInner.implicitHeight + Appearance.padding.small

                    Layout.preferredWidth: implicitWidth + (actionStateLayer.pressed ? Appearance.padding.large : 0)
                    radius: actionStateLayer.pressed ? Appearance.rounding.small : Appearance.rounding.medium
                    color: Colours.layer(Colours.palette.surface_container_highest, 4)

                    Timer {
                        id: copyTimer

                        interval: 3000
                        onTriggered: actionInner.item.text = "\uea7a" // tabler copy
                    }

                    StateLayer {
                        id: actionStateLayer

                        radius: action.radius
                        function onClicked(): void {
                            if (action.modelData.isClose) {
                                root.notif.close();
                            } else if (action.modelData.isCopy) {
                                Quickshell.clipboardText = root.notif.body;
                                actionInner.item.text = "\uea6c"; // tabler clipboard-check
                                copyTimer.start();
                            } else if (action.modelData.invoke) {
                                action.modelData.invoke();
                            } else if (!root.notif.resident) {
                                root.notif.close();
                            }
                        }
                    }

                    Loader {
                        id: actionInner

                        anchors.centerIn: parent
                        // Actions may carry an unresolvable icon name or an
                        // empty label — fall through to a generic glyph so the
                        // pill is never blank.
                        sourceComponent: {
                            if (action.modelData.isClose || action.modelData.isCopy)
                                return iconBtn;
                            if (root.notif?.hasActionIcons && Quickshell.iconPath(action.modelData.identifier, true))
                                return iconComp;
                            if (action.modelData.text)
                                return textComp;
                            return fallbackComp;
                        }
                    }

                    Component {
                        id: iconBtn

                        StyledIcon {
                            animate: action.modelData.isCopy ?? false
                            text: action.modelData.isCopy ? "\uea7a" : "\ueb55" // tabler copy / x
                            color: Colours.palette.on_surface_variant
                        }
                    }

                    Component {
                        id: iconComp

                        IconImage {
                            asynchronous: true
                            source: Quickshell.iconPath(action.modelData.identifier)
                        }
                    }

                    Component {
                        id: textComp

                        StyledText {
                            text: action.modelData.text
                            color: Colours.palette.on_surface_variant
                        }
                    }

                    Component {
                        id: fallbackComp

                        StyledIcon {
                            text: "\uef4f" // tabler hand-click
                            color: Colours.palette.on_surface_variant
                        }
                    }

                    Behavior on Layout.preferredWidth {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    Behavior on radius {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }
            }
        }
    }
}
