import Quickshell.Io
import QtQuick

JsonObject {
    // Page content size (the panel sizes itself from the current page).
    property int pageWidth: 440
    property int pageHeight: 560

    property string model: "gemini-2.5-flash"
    property real temperature: 0.7
    property string systemPrompt: "You are a helpful assistant running inside the pShell desktop shell on Linux. Be concise and accurate."
    property bool useG4f: false
    property string g4fModel: "gpt-4"
}
