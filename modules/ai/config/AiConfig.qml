import Quickshell.Io
import QtQuick

JsonObject {
    // Page content size (the panel sizes itself from the current page). These
    // describe the VERTICAL (side-drawer) footprint; the translator swaps them
    // when it renders horizontally (top/bottom/floating anchor).
    property int pageWidth: 500
    property int pageHeight: 850

    property string model: "gemini-2.5-flash"
    property real temperature: 0.7
    property string systemPrompt: "You are a helpful assistant running inside the pShell desktop shell on Linux. Be concise and accurate."
    property bool useG4f: false
    property string g4fModel: "gpt-4"

    // ── Geometry / anchors (drives the wrapper's rails contract) ──────────
    // Default: left edge, vertically centered (the original AI side-drawer).
    // Left/right anchors → the translator lays out vertically; top/bottom or a
    // floating centre (horizontalCenter) → it lays out horizontally.
    property AnchorsData anchors: AnchorsData {
        left: true
        verticalCenter: true
    }

    // Overlay = covers underlying window; push = displaces siblings on rail.
    property string mode: "push"
    property bool sticks: true

    // ── Background geometry (edited via BackgroundCard) ───────────────
    // Margins / paddings: each side is a number, "all" (inherit the group's
    // `all`), or null ("global" → the rails contract default). Centre offsets
    // shift the panel along the centred axis and may be negative.
    property EdgesData margins: EdgesData {}
    property EdgesData paddings: EdgesData {}
    property int hCenterOffset: 0
    property int vCenterOffset: 0

    // Stacking depth on the anchor rail.
    property int layer: 0
    // For mode "replace": position the borrowed bg INSIDE the reserved edge
    // strip (on the donor's spot, edge-flush like pinned) instead of being
    // inset past it.
    property bool reservesSpace: false

    // Rounding: a number, or null to follow Config.backgrounds.rounding.
    property var rounding: null
    // Size-spring override for the bg open/close/resize animation:
    // numbers, or null to follow the global Liquid defaults.
    property var sizeSpring: null
    property var sizeDamping: null

    component AnchorsData: JsonObject {
        property bool left: false
        property bool right: false
        property bool top: false
        property bool bottom: false
        property bool horizontalCenter: false
        property bool verticalCenter: false
    }

    component EdgesData: JsonObject {
        property var all: null
        property var left: "all"
        property var right: "all"
        property var top: "all"
        property var bottom: "all"
    }

    // ── Translator page ───────────────────────────────────────────────────
    property Translator translator: Translator {}

    component Translator: JsonObject {
        // Backend: "ai" | "google" | "deepl" | "duckduckgo".
        property string engine: "google"

        // BCP-47-ish codes understood by the backends. "auto" only valid as
        // source (the target must be concrete).
        property string sourceLanguage: "auto"
        property string targetLanguage: "en"

        // Auto-translate debounce after typing / language change (ms).
        property int debounceMs: 500

        // Prompt template used when engine == "ai". Placeholders are filled at
        // request time: {{from-language}}, {{to-language}}, {{text-to-translate}}.
        property string prompt: "Translate the following text from {{from-language}} to {{to-language}}. Output only the translation, with no explanations, notes or quotes.\n\n{{text-to-translate}}"
    }
}
