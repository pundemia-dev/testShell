#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["feedparser"]
# ///
"""Fetch RSS/Atom feeds in parallel and emit one JSON document on stdout.

Usage: news_fetch.py [--limit N] <feed-url> [<feed-url> ...]

Output: {"articles": [{"title", "link", "source", "published"}, ...]}
sorted newest-first, `published` = unix epoch seconds (0 if the feed
didn't provide a date).
"""

import json
import socket
import sys
import time
from calendar import timegm
from concurrent.futures import ThreadPoolExecutor

import feedparser

socket.setdefaulttimeout(10)


def fetch(url: str) -> list[dict]:
    try:
        feed = feedparser.parse(url, agent="pShell-news/1.0")
    except Exception as e:
        print(f"news_fetch: {url}: {e}", file=sys.stderr)
        return []
    source = feed.feed.get("title", "") or url
    out = []
    for e in feed.entries:
        ts = e.get("published_parsed") or e.get("updated_parsed")
        out.append({
            "title": (e.get("title") or "").strip(),
            "link": e.get("link") or "",
            "source": source,
            "published": timegm(ts) if ts else 0,
        })
    return out


def main() -> None:
    args = sys.argv[1:]
    limit = 40
    if args and args[0] == "--limit":
        limit = int(args[1])
        args = args[2:]
    if not args:
        print(json.dumps({"articles": []}))
        return

    with ThreadPoolExecutor(max_workers=min(8, len(args))) as pool:
        results = pool.map(fetch, args)

    articles = [a for feed in results for a in feed if a["title"] and a["link"]]
    articles.sort(key=lambda a: a["published"], reverse=True)
    print(json.dumps({"articles": articles[:limit], "fetched": int(time.time())}))


if __name__ == "__main__":
    main()
