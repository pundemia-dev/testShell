import QtQuick
import qs.modules.launcher.content

// Manifest for the Applications launcher module — metadata only; the
// implementation (AppsModule) is built lazily on activation.
LauncherManifest {
    title: "Applications"
    description: "Search and launch applications"
    icon: "💻"
    order: 0

    content: Component {
        AppsModule {}
    }
}
