pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import M3Shapes
import QtQuick
import QtQuick.Layouts

// CPU/GPU hero card: usage ring (with glyph), name/label, temperature bar and a
// morphing usage MaterialShape. 1:1 port of caelestia performance/HeroCard.qml.
StyledRect {
    id: root

    required property string glyph
    required property string label
    required property string subLabel
    required property color accent
    required property real usage
    required property real temperature

    readonly property color cardColour: Colours.transparency.enabled
        ? Colours.layer(Colours.palette.surface_container, 2)
        : Colours.palette.surface_container

    color: cardColour
    radius: Appearance.rounding.large

    implicitWidth: Config.dashboard.performance.heroCardWidth
    implicitHeight: Math.max(tempProg.implicitHeight + detailsCol.implicitHeight + Appearance.spacing.large, usageShape.implicitHeight + usageLabel.implicitHeight) + Appearance.padding.large * 2

    DashProgress {
        id: tempProg
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Appearance.padding.large

        fgColour: root.accent
        spacing: Appearance.spacing.small
        strokeWidth: Appearance.padding.small
        implicitSize: Math.max(icon.implicitWidth, icon.implicitHeight) + Appearance.padding.medium * 2
        value: root.usage

        Behavior on clampedVal { Anim {} }

        StyledText {
            id: icon
            anchors.centerIn: parent
            text: root.glyph
            font.family: Appearance.font.family.tabler
            font.pointSize: Appearance.font.size.large
            color: root.accent
        }
    }

    ColumnLayout {
        anchors.left: tempProg.right
        anchors.right: usageShape.left
        anchors.verticalCenter: tempProg.verticalCenter
        anchors.margins: Appearance.spacing.large
        spacing: Appearance.spacing.small

        StyledText {
            text: root.label
            font.pointSize: Appearance.font.size.large
            font.weight: Font.DemiBold
            color: root.accent
        }
        StyledText {
            Layout.fillWidth: true
            text: root.subLabel
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.on_surface_variant
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        id: detailsCol
        anchors.left: parent.left
        anchors.right: usageShape.left
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large
        anchors.rightMargin: Appearance.spacing.large
        spacing: Appearance.spacing.small

        RowLayout {
            spacing: Appearance.spacing.small

            StyledText {
                text: root.temperature > 90 ? "\uec2c" : "\ueb38" // tabler temperature/flame
                font.family: Appearance.font.family.tabler
                font.pointSize: Appearance.font.size.large
                color: root.temperature > 90 ? Colours.palette.error : root.accent
            }
            StyledText {
                text: `${Math.ceil(Config.dashboard.performance.useFahrenheit ? root.temperature * 1.8 + 32 : root.temperature)}°${Config.dashboard.performance.useFahrenheit ? "F" : "C"}`
                font.pointSize: Appearance.font.size.normal
            }
        }

        // Temperature bar — M3 linear with stop dot (caelestia parity).
        StyledProgressBar {
            Layout.fillWidth: true
            value: root.temperature / 100
            fgColour: root.accent
        }
    }

    MaterialShape {
        id: usageShape
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.medium

        implicitSize: Config.dashboard.performance.usageShapeSize
        color: Colours.palette.secondary_container
        shape: {
            if (root.usage >= 0.8)
                return MaterialShape.SoftBurst;
            if (root.usage >= 0.4)
                return MaterialShape.Sunny;
            return MaterialShape.Cookie4Sided;
        }

        Behavior on color { CAnim {} }

        StyledText {
            id: usageLabel
            anchors.bottom: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Usage")
            color: Colours.palette.on_surface_variant
            font.pointSize: Appearance.font.size.small
        }
        StyledText {
            anchors.centerIn: parent
            text: isNaN(root.usage) ? "...%" : Math.round(root.usage * 100) + "%"
            color: root.accent
            font.pointSize: Appearance.font.size.large
            font.weight: Font.DemiBold
        }
    }
}
