import QtQuick
import qs.config
import qs.components
import qs.components.controls
import qs.services
import Quickshell
import qs.modules.launcher.content

LauncherModule {
    id: root

    hasLeftPanel: true
    hasRightPanel: false
    customRightWidth: 350

    // Текущее выбранное приложение для отображения в правой панели
    property var selectedApp: null
    property var _pendingApp: null

    // Текущий запрос и сырые результаты последнего handleInput
    property string _query: ""
    property var _results: []

    // Кэш элементов модели по DesktopEntry: ScriptModel диффит значения
    // по идентичности, поэтому повторные запросы должны отдавать те же
    // объекты — иначе ListView полностью пересоздаётся на каждый символ
    property var _entryCache: new Map()

    Timer {
        id: debounceTimer
        interval: 80
        onTriggered: selectedApp = _pendingApp
    }

    // Если панель открыли кнопкой, автоматически выбираем первое приложение
    onHasRightPanelChanged: {
        if (hasRightPanel && !selectedApp && _results.length > 0) {
            selectedApp = _results[0];
        }
    }

    function onActivated(initialQuery) {
        hasRightPanel = false
        handleInput(initialQuery)
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            // DesktopEntry-объекты могли пересоздаться — кэш недействителен
            root._entryCache = new Map()
            if (root.isActive) root.handleInput(root._query)
        }
    }

    property bool isPinned: false
    property bool isHidden: false

    // Обновляй при смене приложения:
    onSelectedAppChanged: {
        isPinned = false  // TODO: проверять реальное состояние из конфига
        isHidden = false
    }

    function togglePin() {
        if (!selectedApp) return
        isPinned = !isPinned
        console.log("Pinning app:", selectedApp.name, isPinned)
    }

    function toggleHide() {
        if (!selectedApp) return
        isHidden = !isHidden
        console.log("Hiding app:", selectedApp.name, isHidden)
        if (isHidden) {
            hasRightPanel = false
            handleInput(_query)
        }
    }

    ScriptModel {
        id: internalModel
    }

    listModel: internalModel

    function _modelEntry(app) {
        let entry = _entryCache.get(app)
        if (!entry) {
            entry = {
                header: app.name ?? "Unknown App",
                text: app.comment || app.genericName || "",
                leftIcon: app.icon ?? "",
                isLeftIconImage: true,
                rightIcon: "",
                rightText: "",
                onClicked: function() {
                    Apps.launch(app)
                    root.requestClose(true)
                },
                onAltClicked: function() {
                    if (root.selectedApp === app && root.hasRightPanel) {
                        root.hasRightPanel = false
                        root.selectedApp = null
                    } else {
                        root.selectedApp = app
                        root.hasRightPanel = true
                    }
                },
                onSelected: function() {
                    if (root.hasRightPanel) {
                        root._pendingApp = app
                        debounceTimer.restart()
                    }
                }
            }
            _entryCache.set(app, entry)
        }
        return entry
    }

    function handleInput(query) {
        _query = query
        _results = Apps.query(query)
        internalModel.values = _results.map(app => _modelEntry(app))

        if (hasRightPanel) {
            // Не бросаем правую панель пустой: показываем первый результат
            _pendingApp = _results[0] ?? null
            debounceTimer.restart()
        } else {
            selectedApp = null
        }
    }

    // ==========================================
    // КНОПКА ДЛЯ ROW INPUT
    // ==========================================
    inputExtensionComponent: Component {
        StyledRect {
            implicitWidth: 32
            implicitHeight: 32
            radius: Appearance.rounding.small ?? 8
            color: toggleArea.containsMouse ? Colours.alpha(Colours.palette.on_surface, 0.1) : "transparent"

            StyledIcon {
                anchors.centerIn: parent
                // Иконка сайдбара из Material: view_sidebar / chrome_reader_mode
                text: root.hasRightPanel ? "ﰽ" : "ﰾ"
                font.pointSize: Appearance.font.size.large ?? 16
                color: root.hasRightPanel ? Colours.palette.primary : Colours.palette.on_surface_variant
            }

            MouseArea {
                id: toggleArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.hasRightPanel = !root.hasRightPanel;
                }
            }
        }
    }

    // ==========================================
    // ГЛОБАЛЬНЫЕ ШОРТКАТЫ (Работают при открытой панели)
    // ==========================================
    shortcutsComponent: Component {
        Item {
            Shortcut {
                sequence: "Ctrl+P"
                onActivated: root.togglePin()
            }
            Shortcut {
                sequence: "Ctrl+H"
                onActivated: root.toggleHide()
            }
        }
    }

    // ==========================================
    // ПРАВАЯ ПАНЕЛЬ (Детали приложения)
    // ==========================================
    rightPanelComponent: Component {
        AppsDetailsPanel {
            mod: root
        }
    }
}
