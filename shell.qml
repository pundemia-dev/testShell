//@ pragma IconTheme Linox-Custom
import Quickshell
import QtQuick
import qs.services
import "drawers"
import "modules/settings"
import "modules/capture"
import qs.modules.lock

ShellRoot {
    Drawers {}
    Settings {}
    CaptureScope {}
    LockWrapper {}

    // Force PresetsManager to instantiate so its "presets" IPC handler and
    // preset-dir bootstrap run even before the settings UI is opened.
    Component.onCompleted: {
        PresetsManager.presetsDir;
    }
}
