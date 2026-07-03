import qs.components
import qs.config
import qs.services
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import "../popouts" as BarPopouts
import qs.components.misc


RadialSliderIcon {
    id: root
    property color colour: Colours.role(Config.getCustom("powerStatus", "colour", "secondary"))

    implicitHeight: 30 // added
    implicitWidth: 40 // added

    progress: UPower.displayDevice.percentage
    // animate: true
    label: {
        const charging = !UPower.onBattery;
        const perc = UPower.displayDevice.percentage;

        if (UPower.displayDevice.isLaptopBattery && !charging) {
            if (perc < 0.2)
                return "\uea06";
            if (PowerProfiles.profile === PowerProfile.PowerSaver)
                return "\ued4f";
            if (PowerProfiles.profile === PowerProfile.Performance)
                return "\uec45";
            return "\ufa77";
        }

        if (perc === 1)
            return "\uea38";
        return "\uefef";
    }
    progressColor: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? Colours.palette.primary : Colours.palette.error
    labelColor: root.colour

    PopoutHandle {
        edge: !Config.bar.orientation ? (Config.bar.position ? "right" : "left") : (Config.bar.position ? "bottom" : "top")
        popoutContent: Component {
            BarPopouts.Power {}
        }
    }
}
