import qs.services
import QtQuick

// Declarative, self-registering toast source. A unit that emits toasts declares
// one of these (like a SettingsSchema) and calls `notify(...)`; it auto-registers
// with ToastRegistry on load and unregisters on unload, so its category — and
// every notification it can emit — shows up in the toast settings WITHOUT any
// hardcoded list. Icon/severity per notification come from the manifest, so the
// call site only passes the dynamic title/message.
//
// Nesting (module → plugin → notification): set `parentId` to a module node's
// id; the settings tree groups this source under it. A leaf source's individual
// toasts can be muted per-severity-group (error vs other) or per-id; a parent
// (module) master toggle mutes everything beneath it. All mute state lives in
// Config.toasts.overrides (open map), never in a fixed schema.
QtObject {
    id: root

    // Stable unique id — the mute key (named sourceId, since `id` is reserved).
    required property string sourceId

    // How the source shows in settings.
    property string label: sourceId
    property string icon: ""

    // Optional parent (module) node id to nest under. "" = top-level source.
    property string parentId: ""

    // Notifications this source can emit:
    //   { id: "wp-applied", label: "Wallpaper applied",
    //     severity: "info"|"success"|"warning"|"error", icon: "<tabler>" }
    // severity drives styling + the error/other mute group; icon/label are used
    // by settings and as emit defaults.
    property var notifications: []

    readonly property var _sevType: ({
            info: Toaster.Info,
            success: Toaster.Success,
            warning: Toaster.Warning,
            error: Toaster.Error
        })

    // Emit a declared notification. `extra` (optional) overrides:
    //   { icon, timeout, type }. Returns the toast id, or -1 if suppressed
    // (globally disabled, or muted at module / source / group / id level).
    function notify(notifId, title, message, extra) {
        const n = (root.notifications ?? []).find(x => x.id === notifId) ?? {};
        const e = extra ?? {};
        return Toaster.push({
            sourceId: root.sourceId,
            notifId: notifId,
            title: title ?? "",
            message: message ?? "",
            icon: e.icon ?? n.icon ?? root.icon ?? "",
            type: e.type ?? root._sevType[n.severity] ?? Toaster.Info,
            timeout: e.timeout
        });
    }

    Component.onCompleted: ToastRegistry.register(root)
    Component.onDestruction: ToastRegistry.unregister(root.sourceId)
}
