pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

// Result chip for the colour picker. Shown modally over the focused output:
// swatch + value with a format toggle (HEX/RGB/RGBA/HSL) + recent history.
// The chosen format is copied to the clipboard immediately and on every change.
PanelWindow {
    id: root

    required property var colour      // { r, g, b }  (0-255)
    signal requestClose()

    property string fmt: Config.capture.defaultColorFormat
    readonly property string valueText: Capture.formatColor(colour.r, colour.g, colour.b, fmt)
    readonly property color swatchColour: Qt.rgba(colour.r / 255, colour.g / 255, colour.b / 255, 1)

    color: "transparent"
    WlrLayershell.namespace: "pShell-capture-color"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onFmtChanged: Capture.copyText(valueText)
    Component.onCompleted: Capture.copyText(valueText)

    // Backdrop: click away or Esc to dismiss.
    MouseArea {
        anchors.fill: parent
        focus: true
        onClicked: root.requestClose()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                root.requestClose();
        }
    }

    StyledRect {
        anchors.centerIn: parent
        radius: Appearance.rounding.large
        color: Colours.palette.surface_container
        implicitWidth: col.implicitWidth + Appearance.padding.large * 2
        implicitHeight: col.implicitHeight + Appearance.padding.large * 2

        // Swallow clicks on the chip so they don't dismiss.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: Appearance.spacing.normal

            // Swatch + value
            Row {
                spacing: Appearance.spacing.normal

                StyledRect {
                    width: Appearance.font.size.extraLarge * 1.8
                    height: width
                    radius: Appearance.rounding.normal
                    color: root.swatchColour
                    border.width: 1
                    border.color: Colours.palette.outline_variant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.valueText
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.larger
                    color: Colours.palette.on_surface

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Capture.copyText(root.valueText)
                    }
                }
            }

            // Format toggle
            Row {
                spacing: Appearance.spacing.small

                Repeater {
                    model: ["hex", "rgb", "rgba", "hsl"]

                    StyledRect {
                        id: chip
                        required property string modelData
                        readonly property bool active: root.fmt === modelData
                        implicitWidth: chipText.implicitWidth + Appearance.padding.normal * 2
                        implicitHeight: chipText.implicitHeight + Appearance.padding.smaller * 2
                        radius: Appearance.rounding.full
                        color: active ? Colours.palette.primary : Colours.palette.surface_container_high

                        StyledText {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.toUpperCase()
                            color: chip.active ? Colours.palette.on_primary : Colours.palette.on_surface_variant
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fmt = chip.modelData
                        }
                    }
                }
            }

            // Recent colours
            Row {
                spacing: Appearance.spacing.small
                visible: Capture.recentColors.length > 0

                Repeater {
                    model: Capture.recentColors

                    StyledRect {
                        id: recent
                        required property var modelData
                        width: Appearance.font.size.large * 1.4
                        height: width
                        radius: Appearance.rounding.small
                        color: Qt.rgba(modelData.r / 255, modelData.g / 255, modelData.b / 255, 1)
                        border.width: 1
                        border.color: Colours.palette.outline_variant

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.colour = { r: recent.modelData.r, g: recent.modelData.g, b: recent.modelData.b }
                        }
                    }
                }
            }
        }
    }
}
