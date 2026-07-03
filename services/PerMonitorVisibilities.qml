import QtQuick
import Quickshell

QtObject {
    id: root

    required property ShellScreen screen

    // Сигнал об изменении visibility state
    signal visibilityChanged(string name, bool state)

    // Структура данных для хранения visibilities с именованным доступом
    property var visibilitiesData: ({})
    property var visibilitiesOrder: []

    Component.onCompleted: {
        VisibilitiesManager.load(screen, this);
    }

    Component.onDestruction: {
        VisibilitiesManager.unload(screen);
    }

    // Добавить visibility (вызывается при инициализации модуля)
    function addVisibility(name: string, shortcut: string, isolated: bool, autostart: bool, description: string): void {
        var entry = {
            name: name,
            shortcut: shortcut,
            isolated: isolated,
            state: autostart
        };
        visibilitiesData[name] = entry;
        visibilitiesOrder.push(name);
        visibilitiesData = visibilitiesData; // trigger binding update
        visibilitiesOrder = visibilitiesOrder;

        // Регистрируем глобальный шорткат (только один раз через менеджер)
        if (shortcut !== "") {
            VisibilitiesManager.registerShortcut(name, shortcut, description);
        }
    }

    // Toggle visibility по имени
    function toggleVisibility(name: string): void {
        if (visibilitiesData[name]) {
            var newState = !visibilitiesData[name].state;
            visibilitiesData[name].state = newState;
            visibilitiesData = visibilitiesData; // trigger binding update
            visibilityChanged(name, newState);
            VisibilitiesManager.visibilityChanged(screen, name, newState);
        }
        return;
    }

    // Установить state напрямую
    function setVisibility(name: string, state: bool): void {
        if (visibilitiesData[name]) {
            if (visibilitiesData[name].state !== state) {
                visibilitiesData[name].state = state;
                visibilitiesData = visibilitiesData;
                visibilityChanged(name, state);
                VisibilitiesManager.visibilityChanged(screen, name, state);
            }
        }
        return;
    }

    // Получить state
    function getVisibility(name: string) {
        if (visibilitiesData[name]) {
            return visibilitiesData[name].state;
        }
        return false;
    }

    // Получить visibility по имени
    function getVisibilityByName(name: string): var {
        return visibilitiesData[name] || null;
    }

    // Получить visibility по индексу
    function getVisibilityByIndex(index: int): var {
        if (index < 0 || index >= visibilitiesOrder.length) {
            return null;
        }
        var name = visibilitiesOrder[index];
        return visibilitiesData[name];
    }

    // Установить параметр visibility
    function setVisibilityParam(name: string, param: string, value): void {
        if (visibilitiesData[name]) {
            visibilitiesData[name][param] = value;
            visibilitiesData = visibilitiesData;
        }
        return;
    }

    // Удалить visibility
    function removeVisibility(name: string): void {
        if (visibilitiesData[name]) {
            delete visibilitiesData[name];
            var idx = visibilitiesOrder.indexOf(name);
            if (idx !== -1) {
                visibilitiesOrder.splice(idx, 1);
            }
            visibilitiesData = visibilitiesData;
            visibilitiesOrder = visibilitiesOrder;
        }
        return;
    }
}
