#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
#
# Text translation backend for the pShell AI-module translator page.
# Reads ONE JSON request line from stdin (keeps text/keys out of argv and
# shared files) and prints ONE JSON result line to stdout. Stdlib only, so it
# starts instantly and needs no network deps.
#
# Request:  {"engine": "google|deepl|duckduckgo",
#            "source": "auto|<code>", "target": "<code>",
#            "text": "...", "apiKey": "..."}
# Result:   {"ok": true,  "text": "<translation>"}
#        |  {"ok": false, "error": "<message>"}
#
# Newlines inside the translation are preserved (single JSON line out), so the
# QML side can SplitParser one line and JSON.parse it losslessly.

import json
import sys
import urllib.parse
import urllib.request
import urllib.error

TIMEOUT = 20


def _get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read().decode("utf-8", "replace")


def _post(url, data, headers=None):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers=headers or {})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read().decode("utf-8", "replace")


def translate_google(text, source, target):
    # Free, key-less endpoint used by the gtx web widget. Returns a nested
    # array; the first element holds the translated sentence chunks.
    params = urllib.parse.urlencode({
        "client": "gtx",
        "sl": source or "auto",
        "tl": target,
        "dt": "t",
        "q": text,
    })
    url = "https://translate.googleapis.com/translate_a/single?" + params
    raw = _get(url, {"User-Agent": "Mozilla/5.0"})
    data = json.loads(raw)
    chunks = data[0] or []
    text = "".join(c[0] for c in chunks if c and c[0] is not None)
    # data[2] carries the detected source language code (e.g. "ru").
    detected = data[2] if len(data) > 2 and data[2] else ""
    return {"text": text, "detected": (detected or "").lower()}


def translate_deepl(text, source, target, api_key):
    if not api_key:
        raise ValueError("No DeepL API key. Add \"deepl\" to "
                         "~/.config/pShell/apikeys.json.")
    # Free keys end in ":fx" and use the api-free host.
    host = "api-free.deepl.com" if api_key.strip().endswith(":fx") else "api.deepl.com"
    fields = {
        "auth_key": api_key,
        "text": text,
        "target_lang": target.upper(),
    }
    if source and source != "auto":
        fields["source_lang"] = source.upper()
    raw = _post("https://%s/v2/translate" % host, fields)
    data = json.loads(raw)
    trs = data.get("translations", [])
    text = "\n".join(t["text"] for t in trs)
    detected = (trs[0].get("detected_source_language", "") if trs else "").lower()
    return {"text": text, "detected": detected}


def translate_duckduckgo(text, source, target):
    # Unofficial DuckDuckGo translate endpoint (best-effort; may break). Needs
    # a vqd token grabbed from the ia=web bootstrap page.
    boot = _get("https://duckduckgo.com/?q=translate&ia=web",
                {"User-Agent": "Mozilla/5.0"})
    marker = 'vqd="'
    i = boot.find(marker)
    if i < 0:
        marker = "vqd='"
        i = boot.find(marker)
    if i < 0:
        raise ValueError("DuckDuckGo unavailable (no vqd token).")
    j = boot.find(marker[-1], i + len(marker))
    vqd = boot[i + len(marker):j]
    params = {"vqd": vqd, "to": target}
    if source and source != "auto":
        params["from"] = source
    url = "https://duckduckgo.com/translation.js?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(
        url, data=text.encode(),
        headers={"User-Agent": "Mozilla/5.0", "Content-Type": "text/plain"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        data = json.loads(r.read().decode("utf-8", "replace"))
    return {"text": data.get("translated", ""),
            "detected": (data.get("detected_language", "") or "").lower()}


def main():
    try:
        req = json.loads(sys.stdin.readline() or "{}")
    except Exception as e:
        print(json.dumps({"ok": False, "error": "Bad request: %s" % e}))
        return

    engine = req.get("engine", "google")
    source = req.get("source", "auto")
    target = req.get("target", "en")
    text = req.get("text", "")
    api_key = req.get("apiKey", "")

    if not text.strip():
        print(json.dumps({"ok": True, "text": ""}))
        return

    try:
        if engine == "google":
            out = translate_google(text, source, target)
        elif engine == "deepl":
            out = translate_deepl(text, source, target, api_key)
        elif engine == "duckduckgo":
            out = translate_duckduckgo(text, source, target)
        else:
            raise ValueError("Unknown engine: %s" % engine)
        print(json.dumps({"ok": True, "text": out["text"],
                          "detected": out.get("detected", "")}))
    except urllib.error.HTTPError as e:
        print(json.dumps({"ok": False,
                          "error": "HTTP %s from %s" % (e.code, engine)}))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))


if __name__ == "__main__":
    main()
