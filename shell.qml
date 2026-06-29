//@ pragma IconTheme Linox-Custom
import Quickshell
import QtQuick
import qs.utils
import "drawers"
import "modules/settings"
import "modules/capture"

ShellRoot {
    Drawers {}
    Settings {}
    CaptureScope {}

    // Force PresetsManager to instantiate so its "presets" IPC handler and
    // preset-dir bootstrap run even before the settings UI is opened. Likewise
    // NiriBlur, so the generated blur.kdl tracks Config from startup.
    Component.onCompleted: {
        PresetsManager.presetsDir;
        NiriBlur.kdlPath;
    }
}
