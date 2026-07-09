pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import M3Shapes
import qs.components
import qs.services
import qs.config

Item {
    id: root

    required property real centerScale
    required property var pam
    readonly property alias placeholder: placeholder
    readonly property alias placeholderWidth: nonAnimPlaceholder.width
    property string buffer
    readonly property list<int> shapeQueue: {
        const shapes = [MaterialShape.Slanted, MaterialShape.Arch, MaterialShape.Fan, MaterialShape.Arrow, MaterialShape.SemiCircle, MaterialShape.Triangle, MaterialShape.Diamond, MaterialShape.ClamShell, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Sunny, MaterialShape.VerySunny, MaterialShape.Cookie4Sided, MaterialShape.Ghostish, MaterialShape.SoftBurst];
        for (let i = shapes.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [shapes[i], shapes[j]] = [shapes[j], shapes[i]];
        }
        return shapes;
    }

    clip: true

    Connections {
        function onBufferChanged(): void {
            if (root.pam.buffer.length > root.buffer.length) {
                charList.bindImWidth();
            } else if (root.pam.buffer.length === 0) {
                charList.implicitWidth = charList.implicitWidth;
                placeholder.animate = true;
            }

            root.buffer = root.pam.buffer;
        }

        target: root.pam
    }

    TextMetrics {
        id: nonAnimPlaceholder

        text: {
            if (root.pam.passwd.active)
                return qsTr("Loading...");
            if (root.pam.state === "max")
                return qsTr("Max tries reached");
            return qsTr("Enter your password");
        }
        font: placeholder.font
    }

    StyledText {
        id: placeholder

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1

        text: nonAnimPlaceholder.text

        animate: true
        color: root.pam.passwd.active ? Colours.palette.secondary : Colours.palette.outline
        font.family: Appearance.font.family.sans
        font.pointSize: Math.max(1, Math.round(Appearance.font.body.medium.pointSize * root.centerScale))

        opacity: root.buffer ? 0 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    ListView {
        id: charList

        readonly property int fullWidth: {
            let w = (count - 1) * spacing;
            for (let i = 0; i < count; i++)
                w += ((itemAtIndex(i) as CharItem)?.nonAnimWidthScale ?? 1) * implicitHeight;
            return w + implicitHeight; // Extra padding at ends
        }

        function bindImWidth(): void {
            imWidthBehavior.enabled = false;
            implicitWidth = Qt.binding(() => fullWidth);
            imWidthBehavior.enabled = true;
        }

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: implicitWidth > root.width ? -(implicitWidth - root.width) / 2 : 0

        implicitWidth: fullWidth
        implicitHeight: Appearance.font.body.medium.pointSize

        orientation: Qt.Horizontal
        spacing: Appearance.spacing.extraSmall
        interactive: false

        model: ScriptModel {
            values: root.buffer.split("")
        }

        delegate: CharItem {}

        Behavior on implicitWidth {
            id: imWidthBehavior

            Anim {}
        }
    }

    component CharItem: Item {
        id: char

        required property int index
        property real nonAnimWidthScale: 1

        implicitHeight: charList.implicitHeight

        ListView.onRemove: {
            initAnim.stop();
            removeAnim.start();
        }

        MaterialShape {
            id: charShape

            anchors.centerIn: parent
            implicitSize: charList.implicitHeight * 1.5
            shape: root.shapeQueue[char.index % root.shapeQueue.length] ?? MaterialShape.Circle
            color: Colours.palette.on_surface

            Behavior on color {
                CAnim {}
            }

            SequentialAnimation {
                id: initAnim

                running: true

                ParallelAnimation {
                    Anim {
                        target: charShape
                        property: "opacity"
                        from: 0
                        to: 1
                        type: Anim.DefaultEffects
                    }
                    Anim {
                        target: charShape
                        property: "scale"
                        from: 0
                        to: 1
                        type: Anim.FastSpatial
                    }
                    Anim {
                        target: char
                        property: "implicitWidth"
                        from: charList.implicitHeight
                        to: charList.implicitHeight * 1.3
                        type: Anim.DefaultEffects
                    }
                    PropertyAction {
                        target: char
                        property: "nonAnimWidthScale"
                        value: 1.5
                    }
                }
                PauseAnimation {
                    duration: 180
                }
                PropertyAction {
                    target: charShape
                    property: "shape"
                    value: MaterialShape.Circle
                }
                ParallelAnimation {
                    Anim {
                        target: charShape
                        property: "scale"
                        to: 2 / 3
                        type: Anim.FastSpatial
                    }
                    Anim {
                        target: char
                        property: "implicitWidth"
                        to: charList.implicitHeight
                        type: Anim.DefaultEffects
                    }
                    PropertyAction {
                        target: char
                        property: "nonAnimWidthScale"
                        value: 1
                    }
                }
            }

            SequentialAnimation {
                id: removeAnim

                PropertyAction {
                    target: char
                    property: "ListView.delayRemove"
                    value: true
                }
                ParallelAnimation {
                    Anim {
                        type: Anim.DefaultEffects
                        target: charShape
                        property: "opacity"
                        to: 0
                    }
                    Anim {
                        target: charShape
                        property: "scale"
                        to: 0.5
                    }
                }
                PropertyAction {
                    target: char
                    property: "ListView.delayRemove"
                    value: false
                }
            }
        }
    }
}
