pragma Singleton

import Quickshell

// Live registry of toast SOURCES (self-registering, no hardcoded category list).
// A unit that emits toasts ships a declarative `ToastSource` (components/misc);
// it registers here on load and unregisters on unload. The settings page reads
// `sources` to build its tree, and Toaster reads `parentOf`/`get` to resolve the
// mute hierarchy. Mirrors the PluginRegistry idea but for a scattered, runtime
// extension point (services, modules, launcher plugins) rather than one folder.
//
// A source descriptor is a ToastSource with:
//   sourceId       — stable unique id (folder/module-ish); the mute key.
//   label, icon    — how it shows in settings.
//   parentId       — optional: nest under a module node (module → plugin → notif).
//   notifications  — [{ id, label, severity, icon }] the source can emit.
// Parent nodes referenced by `parentId` but never registered themselves are
// synthesised on the fly (see `nodes`), so a module grouping appears from a
// child plugin alone.
Singleton {
    id: root

    // Registered ToastSource objects (unordered).
    property var sources: []

    property var _byId: ({})

    function register(src): void {
        if (!src || !src.sourceId)
            return;
        _byId[src.sourceId] = src;
        _rebuild();
    }

    function unregister(id: string): void {
        if (_byId[id]) {
            delete _byId[id];
            _rebuild();
        }
    }

    // The registered source object for an id, or null.
    function get(id: string): var {
        return _byId[id] ?? null;
    }

    // Parent node id of a source, or "" if top-level / unknown.
    function parentOf(id: string): string {
        return _byId[id]?.parentId ?? "";
    }

    function _rebuild(): void {
        const out = [];
        for (const k in _byId)
            if (_byId[k])
                out.push(_byId[k]);
        root.sources = out;
    }
}
