pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts

// A single toast card. Purely visual — lifecycle (expiry timer, hover-to-hold,
// click-to-dismiss, enter/exit anim) is owned by the ListView delegate in
// ToastsContent. Ported from caelestia's ToastItem with the pShell translations:
// StyledIcon/tokens/snake_case palette, and — since pShell has no m3success* —
// the four Toaster types map onto tertiary (success) / secondary (warning) /
// error / surface (info). The neutral Info card uses tPalette so it honours the
// global translucency; the coloured attention states stay opaque so they read.
StyledRect {
    id: root

    required property var modelData

    readonly property int _t: modelData?.type ?? -1

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: layout.implicitHeight + Appearance.padding.large

    radius: Appearance.rounding.large
    // Info uses the elevated container (surface itself is near-black and would
    // vanish against the panel bg) — same choice as the notification card.
    color: _t === Toaster.Success ? Colours.palette.tertiary_container : _t === Toaster.Warning ? Colours.palette.secondary_container : _t === Toaster.Error ? Colours.palette.error_container : Colours.tPalette.surface_container

    readonly property color onColor: _t === Toaster.Success ? Colours.palette.on_tertiary_container : _t === Toaster.Warning ? Colours.palette.on_secondary_container : _t === Toaster.Error ? Colours.palette.on_error_container : Colours.palette.on_surface
    readonly property color chipColor: _t === Toaster.Success ? Colours.palette.tertiary : _t === Toaster.Warning ? Colours.palette.secondary : _t === Toaster.Error ? Colours.palette.error : Colours.palette.surface_container_high
    readonly property color onChipColor: _t === Toaster.Success ? Colours.palette.on_tertiary : _t === Toaster.Warning ? Colours.palette.on_secondary : _t === Toaster.Error ? Colours.palette.on_error : Colours.palette.on_surface_variant

    border.width: 1
    border.color: Qt.alpha(_t === Toaster.Success ? Colours.palette.tertiary : _t === Toaster.Warning ? Colours.palette.secondary : _t === Toaster.Error ? Colours.palette.error : Colours.palette.outline_variant, 0.3)

    Elevation {
        anchors.fill: parent
        radius: parent.radius
        z: -1
        level: 2
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.small
        anchors.leftMargin: Appearance.padding.medium
        anchors.rightMargin: Appearance.padding.medium
        spacing: Appearance.spacing.medium

        StyledRect {
            visible: !!root.modelData?.icon
            radius: Appearance.rounding.large
            color: root.chipColor
            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Appearance.padding.large

            StyledIcon {
                id: icon
                anchors.centerIn: parent
                text: root.modelData?.icon ?? ""
                color: root.onChipColor
                font.pointSize: Appearance.font.icon.large.pointSize
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.modelData?.title ?? ""
                color: root.onColor
                font: Appearance.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: !!root.modelData?.message
                textFormat: Text.StyledText
                text: root.modelData?.message ?? ""
                color: root.onColor
                opacity: 0.8
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
        }
    }
}
