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

    component AnchorsData: JsonObject {
        property bool left: false
        property bool right: false
        property bool top: false
        property bool bottom: false
        property bool horizontalCenter: false
        property bool verticalCenter: false
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
