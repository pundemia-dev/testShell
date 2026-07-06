pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import QtQuick
import qs.modules.launcher.content

// Notes launcher module: browse & search an Obsidian vault. The left list is
// the note list — today's daily note pinned first while the query is empty,
// then notes by recency; typing fuzzy-matches filename + frontmatter aliases,
// and a leading "/" switches to full-text (rg/grep) content search. Enter opens
// the highlighted note in Obsidian; a leading ">" captures the rest of the line
// into today's daily note without opening anything. The right panel previews
// the highlighted note (rendered markdown) — and is editable when it's the
// daily note.
LauncherModule {
    id: root

    hasLeftPanel: true
    hasRightPanel: true
    customRightWidth: 460

    property string query: ""
    property var selectedNote: null
    property var _pendingNote: null

    readonly property NotesService service: NotesService {}

    ScriptModel {
        id: internalModel
    }
    listModel: internalModel

    Timer {
        // Preview rebuild (markdown re-render + segment Repeater) is heavy, so
        // coalesce fast arrow-key navigation before committing the selection.
        id: selDebounce
        interval: 140
        onTriggered: root.selectedNote = root._pendingNote
    }

    Connections {
        target: service
        function onNotesChanged() { root.rebuild(); }
        function onSearchResultsChanged() {
            if (root.query.startsWith("/"))
                root.rebuild();
        }
    }

    function onActivated(initialQuery) {
        query = "";
        selectedNote = null;
        service.scan();
        handleInput(initialQuery ?? "");
    }

    function onDeactivated() {
        selectedNote = null;
    }

    function handleInput(q) {
        query = (q ?? "").trim();
        // Kick off full-text search up front so results are ready by rebuild.
        if (query.startsWith("/"))
            service.fullText(query.slice(1).trim());
        rebuild();
    }

    // First shot at Enter (before the host triggers the highlighted row):
    // a leading ">" is a quick-capture into today's daily note.
    function handleExecute(q, isAlt) {
        const t = (q ?? "").trim();
        if (t.startsWith(">") && service.configured) {
            const line = t.slice(1).trim();
            if (line.length) {
                service.appendToDaily(line);
                requestSetInput("");
                query = "";
                requestClose(true);
            }
            return true;
        }
        return false;
    }

    function _fuzzy(q) {
        const terms = q.toLowerCase().split(/\s+/).filter(s => s.length);
        return service.notes.filter(n => terms.every(t => n.search.indexOf(t) >= 0));
    }

    function rebuild() {
        if (!service.configured) {
            internalModel.values = [root._hintCard()];
            selectedNote = null;
            hasRightPanel = false;
            return;
        }

        const q = query;
        let notes;

        if (q.startsWith(">")) {
            // Capture mode: preview today's daily note, list stays on recents.
            notes = _pinnedDefault();
        } else if (q.startsWith("/")) {
            notes = service.searchResults.map(r => ({
                path: r.path, relPath: r.relPath, name: r.name,
                dir: r.relPath.indexOf("/") >= 0 ? r.relPath.slice(0, r.relPath.lastIndexOf("/")) : "",
                isDaily: r.relPath === service.dailyRelPath(),
                snippet: r.snippet
            }));
        } else if (q.length) {
            notes = _fuzzy(q).map(n => root._toEntry(n));
        } else {
            notes = _pinnedDefault();
        }

        internalModel.values = notes.map(n => root._toCard(n));

        if (notes.length > 0) {
            selectedNote = notes[0];
            hasRightPanel = true;
        } else {
            selectedNote = null;
            hasRightPanel = false;
        }
    }

    // Empty-query view: today's daily note first, then the rest by recency.
    function _pinnedDefault() {
        const dailyRel = service.dailyRelPath();
        const rest = service.notes.filter(n => n.relPath !== dailyRel).map(n => root._toEntry(n));
        const existing = service.notes.find(n => n.relPath === dailyRel);
        const daily = existing
            ? root._toEntry(existing, true)
            : {
                path: service.dailyAbsPath(), relPath: dailyRel, name: service.dailyName(),
                dir: service.dailyFolder, aliases: [], isDaily: true, isVirtual: true
            };
        return [daily, ...rest];
    }

    function _toEntry(n, forceDaily) {
        const isDaily = forceDaily || n.relPath === service.dailyRelPath();
        return {
            path: n.path, relPath: n.relPath, name: n.name, dir: n.dir,
            aliases: n.aliases ?? [], isDaily
        };
    }

    function _toCard(n) {
        const base = {
            _note: n,
            onClicked: function () {
                service.openInObsidian(n.relPath);
                root.requestClose(true);
            },
            onSelected: function () {
                root._pendingNote = n;
                selDebounce.restart();
            }
        };

        if (n.isDaily)
            return Object.assign(base, {
                leftIcon: "", // tabler calendar-event
                header: n.name,
                text: n.isVirtual ? "Today · daily note (new)" : "Today · daily note",
                rightText: "edit"
            });

        if (n.snippet !== undefined)
            return Object.assign(base, {
                leftIcon: "", // tabler file-search
                header: n.name,
                text: n.snippet
            });

        const sub = (n.aliases && n.aliases.length)
            ? n.aliases.join(", ")
            : (n.dir || "vault root");
        return Object.assign(base, {
            leftIcon: "", // tabler file-text
            header: n.name,
            text: sub
        });
    }

    function _hintCard() {
        return {
            leftIcon: "", // tabler notes
            header: "Set your Obsidian vault path",
            text: "Settings → Notes: vaultPath (and daily-note format / template)",
            onClicked: function () {},
            onSelected: function () {}
        };
    }

    rightPanelComponent: Component {
        NotePreviewPanel {
            mod: root
            svc: root.service
        }
    }
}
