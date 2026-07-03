import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import qs.components.effects

// Placeholder — translator page to be implemented. Page contract: the root
// exposes implicitWidth/implicitHeight for the swipeable view.
Item {
    implicitWidth: Config.ai.pageWidth
    implicitHeight: Config.ai.pageHeight

    // Calm always-on ambient drift for the placeholder: fewer, larger,
    // slower shapes than the chat's thinking indicator.
    DriftingShapes {
        anchors.fill: parent
        count: 8
        minSize: 48
        maxSize: 140
        minSpeed: 2
        maxSpeed: 7
        minRotSpeed: -5
        maxRotSpeed: 5
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.medium

        StyledIcon {
            Layout.alignment: Qt.AlignHCenter
            text:  ""   // language
            color: Colours.palette.on_surface_variant
            font.pointSize: Appearance.font.icon.extraLarge.pointSize
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text:  "Translator"
            font:  Appearance.font.title.medium
            color: Colours.palette.on_surface_variant
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text:  "Coming soon"
            font:  Appearance.font.body.small
            color: Colours.palette.on_surface_variant
        }
    }
}
