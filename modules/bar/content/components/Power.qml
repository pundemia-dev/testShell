import qs.components
import qs.services
import qs.utils
import qs.config
import Quickshell
import QtQuick

import qs.services
import qs.config
import Quickshell

Item {
    id: root

    implicitWidth: stLayer.implicitHeight
    implicitHeight: implicitWidth

    StyledIcon {
        id: icon

        anchors.centerIn: parent
        text: "\ueb0d"//"power_settings_new"
        color: Colours.role(Config.getCustom("power", "colour", "error"))
        // font.bold: true
        font.pointSize: Appearance.font.size.larger

        StateLayer {
            id: stLayer
            anchors.fill: undefined
            anchors.centerIn: parent
            // anchors.horizontalCenterOffset: 1

            implicitWidth: parent.implicitHeight + Appearance.padding.small * 2
            implicitHeight: implicitWidth

            radius: Appearance.rounding.small

            function onClicked(): void {
                VisibilitiesManager.getForActive().toggleVisibility("launcher");
            }
        }
    }
}


// Item {
//     id: root

//     // required property PersistentProperties visibilities

//     // implicitWidth: icon.implicitHeight + Appearance.padding.small * 2
//     // implicitHeight: icon.implicitHeight
//     implicitWidth: implicitHeight
//     implicitHeight: icon.implicitHeight + Appearance.padding.small * 2

//     StateLayer {
//         // Cursed workaround to make the height larger than the parent
//         anchors.fill: undefined
//         anchors.centerIn: parent
//         implicitWidth: implicitHeight
//         implicitHeight: icon.implicitHeight + Appearance.padding.small * 2

//         radius: Appearance.rounding.full

//         function onClicked(): void {
//             VisibilitiesManager.getForActive().toggleVisibility("launcher");
//         }
//     }

//     StyledText {
//         id: icon

//         anchors.centerIn: parent
//         // anchors.horizontalCenterOffset: -1
//         anchors.verticalCenterOffset: -1

//         // text: "power_settings_new"
//         text: "\ueb0d"
//         font.pointSize: Appearance.font.size.smaller
//         font.family: Appearance.font.family.tabler
//         color: Colours.palette.tertiary
//         // text: Icons.osIcon //"\ueb0d"//"power_settings_new"
//         // color: Colours.palette.tertiary
//         // // font.bold: true
//         // font.pointSize: Appearance.font.size.smaller
//     }
// }


// StyledIcon {
//     id: root

//     // required property PersistentProperties visibilities

//     text: Icons.osIcon //"\ueb0d"//"power_settings_new"
//     font.pointSize: Appearance.font.size.smaller
//     font.family: Appearance.font.family.mono
//     color: Colours.palette.error
//     // font.bold: true

//     StateLayer {
//         anchors.fill: undefined
//         anchors.centerIn: parent
//         // anchors.horizontalCenterOffset: 1

//         implicitWidth: parent.implicitHeight + Appearance.padding.small * 2
//         implicitHeight: implicitWidth

//         radius: Appearance.rounding.small

//         function onClicked(): void {
//             root.visibilities.session = !root.visibilities.session;
//         }
//     }
// }

// StyledText {
//     text: Icons.osIcon
//     font.pointSize: Appearance.font.size.smaller
//     font.family: Appearance.font.family.mono
//     color: Colours.palette.tertiary
// }
