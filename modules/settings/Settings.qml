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

        // The bar layout editor is driven from this window — leaving it in
        // edit mode with no settings open strands the jiggle/badges on screen.
        onVisibleChanged: {
            if (!visible)
                BarEditManager.editing = false;
        }

        SettingsContent {
            anchors.fill: parent
            focus: true

            onCloseRequested: settingsWindow.close()
        }
    }
}
