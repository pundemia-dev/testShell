// TEMP debug harness: real Rail + BackgroundsManager + WindowSlot, no windows.
// Run: qs -p ~/.config/quickshell/pShell/harness.qml   (delete after use)
import Quickshell
import QtQuick
import Caelestia.Blobs
import qs.services
import "drawers/backgrounds/components"

ShellRoot {
    id: root

    BackgroundsManager {
        id: mgr
    }

    property QtObject stubWrapper: QtObject {
        property int wrapperWidth: 0
        property int wrapperHeight: 0
        property bool aLeft: false
        property bool aRight: false
        property bool aTop: true
        property bool aBottom: false
        property bool aHorizontalCenter: true
        property bool aVerticalCenter: false
        property int mLeft: 0
        property int mRight: 0
        property int mTop: 10
        property int mBottom: 0
        property int vCenterOffset: 0
        property int hCenterOffset: 0
        property int pLeft: 15
        property int pTop: 15
        property int pRight: 15
        property int pBottom: 15
        property string mode: "push"
        property bool pinned: false
        property bool reservesSpace: false
        property bool sticks: true
        property int layer: 0
        property int windowRounding: 30
        property Component content: Component {
            Item {
                Rectangle {
                    id: inner
                    width: 0
                    height: 300
                    Timer {
                        interval: 600
                        running: true
                        onTriggered: {
                            console.log("HARNESS growing content now");
                            inner.width = 869;
                        }
                    }
                }
            }
        }
    }

    Item {
        id: host
        width: 1920
        height: 1080

        BlobGroup {
            id: grp
        }
        Item {
            id: grpHost
        }
        Item {
            id: contentLyr
        }

        Rail {
            railIndex: 1
            anchor: "top"
            windows: mgr.rails[1]
            group: grp
            groupHost: grpHost
            contentLayer: contentLyr
            zWidth: 1920
            zHeight: 1080
            left_area: 0
            top_area: 0
            right_area: 0
            bottom_area: 0
            manager: mgr
        }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: {
            console.log("HARNESS requestBackground");
            mgr.requestBackground(root.stubWrapper);
        }
    }
    Timer {
        interval: 2500
        running: true
        onTriggered: {
            console.log("HARNESS closing");
            mgr.removeBackground(root.stubWrapper);
        }
    }
    Timer {
        interval: 4000
        running: true
        onTriggered: Qt.quit()
    }
}
