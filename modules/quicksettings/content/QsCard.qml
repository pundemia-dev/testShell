import qs.config
import qs.services
import qs.components

// Base surface for quicksettings cards: the outermost card fill on the panel,
// so it takes tPalette (layer 0/1 handled globally).
StyledRect {
    radius: Appearance.rounding.large
    color: Colours.tPalette.surface_container
}
