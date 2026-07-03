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

    // 4 ── Appear/collapse blur (content MultiEffect) ──────────────────────────
    // A blur on the panel CONTENT, driven by its OWN time-based animation — NOT
    // the size spring. This decoupling is the whole point: the size spring reaches
    // full in ~100ms, so a size-keyed blur clears while the panel is still a tiny,
    // fast-moving speck (strongest blur exactly when least visible) — invisible in
    // practice. A time ramp instead keeps the blur on the already-full-size panel
    // and resolves it over `appearBlurDuration`:
    //   appear  : blur 1 → 0  (content materialises sharp)
    //   collapse: blur 0 → 1  (content dissolves as it shrinks away)
    // The MultiEffect layer is gated to only switch on while blurring, so there's
    // zero steady-state cost. Set appearBlurMax = 0 to disable entirely.
    //
    //   • appearBlurMax      — MultiEffect.blurMax: peak blur radius in SCREEN px
    //                          at blur=1 (meaningful range 2..64). 0 disables.
    //   • appearBlurDuration — ms for the blur to clear (appear) / build (collapse).
    property int appearBlurMax: 16
    property int appearBlurDuration: 300
}
