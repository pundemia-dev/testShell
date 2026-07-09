import qs.components.misc

// Slot contract for session action units (modules/session/plugins/<id>/): the
// generic PluginManifest (id/title/icon/order/settingsSchema) plus the one
// session-specific field the host needs — the command to run when the button
// is triggered. Buttons are uniform, so units declare metadata only; there is
// no per-unit `content` Component (the host renders a shared SessionButton).
PluginManifest {
    // Command executed via Quickshell.execDetached when the button fires.
    property list<string> command: []
}
