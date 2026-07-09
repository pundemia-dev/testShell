import Quickshell.Io

// Lock screen module config. `skin` selects the visual plugin under
// modules/lock/skins/<id>/ (all visuals live there; this module owns only the
// locking logic). `sizes` are layout constants for the default caelestia skin
// (1:1 with caelestia's Tokens.sizes.lock).
JsonObject {
    // Active visual skin id (folder name under skins/).
    property string skin: "caelestia"

    // Fingerprint auth (needs fprintd + enrolled prints; auto-detected).
    property bool enableFprint: true
    property int maxFprintTries: 3

    // Hide notification contents on the lock screen.
    property bool hideNotifs: false

    // Recolour the distro logo to the theme's primary colour.
    property bool recolourLogo: true

    // false → show the pShell Logo component; true → the distro glyph.
    property bool useDistroLogo: false

    // Optional image shown in the notification dock's empty state.
    property string noNotifsPic: ""

    // Caelestia-skin layout constants (from caelestia Tokens.sizes.lock).
    property JsonObject sizes: JsonObject {
        property real heightMult: 0.7
        property real ratio: 16 / 9
        property int centerWidth: 600
        property int showWeatherDetailsHeight: 550
        property int showForecastHeight: 975
        property int forecastItemWidth: 51
        property int largeLogoWidth: 320
        property int largeFontWidth: 400
        property int fetch4LinesHeight: 600
        property int fetch3LinesHeight: 500
        property int showColourBoxRowHeight: 570
    }
}
