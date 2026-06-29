import qs.components
import qs.services
import qs.utils
import qs.config
import Quickshell
import QtQuick

// StyledIcon {
//     id: root

//     text: "\uebca"//"power_settings_new"
//     color: Colours.palette.tertiary
//     // implicitWidth: Config.bar.sizes.barUnitWidth //parent.implicitHeight + Appearance.padding.small * 2
//     // implicitHeight: implicitWidth
//     // font.bold: true
//     font.pointSize: Appearance.font.size.normal

//     StateLayer {
//         anchors.fill: undefined
//         // anchors.left: parent.parent.left
//         // anchors.right: parent.parent.right
//         anchors.centerIn: parent
//         // anchors.horizontalCenterOffset: 1

//         // anchors.leftMargin: Config.bar.sizes.barPadX
//         // anchors.rightMargin: Config.bar.sizes.barPadX
//         // implicitWidth: Config.bar.sizes.barUnitWidth - Config.bar.sizes.barPadX * 2 //parent.implicitHeight + Appearance.padding.small * 2
//         // // implicitHeight: Config.bar.sizes.barUnitWidth //parent.implicitHeight + Appearance.padding.small * 2
//         // implicitHeight: implicitWidth

//         radius: Appearance.rounding.small
//                 implicitWidth: implicitHeight
//                 implicitHeight: icon.implicitHeight + Appearance.padding.small * 2

//         function onClicked(): void {
//         }
//     }
// }

Item {
    id: root

    // required property PersistentProperties visibilities

    // implicitWidth: icon.implicitHeight + Appearance.padding.small * 2
    // implicitHeight: icon.implicitHeight
    implicitWidth: implicitHeight
    implicitHeight: icon.implicitHeight + Appearance.padding.small * 2

    StateLayer {
        // Cursed workaround to make the height larger than the parent
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Appearance.padding.normal * 1.5

        radius: Appearance.rounding.full

        function onClicked(): void {
            // root.visibilities.session = !root.visibilities.session;
        }
    }

    StyledIcon {
        id: icon

        anchors.centerIn: parent
        // anchors.horizontalCenterOffset: -1

        // text: "power_settings_new"
        text: "\uebca"
        font.pointSize: Appearance.font.size.normal
        color: Colours.role(Config.getCustom("utilities", "colour", "tertiary"))
        // text: Icons.osIcon //"\ueb0d"//"power_settings_new"
        // color: Colours.palette.tertiary
        // // font.bold: true
        // font.pointSize: Appearance.font.size.smaller
    }
}
