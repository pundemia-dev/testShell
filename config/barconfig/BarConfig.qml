import Quickshell.Io
import qs.config

import "components"

//

JsonObject {
    property bool enabled: true
    property bool autoHide: false
    property bool orientation: false// orientation ([false] - vertical / [true] - horizontal)
    property bool position: true//  position ([false] - top or [true] - bottom / [false] - left or [true] - right)
    // property int thickness: 50
    property SeparatedData thickness: SeparatedData {
        all: 44
        center: 52
    }
    property bool separated: true
    property SeparatedData paddings: SeparatedData {
        all: 8
        center: 10
        // begin: 20
    }
    property SeparatedData rounding: SeparatedData {
        all: 12
        center: 70
        // begin: 15
    }
    property SeparatedData reusability: SeparatedData {
        all: false
    }

    property SeparatedData longSideMargin: SeparatedData {
        all: 7
        center: 0
    }

    property SeparatedData shortSideMargin: SeparatedData {
        all: 7
        // begin: 100
        // end: 100
    }

    property GroupData group: GroupData {
        thickness: 36
        padding: 5
        rounding: 12
        // separatorOnEmpty:
    }

    property list<var> beginLayout: [
        {
            "type": "widget",
            "name": "OsIcon"
        },
        {
            "type": "group",
            "children": [
                {
                    "type": "widget",
                    "name": "Tray"
                },
            ]
        },
        {
            "type": "widget",
            "name": "Utilities"
        },
    ]

    property list<var> centerLayout: [
        {
            "type": "widget",
            "name": "Workspaces"
        }
    ]

    property list<var> endLayout: [
        {
            "type": "group",
            "children": [
                {
                    "type": "widget",
                    "name": "KeyboardPreview"
                },
            ]
        },
        {
            "type": "widget",
            "name": "Clock"
        },
        {
            "type": "group",
            "children": [
                {
                    "type": "widget",
                    "name": "BluetoothStatus"
                },
                {
                    "type": "widget",
                    "name": "NetworkStatus"
                },
                {
                    "type": "widget",
                    "name": "PowerStatus"
                },
            ]
        },
        {
            "type": "widget",
            "name": "Power"
        },
    ]
    property bool isEditing: false
    property KbPreviewConfig kbPreview: KbPreviewConfig {}
    property TrayConfig tray: TrayConfig {}
    property WorkspacesConfig workspaces: WorkspacesConfig {}
}
