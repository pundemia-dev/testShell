pragma Singleton

import Quickshell
import QtQuick

// ── Liquid-glass motion tuning (single source of truth) ──────────────────────
//
// Two cooperating systems make a panel read as "liquid glass":
//
//  1. SIZE FOLLOW — how a slot's painted width/height chase their target. One
//     spring shared by both axes; keep it brisk with little overshoot. This is
//     only the underlying MOTION — we do NOT fake liquid by under-damping it.
//
//  2. SDF DEFORM — the actual squash/stretch, performed by the Caelestia.Blobs
//     C++ engine (BlobRect). The blob is SDF-rendered in a shared group, so it
//     can only be deformed through the shader, not a QML transform. Each frame
//     the BlobRect measures its own CENTRE velocity in the scene, stretches
//     along the motion direction and compresses perpendicular (area-preserving),
//     then settles back to identity via an under-damped spring on the deform
//     matrix. Two liquid-glass properties fall out for free:
//
//       • SPEED  → stretch magnitude   (× deformScale, capped ~0.35 in C++).
//       • ORIGIN → stretch direction: a slot anchored to an edge drifts its
//         centre toward that edge as it grows, so the velocity vector already
//         encodes "which side it expands from":
//             right-anchored grow  → centre drifts left     → horizontal stretch
//             top-anchored  grow   → centre drifts down      → vertical stretch
//             corner        grow   → centre drifts diagonally→ diagonal stretch
//             centre-anchored grow → centre still            → (no stretch)
//
// Everything here hot-reloads — tune live with `qs -c pShell`.
Singleton {
    id: root

    // 1 ── Size follow (Behavior SpringAnimation on painted width/height) ──────
    property real sizeSpring: 4.0     // higher = faster catch-up to target
    property real sizeDamping: 0.26    // higher = less size overshoot (brisk, barely bounces)
    property real sizeEpsilon: 1.0    // settle threshold in px (cuts the slow tail)

    // 2 ── SDF deform (BlobRect.deformScale / stiffness / damping) ─────────────
    property real deformScale: 0.0004     // stretch per (px/sec) of centre speed; 0 disables
    property real deformStiffness: 200    // spring pulling the deform back to identity (higher = snappier)
    property real deformDamping: 16 //16       // lower = more liquid wobble on stop; higher = calmer

    // 3 ── Size attenuation (BlobRect.deformAtten) ─────────────────────────────
    // The deform looks fun on small panels but turns big ones into an obvious
    // parallelogram on diagonal motion (worst on a corner appear). Attenuate the
    // magnitude by panel size, CONTINUOUSLY (every px over `full` counts, so mid-
    // size panels respond too — not just past some threshold):
    //
    //     atten = full / (full + (size − full)·strength)   , floored at `floor`
    //
    //   • deformSizeFull   — size at/below which the effect is full (atten = 1).
    //   • deformSizeStrength — master "how much size matters" multiplier:
    //         0   → size ignored (full effect at every size)
    //         1   → at 2×full the effect is halved
    //         higher → big panels killed harder.
    //   • deformSizeFloor  — minimum multiplier (0 = can vanish entirely).
    property real deformSizeFull: 250      // px ≤ this → full effect
    property real deformSizeStrength: 7.0  // how strongly size beyond `full` cuts the effect
    property real deformSizeFloor: 0.0     // minimum multiplier (0 = can fully vanish)

    // Magnitude multiplier for a panel of (target) size w×h. Feed BlobRect.deformAtten.
    // Keyed on the STABLE target size so a panel that WILL be large is attenuated
    // throughout its appear, not only once it has finished growing.
    function deformSizeScale(w: real, h: real): real {
        const over = Math.max(0, Math.max(w, h) - deformSizeFull);
        const a = deformSizeFull / (deformSizeFull + over * deformSizeStrength);
        return Math.max(deformSizeFloor, a);
    }

    // 4 ── (removed) Appear/collapse content blur ──────────────────────────────
    // Migrated into the contentwarp shader on WindowSlot's scalingRoot: the
    // fragment stage blurs by Config.backgrounds.liquidContentBlurMax scaled by
    // the same animated mix as the rounding morph, so it covers open, close AND
    // movement. Tuning lives in Config.backgrounds (settings dials), not here.

    // 5 ── Speed-keyed rounding (BlobRect.speedRounding) ───────────────────────
    // While a panel MOVES, its corner radii ride toward the full capsule and
    // settle back as it decelerates — the speed bell of any spring/eased motion
    // gives the "roundest mid-path" profile for free. Value = rounding mix per
    // px/s of centre speed (full capsule reached at 1/value px/s). Gated by
    // Config.backgrounds.liquidRounding in WindowSlot; the smoothing (fast
    // attack / slower release) lives in the C++ physics next to the deform.
    property real roundingSpeed: 0.0012
}
