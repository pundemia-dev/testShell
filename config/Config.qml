pragma Singleton

import qs.services
import Quickshell
import Quickshell.Io

import "barconfig"
import qs.modules.launcher.config
import "borderconfig"
import "cornersconfig"
import "backgroundsconfig"
// Feature-sliced module configs live inside their modules (stage 4 of the
// architecture cleanup); the remaining relative imports migrate as each
// module is sliced.
import qs.modules.notifications.config
import qs.modules.stash.config
import qs.modules.capture.config
import "popoutsconfig"
import qs.modules.dashboard.config
import "generalconfig"
import qs.modules.ai.config

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
    property alias dashboard: adapter.dashboard
    property alias general: adapter.general
    property alias ai: adapter.ai
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

    // Guards the startup write race: until the initial on-disk read finishes,
    // the JsonAdapter holds only the sub-configs' QML defaults. Writing those
    // back (async load hasn't delivered yet) would clobber shell.json with a
    // full default config — wiping the applied theme on every restart. Only
    // persist after `loaded` (or after creating a missing file). See
    // [[config-startup-write-race]].
    property bool ready: false

    FileView {
        id: fileview
        // path: `${Paths.stringify(Paths.config)}/shell.json`
        path: `/home/pundemia/.config/pShell/shell.json`
        watchChanges: true
        // Synchronous first read so the adapter is populated from disk before
        // any binding can fire onAdapterUpdated.
        blockLoading: true
        onFileChanged: reload()
        onAdapterUpdated: if (root.ready) writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                // First run: no file yet — create it from defaults, then allow writes.
                root.ready = true;
                writeAdapter();
            }
        }

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
            property DashboardConfig dashboard: DashboardConfig {}
            property GeneralConfig general: GeneralConfig {}
            property AiConfig ai: AiConfig {}
            property var custom: ({})
        }
    }
}
