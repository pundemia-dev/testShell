import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import "../popouts" as BarPopouts
import qs.components.misc


RadialSliderIcon {
    id: network

    label: Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "\uecfa"
    labelColor: Colours.role(Config.getCustom("networkStatus", "colour", "secondary"))
    implicitHeight: 30
    implicitWidth: 40
    progress: 0

    PopoutHandle {
        edge: !Config.bar.orientation ? (Config.bar.position ? "right" : "left") : (Config.bar.position ? "bottom" : "top")
        popoutContent: Component {
            BarPopouts.Network {}
        }
    }
}
