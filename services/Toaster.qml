pragma Singleton

import qs.config
import Quickshell
import QtQuick

// Ephemeral shell/OS toasts — the shell talking about ITSELF (config loaded,
// audio device changed, keyboard layout switched, DND toggled, now-playing…),
// as opposed to the freedesktop notification daemon (services/Notifs.qml), which
// relays messages from external apps. Ported in spirit from caelestia's C++
// Toaster, reimplemented as a pure-QML queue: no plugin rebuild, hot-reloadable.
//
// Per-source muting is dynamic, not a hardcoded category list. Emitters declare
// a `ToastSource` (components/misc) that self-registers with ToastRegistry;
// mute state lives in the open map Config.toasts.overrides, keyed by source id:
//
//   overrides["<sourceId>"] = {
//       enabled: false,             // mute the whole source (or a module node)
//       errors:  false,             // mute error-severity toasts from it
//       others:  false,             // mute non-error toasts from it
//       ids: { "<notifId>": false } // mute one specific notification
//   }
//
// Any level left undefined means "show" (opt-out), so a freshly registered
// source is on by default. A module node (parentId target) disabled mutes every
// plugin beneath it.
Singleton {
    id: root

    enum Type {
        Info,
        Success,
        Warning,
        Error
    }

    // Active toasts, oldest first. Each: {id,title,message,icon,type,timeout,sourceId,notifId}.
    // Reassigned wholesale (never mutated in place) so bindings / Repeaters refresh.
    property var toasts: []

    property int _seq: 0

    // Canonical enqueue. `o` fields:
    //   title, message                 — text (title required-ish; message may be "").
    //   icon                           — Tabler glyph codepoint; "" for none.
    //   type                           — Toaster.Info|Success|Warning|Error (default Info).
    //   timeout                        — ms until auto-dismiss (<=0 → default).
    //   sourceId, notifId              — for muting (ad-hoc toasts omit them).
    // Returns the new toast id, or -1 if suppressed.
    function push(o) {
        if (!Config.toasts.enabled)
            return -1;

        const sourceId = o.sourceId ?? "";
        const notifId = o.notifId ?? "";
        const type = o.type ?? Toaster.Info;

        if (sourceId && !root.shouldShow(sourceId, notifId, type))
            return -1;

        const t = {
            id: ++root._seq,
            title: o.title ?? "",
            message: o.message ?? "",
            icon: o.icon ?? "",
            type: type,
            timeout: (o.timeout && o.timeout > 0) ? o.timeout : Config.toasts.defaultTimeout,
            sourceId: sourceId,
            notifId: notifId
        };

        // Enforce the on-screen cap: dropping the oldest keeps every remaining
        // toast backed by a live delegate (delegates own the expiry timer), so
        // queued-but-hidden toasts can never get stuck un-expiring.
        let arr = root.toasts;
        const cap = Config.toasts.maxVisible;
        if (cap > 0)
            while (arr.length >= cap)
                arr = arr.slice(1);

        root.toasts = arr.concat(t);
        return t.id;
    }

    // Convenience for ad-hoc toasts with no registered source (only the global
    // enable gate applies). Mirrors caelestia's toast() signature.
    function toast(title, message, icon, type, timeout) {
        return root.push({
            title: title,
            message: message,
            icon: icon,
            type: type,
            timeout: timeout
        });
    }

    // Mute decision. Walks the source's ancestor chain for a disabled master
    // toggle, then applies leaf-level severity-group and per-notification mutes.
    function shouldShow(sourceId, notifId, type): bool {
        const ov = Config.toasts.overrides ?? ({});

        // Ancestor master toggles (module → plugin). Guard against cycles.
        let node = sourceId;
        const seen = ({});
        while (node && !seen[node]) {
            seen[node] = true;
            if (ov[node]?.enabled === false)
                return false;
            node = ToastRegistry.parentOf(node);
        }

        // Leaf-level: severity group + specific notification.
        const o = ov[sourceId];
        if (o) {
            const isErr = type === Toaster.Error;
            if (isErr && o.errors === false)
                return false;
            if (!isErr && o.others === false)
                return false;
            if (o.ids?.[notifId] === false)
                return false;
        }
        return true;
    }

    function dismiss(id): void {
        root.toasts = root.toasts.filter(t => t.id !== id);
    }

    function clear(): void {
        root.toasts = [];
    }

    // ── Override writers (used by the settings page) ──────────────────────
    // Reassign Config.toasts.overrides wholesale so the JsonAdapter persists it
    // (in-place mutation of a nested object does NOT fire the change signal).

    // Set a node-level flag: field ∈ {"enabled","errors","others"}.
    function setOverride(sourceId, field, value): void {
        const ov = Object.assign({}, Config.toasts.overrides ?? {});
        const sub = Object.assign({}, ov[sourceId] ?? {});
        sub[field] = value;
        ov[sourceId] = sub;
        Config.toasts.overrides = ov;
    }

    // Set a per-notification flag inside a source.
    function setNotifOverride(sourceId, notifId, value): void {
        const ov = Object.assign({}, Config.toasts.overrides ?? {});
        const sub = Object.assign({}, ov[sourceId] ?? {});
        const ids = Object.assign({}, sub.ids ?? {});
        ids[notifId] = value;
        sub.ids = ids;
        ov[sourceId] = sub;
        Config.toasts.overrides = ov;
    }

    // Read a node flag with a default of true (opt-out model).
    function flag(sourceId, field): bool {
        return (Config.toasts.overrides ?? {})[sourceId]?.[field] !== false;
    }

    // Read a per-notification flag with a default of true.
    function notifFlag(sourceId, notifId): bool {
        return (Config.toasts.overrides ?? {})[sourceId]?.ids?.[notifId] !== false;
    }
}
