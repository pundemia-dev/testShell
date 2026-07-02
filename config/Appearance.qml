pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property Rounding rounding: Rounding {}
    readonly property Spacing spacing: Spacing {}
    readonly property Padding padding: Padding {}
    readonly property FontStuff font: FontStuff {}
    readonly property Anim anim: Anim {}

    // ===================================================================
    // Rounding — M3 scale (values 1:1 from caelestia Tokens.rounding).
    // Better adapted to scaling than the old small/normal/large triple.
    // ===================================================================
    component Rounding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
        readonly property int full: 1000

        // pShell-specific pill-shape multiplier — NOT caelestia's all-radius
        // `scale`. Consumed by IconButton/TextButton/ToggleButton/etc. as
        // `Math.min(1, scale)`: 1.0 → fully pill-rounded, 0 → square.
        readonly property real scale: 1.0
    }

    // ===================================================================
    // Spacing — M3 scale (values 1:1 from caelestia Tokens.spacing).
    // ===================================================================
    component Spacing: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
        readonly property real scale: 1.0
    }

    // ===================================================================
    // Padding — M3 scale (values 1:1 from caelestia Tokens.padding).
    // ===================================================================
    component Padding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
        readonly property real scale: 1.0
    }

    // ===================================================================
    // Fonts.
    //   • family.*  — unchanged (Sofia Sans / tabler), do not touch.
    //   • M3 type scale (headline/title/body/label/mono/icon × size) —
    //     full font specs (family + size + weight) exposed as `font`
    //     value types so a component can bind `font: Appearance.font.body.small`
    //     exactly like caelestia's Tokens.font.*.
    //   • size.*    — legacy flat point sizes (deprecated), kept frozen so
    //     existing StyledText/StyledIcon call sites keep working.
    // ===================================================================
    component FontFamily: QtObject {
        readonly property string sans: "Sofia Sans Medium"//"Zen Kurenaido"//"Ioskeley Mono"//"Dank Mono"//"ZedMono Nerd Font"//"IBM Plex Sans"
        readonly property string mono: "Sofia Sans Medium"//"Zen Kurenaido"//"Ioskeley Mono"//"Dank Mono"//"ZedMono Nerd Font"//"JetBrains Mono NF"
        readonly property string tabler: "tabler-icons"//"Material Symbols Rounded"
    }

    component FontSize: QtObject {
        readonly property int small: 11
        readonly property int smaller: 12
        readonly property int normal: 13
        readonly property int larger: 15
        readonly property int large: 18
        readonly property int extraLarge: 28
    }

    component FontStuff: QtObject {
        readonly property FontFamily family: FontFamily {}
        readonly property FontSize size: FontSize {}
        readonly property real scale: 1.0

        // Special-purpose families (caelestia parity). pShell keeps sans.
        readonly property string clock: family.sans
        readonly property string workspaces: family.sans

        // --- M3 type scale ---
        readonly property QtObject headline: QtObject {
            readonly property font large: Qt.font({ family: root.font.family.sans, pointSize: Math.round(32 * root.font.scale), weight: Font.Medium })
            readonly property font medium: Qt.font({ family: root.font.family.sans, pointSize: Math.round(28 * root.font.scale), weight: Font.Medium })
            readonly property font small: Qt.font({ family: root.font.family.sans, pointSize: Math.round(24 * root.font.scale), weight: Font.Medium })
        }
        readonly property QtObject title: QtObject {
            readonly property font large: Qt.font({ family: root.font.family.sans, pointSize: Math.round(22 * root.font.scale), weight: Font.Medium })
            readonly property font medium: Qt.font({ family: root.font.family.sans, pointSize: Math.round(16 * root.font.scale), weight: Font.Medium })
            readonly property font small: Qt.font({ family: root.font.family.sans, pointSize: Math.round(14 * root.font.scale), weight: Font.Medium })
        }
        readonly property QtObject body: QtObject {
            readonly property font large: Qt.font({ family: root.font.family.sans, pointSize: Math.round(16 * root.font.scale), weight: Font.Normal })
            readonly property font medium: Qt.font({ family: root.font.family.sans, pointSize: Math.round(14 * root.font.scale), weight: Font.Normal })
            readonly property font small: Qt.font({ family: root.font.family.sans, pointSize: Math.round(12 * root.font.scale), weight: Font.Normal })
        }
        readonly property QtObject label: QtObject {
            readonly property font large: Qt.font({ family: root.font.family.sans, pointSize: Math.round(14 * root.font.scale), weight: Font.Medium })
            readonly property font medium: Qt.font({ family: root.font.family.sans, pointSize: Math.round(12 * root.font.scale), weight: Font.Medium })
            readonly property font small: Qt.font({ family: root.font.family.sans, pointSize: Math.round(11 * root.font.scale), weight: Font.Normal })
        }
        readonly property QtObject mono: QtObject {
            readonly property font large: Qt.font({ family: root.font.family.mono, pointSize: Math.round(16 * root.font.scale), weight: Font.Normal })
            readonly property font medium: Qt.font({ family: root.font.family.mono, pointSize: Math.round(14 * root.font.scale), weight: Font.Normal })
            readonly property font small: Qt.font({ family: root.font.family.mono, pointSize: Math.round(12 * root.font.scale), weight: Font.Normal })
        }
        readonly property QtObject icon: QtObject {
            // caelestia divides Material Symbols point sizes by 1.33; kept 1:1.
            readonly property font extraLarge: Qt.font({ family: root.font.family.tabler, pointSize: Math.round(36 * root.font.scale), weight: Font.Normal })
            readonly property font large: Qt.font({ family: root.font.family.tabler, pointSize: Math.round(24 * root.font.scale), weight: Font.Normal })
            readonly property font medium: Qt.font({ family: root.font.family.tabler, pointSize: Math.round(18 * root.font.scale), weight: Font.Normal })
            readonly property font small: Qt.font({ family: root.font.family.tabler, pointSize: Math.round(15 * root.font.scale), weight: Font.Normal })
        }
    }

    // ===================================================================
    // Animations.
    // ===================================================================
    component AnimCurves: QtObject {
        property list<real> bubblyWidth: [0.23, 1.76, 0.05, 1.00, 1, 1]
        property list<real> bubblyHeight: [0.43, 1.72, 0.35, 0.96, 1, 1]
        property list<real> bubblyMove: [0.22, 1.84, 0.24, 0.93, 1, 1]
        property list<real> bubblyLongSide: [0.23, 1.76, 0.05, 1.00, 1, 1]
        property list<real> bubblyShortSide: [0.43, 1.72, 0.35, 0.96, 1, 1]

        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property list<real> expressiveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
        readonly property list<real> expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property list<real> expressiveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    }

    component AnimDurations: QtObject {
        readonly property int small: 200
        readonly property int normal: 400
        readonly property int large: 600
        readonly property int extraLarge: 1000
        readonly property int expressiveFastSpatial: 350
        readonly property int expressiveDefaultSpatial: 500
        readonly property int expressiveSlowSpatial: 650
        readonly property int expressiveFastEffects: 150
        readonly property int expressiveDefaultEffects: 200
        readonly property int expressiveSlowEffects: 300

        // pShell-specific fast duration (no M3 equivalent; M3 min = small 200)
        readonly property int smaller: 100
    }

    component Anim: QtObject {
        readonly property AnimCurves curves: AnimCurves {}
        readonly property AnimDurations durations: AnimDurations {}
    }
}
