pragma ComponentBehavior: Bound

import qs.components.effects
import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell.Services.SystemTray
import QtQuick
import "../popouts" as BarPopouts

MouseArea {
    id: root

    required property SystemTrayItem modelData

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Appearance.font.size.small * 2
    implicitHeight: Appearance.font.size.small * 2
    scale: 0

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    // Per-item popout: each tray item gets its own context-menu popout. Items
    // without a menu stay inert (contentReady false), so they never summon an
    // empty popout.
    PopoutHandle {
        edge: !Config.bar.orientation ? (Config.bar.position ? "right" : "left") : (Config.bar.position ? "bottom" : "top")
        contentReady: root.modelData.hasMenu
        popoutContent: Component {
            BarPopouts.TrayMenu {
                trayItem: root.modelData.menu
            }
        }
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Colours.palette.secondary
        layer.enabled: Config.bar.tray.recolour
    }

    Component.onCompleted: {
        scale = 1;
    }

    Behavior on scale {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }
}
