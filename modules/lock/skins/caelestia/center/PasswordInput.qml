pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import qs.components
import qs.components.controls
import qs.services
import qs.config

StyledRect {
    id: root

    required property real centerScale
    required property int centerWidth
    required property var lock

    implicitWidth: {
        const w = centerWidth * 0.8;
        return lock.pam.buffer ? w : Math.min(w, inputField.placeholderWidth + iconWrapper.implicitWidth + enterButton.implicitWidth + input.spacing * 2 + Appearance.padding.medium * 2);
    }
    implicitHeight: input.implicitHeight + Appearance.padding.small

    color: Colours.tPalette.surface_container
    radius: Appearance.rounding.full

    focus: true
    onActiveFocusChanged: {
        if (!activeFocus)
            forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (root.lock.unlocking)
            return;

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
            inputField.placeholder.animate = false;

        root.lock.pam.handleKey(event);
    }

    Behavior on implicitWidth {
        Anim {}
    }

    StateLayer {
        hoverEnabled: false
        cursorShape: Qt.IBeamCursor

        function onClicked(): void {
            root.forceActiveFocus();
        }
    }

    RowLayout {
        id: input

        anchors.fill: parent
        anchors.margins: Appearance.padding.extraSmall
        spacing: Appearance.spacing.medium

        Item {
            id: iconWrapper

            Layout.fillHeight: true
            implicitWidth: height

            AnimLoader {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: sourceComponent === iconComp ? 1 : 0
                sourceComp: root.lock.pam.passwd.active ? loadingComp : iconComp
            }

            Component {
                id: iconComp

                StyledIcon {
                    animate: true
                    text: {
                        if (root.lock.pam.fprint.tries >= Config.lock.maxFprintTries)
                            return ""; // tabler fingerprint-off
                        if (root.lock.pam.fprint.active)
                            return ""; // tabler fingerprint
                        return ""; // tabler lock
                    }
                    color: root.lock.pam.fprint.tries >= Config.lock.maxFprintTries ? Colours.palette.error : Colours.palette.on_surface_variant
                    font.pointSize: Math.max(1, Math.round(Appearance.font.icon.medium.pointSize * root.centerScale))
                }
            }

            Component {
                id: loadingComp

                LoadingIndicator {
                    implicitSize: iconWrapper.height - Appearance.padding.small * 2
                }
            }
        }

        InputField {
            id: inputField

            Layout.fillWidth: true
            Layout.fillHeight: true

            centerScale: root.centerScale
            pam: root.lock.pam
        }

        Item {
            id: enterButton

            implicitWidth: implicitHeight
            implicitHeight: {
                const h = enterIcon.implicitHeight + Appearance.padding.extraSmall * 2;
                return h % 2 === 0 ? h : h + 1;
            }

            MaterialShape {
                anchors.fill: parent

                color: root.lock.pam.buffer ? Colours.palette.primary : Colours.layer(Colours.palette.surface_container_high, 2)
                shape: root.lock.pam.buffer ? MaterialShape.Arrow : MaterialShape.Circle
                scale: !root.lock.pam.buffer ? 1 : mouse.pressed ? 0.6 : mouse.containsMouse ? 0.8 : 0.7
                rotation: 90

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Behavior on color {
                    CAnim {}
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.lock.pam.buffer ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.lock.pam.buffer && root.lock.pam.passwd.start()
                }
            }

            StyledIcon {
                id: enterIcon

                anchors.centerIn: parent
                text: "" // tabler arrow-right
                color: Colours.palette.on_surface_variant
                font.pointSize: Math.max(1, Math.round(Appearance.font.icon.medium.pointSize * root.centerScale * 1.2))
                opacity: root.lock.pam.buffer ? 0 : 1

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }
    }
}
