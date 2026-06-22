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
import "popoutsconfig"
import "generalconfig"

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
    property alias popouts: adapter.popouts
    property alias general: adapter.general
    // Open map for third-party module settings, keyed by SettingsSchema.key.
    // Official modules use their typed sub-configs above; custom modules read
    // their values as Config.custom["<key>"]?.field ?? default. See
    // docs/development/settings.md.
    property alias custom: adapter.custom

    // Read a third-party value with a fallback.
    function getCustom(key: string, field: string, fallback: var): var {
        return custom?.[key]?.[field] ?? fallback;
    }

    // Write a third-party value. Reassigns `custom` wholesale so JsonAdapter
    // sees the change and persists it (in-place mutation of nested objects
    // does NOT fire customChanged).
    function setCustom(key: string, field: string, value: var): void {
        const c = Object.assign({}, custom);
        const sub = Object.assign({}, c[key] ?? {});
        sub[field] = value;
        c[key] = sub;
        custom = c;
    }

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
            property PopoutsConfig popouts: PopoutsConfig {}
            property GeneralConfig general: GeneralConfig {}
            property var custom: ({})
        }
    }
}
