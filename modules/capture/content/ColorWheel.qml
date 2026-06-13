pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick

// Radial colour picker (flameshot's RMB wheel): swatches arranged in a ring
// around the cursor position where the palette was summoned (RMB anywhere or
// the toolbar swatch button). Click a swatch to pick; click elsewhere / Esc
// to close (handled by the editor).
Item {
    id: root

    required property var editor

    anchors.fill: parent
    visible: editor.paletteOpen

    // Harmonised ring mirrors the static palette's hue set exactly:
    // red, orange, yellow, green, blue, purple, black, white.
    readonly property var swatches: {
        if (Config.capture.harmonizedPalette) {
            const p = Colours.palette;
            return [p.red, p.orange, p.yellow, p.green, p.blue, p.purple, p.black, p.white].map(c => "" + c);
        }
        return [...Config.capture.editorPalette, "" + Colours.palette.primary];
    }
    readonly property real swatchD: Appearance.font.size.large + Appearance.padding.small * 2
    readonly property real ringR: Math.max(swatchD * 1.8, (swatches.length * (swatchD + Appearance.spacing.small)) / (2 * Math.PI))
    // Keep the whole ring on screen even when summoned near an edge.
    readonly property real cx: Math.max(ringR + swatchD / 2, Math.min(width - ringR - swatchD / 2, editor.palettePos.x))
    readonly property real cy: Math.max(ringR + swatchD / 2, Math.min(height - ringR - swatchD / 2, editor.palettePos.y))

    Repeater {
        model: root.swatches

        StyledRect {
            id: swatch

            required property var modelData
            required property int index

            readonly property real ang: -Math.PI / 2 + index * 2 * Math.PI / root.swatches.length

            x: root.cx + root.ringR * Math.cos(ang) - width / 2
            y: root.cy + root.ringR * Math.sin(ang) - height / 2
            implicitWidth: root.swatchD
            implicitHeight: root.swatchD
            radius: root.swatchD / 2
            color: modelData
            border.width: root.editor.drawColor === modelData ? 2 : 1
            border.color: root.editor.drawColor === modelData ? Colours.palette.on_surface : Colours.palette.outline_variant
            scale: sl.containsMouse ? 1.25 : 1

            Behavior on scale {
                Anim {}
            }

            StateLayer {
                id: sl

                function onClicked(): void {
                    root.editor.drawColor = swatch.modelData;
                    root.editor.paletteOpen = false;
                }
            }
        }
    }
}
