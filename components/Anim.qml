import qs.config
import QtQuick

// Ported from caelestia: a NumberAnimation carrying an M3 motion `type` that
// selects both duration and easing from the design tokens. pShell curves are
// `list<real>` (not prebuilt easing objects), so easing is applied via
// easing.type + easing.bezierCurve instead of caelestia's wholesale `easing:`.
//
// Default type is `Standard` → duration `normal` + curve `standard`, i.e. the
// exact behaviour of the previous bare Anim, so existing call sites (including
// those overriding easing.bezierCurve) are unchanged.
NumberAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.Standard

    duration: {
        if (type < Anim.StandardSmall || type > Anim.SlowEffects)
            return Appearance.anim.durations.normal;

        if (type === Anim.FastSpatial)
            return Appearance.anim.durations.expressiveFastSpatial;
        if (type === Anim.DefaultSpatial)
            return Appearance.anim.durations.expressiveDefaultSpatial;
        if (type === Anim.SlowSpatial)
            return Appearance.anim.durations.expressiveSlowSpatial;
        if (type === Anim.FastEffects)
            return Appearance.anim.durations.expressiveFastEffects;
        if (type === Anim.DefaultEffects)
            return Appearance.anim.durations.expressiveDefaultEffects;
        if (type === Anim.SlowEffects)
            return Appearance.anim.durations.expressiveSlowEffects;

        const types = ["small", "normal", "large", "extraLarge"];
        const idx = type % 4; // 0-7 are the 4 standard/emphasized size steps
        return Appearance.anim.durations[types[idx]];
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        if (type === Anim.FastSpatial)
            return Appearance.anim.curves.expressiveFastSpatial;
        if (type === Anim.DefaultSpatial)
            return Appearance.anim.curves.expressiveDefaultSpatial;
        if (type === Anim.SlowSpatial)
            return Appearance.anim.curves.expressiveSlowSpatial;
        if (type === Anim.FastEffects)
            return Appearance.anim.curves.expressiveFastEffects;
        if (type === Anim.DefaultEffects)
            return Appearance.anim.curves.expressiveDefaultEffects;
        if (type === Anim.SlowEffects)
            return Appearance.anim.curves.expressiveSlowEffects;

        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return Appearance.anim.curves.emphasized;
        return Appearance.anim.curves.standard;
    }
}
