pragma Singleton
pragma ComponentBehavior: Bound

import qs.components.misc
import qs.services
import QtQuick
import Quickshell

Singleton {
    id: root

    // Глобальный сигнал об изменении visibility (для любого монитора)
    signal visibilityChanged(ShellScreen screen, string name, bool state)

    // Map: screen.name (string) -> PerMonitorVisibilities
    property var screens: ({})

    // Очередь отложенных запросов (когда visibility запрашивается до регистрации screen)
    property var pendingRequests: []

    // Для хранения созданных шорткатов (чтобы не дублировать)
    property var createdShortcuts: []
    property var registeredShortcuts: ({})

    property Component shortcutComponent: Component {
        CustomShortcut {}
    }

    function _key(screen) {
        return screen && screen.name ? screen.name : "";
    }

    // Регистрация per-monitor visibilities
    function load(screen: ShellScreen, visibilities): void {
        screens[_key(screen)] = visibilities;
        screens = screens; // trigger binding

        // Обрабатываем отложенные запросы для этого экрана
        processPendingRequests(screen);
    }

    // Обработка отложенных запросов для конкретного экрана
    function processPendingRequests(screen: ShellScreen): void {
        var vis = screens[_key(screen)];
        if (!vis) return;

        var remaining = [];
        for (var i = 0; i < pendingRequests.length; i++) {
            var req = pendingRequests[i];
            if (_key(req.screen) === _key(screen)) {
                vis.addVisibility(req.name, req.shortcut, req.isolated, req.autostart, req.description);
            } else {
                remaining.push(req);
            }
        }
        pendingRequests = remaining;
    }

    // Добавить visibility (можно вызывать из любого места)
    function addVisibility(screen: ShellScreen, name: string, shortcut: string, isolated: bool, autostart: bool, description: string): void {
        var vis = getForScreen(screen);
        if (vis) {
            vis.addVisibility(name, shortcut, isolated, autostart, description);
        } else {
            // Откладываем запрос до регистрации screen
            pendingRequests.push({
                screen: screen,
                name: name,
                shortcut: shortcut,
                isolated: isolated,
                autostart: autostart,
                description: description
            });
        }
    }

    // Установить visibility state (можно вызывать из любого места)
    function setVisibility(screen: ShellScreen, name: string, state: bool): void {
        var vis = getForScreen(screen);
        if (vis) {
            vis.setVisibility(name, state);
        }
    }

    // Удаление per-monitor visibilities
    function unload(screen: ShellScreen): void {
        delete screens[_key(screen)];
        screens = screens;
    }

    // Получить visibilities для активного монитора (на основе фокуса niri)
    function getForActive(): var {
        const focused = Niri.focusedMonitor;
        if (focused && screens[focused.name]) {
            return screens[focused.name];
        }
        // Фоллбэк: первый зарегистрированный экран
        const keys = Object.keys(screens);
        return keys.length > 0 ? screens[keys[0]] : null;
    }

    // Получить visibilities для конкретного экрана
    function getForScreen(screen: ShellScreen): var {
        return screens[_key(screen)] || null;
    }

    // Регистрация глобального шортката (вызывается один раз)
    function registerShortcut(name: string, shortcut: string, description: string): void {
        if (registeredShortcuts[name]) {
            return;
        }
        if (shortcut === "") {
            return;
        }

        var visName = name;
        var mainShortcut = shortcutComponent.createObject(root, {
            name: shortcut,
            description: description !== "" ? description : name,
            onActivated: function() {
                var vis = getForActive();
                if (vis) {
                    vis.toggleVisibility(visName);
                }
            }
        });
        createdShortcuts.push(mainShortcut);

        registeredShortcuts[name] = true;
    }
}
