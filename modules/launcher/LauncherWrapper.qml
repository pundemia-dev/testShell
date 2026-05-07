pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.utils
import Quickshell
import QtQuick
import qs.components
import QtQuick.Layouts
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.components.images
import "content"

Item {
    id: root
    // required property int screenHeight
    // required property int screenWidth
    required property var manager
    required property ShellScreen screen

    // Visibility state
    property bool launcherVisible: false
    property bool clearTrigger: false

    onLauncherVisibleChanged: {
        // onLauncherVisibleChanged: {
        //     if (launcherVisible) {
        //         rowInput.clear()
        //         moduleManager.activeModule?.onActivated("")
        //         moduleManager.processInput("")
        //     }
        // }f
            if (launcherVisible) {
                moduleManager._setActiveModule(moduleManager.defaultModule, "")
                moduleManager.currentState = moduleManager.stateDefault
                FocusManager.requestFocus("launcher");
            } else {
                FocusManager.releaseFocus("launcher");
            }
        }

        // Слушаем глобальную потерю фокуса (например, клик мышью мимо окна лаунчера)
        Connections {
            target: FocusManager
            function onFocusCleared() {
                if (root.launcherVisible) {
                    // Сообщаем VisibilitiesManager, что лаунчер нужно закрыть.
                    // Замени метод setVisibility на тот, который реально используется в твоем VisibilitiesManager
                    VisibilitiesManager.setVisibility(root.screen, "launcher", false);

                    // Если у менеджера нет метода setVisibility, можно использовать toggle:
                    // VisibilitiesManager.toggleVisibility(root.screen, "launcher")
                }
            }
        }


    // Регистрация visibility через менеджер (с поддержкой pendingRequests)
    Component.onCompleted: {
        VisibilitiesManager.addVisibility(root.screen, "launcher", "launcher", false, false, "Toggle Launcher");
    }

    // Слушаем изменения visibility от глобального менеджера
    Connections {
        target: VisibilitiesManager
        function onVisibilityChanged(screen: ShellScreen, name: string, state: bool) {
            if (screen === root.screen && name === "launcher") {
                root.launcherVisible = state;
            }
        }
    }

    Connections {
        target: moduleManager.activeModule
        function onRequestClose(closeLauncher) {
            if (closeLauncher) {
                VisibilitiesManager.setVisibility(root.screen, "launcher", false)
            } else {
                moduleManager.escapeCurrentState()
            }
        }
    }

    ModuleManager {
        id: moduleManager
    }
    Loader {
        id: shortcutsLoader
        active: moduleManager.activeModule?.hasRightPanel ?? false
        sourceComponent: moduleManager.activeModule?.shortcutsComponent ?? null
    }

    property QtObject content: QtObject {
        // Content size
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        // Anchors
        property bool aLeft: Config.launcher.anchors.left ?? undefined
        property bool aRight: Config.launcher.anchors.right ?? undefined
        property bool aTop: Config.launcher.anchors.top ?? undefined
        property bool aBottom: Config.launcher.anchors.bottom ?? undefined
        property bool aHorizontalCenter: Config.launcher.anchors.horizontalCenter ?? undefined
        property bool aVerticalCenter: Config.launcher.anchors.verticalCenter ?? undefined
        // Margins & offsets
        property var mLeft: Config.launcher.offsets.left ?? Config.launcher.offsets.all
        property var mRight: Config.launcher.offsets.right ?? Config.launcher.offsets.all
        property var mTop: Config.launcher.offsets.top ?? Config.launcher.offsets.all
        property var mBottom: Config.launcher.offsets.bottom ?? Config.launcher.offsets.all
        property var mHorizontalCenter: Config.launcher.offsets.horizontalCenter ?? Config.launcher.offsets.all
        property var mVerticalCenter: Config.launcher.offsets.verticalCenter ?? Config.launcher.offsets.all
        // Paddings
        property var pLeft: Config.launcher.paddings.left ?? Config.launcher.paddings.all
        property var pRight: Config.launcher.paddings.right ?? Config.launcher.paddings.all// ?? 0
        property var pTop: Config.launcher.paddings.top ?? Config.launcher.paddings.all// ?? 0
        property var pBottom: Config.launcher.paddings.bottom ?? Config.launcher.paddings.all// ?? 0
        // Base settings
        property var rounding: Config.launcher.rounding ?? undefined
        property bool invertBaseRounding: Config.launcher.invertBaseRounding ?? undefined
        // Bar exclusion
        property bool excludeBarArea: true
        // Reusability
        property bool reusable: Config.launcher.reusability ?? undefined

        property Component content: FlexboxLayout {
                    id: flexLayout

                    direction: (Config.launcher.direction ?? (Config.launcher.anchors.top || Config.launcher.anchors.verticalCenter)) ? FlexboxLayout.Column : FlexboxLayout.ColumnReverse
                    alignItems: FlexboxLayout.AlignCenter
                    justifyContent: (Config.launcher.direction ?? (Config.launcher.anchors.top || Config.launcher.anchors.verticalCenter)) ? FlexboxLayout.JustifyStart : FlexboxLayout.JustifyEnd
                    gap: Config.launcher.gap ?? 8


                    // --- КОНСТАНТЫ ---
                    property real defaultTotalWidth: 700

                    // --- ПАНЕЛИ ---
                    property bool hasLeftPanel: moduleManager.currentState === moduleManager.stateSelecting ? true : (moduleManager.activeModule?.hasLeftPanel ?? true)
                    property bool hasRightPanel: moduleManager.currentState === moduleManager.stateSelecting ? false : (moduleManager.activeModule?.hasRightPanel ?? false)

                    // --- ШИРИНЫ ---
                    property real totalWidth: moduleManager.activeModule?.customTotalWidth > 0
                                              ? moduleManager.activeModule.customTotalWidth
                                              : defaultTotalWidth

                    property real activeRightWidth: moduleManager.activeModule?.customRightWidth > 0
                                                    ? moduleManager.activeModule.customRightWidth
                                                    : 300

                    // property real activeLeftWidth: totalWidth - (hasRightPanel ? activeRightWidth + gap : 0)

                    // --- ВЫСОТЫ ---
                    // property real leftPanelHeight: leftPanel.implicitListHeight
                    property real activeRightHeight: moduleManager.activeModule?.customRightHeight > 0
                                                     ? moduleManager.activeModule.customRightHeight
                                                     : 400

                    // --- ИТОГОВЫЕ РАЗМЕРЫ ---
                    property real contentWidth: totalWidth
                    property real contentHeight: hasRightPanel ? activeRightHeight : leftPanel.implicitListHeight
                    // --- 1. ROW INPUT (Поле ввода) ---
                    // RowInput {
                    //     id: rowInput
                    //     moduleManager: moduleManager // или как у тебя называется ID менеджера
                    //     targetList: leftPanel.listView // Передаем ссылку на ListView внутри LeftPanel

                    //     // Ширина тянется за всем контентом
                    //     implicitWidth: flexLayout.contentWidth
                    // }

                    RowInput {
                        id: rowInput
                        moduleManager: moduleManager
                        implicitWidth: flexLayout.contentWidth

                        onMoveUp:   moduleManager.activeModule
                                        ? moduleManager.activeModule.navigateUp()
                                        : leftPanel.listView.decrementCurrentIndex()
                        onMoveDown: moduleManager.activeModule
                                        ? moduleManager.activeModule.navigateDown()
                                        : leftPanel.listView.incrementCurrentIndex()
                        onMoveLeft: {
                            if (moduleManager.activeModule && typeof moduleManager.activeModule.navigateUp === "function")
                                moduleManager.activeModule.navigateUp()
                        }
                        onMoveRight: {
                            if (moduleManager.activeModule && typeof moduleManager.activeModule.navigateDown === "function")
                                moduleManager.activeModule.navigateDown()
                        }
                        onModifierPressed: (key) => {
                            if (moduleManager.activeModule && typeof moduleManager.activeModule.onModifierPressed === "function")
                                moduleManager.activeModule.onModifierPressed(key)
                        }
                        onModifierReleased: (key) => {
                            if (moduleManager.activeModule && typeof moduleManager.activeModule.onModifierReleased === "function")
                                moduleManager.activeModule.onModifierReleased(key)
                        }
                        onExecute: (query, isAlt) => {
                            // В режиме выбора модуля — Enter активирует модуль из списка
                            if (moduleManager.currentState === moduleManager.stateSelecting) {
                                moduleManager.activateBySelectingIndex(leftPanel.listView.currentIndex)
                                return
                            }
                            // Если есть левая панель — триггерим элемент списка
                            if (flexLayout.hasLeftPanel && leftPanel.listView.currentItem) {
                                let item = leftPanel.listView.currentItem
                                if (isAlt) {
                                    if (typeof item.triggerAlt === "function") item.triggerAlt()
                                } else {
                                    if (typeof item.trigger === "function") item.trigger()
                                }
                            }
                            // Иначе — отдаём модулю напрямую
                            else if (moduleManager.activeModule) {
                                if (typeof moduleManager.activeModule.execute === "function")
                                    moduleManager.activeModule.execute(query, isAlt)
                            }
                        }
                        // onExecute: (isAlt) => {
                        //     let item = leftPanel.listView.currentItem
                        //     if (!item) return
                        //     if (isAlt) {
                        //         if (typeof item.triggerAlt === "function") item.triggerAlt()
                        //     } else {
                        //         if (typeof item.trigger === "function") item.trigger()
                        //     }
                        // }

                        onCloseRequested: VisibilitiesManager.setVisibility(root.screen, "launcher", false)

                        Connections {
                            target: root
                            function onLauncherVisibleChanged() {
                                if (root.launcherVisible) rowInput.clear()
                            }
                        }

                        Connections {
                            target: moduleManager.activeModule ?? null
                            function onDefaultNavigateUp()   { leftPanel.listView.decrementCurrentIndex() }
                            function onDefaultNavigateDown() { leftPanel.listView.incrementCurrentIndex() }
                        }
                    }
                    RowLayout {
                        id: contentRow
                        spacing: flexLayout.gap
                        // Ширина всего ряда = totalWidth, высота = contentHeight
                        // implicitWidth: flexLayout.contentWidth
                        // implicitHeight: flexLayout.contentHeight
                        Layout.preferredWidth: flexLayout.contentWidth
                        Layout.preferredHeight: flexLayout.contentHeight
                        // clip: true

                        LeftPanel {
                            id: leftPanel
                            visible: flexLayout.hasLeftPanel
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            rightViewWidth: flexLayout.hasRightPanel ? flexLayout.activeRightWidth : 0

                            model: moduleManager.currentState === moduleManager.stateSelecting
                                   ? moduleManager.selectingModel
                                   : moduleManager.activeModule?.listModel

                            delegate: UniversalDelegate {
                                list: leftPanel
                            }

                            Connections {
                                target: leftPanel.model
                                function onValuesChanged() {
                                    Qt.callLater(() => leftPanel.listView.currentIndex = 0)
                                }
                            }
                            Connections {
                                target: leftPanel.listView
                                function onCurrentIndexChanged() {
                                    let idx = leftPanel.listView.currentIndex
                                    if (idx >= 0) {// && moduleManager.activeModule?.hasRightPanel) {
                                        let item = moduleManager.activeModule?.listModel?.values?.[idx]
                                        if (typeof item?.onSelected === "function") item.onSelected()
                                    }
                                }
                            }
                        }

                        RightPanel {
                            id: rightPanel
                            Layout.preferredWidth: flexLayout.hasRightPanel ? flexLayout.activeRightWidth : 0
                            Layout.fillHeight: true
                            visible: flexLayout.hasRightPanel || width > 0
                            // Disable clip when module needs overflow (e.g., for dropdown menus)
                            clip: !(rightLoader.item && rightLoader.item.needsOverflow)

                            Behavior on Layout.preferredWidth {
                                Anim { duration: Appearance.anim.durations.normal; easing.type: Easing.OutCubic }
                            }

                            Loader {
                                id: rightLoader
                                anchors.fill: parent
                                anchors.margins: 10
                                asynchronous: true
                                active: flexLayout.hasRightPanel &&
                                        moduleManager.currentState !== moduleManager.stateSelecting
                                sourceComponent: moduleManager.activeModule?.rightPanelComponent ?? null

                                opacity: status === Loader.Ready ? 1.0 : 0.0
                                Behavior on opacity {
                                    Anim { duration: Appearance.anim.durations.small }
                                }
                            }
                        }
                    }

                }
    }

    Loader {
        id: launcherLoader
        active: root.launcherVisible
        // anchors.fill: parent

        sourceComponent: Item {
            // anchors.fill: parent

            Component.onCompleted: {
                root.manager.requestBackground(root.content, false, true);
            }

            Component.onDestruction: {
                root.manager.removeBackground(root.content);
            }
        }
    }
}
