import qs.components.misc
import QtQuick

// Bar-widget binding of the generic PluginRegistry: scans ../widgets/<id>/ for
// `<id>.widget.qml` manifests (PluginManifest: title/icon/order + optional
// settingsSchema). The widget implementation stays `<id>/<id>.qml`, loaded by
// URL (WidgetHost, palette previews) — manifests carry metadata only. Widget
// availability isn't user-configurable (the bar layout in Config.bar decides
// what's shown), so no order/disabled bindings.
PluginRegistry {
    folder: Qt.resolvedUrl("../widgets")
    suffix: "widget"
}
