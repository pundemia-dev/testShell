import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    signal closeRequested()

    required property var moduleManager

    signal moveUp()
    signal moveDown()
    signal moveLeft()
    signal moveRight()
    signal execute(string query, bool isAlt)
    signal modifierPressed(int key)
    signal modifierReleased(int key)

    implicitHeight: 50

    function clear() {
        inputField.text = ""
    }

    function forceInputFocus() {
        inputField.forceActiveFocus()
    }

    Connections {
        target: root.moduleManager
        function onModuleActivatedForUI(moduleName) {
            inputField.text = ""
            inputField.forceActiveFocus()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Config.launcher.gap ?? 8

        StyledRect {
            id: searchContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 15
            color: Colours.tPalette.surface_container

            // Удобные проперти для управления цветами и состояниями
            property bool isModActive: root.moduleManager.currentState === root.moduleManager.stateActive
            property bool isErr: root.moduleManager.isEscapePending

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: inputField.forceActiveFocus()
            }

            // --- ПИЛЮЛЯ (Базовый левый якорь) ---
            StyledRect {
                id: pill
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.small ?? 8
                anchors.verticalCenter: parent.verticalCenter

                // Высота пилюли
                height: inputField.implicitHeight - 8//+ 8

                // Ширина: если активна - ширина контента + 12px отступ, иначе - просто круг (равна высоте)
                width: searchContainer.isModActive ? pillContent.implicitWidth + 12 : height
                radius: height / 2 // Всегда идеальный круг или закругленная пилюля
                clip: true

                // Цвет фона и обводки плавно меняется из прозрачного в цветной
                color: searchContainer.isModActive
                    ? (searchContainer.isErr ? Colours.palette.error : Colours.palette.primary)
                    : "transparent"

                border.width: 1
                border.color: searchContainer.isModActive
                    ? (searchContainer.isErr ? Colours.palette.error : Colours.palette.primary)
                    : "transparent"

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                // Внутренний контент пилюли
                Row {
                    id: pillContent
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // 1. Невидимый блок, который резервирует место под лупу (равен квадрату высоты пилюли)
                    Item {
                        width: pill.height
                        height: pill.height
                    }

                    // 2. Текст модуля (Иконка + moduleId)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        // Текст плавно проявляется, когда пилюля начинает раскрываться
                        opacity: searchContainer.isModActive ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InQuad } }

                        // StyledText {
                        //     text: root.moduleManager.activeModule?.icon ?? ""
                        //     font.pointSize: Appearance.font.size.normal
                        //     visible: text !== ""
                        //     anchors.verticalCenter: parent.verticalCenter
                        // }

                        StyledText {
                            // Имя активного модуля из его манифеста
                            text: root.moduleManager.activeManifest?.title ?? ""
                            font.pointSize: Appearance.font.size.normal
                            font.weight: Font.DemiBold
                            // color: searchContainer.isErr ? Colours.palette.error : Colours.palette.primary
                            color: searchContainer.isErr ? Colours.palette.on_error : Colours.palette.on_primary
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }

            // --- ИКОНКА ПОИСКА (Наложена поверх пилюли) ---
            StyledIcon {
                id: searchIcon
                anchors.left: pill.left
                anchors.verticalCenter: pill.verticalCenter

                // Центрируем иконку строго внутри левой круглой части пилюли
                width: pill.height
                horizontalAlignment: Text.AlignHCenter

                text: "\ueb1c"
                font.pointSize: Appearance.font.size.large ?? 16

                // Цвет красится вместе с пилюлей
                color: searchContainer.isModActive
                    ? (searchContainer.isErr ? Colours.palette.on_error : Colours.palette.on_primary)
                    : Colours.palette.on_surface
                // color: searchContainer.isModActive
                //     ? (searchContainer.isErr ? Colours.palette.error : Colours.palette.primary)
                //     : Colours.palette.on_surface_variant

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // --- КНОПКА ОЧИСТКИ (Справа) ---
            StyledIcon {
                id: clearIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.medium ?? 12
                width: inputField.text ? implicitWidth : implicitWidth / 2
                opacity: {
                    if (!inputField.text) return 0
                    if (clearMouse.pressed) return 0.7
                    if (clearMouse.containsMouse) return 0.8
                    return 1
                }
                text: "\ue5cd"
                color: Colours.palette.on_surface_variant
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: inputField.text ? Qt.PointingHandCursor : undefined
                    onClicked: {
                        inputField.text = ""
                        root.moduleManager.processInput("")
                        inputField.forceActiveFocus()
                    }
                }
                Behavior on width  { NumberAnimation { duration: Appearance.anim.durations.small } }
                Behavior on opacity { NumberAnimation { duration: Appearance.anim.durations.small } }
            }

            // --- ПОЛЕ ВВОДА ---
            StyledTextField {
                id: inputField

                // Привязываем левый край поля к правому краю пилюли
                anchors.left: pill.right
                anchors.leftMargin: Appearance.spacing.small
                anchors.right: clearIcon.left
                anchors.verticalCenter: parent.verticalCenter

                topPadding: Appearance.padding.large
                bottomPadding: Appearance.padding.large
                placeholderText: qsTr("Type \"%1\" for commands").arg(root.moduleManager.magicSymbol)

                onTextEdited: root.moduleManager.processInput(text)

                Keys.onPressed: (event) => {
                    // Forward bare modifier press (no Ctrl held — Ctrl combos are shortcuts)
                    if ((event.key === Qt.Key_Alt || event.key === Qt.Key_Shift)
                        && !(event.modifiers & Qt.ControlModifier)) {
                        root.modifierPressed(event.key)
                        return
                    }

                    // Отмена красной пилюли при любом вводе
                    if (event.key !== Qt.Key_Backspace || text.length > 0) {
                        root.moduleManager.cancelEscape()
                    }

                    switch (event.key) {
                    case Qt.Key_Backspace:
                        if (text.length === 0) {
                            let sym = root.moduleManager.handleBackspaceOnEmpty(event.isAutoRepeat)
                            if (sym !== null) {
                                text = sym
                                Qt.callLater(() => { cursorPosition = text.length })
                            }
                            event.accepted = true
                        }
                        break
                    case Qt.Key_Up:
                        root.moveUp()
                        event.accepted = true
                        break
                    case Qt.Key_Down:
                        root.moveDown()
                        event.accepted = true
                        break
                    case Qt.Key_Left:
                        if (text.length === 0 || cursorPosition === 0) {
                            root.moveLeft()
                            event.accepted = true
                        }
                        break
                    case Qt.Key_Right:
                        if (text.length === 0 || cursorPosition === text.length) {
                            root.moveRight()
                            event.accepted = true
                        }
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.execute(text, event.modifiers & Qt.AltModifier)
                        event.accepted = true
                        break
                    case Qt.Key_Escape:
                        root.closeRequested()
                        event.accepted = true
                        break
                    }
                }

                Keys.onReleased: (event) => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_Shift) {
                        root.modifierReleased(event.key)
                    }
                }

                Component.onCompleted: forceActiveFocus()
            }
        }

        Loader {
            id: extensionLoader
            Layout.fillHeight: true
            sourceComponent: root.moduleManager.activeModule?.inputExtensionComponent ?? null
            visible: status === Loader.Ready
            Layout.preferredWidth: visible ? item.implicitWidth : 0
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            clip: true
        }
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => inputField.forceActiveFocus())
        } else {
            inputField.text = ""
            if (root.moduleManager.currentState !== root.moduleManager.stateDefault)
                root.moduleManager.processInput("")
        }
    }
}





// import QtQuick
// import QtQuick.Layouts
// import qs.config
// import qs.utils
// import qs.components
// import qs.components.controls
// import qs.services

// Item {
//     id: root

//     required property var moduleManager

//     signal moveUp()
//     signal moveDown()
//     signal execute(string query, bool isAlt)
//     // signal execute(bool isAlt)

//     implicitHeight: 50

//     function clear() {
//         inputField.text = ""
//     }

//     function forceInputFocus() {
//         inputField.forceActiveFocus()
//     }

//     Connections {
//         target: root.moduleManager
//         function onModuleActivatedForUI(moduleName) {
//             inputField.text = ""
//             inputField.forceActiveFocus()
//         }
//     }

//     RowLayout {
//         anchors.fill: parent
//         spacing: Config.launcher.gap ?? 8

//         StyledRect {
//             id: searchContainer
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//             radius: 15
//             color: Colours.alpha(Colours.palette.surface_container, true)

//             MouseArea {
//                 anchors.fill: parent
//                 cursorShape: Qt.IBeamCursor
//                 onClicked: inputField.forceActiveFocus()
//             }

//             StyledIcon {
//                 id: searchIcon
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.left: parent.left
//                 anchors.leftMargin: Appearance.padding.medium ?? 12
//                 text: "\ueb1c"
//                 font.pointSize: Appearance.font.size.large ?? 16
//                 color: Colours.palette.on_surface_variant
//             }

//             StyledIcon {
//                 id: clearIcon
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.right: parent.right
//                 anchors.rightMargin: Appearance.padding.medium ?? 12
//                 width: inputField.text ? implicitWidth : implicitWidth / 2
//                 opacity: {
//                     if (!inputField.text) return 0
//                     if (clearMouse.pressed) return 0.7
//                     if (clearMouse.containsMouse) return 0.8
//                     return 1
//                 }
//                 text: "\ue5cd"
//                 color: Colours.palette.on_surface_variant
//                 MouseArea {
//                     id: clearMouse
//                     anchors.fill: parent
//                     hoverEnabled: true
//                     cursorShape: inputField.text ? Qt.PointingHandCursor : undefined
//                     onClicked: {
//                         inputField.text = ""
//                         root.moduleManager.processInput("")
//                         inputField.forceActiveFocus()
//                     }
//                 }
//                 Behavior on width  { NumberAnimation { duration: Appearance.anim.durations.small } }
//                 Behavior on opacity { NumberAnimation { duration: Appearance.anim.durations.small } }
//             }

//             // --- ПИЛЮЛЯ ---
//             StyledRect {
//                 id: pill
//                 visible: root.moduleManager.currentState === root.moduleManager.stateActive
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.left: searchIcon.right
//                 anchors.leftMargin: 8
//                 height: inputField.implicitHeight + 8
//                 // Цвет зависит от isEscapePending в ModuleManager
//                 color: root.moduleManager.isEscapePending
//                     ? Colours.alpha(Colours.palette.error, 0.2)
//                     : Colours.alpha(Colours.palette.primary, 0.15)
//                 radius: 8
//                 border.width: 1
//                 border.color: root.moduleManager.isEscapePending
//                     ? Colours.palette.error
//                     : Colours.palette.primary
//                 Behavior on color       { ColorAnimation { duration: 150 } }
//                 Behavior on border.color { ColorAnimation { duration: 150 } }

//                 Row {
//                     anchors.centerIn: parent
//                     anchors.leftMargin: 10
//                     anchors.rightMargin: 10
//                     spacing: 6
//                     StyledText {
//                         text: root.moduleManager.activeModule?.icon ?? ""
//                         font.pointSize: Appearance.font.size.normal
//                         visible: text !== ""
//                         anchors.verticalCenter: parent.verticalCenter
//                     }
//                     StyledText {
//                         text: root.moduleManager.activeModule?.name ?? ""
//                         font.pointSize: Appearance.font.size.normal
//                         font.weight: Font.DemiBold
//                         color: root.moduleManager.isEscapePending
//                             ? Colours.palette.error
//                             : Colours.palette.primary
//                         anchors.verticalCenter: parent.verticalCenter
//                         Behavior on color { ColorAnimation { duration: 150 } }
//                     }
//                 }

//                 width: visible ? implicitWidth + 20 : 0
//                 opacity: visible ? 1.0 : 0.0
//                 clip: true
//                 Behavior on opacity { NumberAnimation { duration: 200 } }
//                 Behavior on width   { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
//             }

//             // --- ПОЛЕ ВВОДА ---
//             StyledTextField {
//                 id: inputField
//                 anchors.left: pill.visible ? pill.right : searchIcon.right
//                 anchors.right: clearIcon.left
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.leftMargin: Appearance.spacing.small
//                 anchors.rightMargin: Appearance.spacing.small
//                 topPadding: Appearance.padding.large
//                 bottomPadding: Appearance.padding.large
//                 placeholderText: qsTr("Type \"%1\" for commands").arg(root.moduleManager.magicSymbol)

//                 onTextEdited: root.moduleManager.processInput(text)

//                 Keys.onPressed: (event) => {
//                     if (event.key !== Qt.Key_Backspace || text.length > 0) {
//                         root.moduleManager.cancelEscape()
//                     }
//                     switch (event.key) {
//                     case Qt.Key_Backspace:
//                         if (text.length === 0) {
//                             let sym = root.moduleManager.handleBackspaceOnEmpty()
//                             if (sym !== null) {
//                                 text = sym
//                                 Qt.callLater(() => { cursorPosition = text.length })
//                             }
//                             event.accepted = true
//                         }
//                         break
//                     case Qt.Key_Up:
//                         root.moveUp()
//                         event.accepted = true
//                         break
//                     case Qt.Key_Down:
//                         root.moveDown()
//                         event.accepted = true
//                         break
//                     case Qt.Key_Return:
//                     case Qt.Key_Enter:
//                         root.execute(text, event.modifiers & Qt.AltModifier)
//                         event.accepted = true
//                         break
//                     case Qt.Key_Escape:
//                         root.moduleManager.processInput("")
//                         event.accepted = true
//                         break
//                     }
//                 }

//                 Component.onCompleted: forceActiveFocus()
//             }
//         }

//         Loader {
//             id: extensionLoader
//             Layout.fillHeight: true
//             sourceComponent: root.moduleManager.activeModule?.inputExtensionComponent ?? null
//             visible: status === Loader.Ready
//             Layout.preferredWidth: visible ? item.implicitWidth : 0
//             Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
//             clip: true
//         }
//     }

//     onVisibleChanged: {
//         if (visible) {
//             Qt.callLater(() => inputField.forceActiveFocus())
//         } else {
//             inputField.text = ""
//             if (root.moduleManager.currentState !== root.moduleManager.stateDefault)
//                 root.moduleManager.processInput("")
//         }
//     }
// }
