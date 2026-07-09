import qs.modules.session.content

// Power off the machine.
SessionManifest {
    title: qsTr("Shut down")
    icon: "" // tabler power
    order: 1
    command: ["systemctl", "poweroff"]
}
