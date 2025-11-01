pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io

import "barconfig"
import "borderconfig"
import "cornersconfig"
import "backgroundsconfig"

Singleton {
    id: root

    property alias bar: adapter.bar
    property alias border: adapter.border
    property alias corners: adapter.corners
    property alias backgrounds: adapter.backgrounds

    FileView {
        id: fileview
        path: `${Paths.stringify(Paths.config)}/shell.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property BarConfig bar: BarConfig {}
            property BorderConfig border: BorderConfig {}
            property CornersConfig corners: CornersConfig {}
            property BackgroundsConfig backgrounds: BackgroundsConfig {}
        }
    }
}