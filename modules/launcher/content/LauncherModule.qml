import QtQuick

// Base type for a launcher plugin's content (the lazily-instantiated part of
// the unit — see LauncherManifest for the metadata half). Identity fields
// (id/title/icon/description/trigger/settingsSchema) live on the manifest;
// this carries only the runtime contract the host drives while the module is
// active. Instantiated by ModuleManager from the manifest's `content` on
// first activation.
Item {
    id: root

    // ==========================================
    // 1. СОСТОЯНИЕ (Управляется Менеджером)
    // ==========================================

    // Флаг, указывающий, что этот модуль сейчас активен
    property bool isActive: false

    // ==========================================
    // 2. НАСТРОЙКИ ИНТЕРФЕЙСА (Панели)
    // ==========================================

    property bool hasLeftPanel: true
    property bool hasRightPanel: true

    // Кастомные размеры (если -1, Менеджер использует дефолтные из конфига)
    property real customTotalWidth: -1
    property real customRightWidth: -1

    // Высота правой панели используется Менеджером, ТОЛЬКО если hasLeftPanel === false
    property real customRightHeight: -1

    // ==========================================
    // 3. ДАННЫЕ И КОМПОНЕНТЫ (UI)
    // ==========================================

    // Модель данных для LeftPanel (массив объектов или ListModel/QAbstractListModel).
    // Должна соответствовать формату UniversalDelegate.
    property var listModel: null

    // UI для правой панели (Превью, настройки и т.д.)
    property Component rightPanelComponent: null

    // UI для расширения строки ввода (например, кнопка настроек справа от RowInput)
    property Component inputExtensionComponent: null

    // Компонент с шорткатами (Action / Shortcut).
    // Менеджер будет инстанцировать его ТОЛЬКО когда модуль активен И открыта правая панель.
    property Component shortcutsComponent: null

    // ==========================================
    // 4. НАВИГАЦИЯ (Вызывается Менеджером при Up/Down в RowInput)
    // ==========================================

    // Если модуль не переопределяет navigateUp/Down — эмитирует сигнал,
    // который LauncherWrapper перехватывает и направляет в leftPanel.
    signal defaultNavigateUp()
    signal defaultNavigateDown()

    function navigateUp()   { defaultNavigateUp()   }
    function navigateDown() { defaultNavigateDown() }

    // ==========================================
    // 5. МЕТОДЫ ЖИЗНЕННОГО ЦИКЛА
    // ==========================================

    // Вызывается Менеджером каждый раз, когда меняется текст в RowInput (исключая триггер)
    function handleInput(query: string) {
        // Переопределяется в наследниках (например, для запуска поиска)
    }

    // Вызывается Менеджером при активации модуля (например, по Enter из поиска или через CLI)
    // initialQuery - текст, который мог быть передан при вызове из CLI
    function onActivated(initialQuery: string) {
        // Переопределяется в наследниках
    }

    // Вызывается Менеджером перед закрытием модуля (например, по двойному Backspace)
    function onDeactivated() {
        // Переопределяется в наследниках (очистка моделей, сброс таймеров)
    }

    // Вызывается Менеджером при нажатии Enter/Return в строке поиска.
    // Полезно для модулей без левой панели (например, калькулятор или CLI),
    // или если модуль хочет перехватить нажатие Enter до срабатывания списка.
    function execute(query: string, isAlt: bool) {
        // Переопределяется в наследниках
    }

    // ==========================================
    // 6. СИГНАЛЫ
    // ==========================================

    // Модуль может вызвать этот сигнал, чтобы принудительно закрыть сам себя (например, при клике/выборе элемента)
    // closeLauncher: если true, закроется весь лаунчер; если false, лаунчер вернется в дефолтное состояние.
    signal requestClose(bool closeLauncher)
}
