import qs.modules.session.content

// Log out of the current session (ends the Niri compositor session).
SessionManifest {
    title: qsTr("Log out")
    icon: "" // tabler logout
    order: 0
    // Niri-targeted shell: quitting the compositor ends the session (logout).
    command: ["niri", "msg", "action", "quit", "-s"]
}
