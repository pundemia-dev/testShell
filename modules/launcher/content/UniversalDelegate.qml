import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick

// Корень — обычный Rectangle, НЕ ClippingRectangle: тот рендерит всех детей
// через ShaderEffectSource-текстуру, и при гонке на создании делегата (нулевая
// ширина до привязки parent) текстура может не подняться — строка занимает
// место, но не рисуется. Клипгинг нужен только фоновой картинке — он живёт
// в её Loader ниже.
StyledRect {
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

    // --- ФУНКЦИИ ---

    function trigger() {
        if (root.modelData && typeof root.modelData.onClicked === "function")
            root.modelData.onClicked(root.modelData, root.list);
    }

    function triggerAlt() {
        if (root.modelData && typeof root.modelData.onAltClicked === "function")
            root.modelData.onAltClicked(root.modelData, root.list);
        else
            trigger();
    }

    // --- ФОН ПРИ НАВЕДЕНИИ (только без картинки) ---

    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: Colours.alpha(Colours.palette.surface_variant, 0.5)
        opacity: !root.hasBackground && stateLayer.containsMouse ? 1.0 : 0.0

        Behavior on opacity {
            Anim {}
        }
    }

    // --- ВЫДЕЛЕНИЕ ПРИ НАВИГАЦИИ (только без картинки) ---

    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: Colours.palette.on_surface
        opacity: !root.hasBackground && root.isCurrent ? 0.08 : 0.0

        Behavior on opacity {
            Anim {}
        }
    }

    // --- STATE LAYER ---

    StateLayer {
        id: stateLayer

        radius: root.radius
        z: 10

        function onClicked(): void {
            root.trigger();
        }

        onEntered: {
            // Пока список прокручивается, строки сами проезжают под курсором —
            // не воровать выделение (это дёргало currentIndex → onSelected →
            // перезагрузку правой панели на каждый кадр прокрутки).
            let lv = root.list?.listView;
            if (lv && !lv.moving && !lv.flicking)
                lv.currentIndex = root.index;
        }
    }

    // --- ФОНОВОЕ ИЗОБРАЖЕНИЕ + ГРАДИЕНТ (клип по скруглению только здесь) ---

    Loader {
        id: bgImageLoader

        active: root.hasBackground
        anchors.fill: parent

        sourceComponent: StyledClippingRect {
            radius: root.radius

            Image {
                anchors.fill: parent
                source: root.modelData?.backgroundImage ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: root.isCurrent ? 1.0 : 0.88

                Behavior on opacity {
                    Anim {}
                }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.2
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(0, 0, 0, 0.75)
                    }
                }
            }
        }
    }

    // --- РАМКА ВЫДЕЛЕНИЯ (поверх картинки — у Rectangle-корня она бы скрылась) ---

    Loader {
        active: root.hasBackground
        anchors.fill: parent

        sourceComponent: StyledRect {
            radius: root.radius
            border.width: root.isCurrent ? 1.5 : 0
            border.color: Colours.alpha(Colours.palette.primary, 0.4)

            Behavior on border.width {
                Anim {}
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

            active: !root.hasBackground && ((root.modelData?.leftIcon ? true : false) || (root.modelData?.swatchColor ? true : false))
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: active ? height : 0
            height: parent.height * 0.8

            sourceComponent: root.modelData?.swatchColor ? swatchComp : (root.modelData?.isLeftIconImage ? leftImageComp : leftFontComp)

            // Плашка сплошного цвета (буфер обмена: HEX/RGB/HSL-записи).
            Component {
                id: swatchComp

                StyledRect {
                    anchors.centerIn: parent
                    width: parent.width * 0.82
                    height: width
                    radius: Appearance.rounding.small
                    color: root.modelData?.swatchColor ?? "transparent"
                    border.width: 1
                    border.color: Colours.alpha(Colours.palette.outline, 0.4)
                }
            }

            Component {
                id: leftImageComp

                IconImage {
                    source: root.modelData?.leftIcon ? Quickshell.iconPath(root.modelData.leftIcon, "image-missing") : ""
                    anchors.fill: parent
                }
            }

            Component {
                id: leftFontComp

                // Rounded square backing plate behind the glyph (only for the
                // font-icon branch — image/swatch branches keep their own look).
                // StyledIcon (not StyledText) so leftIcon glyphs render in the
                // tabler family — the leftIcon slot is always an icon (clipboard,
                // module picker, todo checkbox), matching how rightIcon works.
                StyledRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.medium
                    color: Colours.palette.secondary_container

                    StyledIcon {
                        anchors.centerIn: parent
                        text: root.modelData?.leftIcon ?? ""
                        font.pointSize: Appearance.font.size.large
                        color: Colours.palette.on_secondary_container
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
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
                color: root.hasBackground ? Qt.rgba(1, 1, 1, 0.7) : Colours.alpha(Colours.palette.outline, true)
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
                color: root.hasBackground ? Qt.rgba(1, 1, 1, 0.8) : Colours.palette.on_surface_variant
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                opacity: (root.isCurrent || stateLayer.containsMouse) ? 1.0 : 0.0

                Behavior on opacity {
                    Anim {}
                }
            }

            // Правая иконка-картинка (видна только при выделении/наведении)
            IconImage {
                id: rightIconImage

                visible: (root.modelData?.isRightIconImage ?? false) && (root.modelData?.rightIcon ? true : false)
                source: visible ? Quickshell.iconPath(root.modelData.rightIcon, "image-missing") : ""
                implicitSize: Appearance.font.size.normal * 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                opacity: (root.isCurrent || stateLayer.containsMouse) ? 1.0 : 0.0

                Behavior on opacity {
                    Anim {}
                }
            }

            // Правый текст (снизу, прижат вправо)
            StyledText {
                id: rightText

                text: root.modelData?.rightText ?? ""
                font.pointSize: Appearance.font.size.small
                color: root.hasBackground ? Qt.rgba(1, 1, 1, 0.5) : Colours.alpha(Colours.palette.outline, true)
                anchors.bottom: parent.bottom
                anchors.right: parent.right
            }
        }
    }
}
