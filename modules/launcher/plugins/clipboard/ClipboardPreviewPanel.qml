pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Right panel of the clipboard module: rich preview of the highlighted record.
// Image → fitted thumbnail + dimensions; colour → big swatch + hex/rgb/hsl
// conversions; text/url/path → readable scrollable body. `mod` = ClipboardModule,
// `svc` = its ClipboardService (used for decode; named `svc` not `service` to
// avoid shadowing the outer id in the `svc: service` binding).
Item {
    id: panelRoot

    anchors.fill: parent

    required property var mod
    required property var svc

    readonly property var rec: mod.selectedRecord
    readonly property string type: rec?.type ?? ""

    // cliphist `list` only returns a truncated single-line preview; the full
    // body needs `decode`. Decode text/url/path on selection (cached on the rec).
    property string fullText: rec?.value ?? ""

    onRecChanged: _loadFull()
    Component.onCompleted: _loadFull()

    function _loadFull() {
        const r = rec;
        if (!r || (type !== "text" && type !== "url" && type !== "path")) {
            fullText = r?.value ?? "";
            return;
        }
        if (r._full !== undefined) {
            fullText = r._full ?? "";
            return;
        }
        fullText = r.value ?? ""; // show the truncated preview while decoding
        decodeProc.rec = r;
        decodeProc.command = ["bash", "-c",
            `printf %s ${svc.shq(r.raw)} | ${svc.binary} decode`];
        decodeProc.running = true;
    }

    Process {
        id: decodeProc
        property var rec: null
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text ?? "";
                if (decodeProc.rec)
                    decodeProc.rec._full = t;
                if (decodeProc.rec === panelRoot.rec)
                    panelRoot.fullText = t;
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Appearance.padding.large * 2
        spacing: Appearance.spacing.medium

        // ── IMAGE ────────────────────────────────────────────────────
        Loader {
            Layout.fillWidth: true
            active: panelRoot.type === "image"
            visible: active
            sourceComponent: ColumnLayout {
                spacing: Appearance.spacing.small

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width * 0.75

                    readonly property real natW: (panelRoot.rec?.width ?? 0) > 0 ? panelRoot.rec.width : 4
                    readonly property real natH: (panelRoot.rec?.height ?? 0) > 0 ? panelRoot.rec.height : 3
                    readonly property real aspect: natW / natH
                    readonly property real contAspect: width / height
                    readonly property real fitW: aspect >= contAspect ? width : height * aspect
                    readonly property real fitH: aspect >= contAspect ? width / aspect : height

                    StyledClippingRect {
                        anchors.centerIn: parent
                        width: parent.fitW
                        height: parent.fitH
                        radius: Appearance.rounding.large
                        color: Colours.alpha(Colours.palette.surface_variant, 0.4)

                        Image {
                            anchors.fill: parent
                            source: panelRoot.rec ? "file://" + panelRoot.rec.imagePath : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: panelRoot.rec
                        ? (panelRoot.rec.width + "×" + panelRoot.rec.height
                           + (panelRoot.rec.size ? "  ·  " + panelRoot.rec.size : ""))
                        : ""
                    font: Appearance.font.label.large
                    color: Colours.alpha(Colours.palette.on_surface, 0.6)
                }
            }
        }

        // ── COLOUR ───────────────────────────────────────────────────
        Loader {
            Layout.fillWidth: true
            active: panelRoot.type === "color"
            visible: active
            sourceComponent: ColumnLayout {
                spacing: Appearance.spacing.medium

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width * 0.55
                    radius: Appearance.rounding.large
                    color: panelRoot.rec?.hex ?? "transparent"
                    border.width: 1
                    border.color: Colours.alpha(Colours.palette.outline, 0.4)

                    StyledText {
                        anchors.centerIn: parent
                        text: panelRoot.rec?.value ?? ""
                        font: Appearance.font.title.medium
                        // Contrast-aware label over the swatch.
                        color: {
                            const c = panelRoot.rec?.hex ? Qt.color(panelRoot.rec.hex) : Qt.rgba(0, 0, 0, 1);
                            const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
                            return lum > 0.55 ? "#000000" : "#ffffff";
                        }
                    }
                }

                Repeater {
                    model: {
                        const rec = panelRoot.rec;
                        if (!rec)
                            return [];
                        const c = Qt.color(rec.hex);
                        const r = Math.round(c.r * 255), g = Math.round(c.g * 255), b = Math.round(c.b * 255);
                        return [
                            { k: "HEX", v: rec.hex.toUpperCase() },
                            { k: "RGB", v: `rgb(${r}, ${g}, ${b})` },
                            { k: "HSL", v: panelRoot._toHsl(c) }
                        ];
                    }

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.medium

                        StyledText {
                            text: modelData.k
                            font: Appearance.font.label.large
                            color: Colours.palette.primary
                            Layout.preferredWidth: 40
                        }
                        StyledText {
                            text: modelData.v
                            font: Appearance.font.mono.medium
                            color: Colours.palette.on_surface
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ── TEXT / URL / PATH ────────────────────────────────────────
        Loader {
            Layout.fillWidth: true
            active: panelRoot.type === "text" || panelRoot.type === "url" || panelRoot.type === "path"
            visible: active
            sourceComponent: StyledRect {
                implicitHeight: Math.min(bodyText.implicitHeight + Appearance.padding.large * 2, 340)
                radius: Appearance.rounding.large
                color: Colours.transparency.enabled
                    ? Colours.layer(Colours.palette.surface_container, 2)
                    : Colours.palette.surface_container

                VerticalFadeFlickable {
                    id: scrollFlick
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    clip: true
                    contentWidth: width
                    contentHeight: bodyText.implicitHeight

                    StyledText {
                        id: bodyText
                        width: scrollFlick.width
                        text: panelRoot.fullText
                        font: panelRoot.type === "text"
                            ? Appearance.font.body.small
                            : Appearance.font.mono.small
                        color: Colours.palette.on_surface
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        // ── Hint ─────────────────────────────────────────────────────
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Enter — copy" + (panelRoot.svc?.autoPaste ? " & paste" : "") + "   ·   Alt+Enter — copy only"
            font: Appearance.font.label.medium
            color: Colours.alpha(Colours.palette.on_surface, 0.45)
        }
    }

    function _toHsl(c) {
        const r = c.r, g = c.g, b = c.b;
        const max = Math.max(r, g, b), min = Math.min(r, g, b);
        let h = 0, s = 0;
        const l = (max + min) / 2;
        const d = max - min;
        if (d !== 0) {
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max === r)
                h = (g - b) / d + (g < b ? 6 : 0);
            else if (max === g)
                h = (b - r) / d + 2;
            else
                h = (r - g) / d + 4;
            h /= 6;
        }
        return `hsl(${Math.round(h * 360)}, ${Math.round(s * 100)}%, ${Math.round(l * 100)}%)`;
    }
}
