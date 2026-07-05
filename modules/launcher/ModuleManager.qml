pragma ComponentBehavior: Bound

import QtQuick
import qs.config
// Statically anchors qs.modules.launcher.content with the qml scanner so the
// file://-loaded plugin units (modules/launcher/plugins/<id>/) can explicitly
// import it for the slot contract types (LauncherModule, LauncherManifest) —
// implicit resolution only covers a unit's own folder, and the scanner only
// creates qs.* modules referenced from statically-reachable files.
import qs.modules.launcher.content

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
    // 2. МОДУЛИ: DISCOVERY + ЛЕНИВЫЕ ИНСТАНСЫ
    // ==========================================
    // Манифесты (metadata only) приходят из реестра; content инстанцируется
    // только при первой активации модуля и кэшируется на сессию.
    readonly property LauncherRegistry registry: LauncherRegistry {}
    readonly property var manifests: registry.active

    property var _instances: ({})  // manifest.id → LauncherModule instance

    readonly property QtObject defaultManifest: manifests.length > 0 ? manifests[0] : null
    property QtObject activeManifest: null
    property QtObject activeModule: null  // content-инстанс activeManifest

    property var selectingResults: []  // параллельный массив для FZF-результатов
    property ListModel selectingModel: ListModel {}

    // Реестр наполняется асинхронно и active[] может переупорядочиваться по
    // мере загрузки манифестов — пока пользователь ничего не выбрал
    // (stateDefault), активный модуль следует за актуальным дефолтом.
    onDefaultManifestChanged: {
        if (defaultManifest && currentState === stateDefault && activeManifest !== defaultManifest)
            _setActiveManifest(defaultManifest, "");
    }

    // ==========================================
    // 3. FZF ПОИСК
    // ==========================================
    LocalSearcher {
        id: fzfEngine
        list: root.manifests
        key: "title"
        useFuzzy: true
    }

    // ==========================================
    // 4. ЛОГИКА ОБРАБОТКИ ВВОДА
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
                activeManifest = null
                activeModule = null
            }

            let query = text.substring(magicSymbol.length).trim()
            _updateSelectingModel(query)

        } else {
            if (currentState !== stateDefault) {
                currentState = stateDefault
                _setActiveManifest(defaultManifest, "")
            }
            if (activeModule) activeModule.handleInput(text)
        }
    }

    // ==========================================
    // 5. АКТИВАЦИЯ И ДЕАКТИВАЦИЯ
    // ==========================================

    // Вызывается из делегата левой панели по индексу FZF-результата
    function activateBySelectingIndex(index) {
        if (index < 0 || index >= selectingResults.length) return
        activateManifest(selectingResults[index], "")
    }

    function activateManifest(manifest, initialQuery) {
        currentState = stateActive
        _setActiveManifest(manifest, initialQuery)
        moduleActivatedForUI(manifest.title)
    }

    function activateModuleById(mId, initialQuery) {
        initialQuery = initialQuery ?? ""
        for (let i = 0; i < manifests.length; i++) {
            if (manifests[i].id === mId) {
                activateManifest(manifests[i], initialQuery)
                return
            }
        }
        console.warn("[ModuleManager] Модуль с ID", mId, "не найден!")
    }

    // Возврат в дефолтное состояние (используется Wrapper'ом при открытии)
    function resetToDefault() {
        currentState = stateDefault
        _setActiveManifest(defaultManifest, "")
    }

    // Вызывается из RowInput при двойном Backspace (пустая строка)
    // Возвращает строку, которую нужно вставить в поле ввода, или null
    function escapeCurrentState() {
        if (currentState === stateActive) {
            currentState = stateSelecting
            _setActiveManifest(null, "")
            return magicSymbol
        }
        if (currentState === stateSelecting) {
            currentState = stateDefault
            _setActiveManifest(defaultManifest, "")
            return ""
        }
        return null
    }

    // ==========================================
    // 6. СИГНАЛЫ
    // ==========================================
    signal moduleActivatedForUI(string moduleName)

    // ==========================================
    // 7. ПРИВАТНЫЕ ФУНКЦИИ
    // ==========================================
    function _instanceFor(manifest) {
        if (!manifest)
            return null
        let inst = _instances[manifest.id]
        if (!inst) {
            if (!manifest.content) {
                console.warn("[ModuleManager] У модуля", manifest.id, "нет content")
                return null
            }
            inst = manifest.content.createObject(root)
            if (!inst) {
                console.warn("[ModuleManager] Ошибка инстанцирования модуля:",
                             manifest.id, manifest.content.errorString())
                return null
            }
            _instances[manifest.id] = inst
        }
        return inst
    }

    function _setActiveManifest(manifest, initialQuery) {
        const inst = _instanceFor(manifest)
        if (activeModule && activeModule !== inst) {
            activeModule.isActive = false
            activeModule.onDeactivated()
        }
        activeManifest = manifest
        activeModule = inst
        if (inst) {
            inst.isActive = true
            inst.onActivated(initialQuery)
        }
    }

    function _updateSelectingModel(query) {
        selectingModel.clear()
        selectingResults = []

        let results = fzfEngine.query(query)
        for (let i = 0; i < results.length; i++) {
            let mod = results[i]
            selectingModel.append({
                header:          mod.title,
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
