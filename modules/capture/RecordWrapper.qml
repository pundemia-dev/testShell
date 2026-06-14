pragma ComponentBehavior: Bound

import qs.config
import qs.services
import Quickshell
import QtQuick
import "content"

// Recording indicator as a rails panel: registers with BackgroundsManager
// while a capture recording runs on this screen, top-centre push window
// (slides in under the bar with the shared blob background).
Item {
    id: root

    required property var manager
    required property ShellScreen screen

    readonly property bool indicatorVisible: (Capture.recording || Capture.recordPending) && Capture.recordScreen === root.screen.name

    property QtObject content: QtObject {
        // Width auto from content; height matches the bar.
        property int wrapperWidth: 0
        property int wrapperHeight: Config.bar.thickness.all ?? 44
        // Anchors
        property bool aLeft: false
        property bool aRight: false
        property bool aTop: true
        property bool aBottom: false
        property bool aHorizontalCenter: true
        property bool aVerticalCenter: false
        // Margins & offsets
        property int mLeft: 0
        property int mRight: 0
        property int mTop: Appearance.spacing.normal
        property int mBottom: 0
        property int vCenterOffset: 0
        property int hCenterOffset: 0
        // Paddings
        property int pLeft: Appearance.padding.large
        property int pRight: Appearance.padding.large
        property int pTop: 0
        property int pBottom: 0
        // Rails contract
        property string mode: "push"
        property bool pinned: false
        property bool reservesSpace: false
        readonly property int layer: 0
        property int windowRounding: Appearance.rounding.large
        property int invertedJoinRounding: -1

        property Component content: RecordPill {}
    }

    Loader {
        active: root.indicatorVisible

        sourceComponent: Item {
            Component.onCompleted: {
                root.manager.requestBackground(root.content);
            }

            Component.onDestruction: {
                root.manager.removeBackground(root.content);
            }
        }
    }
}
