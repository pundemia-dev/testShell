import qs.config
import qs.services
import qs.components
import qs.components.misc
import Quickshell
import QtQuick
import QtQuick.Window

Scope {
    id: root

    // Toggle settings window via Hyprland global shortcut (bind = SUPER, comma, global, pShell:settings)
    CustomShortcut {
        name: "settings"
        onActivated: () => {
            settingsWindow.visible = !settingsWindow.visible;
        }
    }

    Window {
        id: settingsWindow

        title: "pShell Settings"
        visible: false
        color: Colours.tPalette.surface

        width: 900
        height: 600
        minimumWidth: 700
        minimumHeight: 450

        SettingsContent {
            anchors.fill: parent
            focus: true

            onCloseRequested: settingsWindow.close()
        }
    }
}
