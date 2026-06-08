pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io

import "barconfig"
import "launcherconfig"
import "borderconfig"
import "cornersconfig"
import "backgroundsconfig"
import "notifsconfig"
import "stashconfig"
import "captureconfig"

Singleton {
    id: root

    property alias bar: adapter.bar
    property alias launcher: adapter.launcher
    property alias border: adapter.border
    property alias corners: adapter.corners
    property alias backgrounds: adapter.backgrounds
    property alias notifs: adapter.notifs
    property alias stash: adapter.stash
    property alias capture: adapter.capture

    FileView {
        id: fileview
        // path: `${Paths.stringify(Paths.config)}/shell.json`
        path: `/home/pundemia/.config/pShell/shell.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property BarConfig bar: BarConfig {}
            property LauncherConfig launcher: LauncherConfig {}
            property BorderConfig border: BorderConfig {}
            property CornersConfig corners: CornersConfig {}
            property BackgroundsConfig backgrounds: BackgroundsConfig {}
            property NotifsConfig notifs: NotifsConfig {}
            property StashConfig stash: StashConfig {}
            property CaptureConfig capture: CaptureConfig {}
        }
    }
}
