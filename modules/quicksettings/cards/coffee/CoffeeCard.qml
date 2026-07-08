import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.modules.quicksettings.content
import QtQuick
import QtQuick.Layouts

// "Keep Awake" card — full port of caelestia's IdleInhibit: coffee icon,
// status line, switch, and an "Active since" chip that slides in from the
// bottom while the card grows.
QsCard {
    id: root

    readonly property real nonAnimHeight: layout.implicitHeight + (IdleInhibit.enabled ? activeChip.implicitHeight + activeChip.anchors.topMargin : 0) + Appearance.padding.large * 2

    implicitHeight: nonAnimHeight
    clip: true

    RowLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.medium

        StyledRect {
            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Appearance.padding.large

            radius: Appearance.rounding.full
            color: IdleInhibit.enabled ? Colours.palette.secondary : Colours.palette.secondary_container

            StyledIcon {
                id: icon

                anchors.centerIn: parent
                text: "\uef0e" // tabler coffee
                color: IdleInhibit.enabled ? Colours.palette.on_secondary : Colours.palette.on_secondary_container
                font.pointSize: Appearance.font.size.large
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Keep Awake")
                font: Appearance.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: IdleInhibit.enabled ? qsTr("Preventing sleep mode") : qsTr("Normal power management")
                color: Colours.palette.on_surface_variant
                font: Appearance.font.body.small
                elide: Text.ElideRight
            }
        }

        StyledSwitch {
            checked: IdleInhibit.enabled
            onToggled: IdleInhibit.enabled = checked
        }
    }

    Loader {
        id: activeChip

        asynchronous: true
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.topMargin: Appearance.spacing.large
        anchors.bottomMargin: IdleInhibit.enabled ? Appearance.padding.large : -implicitHeight
        anchors.leftMargin: Appearance.padding.large

        opacity: IdleInhibit.enabled ? 1 : 0
        scale: IdleInhibit.enabled ? 1 : 0.5

        Component.onCompleted: active = Qt.binding(() => opacity > 0)

        sourceComponent: StyledRect {
            implicitWidth: activeText.implicitWidth + Appearance.padding.medium * 2
            implicitHeight: activeText.implicitHeight + Appearance.padding.small

            radius: Appearance.rounding.full
            color: Colours.palette.primary

            StyledText {
                id: activeText

                anchors.centerIn: parent
                text: qsTr("Active since %1").arg(Qt.formatTime(IdleInhibit.enabledSince, Config.services?.useTwelveHourClock ? "hh:mm a" : "hh:mm"))
                color: Colours.palette.on_primary
                font.pointSize: Math.round(Appearance.font.body.small.pointSize * 0.9)
            }
        }

        Behavior on anchors.bottomMargin {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
