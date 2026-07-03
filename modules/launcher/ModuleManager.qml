pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.utils
// Registers qs.modules.launcher.content.components with the qml scanner so the
// dynamically-loaded launcher modules can import it for sibling types
// (LauncherModule, PropertyRow) — implicit same-dir resolution doesn't work
// through the qsintercept scheme, and the scanner only creates qs.* modules
// referenced from statically-reachable files.
import qs.modules.launcher.content.components

Item {
    id: root

    // ==========================================
    // 1. КОНСТАНТЫ И СОСТОЯНИЯ
    // ==========================================
    readonly property int stateDefault:   0  // Обычный ввод (App List)
    readonly property int stateSelecting: 1  // Введён магический символ (выбор модуля)
    readonly property int stateActive:    2  // Модуль выбран, в строке висит "Пилюля"

    property int currentState: stateDefault

    property string magicSymbol: Config.launcher?.magicSymbol ?? "!"

    // ==========================================
    // 2. ДАННЫЕ МОДУЛЕЙ
    // ==========================================
    property list<QtObject> loadedModules: []
    // property var loadedModules:   []   // массив инстансов BaseModule
    property var selectingResults: []  // параллельный массив для FZF-результатов

    property QtObject defaultModule: null
    property QtObject activeModule:  null

    property ListModel selectingModel: ListModel {}

    // ==========================================
    // 3. FZF ПОИСК
    // ==========================================
    LocalSearcher {
        id: fzfEngine
        list: root.loadedModules
        key: "name"
        useFuzzy: true
    }

    // ==========================================
    // 4. ИНИЦИАЛИЗАЦИЯ
    // ==========================================
    Component.onCompleted: {
        let moduleNames = Config.launcher?.modules ?? ["AppListModule"]
        let temp = []

        for (let i = 0; i < moduleNames.length; i++) {
            let url  = Qt.resolvedUrl("content/components/" + moduleNames[i] + ".qml")
            let comp = Qt.createComponent(url)

            if (comp.status === Component.Ready) {
                let inst = comp.createObject(root)
                temp.push(inst)
            } else {
                console.error("[ModuleManager] Ошибка загрузки модуля:",
                              moduleNames[i], comp.errorString())
            }
        }

        loadedModules = temp  // присваиваем весь массив целиком
        if (temp.length > 0) {
            defaultModule = temp[0]
            activeModule  = temp[0]
            activeModule.isActive = true
            activeModule.onActivated("")
        }
    }
    // Component.onCompleted: {
    //     let moduleNames = Config.launcher?.modules ?? ["AppListModule"]
    //     let tempModules = []

    //     for (let i = 0; i < moduleNames.length; i++) {
    //         // let comp = Qt.resolvedUrl("../components/" + moduleNames[i] + ".qml")
    //         let url  = Qt.resolvedUrl("content/components/" + moduleNames[i] + ".qml")
    //         let comp = Qt.createComponent(url)
    //         // let comp = Qt.createComponent("/home/pundemia/quickshell/pShell/modules/laucher/content/components/" + moduleNames[i] + ".qml")

    //         if (comp.status === Component.Ready) {
    //             let inst = comp.createObject(root)
    //             tempModules.push(inst)

    //             if (i === 0) {
    //                 root.defaultModule = inst
    //                 root.activeModule  = inst
    //             }
    //         } else {
    //             console.error("[ModuleManager] Ошибка загрузки модуля:",
    //                           moduleNames[i], comp.errorString())
    //         }
    //     }

    //     root.loadedModules = tempModules
    // }

    // ==========================================
    // 5. ЛОГИКА ОБРАБОТКИ ВВОДА
    // ==========================================
    function cancelEscape() {
        if (isEscapePending) {
            isEscapePending = false
            bsTimer.stop()
        }
    }

    function processInput(text) {
        cancelEscape()
        if (currentState === stateActive) {
            if (activeModule) activeModule.handleInput(text)
            return
        }

        if (text.startsWith(magicSymbol)) {
            if (currentState !== stateSelecting) {
                currentState = stateSelecting
                if (activeModule) activeModule.isActive = false
                activeModule = null
            }

            let query = text.substring(magicSymbol.length).trim()
            _updateSelectingModel(query)

        } else {
            if (currentState !== stateDefault) {
                currentState = stateDefault
                _setActiveModule(defaultModule, "")
            }
            if (activeModule) activeModule.handleInput(text)
        }
    }

    // ==========================================
    // 6. АКТИВАЦИЯ И ДЕАКТИВАЦИЯ
    // ==========================================

    // Вызывается из делегата левой панели по индексу FZF-результата
    function activateBySelectingIndex(index) {
        if (index < 0 || index >= selectingResults.length) return
        activateModuleInstance(selectingResults[index], "")
    }

    function activateModuleInstance(mod, initialQuery) {
        currentState = stateActive
        _setActiveModule(mod, initialQuery)
        moduleActivatedForUI(mod.name)
    }

    function activateModuleById(mId, initialQuery) {
        initialQuery = initialQuery ?? ""
        for (let i = 0; i < loadedModules.length; i++) {
            if (loadedModules[i].moduleId === mId) {
                activateModuleInstance(loadedModules[i], initialQuery)
                return
            }
        }
        console.warn("[ModuleManager] Модуль с ID", mId, "не найден!")
    }

    // Вызывается из RowInput при двойном Backspace (пустая строка)
    // Возвращает строку, которую нужно вставить в поле ввода, или null
    function escapeCurrentState() {
        if (currentState === stateActive) {
            currentState = stateSelecting
            _setActiveModule(null, "")
            return magicSymbol
        }
        if (currentState === stateSelecting) {
            currentState = stateDefault
            _setActiveModule(defaultModule, "")
            return ""
        }
        return null
    }

    // ==========================================
    // 7. СИГНАЛЫ
    // ==========================================
    signal moduleActivatedForUI(string moduleName)

    // ==========================================
    // 8. ПРИВАТНЫЕ ФУНКЦИИ
    // ==========================================
    function _setActiveModule(mod, initialQuery) {
        if (activeModule && activeModule !== mod) {
            activeModule.isActive = false
            activeModule.onDeactivated()
        }
        activeModule = mod
        if (activeModule) {
            activeModule.isActive = true
            activeModule.onActivated(initialQuery)
        }
    }

    function _updateSelectingModel(query) {
        selectingModel.clear()
        selectingResults = []

        let results = fzfEngine.query(query)
        for (let i = 0; i < results.length; i++) {
            let mod = results[i]
            selectingModel.append({
                header:          mod.name,
                text:            mod.description,
                leftIcon:        mod.icon,
                isLeftIconImage: false
            })
            selectingResults.push(mod)
        }
    }
    // ── Escape pending (для пилюли) ───────────────────────────────────────
    property bool isEscapePending: false

    Timer {
        id: bsTimer
        interval: 400
        onTriggered: root.isEscapePending = false
    }

    function handleBackspaceOnEmpty(isAutoRepeat) {
        if (currentState === stateActive) {
            // Авто-повтор зажатого Backspace не считается за нажатие — игнорируем
            if (isAutoRepeat) return null
            if (isEscapePending) {
                bsTimer.stop()
                isEscapePending = false
                return escapeCurrentState()
            } else {
                isEscapePending = true
                bsTimer.restart()
                return null
            }
        } else if (currentState === stateSelecting) {
            return escapeCurrentState()
        }
        return null
    }
}
