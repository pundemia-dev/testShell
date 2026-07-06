pragma Singleton

import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

// Shared IPC surface for the toggleable, registry-driven modules (launcher,
// dashboard, ai). Each module's per-screen wrapper `register()`s its visibility
// name once and feeds its manifest list; this singleton owns one IPC target per
// module (so the generic CustomShortcut must NOT — wrappers pass an empty
// shortcut to addVisibility, freeing the target for us). The IPC target name is
// the module's visibility name verbatim: "launcher" | "dashboard" | "ai".
//
// Auto per-plugin dispatch is registry-driven: the manifest list comes straight
// from the module's PluginRegistry (fed via register/setManifests), so every
// plugin is reachable with no extra per-plugin fields. Selecting the plugin is
// module-specific, so we only emit `openRequested` and let the visible wrapper
// do the selection. The module set itself is fixed, so targets are declared
// statically below (one IpcHandler each).
//
//   qs -c pShell ipc call <name> toggle              # launcher | dashboard | ai
//   qs -c pShell ipc call <name> open <pluginId>
//   qs -c pShell ipc call <name> openQuery <id> <q>  # launcher initial query
//   qs -c pShell ipc call <name> list                # JSON [{id,trigger,title}]
Singleton {
    id: root

    // name -> { manifests }. Reassigned on mutation so bindings notify.
    property var _modules: ({})

    // Emitted after the module is shown on the active monitor; its visible
    // wrapper activates/selects the requested plugin.
    signal openRequested(string name, string id, string query)

    function register(name: string, manifests: var): void {
        const m = root._modules;
        m[name] = ({ manifests: manifests ?? [] });
        root._modules = m;
    }

    function setManifests(name: string, manifests: var): void {
        const m = root._modules;
        if (m[name]) {
            m[name].manifests = manifests ?? [];
            root._modules = m;
        }
    }

    function toggle(name: string): void {
        const v = VisibilitiesManager.getForActive();
        if (v)
            v.toggleVisibility(name);
    }

    function show(name: string, state: bool): void {
        const v = VisibilitiesManager.getForActive();
        if (v)
            v.setVisibility(name, state);
    }

    function open(name: string, id: string, query: string): void {
        // Show first (synchronously flips the active wrapper visible), then let
        // that wrapper select the plugin off openRequested.
        show(name, true);
        openRequested(name, id ?? "", query ?? "");
    }

    function listJson(name: string): string {
        const mod = root._modules[name];
        const mans = mod ? (mod.manifests ?? []) : [];
        return JSON.stringify(mans.map(x => ({
            id: x.id,
            trigger: x.trigger ?? "",
            title: x.title ?? ""
        })));
    }

    // One static handler per module (fixed set — modules aren't drop-in folders
    // like plugins). Dynamic Instantiator+IpcHandler mis-registers (stray
    // modelDataChanged / "engine generation" races), so keep them declarative.
    IpcHandler {
        target: "launcher"
        function activate(): void { root.toggle("launcher"); }
        function toggle(): void { root.toggle("launcher"); }
        function open(id: string): void { root.open("launcher", id, ""); }
        function openQuery(id: string, query: string): void { root.open("launcher", id, query); }
        function list(): string { return root.listJson("launcher"); }
    }

    IpcHandler {
        target: "dashboard"
        function activate(): void { root.toggle("dashboard"); }
        function toggle(): void { root.toggle("dashboard"); }
        function open(id: string): void { root.open("dashboard", id, ""); }
        function openQuery(id: string, query: string): void { root.open("dashboard", id, query); }
        function list(): string { return root.listJson("dashboard"); }
    }

    IpcHandler {
        target: "ai"
        function activate(): void { root.toggle("ai"); }
        function toggle(): void { root.toggle("ai"); }
        function open(id: string): void { root.open("ai", id, ""); }
        function openQuery(id: string, query: string): void { root.open("ai", id, query); }
        function list(): string { return root.listJson("ai"); }
    }
}
