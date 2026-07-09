import qs.modules.session.content

// Restart the machine.
SessionManifest {
    title: qsTr("Reboot")
    icon: "" // tabler refresh
    order: 3
    command: ["systemctl", "reboot"]
}
