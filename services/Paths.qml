pragma Singleton

import qs.config
import Quickshell

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`
    readonly property string videos: Quickshell.env("XDG_VIDEOS_DIR") || `${home}/Videos`

    readonly property string data: `${Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`}/pShell`
    readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/pShell`
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/pShell`
    readonly property string config: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/pShell`

    readonly property string imagecache: `${cache}/imagecache`
    readonly property string notifimagecache: `${imagecache}/notifs`
    readonly property string wallsdir: Quickshell.env("PSHELL_WALLPAPERS_DIR") || absolutePath(Config.paths?.wallpaperDir ?? "")
    readonly property string recsdir: Quickshell.env("PSHELL_RECORDINGS_DIR") || `${videos}/Recordings`
    readonly property string libdir: Quickshell.env("PSHELL_LIB_DIR") || "/usr/lib/pShell"

    function toLocalFile(path: url): string {
        const resolved = Qt.resolvedUrl(path).toString();
        if (!resolved) return "";
        return resolved.startsWith("file://") ? decodeURIComponent(resolved.slice(7)) : resolved;
    }

    function absolutePath(path: string): string {
        return toLocalFile(path.replace(/~|(\$({?)HOME(}?))+/, home));
    }

    function shortenHome(path: string): string {
        return path.replace(home, "~");
    }
}

// pragma Singleton

// import Quickshell
// import Qt.labs.platform

// Singleton {
//     id: root

//     // readonly property url home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
//     // readonly property url pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]

//     // readonly property url data: `${StandardPaths.standardLocations(StandardPaths.GenericDataLocation)[0]}/caelestia`
//     // readonly property url state: `${StandardPaths.standardLocations(StandardPaths.GenericStateLocation)[0]}/caelestia`
//     // readonly property url cache: `${StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]}/caelestia`
//     readonly property url config: `${StandardPaths.standardLocations(StandardPaths.GenericConfigLocation)[0]}/pShell`
//     // readonly property url data: `~/.config/quickshell/pShell/cache/data`
//     // readonly property url state: `~/.config/quickshell/pShell/cache/state`
//     // readonly property url cache: `~/.config/quickshell/pShell/cache/cache`
//     // readonly property url config: `~/.config/quickshell/pShell/cache/config`

//     // readonly property url imagecache: `${cache}/imagecache`
//     // readonly property url imagecache: `${home}/.config/quickshell/pShell/cache/imagecache`

//     function stringify(path: url): string {
//         return path.toString().replace(/%20/g, " ");
//     }

//     function expandTilde(path: string): string {
//         return strip(path.replace("~", stringify(root.home)));
//     }

//     function shortenHome(path: string): string {
//         return path.replace(strip(root.home), "~");
//     }

//     function strip(path: url): string {
//         return stringify(path).replace("file://", "");
//     }

//     function mkdir(path: url): void {
//         Quickshell.execDetached(["mkdir", "-p", strip(path)]);
//     }

//     function copy(from: url, to: url): void {
//         Quickshell.execDetached(["cp", strip(from), strip(to)]);
//     }
// }
