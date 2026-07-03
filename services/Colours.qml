pragma Singleton

import qs.config
import qs.services
import Caelestia
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // readonly property list<string> colourNames: ["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"]

    property bool showPreview
    property string scheme
    property string flavour
    property bool light
    readonly property M3Palette palette: showPreview ? preview : current
    readonly property M3Palette current: M3Palette {}
    readonly property M3Palette preview: M3Palette {}
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property Transparency transparency: Transparency {}

    // Average luminance of the current wallpaper (0..1), driven by the
    // ImageAnalyser plugin. Feeds alterColour's stacked-layer offset so the
    // tint boost scales with how bright the wallpaper is (caelestia parity).
    readonly property alias wallLuminance: analyser.luminance

    // Pick a representative wallpaper image path from WallpaperState (global
    // singleton, so prefer the fallback entry, else any monitor). Video
    // entries are skipped — QImage can't decode them and the last good
    // luminance is kept.
    readonly property string wallpaperPath: {
        const d = WallpaperState.stateData;
        if (!d)
            return "";
        const pick = e => e && e.path && (e.media_type ?? "image") !== "video" ? e.path : "";
        let p = pick(d.fallback);
        if (p)
            return p;
        if (d.monitors)
            for (const k in d.monitors) {
                p = pick(d.monitors[k]);
                if (p)
                    return p;
            }
        return "";
    }

    function alpha(c: color, layer: bool): color {
        if (!transparency.enabled)
            return c;
        c = Qt.rgba(c.r, c.g, c.b, layer ? transparency.layers : transparency.base);
        if (layer)
            c.hsvValue = Math.max(0, Math.min(1, c.hslLightness + (light ? -0.2 : 0.2))); // TODO: edit based on colours (hue or smth)
        return c;
    }
    function layer(c: color, layer: var): color {
            if (!transparency.enabled)
                return c;

            return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
        }
    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    // Lighten/darken a colour for a stacked layer, then apply alpha `a`. Ported
    // from caelestia: the offset scales with light/dark mode, `base`, and the
    // wallpaper luminance (brighter wallpaper → stronger tint boost).
    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);
        if (luminance === 0)
            return Qt.rgba(c.r, c.g, c.b, a);

        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base) * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    // Resolve a palette role by name (used by widget settings' `colour` enum).
    // Unknown names fall back to tertiary.
    function role(name: string): color {
        switch (name) {
        case "primary": return palette.primary;
        case "secondary": return palette.secondary;
        case "tertiary": return palette.tertiary;
        case "error": return palette.error;
        case "on_surface": return palette.on_surface;
        default: return palette.tertiary;
        }
    }

    function load(data: string, isPreview: bool): void {
        const colours = isPreview ? preview : current;
        const scheme = JSON.parse(data);

        if (!isPreview) {
            root.scheme = scheme.name;
            flavour = scheme.flavour;
        }
        // console.warn(data);

        light = scheme.mode === "light";

        for (const [name, colour] of Object.entries(scheme.colours)) {
            // const propName = colourNames.includes(name) ? name : `m3${name}`;
            // const propName = colourNames.includes(name) ? name : `m3${name}`;
            if (colours.hasOwnProperty(name))
                colours[name] = `#${colour}`;
        }
    }

    function setMode(mode: string): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", "-m", mode]);
    }

    ImageAnalyser {
        id: analyser

        source: root.wallpaperPath
    }

    FileView {
        path: `/home/pundemia/.local/state/pShell/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text(), false)
    }

    component Transparency: QtObject {
        readonly property bool enabled: Config.general.transparency.enabled
        // Light schemes get a touch more transparency than dark (matches
        // caelestia) — panels over a bright wallpaper need it to read.
        readonly property real base: Math.max(0, Math.min(1, Config.general.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Config.general.transparency.layers
    }

    // Transparency-applied palette — mirrors caelestia's M3TPalette. Surface and
    // background roles use layer 0 (just `base` alpha, no tint shift); every
    // other role defaults to layer 1 (`layers` alpha + luminance-based tint via
    // alterColour). Reference `Colours.tPalette.*` for any fill that should turn
    // translucent when `Config.general.transparency.enabled`; keep `Colours.palette.*`
    // for opaque elements (text, outlines, anything that must stay readable).
    // When transparency is off, `layer()` returns the colour untouched, so these
    // are drop-in for `palette.*`.
    component M3TPalette: QtObject {
        readonly property color background: root.layer(root.palette.background, 0)
        readonly property color on_background: root.layer(root.palette.on_background)
        readonly property color surface: root.layer(root.palette.surface, 0)
        readonly property color surface_dim: root.layer(root.palette.surface_dim, 0)
        readonly property color surface_bright: root.layer(root.palette.surface_bright, 0)
        readonly property color surface_container_lowest: root.layer(root.palette.surface_container_lowest)
        readonly property color surface_container_low: root.layer(root.palette.surface_container_low)
        readonly property color surface_container: root.layer(root.palette.surface_container)
        readonly property color surface_container_high: root.layer(root.palette.surface_container_high)
        readonly property color surface_container_highest: root.layer(root.palette.surface_container_highest)
        readonly property color on_surface: root.layer(root.palette.on_surface)
        readonly property color surface_variant: root.layer(root.palette.surface_variant, 0)
        readonly property color on_surface_variant: root.layer(root.palette.on_surface_variant)
        readonly property color inverse_surface: root.layer(root.palette.inverse_surface, 0)
        readonly property color inverse_on_surface: root.layer(root.palette.inverse_on_surface)
        readonly property color outline: root.layer(root.palette.outline)
        readonly property color outline_variant: root.layer(root.palette.outline_variant)
        readonly property color shadow: root.layer(root.palette.shadow)
        readonly property color scrim: root.layer(root.palette.scrim)
        readonly property color surface_tint: root.layer(root.palette.surface_tint)
        readonly property color primary: root.layer(root.palette.primary)
        readonly property color on_primary: root.layer(root.palette.on_primary)
        readonly property color primary_container: root.layer(root.palette.primary_container)
        readonly property color on_primary_container: root.layer(root.palette.on_primary_container)
        readonly property color inverse_primary: root.layer(root.palette.inverse_primary)
        readonly property color secondary: root.layer(root.palette.secondary)
        readonly property color on_secondary: root.layer(root.palette.on_secondary)
        readonly property color secondary_container: root.layer(root.palette.secondary_container)
        readonly property color on_secondary_container: root.layer(root.palette.on_secondary_container)
        readonly property color tertiary: root.layer(root.palette.tertiary)
        readonly property color on_tertiary: root.layer(root.palette.on_tertiary)
        readonly property color tertiary_container: root.layer(root.palette.tertiary_container)
        readonly property color on_tertiary_container: root.layer(root.palette.on_tertiary_container)
        readonly property color error: root.layer(root.palette.error)
        readonly property color on_error: root.layer(root.palette.on_error)
        readonly property color error_container: root.layer(root.palette.error_container)
        readonly property color on_error_container: root.layer(root.palette.on_error_container)
        readonly property color primary_fixed: root.layer(root.palette.primary_fixed)
        readonly property color primary_fixed_dim: root.layer(root.palette.primary_fixed_dim)
        readonly property color on_primary_fixed: root.layer(root.palette.on_primary_fixed)
        readonly property color on_primary_fixed_variant: root.layer(root.palette.on_primary_fixed_variant)
        readonly property color secondary_fixed: root.layer(root.palette.secondary_fixed)
        readonly property color secondary_fixed_dim: root.layer(root.palette.secondary_fixed_dim)
        readonly property color on_secondary_fixed: root.layer(root.palette.on_secondary_fixed)
        readonly property color on_secondary_fixed_variant: root.layer(root.palette.on_secondary_fixed_variant)
        readonly property color tertiary_fixed: root.layer(root.palette.tertiary_fixed)
        readonly property color tertiary_fixed_dim: root.layer(root.palette.tertiary_fixed_dim)
        readonly property color on_tertiary_fixed: root.layer(root.palette.on_tertiary_fixed)
        readonly property color on_tertiary_fixed_variant: root.layer(root.palette.on_tertiary_fixed_variant)
    }

    component M3Palette: QtObject {
        property color background: "#141318"
        property color on_background: "#E5E1E9"
        property color surface: "#141318"
        property color surface_dim: "#141318"
        property color surface_bright: "#3A383E"
        property color surface_container_lowest: "#0E0D13"
        property color surface_container_low: "#1C1B20"
        property color surface_container: "#201F25"
        property color surface_container_high: "#2B292F"
        property color surface_container_highest: "#35343A"
        property color on_surface: "#E5E1E9"
        property color surface_variant: "#48454E"
        property color on_surface_variant: "#C9C5D0"
        property color inverse_surface: "#E5E1E9"
        property color inverse_on_surface: "#312F36"
        property color outline: "#938F99"
        property color outline_variant: "#48454E"
        property color shadow: "#000000"
        property color scrim: "#000000"
        property color surface_tint: "#C8BFFF"
        property color primary: "#C8BFFF"
        property color on_primary: "#30285F"
        property color primary_container: "#473F77"
        property color on_primary_container: "#E5DEFF"
        property color inverse_primary: "#5F5791"
        property color secondary: "#C9C3DC"
        property color on_secondary: "#312E41"
        property color secondary_container: "#484459"
        property color on_secondary_container: "#E5DFF9"
        property color tertiary: "#ECB8CD"
        property color on_tertiary: "#482536"
        property color tertiary_container: "#B38397"
        property color on_tertiary_container: "#000000"
        property color error: "#EA8DC1"
        property color on_error: "#690005"
        property color error_container: "#93000A"
        property color on_error_container: "#FFDAD6"
        property color primary_fixed: "#E5DEFF"
        property color primary_fixed_dim: "#C8BFFF"
        property color on_primary_fixed: "#1B1149"
        property color on_primary_fixed_variant: "#473F77"
        property color secondary_fixed: "#E5DFF9"
        property color secondary_fixed_dim: "#C9C3DC"
        property color on_secondary_fixed: "#1C192B"
        property color on_secondary_fixed_variant: "#484459"
        property color tertiary_fixed: "#FFD8E7"
        property color tertiary_fixed_dim: "#ECB8CD"
        property color on_tertiary_fixed: "#301121"
        property color on_tertiary_fixed_variant: "#613B4C"

        property color blue: "#B8C4FF"
        property color blue_container: "#B8C4FF"
        property color blue_source: "#B8C4FF"
        property color blue_value: "#B8C4FF"
        property color on_blue: "#B8C4FF"
        property color on_blue_container: "#B8C4FF"

        property color cyan: "#B8C4FF"
        property color cyan_container: "#B8C4FF"
        property color cyan_source: "#B8C4FF"
        property color cyan_value: "#B8C4FF"
        property color on_cyan: "#B8C4FF"
        property color on_cyan_container: "#B8C4FF"

        property color green: "#B8C4FF"
        property color green_container: "#B8C4FF"
        property color green_source: "#B8C4FF"
        property color green_value: "#B8C4FF"
        property color on_green: "#B8C4FF"
        property color on_green_container: "#B8C4FF"

        property color magenta: "#B8C4FF"
        property color magenta_container: "#B8C4FF"
        property color magenta_source: "#B8C4FF"
        property color magenta_value: "#B8C4FF"
        property color on_magenta: "#B8C4FF"
        property color on_magenta_container: "#B8C4FF"

        property color orange: "#B8C4FF"
        property color orange_container: "#B8C4FF"
        property color orange_source: "#B8C4FF"
        property color orange_value: "#B8C4FF"
        property color on_orange: "#B8C4FF"
        property color on_orange_container: "#B8C4FF"

        property color purple: "#B8C4FF"
        property color purple_container: "#B8C4FF"
        property color purple_source: "#B8C4FF"
        property color purple_value: "#B8C4FF"
        property color on_purple: "#B8C4FF"
        property color on_purple_container: "#B8C4FF"

        property color black: "#B8C4FF"
        property color black_container: "#B8C4FF"
        property color black_source: "#B8C4FF"
        property color black_value: "#B8C4FF"
        property color on_black: "#B8C4FF"
        property color on_black_container: "#B8C4FF"

        property color red: "#B8C4FF"
        property color red_container: "#B8C4FF"
        property color red_source: "#B8C4FF"
        property color red_value: "#B8C4FF"
        property color on_red: "#B8C4FF"
        property color on_red_container: "#B8C4FF"

        property color yellow: "#B8C4FF"
        property color yellow_container: "#B8C4FF"
        property color yellow_source: "#B8C4FF"
        property color yellow_value: "#B8C4FF"
        property color on_yellow: "#B8C4FF"
        property color on_yellow_container: "#B8C4FF"

        property color white: "#B8C4FF"
        property color white_container: "#B8C4FF"
        property color white_source: "#B8C4FF"
        property color white_value: "#B8C4FF"
        property color on_white: "#B8C4FF"
        property color on_white_container: "#B8C4FF"

        property color source_color: "#B8C4FF"
    }
}
