pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Caelestia.Blobs
import QtQuick

// Inline colour result + quick editor for the pipette mode. Pops out of the
// live-preview chip next to the pick point (scale+fade from the nearest
// corner) and stays put while the loupe keeps roaming: it shows TWO
// previews — the live colour under the cursor and the picked one. The picked
// colour can be edited with M3-style HSL sliders or by typing a value
// (hex / rgb() / hsl()) into the field. Format toggle persists through the
// "auto" memory; every pick / format switch / edit re-copies silently,
// Enter|Space at the overlay level copies with feedback and closes.
Item {
    id: root

    required property var picker   // ColorLoupe

    property bool open: false
    property real hue: 0
    property real sat: 0
    property real lig: 0
    property string fmt: "hex"

    // Resting position (top-left). Far picks make it crawl, animated.
    property real panelX: 0
    property real panelY: 0
    // Grow-out-of-the-chip morph: 0 = live-chip geometry, 1 = settled panel.
    property real growT: 0
    property var fromRect: ({ x: 0, y: 0, w: 1, h: 1 })
    property bool crawlLive: false

    readonly property color cur: Qt.hsla(hue, sat, lig, 1)
    readonly property int rC: Math.round(cur.r * 255)
    readonly property int gC: Math.round(cur.g * 255)
    readonly property int bC: Math.round(cur.b * 255)
    readonly property string valueText: Capture.formatColor(rC, gC, bC, fmt)

    // The loupe hides while the cursor is over the panel.
    readonly property bool hovering: panelHover.hovered
    // The overlay must not treat Enter/Space as "confirm" while typing here.
    readonly property bool fieldFocused: valField.activeFocus

    function initialFmt(): string {
        const def = Config.capture.colorDefaultFormat;
        if (def === "auto")
            return Config.capture.colorLastFormat || "hex";
        return def;
    }

    function setRgb(r: int, g: int, b: int): void {
        const c = Qt.rgba(r / 255, g / 255, b / 255, 1);
        hue = Math.max(0, c.hslHue);
        sat = c.hslSaturation;
        lig = c.hslLightness;
    }

    function show(r: int, g: int, b: int): void {
        setRgb(r, g, b);
        if (!open) {
            fmt = initialFmt();
            fromRect = picker.chipRect();
            // Open onto the radius too — toward the screen centre.
            const cx = picker.cursorX, cy = picker.cursorY;
            const p = placeOnRadius(cx, cy, picker.width / 2 - cx, picker.height / 2 - cy);
            panelX = p.x;
            panelY = p.y;
            crawlLive = false;
            growT = 0;
            open = true;
            growAnim.restart();
        } else {
            maybeCrawl(picker.cursorX, picker.cursorY);
        }
        Capture.addRecent(rC, gC, bC);
        Capture.copyText(valueText);
    }

    function selectFmt(f: string): void {
        if (fmt === f)
            return;
        fmt = f;
        // Persisted through the config adapter → "auto" default remembers it.
        Config.capture.colorLastFormat = f;
        Capture.copyText(valueText);
    }

    // Typed colour: hex (#abc / #aabbcc), rgb()/rgba(), hsl()/hsla().
    function applyText(t: string): void {
        const s = t.trim().toLowerCase();
        let m = s.match(/^#?([0-9a-f]{6})$/);
        if (m) {
            setRgb(parseInt(m[1].slice(0, 2), 16), parseInt(m[1].slice(2, 4), 16), parseInt(m[1].slice(4, 6), 16));
            Capture.copyText(valueText);
            return;
        }
        m = s.match(/^#?([0-9a-f]{3})$/);
        if (m) {
            setRgb(parseInt(m[1][0] + m[1][0], 16), parseInt(m[1][1] + m[1][1], 16), parseInt(m[1][2] + m[1][2], 16));
            Capture.copyText(valueText);
            return;
        }
        m = s.match(/^rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)/);
        if (m) {
            const c255 = v => Math.max(0, Math.min(255, parseInt(v)));
            setRgb(c255(m[1]), c255(m[2]), c255(m[3]));
            Capture.copyText(valueText);
            return;
        }
        m = s.match(/^hsla?\(\s*(\d+)[,\s]+(\d+)%?[,\s]+(\d+)%?/);
        if (m) {
            hue = Math.max(0, Math.min(360, parseInt(m[1]))) / 360;
            sat = Math.max(0, Math.min(100, parseInt(m[2]))) / 100;
            lig = Math.max(0, Math.min(100, parseInt(m[3]))) / 100;
            Capture.copyText(valueText);
        }
        // Anything else: invalid → the field snaps back to the bound value.
    }

    // ── Placement: first opening lands next to the pick point ──────
    readonly property real boxW: Appearance.font.size.normal * 24
    readonly property real panelW: boxW + Appearance.padding.large * 2
    readonly property real panelH: col.implicitHeight + Appearance.padding.large * 2

    // Position whose nearest EDGE lands on the follow radius from (cx,cy),
    // approached along (dx,dy). Used both for the first opening and for
    // crawling — the panel never settles closer than the radius.
    function placeOnRadius(cx: real, cy: real, dx: real, dy: real): var {
        const sh = picker.height;
        const radius = sh * Config.capture.colorPanelFollowRadius / 100;
        const len = Math.hypot(dx, dy) || 1;
        dx /= len;
        dy /= len;
        // Offset the centre so the rect BOUNDARY lands on the radius.
        const edge = Math.min(dx !== 0 ? (panelW / 2) / Math.abs(dx) : 1e9, dy !== 0 ? (panelH / 2) / Math.abs(dy) : 1e9);
        const pad = Appearance.padding.medium;
        return {
            x: Math.max(pad, Math.min(picker.width - panelW - pad, cx + dx * (radius + edge) - panelW / 2)),
            y: Math.max(pad, Math.min(picker.height - panelH - pad, cy + dy * (radius + edge) - panelH / 2))
        };
    }

    // A pick made far from the panel makes it crawl back onto the radius,
    // approaching from its current direction. Thresholds are % of screen height.
    function maybeCrawl(cx: real, cy: real): void {
        const nx = Math.max(panelX, Math.min(cx, panelX + panelW));
        const ny = Math.max(panelY, Math.min(cy, panelY + panelH));
        const sh = picker.height;
        if (Math.hypot(cx - nx, cy - ny) <= sh * Config.capture.colorPanelMoveThreshold / 100)
            return;
        const p = placeOnRadius(cx, cy, panelX + panelW / 2 - cx, panelY + panelH / 2 - cy);
        panelX = p.x;
        panelY = p.y;
    }

    // Morph out of the live-preview chip: the blob's REAL geometry animates
    // from the chip rect to the panel rect — the SDF engine tracks its own
    // item's geometry (exactly like rails slots), so wrapping it in a scaled
    // parent would leave the shader stale.
    readonly property real vx: fromRect.x + (panelX - fromRect.x) * growT
    readonly property real vy: fromRect.y + (panelY - fromRect.y) * growT
    readonly property real vw: fromRect.w + (panelW - fromRect.w) * growT
    readonly property real vh: fromRect.h + (panelH - fromRect.h) * growT

    anchors.fill: parent
    visible: open

    Anim {
        id: growAnim

        target: root
        property: "growT"
        from: 0
        to: 1
        duration: Appearance.anim.durations.large
        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        onStopped: root.crawlLive = true
    }

    Behavior on panelX {
        enabled: root.crawlLive

        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on panelY {
        enabled: root.crawlLive

        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    // Liquid blob background — the same SDF renderer as the shell panels,
    // so the grow morph and the crawl get velocity squash/stretch for free.
    BlobGroup {
        id: panelGroup

        color: Colours.tPalette.surface_container
        smoothing: 32
    }

    BlobRect {
        id: panelBlob

        group: panelGroup
        x: root.vx
        y: root.vy
        width: Math.max(1, root.vw)
        height: Math.max(1, root.vh)
        radius: Appearance.rounding.large
        deformScale: Liquid.deformScale
        stiffness: Liquid.deformStiffness
        damping: Liquid.deformDamping
        deformAtten: Liquid.deformSizeScale(root.panelW, root.panelH)
    }

    // Content box: rides the morph (scaled to the growing blob), fades in.
    Item {
        id: contentBox

        x: root.vx
        y: root.vy
        width: root.panelW
        height: root.panelH
        scale: root.vw / Math.max(1, root.panelW)
        transformOrigin: Item.TopLeft
        opacity: Math.min(1, root.growT * 2)

        // Mirror the blob's velocity deform onto the content so it
        // stretches WITH the background instead of staying rectangular.
        transform: Matrix4x4 {
            matrix: panelBlob.deformMatrix
        }

        HoverHandler {
            id: panelHover
        }

        // Swallow clicks on the panel so they don't pick through it.
        MouseArea {
            anchors.fill: parent
        }

    Column {
        id: col

        anchors.centerIn: parent
        width: root.boxW
        spacing: Appearance.spacing.medium

        // ── Two previews (live / picked) + actions ──────────────────
        Item {
            width: parent.width
            implicitHeight: previews.implicitHeight

            Row {
                id: previews

                anchors.left: parent.left
                spacing: Appearance.spacing.large

                Column {
                    spacing: Appearance.spacing.small / 2

                    StyledRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: Appearance.font.size.large + Appearance.padding.large * 2
                        implicitHeight: implicitWidth
                        radius: Appearance.rounding.full
                        color: root.picker.liveColor ? Qt.rgba(root.picker.liveColor.r / 255, root.picker.liveColor.g / 255, root.picker.liveColor.b / 255, 1) : "transparent"
                        border.width: 1
                        border.color: Colours.palette.outline_variant
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "cursor"
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.on_surface_variant
                    }
                }

                Column {
                    spacing: Appearance.spacing.small / 2

                    StyledRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: Appearance.font.size.large + Appearance.padding.large * 2
                        implicitHeight: implicitWidth
                        radius: Appearance.rounding.full
                        color: root.cur
                        border.width: 2
                        border.color: Colours.palette.primary
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "picked"
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.on_surface_variant
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.small / 2

                IconButton {
                    type: IconButton.Text
                    icon: "" // copy
                    onClicked: Capture.copyTextNotify(root.valueText, "Color copied")
                }

                IconButton {
                    type: IconButton.Text
                    icon: "" // x
                    onClicked: root.open = false
                }
            }
        }

        // ── Editable value field ────────────────────────────────────
        StyledRect {
            width: parent.width
            radius: Appearance.rounding.small
            color: Colours.palette.surface_container_high
            border.width: valField.activeFocus ? 2 : 0
            border.color: Colours.palette.primary
            implicitHeight: valField.implicitHeight + Appearance.padding.medium * 2

            TextInput {
                id: valField

                property bool escCancel: false

                anchors.fill: parent
                anchors.margins: Appearance.padding.medium
                verticalAlignment: TextInput.AlignVCenter
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.larger
                color: Colours.palette.on_surface
                selectionColor: Colours.palette.primary
                selectedTextColor: Colours.palette.on_primary
                selectByMouse: true
                clip: true
                text: root.valueText

                onAccepted: focus = false

                Keys.onEscapePressed: {
                    escCancel = true;
                    focus = false;
                }

                onActiveFocusChanged: {
                    if (!activeFocus) {
                        if (!escCancel)
                            root.applyText(text);
                        escCancel = false;
                        text = Qt.binding(() => root.valueText);
                    }
                }
            }
        }

        // ── Format toggle ───────────────────────────────────────────
        Row {
            spacing: Appearance.spacing.small

            Repeater {
                model: ["hex", "rgb", "rgba", "hsl"]

                StyledRect {
                    id: chip

                    required property string modelData

                    readonly property bool active: root.fmt === modelData

                    implicitWidth: chipText.implicitWidth + Appearance.padding.medium * 2
                    implicitHeight: chipText.implicitHeight + Appearance.padding.small * 2
                    radius: Appearance.rounding.full
                    color: active ? Colours.palette.primary : Colours.palette.surface_container_high

                    StyledText {
                        id: chipText

                        anchors.centerIn: parent
                        text: chip.modelData.toUpperCase()
                        color: chip.active ? Colours.palette.on_primary : Colours.palette.on_surface_variant
                    }

                    StateLayer {
                        color: chip.active ? Colours.palette.on_primary : Colours.palette.on_surface

                        function onClicked(): void {
                            root.selectFmt(chip.modelData);
                        }
                    }
                }
            }
        }

        // ── Quick editor: hue / saturation / lightness ──────────────
        Column {
            width: parent.width
            spacing: Appearance.spacing.small

            ColorSlider {
                width: parent.width
                value: root.hue
                colorAt: t => Qt.hsla(t, 1, 0.5, 1)
                onMoved: v => root.hue = v
                onFinished: Capture.copyText(root.valueText)
            }

            ColorSlider {
                width: parent.width
                value: root.sat
                colorAt: t => Qt.hsla(root.hue, t, root.lig, 1)
                onMoved: v => root.sat = v
                onFinished: Capture.copyText(root.valueText)
            }

            ColorSlider {
                width: parent.width
                value: root.lig
                colorAt: t => Qt.hsla(root.hue, root.sat, t, 1)
                onMoved: v => root.lig = v
                onFinished: Capture.copyText(root.valueText)
            }
        }

        // ── Recent colours ──────────────────────────────────────────
        Flow {
            width: parent.width
            spacing: Appearance.spacing.small
            visible: Capture.recentColors.length > 0

            Repeater {
                model: Capture.recentColors

                StyledRect {
                    id: recent

                    required property var modelData

                    implicitWidth: Appearance.font.size.large
                    implicitHeight: implicitWidth
                    radius: Appearance.rounding.small / 2
                    color: Qt.rgba(modelData.r / 255, modelData.g / 255, modelData.b / 255, 1)
                    border.width: 1
                    border.color: Colours.palette.outline_variant

                    StateLayer {
                        function onClicked(): void {
                            root.setRgb(recent.modelData.r, recent.modelData.g, recent.modelData.b);
                            Capture.copyText(root.valueText);
                        }
                    }
                }
            }
        }
    }
    }

    // M3-style gradient slider: tall rounded track previewing the channel
    // sweep, and the M3 signature handle — a narrow vertical bar with a gap
    // carved out of the track on both sides; the bar stretches while dragged.
    component ColorSlider: Item {
        id: cs

        property real value: 0
        property var colorAt: t => "#000000"

        signal moved(real v)
        signal finished()

        readonly property real barW: Appearance.padding.small
        readonly property real gapW: Appearance.padding.small
        readonly property real knobX: value * (width - barW)

        implicitHeight: Appearance.font.size.large

        Rectangle {
            anchors.fill: parent
            radius: height / 2

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: cs.colorAt(0)
                }
                GradientStop {
                    position: 1 / 6
                    color: cs.colorAt(1 / 6)
                }
                GradientStop {
                    position: 2 / 6
                    color: cs.colorAt(2 / 6)
                }
                GradientStop {
                    position: 0.5
                    color: cs.colorAt(0.5)
                }
                GradientStop {
                    position: 4 / 6
                    color: cs.colorAt(4 / 6)
                }
                GradientStop {
                    position: 5 / 6
                    color: cs.colorAt(5 / 6)
                }
                GradientStop {
                    position: 1
                    color: cs.colorAt(1)
                }
            }
        }

        // Gap (panel background) around the handle bar — M3 split-track look.
        Rectangle {
            x: cs.knobX - cs.gapW
            anchors.verticalCenter: parent.verticalCenter
            width: cs.barW + cs.gapW * 2
            height: parent.height
            color: Colours.palette.surface_container
        }

        // Handle bar.
        Rectangle {
            x: cs.knobX
            anchors.verticalCenter: parent.verticalCenter
            width: cs.barW
            height: sliderMa.pressed ? cs.height + Appearance.padding.small * 2 : cs.height + Appearance.padding.small
            radius: width / 2
            color: Colours.palette.on_surface

            Behavior on height {
                Anim {
                    duration: Appearance.anim.durations.smaller
                }
            }
        }

        MouseArea {
            id: sliderMa

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function apply(mx: real): void {
                cs.moved(Math.max(0, Math.min(1, (mx - cs.barW / 2) / (cs.width - cs.barW))));
            }

            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => apply(mouse.x)
            onReleased: cs.finished()
        }
    }
}
