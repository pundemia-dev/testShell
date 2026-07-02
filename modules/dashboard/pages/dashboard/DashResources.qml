pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Caelestia.Services
import QtQuick
import QtQuick.Layouts

// Vertical CPU / RAM / Disk rings. 1:1 port of caelestia dash/Resources.qml,
// driven by the real Caelestia.Services sensors (ServiceRef keeps the ticking
// services alive while visible).
Item {
    id: root

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: layout.implicitWidth + layout.anchors.margins * 2

    ServiceRef { service: Cpu }
    ServiceRef { service: Memory }
    ServiceRef { service: Storage }

    ColumnLayout {
        id: layout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.medium

        Resource {
            glyph: "\uef8e" // tabler cpu
            value: Cpu.percentage
            colour: Colours.palette.primary
        }
        Resource {
            glyph: "\ueb2d" // tabler stack
            value: Memory.percentage
            colour: Colours.palette.tertiary
        }
        Resource {
            glyph: "\uea88" // tabler database
            value: Storage.percentage
            colour: Colours.palette.secondary
        }
    }

    component Resource: Item {
        id: res
        property string glyph
        property alias value: prog.value
        property color colour

        Layout.fillHeight: true
        Layout.preferredWidth: 52
        Layout.minimumHeight: 52

        CircularProgress {
            id: prog
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            strokeWidth: Config.dashboard.dash.resourceProgressThickness
            fgColour: res.colour

            Behavior on value {
                Anim {}
            }

            StyledText {
                anchors.centerIn: parent
                text: res.glyph
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.large
                color: res.colour
            }
        }
    }
}
