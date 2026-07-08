pragma Singleton

import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

// RSS/Atom news for the quicksettings News page. Feeds come from
// Config.quicksettings.newsFeeds; fetching/parsing is delegated to
// scripts/news_fetch.py (uv + feedparser) which emits one JSON doc. The last
// result is cached on disk so the page shows data instantly on the next
// launch, then refreshes in the background (same pattern as Weather).
Singleton {
    id: root

    // [{title, link, source, published(epoch s)}], newest first.
    property var articles: []
    property bool loading: false
    property double fetchedAt: 0

    function refresh(): void {
        if (proc.running)
            return;
        const feeds = Config.quicksettings.newsFeeds ?? [];
        if (feeds.length === 0) {
            articles = [];
            return;
        }
        loading = true;
        proc.command = [`${Quickshell.shellDir}/scripts/news_fetch.py`,
                        "--limit", String(Config.quicksettings.newsLimit)].concat(feeds);
        proc.running = true;
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (!text || !text.trim().length)
                    return;
                try {
                    const d = JSON.parse(text);
                    root.articles = d.articles ?? [];
                    root.fetchedAt = (d.fetched ?? 0) * 1000;
                    cacheFile.setText(JSON.stringify(d));
                } catch (e) {
                    console.warn("[News] parse:", e);
                }
            }
        }

        onExited: code => {
            root.loading = false;
            if (code !== 0)
                console.warn("[News] news_fetch.py exit", code);
        }
    }

    // Cached snapshot first (instant UI), then a network refresh.
    FileView {
        id: cacheFile

        path: `${Paths.cache}/news.json`
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.articles = d.articles ?? [];
                root.fetchedAt = (d.fetched ?? 0) * 1000;
            } catch (e) {
                console.warn("[News] cache parse:", e);
            }
            root.refresh();
        }
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("[News] cache load:", err);
            root.refresh();
        }
    }

    Connections {
        target: Config.quicksettings
        function onNewsFeedsChanged(): void {
            root.refresh();
        }
    }

    Timer {
        interval: Math.max(5, Config.quicksettings.newsRefreshMinutes) * 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
