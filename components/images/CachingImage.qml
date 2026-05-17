import Quickshell
import QtQuick

// Replaces the former Caelestia.Internal-backed CachingImage. Relies on Qt's
// built-in image cache plus asynchronous loading. The `path` property is kept
// for backwards compatibility with call sites that don't use `source`.
Image {
    id: root

    property string path
    source: path ? Qt.resolvedUrl(path) : ""

    asynchronous: true
    cache: true
    fillMode: Image.PreserveAspectCrop
}
