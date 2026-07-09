import qs.modules.session.content

// Hibernate (suspend to disk).
SessionManifest {
    title: qsTr("Hibernate")
    icon: "" // tabler moon
    order: 2
    command: ["systemctl", "hibernate"]
}
