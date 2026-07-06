pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import QtQuick
import qs.modules.launcher.content

// Emoji picker launcher module. Unlike the list-based plugins this one is
// panel-only (no left list): the whole picker — category tabs + searchable
// grid + preview footer — lives in the right panel (EmojiPanel). The RowInput
// text filters; Up/Down/Left/Right walk the grid selection linearly (the host
// contract folds all four arrows into navigateUp/navigateDown, so navigation
// is ±1 through the filtered set); Enter copies the selected emoji.
LauncherModule {
    id: root

    hasLeftPanel: false
    hasRightPanel: true

    // Panel-only: give the right panel the whole width.
    customTotalWidth: 620
    customRightWidth: 620
    customRightHeight: 468

    readonly property bool autoPaste: Config.getCustom("emoji", "autoPaste", false) ?? false
    readonly property string pasteCommand: Config.getCustom("emoji", "pasteCommand", "wtype -M ctrl v -m ctrl") ?? "wtype -M ctrl v -m ctrl"

    property string query: ""
    property string activeGroup: ""
    property var filtered: []
    property int selectedIndex: 0

    readonly property EmojiStore store: EmojiStore {}

    // The dataset loads async — if activation raced ahead of it, settle on the
    // default category and rebuild once it lands.
    property bool _dataReady: store.loaded
    on_DataReadyChanged: {
        if (!_dataReady)
            return;
        if (!activeGroup)
            activeGroup = _defaultGroup();
        rebuild();
    }

    function _defaultGroup() {
        if (store.recents.length > 0)
            return store.recentGroup;
        return store.groups.length > 0 ? store.groups[0] : "";
    }

    function onActivated(initialQuery) {
        query = (initialQuery ?? "").trim();
        activeGroup = _defaultGroup();
        rebuild();
    }

    function handleInput(q) {
        query = (q ?? "").trim();
        rebuild();
    }

    // Ordered tab ids: recents (when present) + categories — mirrors the tab
    // bar in EmojiPanel.
    function _tabIds() {
        const ids = [];
        if (store.recents.length > 0)
            ids.push(store.recentGroup);
        for (let i = 0; i < store.groups.length; i++)
            ids.push(store.groups[i]);
        return ids;
    }

    // Tab / Shift+Tab — cycle the active category (wraps). Routed from RowInput
    // via the host's onTab hook.
    function onTab(backwards) {
        const ids = _tabIds();
        if (ids.length === 0)
            return;
        let i = ids.indexOf(activeGroup);
        if (i < 0)
            i = 0;
        else
            i = (i + (backwards ? -1 : 1) + ids.length) % ids.length;
        setGroup(ids[i]);
    }

    // Called by the tab bar. Clears any active search (via the input) so the
    // chosen category actually shows.
    function setGroup(g) {
        activeGroup = g;
        if (query.length > 0) {
            query = "";
            requestSetInput("");
        }
        rebuild();
    }

    function rebuild() {
        filtered = store.filter(query, activeGroup);
        selectedIndex = filtered.length > 0 ? 0 : -1;
    }

    function navigateUp() {
        if (filtered.length === 0)
            return;
        selectedIndex = Math.max(0, selectedIndex - 1);
    }

    function navigateDown() {
        if (filtered.length === 0)
            return;
        selectedIndex = Math.min(filtered.length - 1, selectedIndex + 1);
    }

    // No left list → the host calls execute() directly on Enter.
    function execute(q, isAlt) {
        if (selectedIndex < 0 || selectedIndex >= filtered.length)
            return;
        copyEmoji(filtered[selectedIndex].emoji, !isAlt && root.autoPaste);
    }

    function copyEmoji(emoji, paste) {
        const q = "'" + String(emoji).replace(/'/g, "'\\''") + "'";
        let cmd = `printf %s ${q} | wl-copy`;
        if (paste)
            cmd += `; sleep 0.06; ${root.pasteCommand}`;
        Quickshell.execDetached(["bash", "-c", cmd]);
        store.pushRecent(emoji);
        root.requestClose(true);
    }

    rightPanelComponent: Component {
        EmojiPanel {
            mod: root
            store: root.store
        }
    }
}
