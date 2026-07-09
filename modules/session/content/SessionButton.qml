pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components.controls
import QtQuick

// One session action button. Uniform rounded-square IconButton driven by a
// manifest's icon; `selected` reflects keyboard focus (the parent
// SessionContent owns the selection index and key handling — buttons stay
// dumb). Visuals are a 1:1 port of caelestia's SessionButton: the corner radius
// morphs largeIncreased → extraLarge on focus → medium on press.
IconButton {
    id: root

    property bool selected: false

    implicitWidth: Config.session.buttonSize
    implicitHeight: Config.session.buttonSize

    inactiveColour: selected ? Colours.palette.secondary_container : Colours.tPalette.surface_container
    inactiveOnColour: selected ? Colours.palette.on_secondary_container : Colours.palette.on_surface

    // Override ButtonBase's radius logic with caelestia's focus-driven morph
    // (the base Behavior on radius still animates it). radiusMorph off so the
    // press branch here isn't shadowed by the base's pressedRadius.
    radiusMorph: false
    radius: pressed ? Appearance.rounding.medium
          : selected ? Appearance.rounding.extraLarge
          : Appearance.rounding.largeIncreased

    // Scale the glyph up to fill the button (caelestia icon.large × 1.3).
    font.family: Appearance.font.family.tabler
    font.pointSize: Appearance.font.icon.large.pointSize * 1.3
}
