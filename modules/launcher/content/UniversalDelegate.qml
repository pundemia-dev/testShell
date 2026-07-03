import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick

StyledClippingRect {
    id: root

    required property var modelData
    required property var list
    required property int index

    readonly property bool isCurrent: ListView.isCurrentItem
    readonly property bool hasBackground: root.modelData?.backgroundImage ? true : false

    implicitHeight: hasBackground ? Config.launcher.itemHeight * 2 : Config.launcher.itemHeight
    width: parent?.width ?? 0

    radius: Appearance.rounding.large
    color: hasBackground ? Colours.tPalette.surface : "transparent"

    border.width: isCurrent && hasBackground ? 1.5 : 0
    border.color: Colours.alpha(Colours.palette.primary, 0.4)

    Behavior on border.width { Anim {} }

    // --- ФУНКЦИИ ---

    function trigger() {
        if (root.modelData && typeof root.modelData.onClicked === "function")
            root.modelData.onClicked(root.modelData, root.list)
    }

    function triggerAlt() {
        if (root.modelData && typeof root.modelData.onAltClicked === "function")
            root.modelData.onAltClicked(root.modelData, root.list)
        else
            trigger()
    }

    // --- ФОН ПРИ НАВЕДЕНИИ (только без картинки) ---

    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: Colours.alpha(Colours.palette.surface_variant, 0.5)
        opacity: !root.hasBackground && stateLayer.containsMouse ? 1.0 : 0.0

        Behavior on opacity { Anim {} }
    }

    // --- ВЫДЕЛЕНИЕ ПРИ НАВИГАЦИИ (только без картинки) ---

    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: Colours.palette.on_surface
        opacity: !root.hasBackground && root.isCurrent ? 0.08 : 0.0

        Behavior on opacity { Anim {} }
    }

    // --- STATE LAYER ---

    StateLayer {
        id: stateLayer

        radius: root.radius
        z: 10

        function onClicked(): void {
            root.trigger()
        }

        onEntered: {
            let lv = root.list?.listView
            if (lv) lv.currentIndex = root.index
        }
    }

    // --- ФОНОВОЕ ИЗОБРАЖЕНИЕ ---

    Loader {
        id: bgImageLoader

        active: root.hasBackground
        anchors.fill: parent

        sourceComponent: Image {
            source: root.modelData?.backgroundImage ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: root.isCurrent ? 1.0 : 0.88

            Behavior on opacity { Anim {} }
        }
    }

    // --- ГРАДИЕНТ ПОВЕРХ КАРТИНКИ ---

    Loader {
        active: root.hasBackground
        anchors.fill: parent

        sourceComponent: Rectangle {
            gradient: Gradient {
                GradientStop { position: 0.2; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
            }
        }
    }

    // --- КОНТЕНТ ---

    Item {
        id: contentArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        height: root.hasBackground ? root.height / 2 : root.height

        // --- ЛЕВАЯ ИКОНКА ---

        Loader {
            id: leftIconLoader

            active: !root.hasBackground && (root.modelData?.leftIcon ? true : false)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: active ? height : 0
            height: parent.height * 0.8

            sourceComponent: root.modelData?.isLeftIconImage ? leftImageComp : leftFontComp

            Component {
                id: leftImageComp

                IconImage {
                    source: root.modelData?.leftIcon
                        ? Quickshell.iconPath(root.modelData.leftIcon, "image-missing")
                        : ""
                    anchors.fill: parent
                }
            }

            Component {
                id: leftFontComp

                StyledText {
                    text: root.modelData?.leftIcon ?? ""
                    font.pointSize: Appearance.font.size.large
                    color: Colours.palette.on_surface
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    anchors.fill: parent
                }
            }
        }

        // --- БЛОК ТЕКСТА (header + text) ---

        Item {
            id: textBlock

            anchors.left: leftIconLoader.right
            anchors.leftMargin: leftIconLoader.active ? Appearance.spacing.medium : 0
            anchors.right: rightContentBlock.left
            anchors.rightMargin: Appearance.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: headerText.implicitHeight + subText.implicitHeight

            StyledText {
                id: headerText

                text: root.modelData?.header ?? ""
                font.pointSize: Appearance.font.size.normal
                font.weight: Font.DemiBold
                color: root.hasBackground ? "white" : Colours.palette.primary
                width: parent.width
                elide: Text.ElideRight
            }

            StyledText {
                id: subText

                text: root.modelData?.text ?? ""
                font.pointSize: Appearance.font.size.small
                color: root.hasBackground
                    ? Qt.rgba(1, 1, 1, 0.7)
                    : Colours.alpha(Colours.palette.outline, true)
                width: parent.width
                elide: Text.ElideRight
                anchors.top: headerText.bottom
            }
        }

        // --- ПРАВЫЙ БЛОК (rightIcon + rightText) ---

        Item {
            id: rightContentBlock

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            width: Math.max(rightIcon.implicitWidth, rightIconImage.implicitWidth, rightText.implicitWidth)

            // Правая иконка-шрифт (видна только при выделении/наведении)
            StyledIcon {
                id: rightIcon

                visible: !root.modelData?.isRightIconImage && (root.modelData?.rightIcon ? true : false)
                text: root.modelData?.rightIcon ?? ""
                font.pointSize: Appearance.font.size.normal
                color: root.hasBackground
                    ? Qt.rgba(1, 1, 1, 0.8)
                    : Colours.palette.on_surface_variant
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                opacity: (root.isCurrent || stateLayer.containsMouse) ? 1.0 : 0.0

                Behavior on opacity { Anim {} }
            }

            // Правая иконка-картинка (видна только при выделении/наведении)
            IconImage {
                id: rightIconImage

                visible: (root.modelData?.isRightIconImage ?? false) && (root.modelData?.rightIcon ? true : false)
                source: visible
                    ? Quickshell.iconPath(root.modelData.rightIcon, "image-missing")
                    : ""
                implicitSize: Appearance.font.size.normal * 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                opacity: (root.isCurrent || stateLayer.containsMouse) ? 1.0 : 0.0

                Behavior on opacity { Anim {} }
            }

            // Правый текст (снизу, прижат вправо)
            StyledText {
                id: rightText

                text: root.modelData?.rightText ?? ""
                font.pointSize: Appearance.font.size.small
                color: root.hasBackground
                    ? Qt.rgba(1, 1, 1, 0.5)
                    : Colours.alpha(Colours.palette.outline, true)
                anchors.bottom: parent.bottom
                anchors.right: parent.right
            }
        }
    }
}
