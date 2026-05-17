pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick

// `Colouriser` resolves to the sibling Colouriser.qml in this directory.
//
// Previously this used Caelestia.ImageAnalyser to extract the icon's dominant
// colour at runtime so the Colouriser shader could swap exactly that colour.
// That plugin is gone, so we drop the analysis step and assume a fixed source
// colour (white). Monochrome icons look identical; full-colour logos lose some
// fidelity, but it's a reasonable trade.
IconImage {
    id: root

    required property color colour

    asynchronous: true

    layer.enabled: true
    layer.effect: Colouriser {
        sourceColor: "white"
        colorizationColor: root.colour
    }
}
