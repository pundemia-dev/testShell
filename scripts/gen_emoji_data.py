#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
#
# Regenerates the bundled emoji dataset for the emoji launcher plugin.
# Pulls the canonical Unicode `emoji-test.txt` for the ordered category groups
# and human names, then enriches each emoji with search keywords lifted from the
# dots-hyprland fuzzel-emoji list (if present locally). Emits one tab-separated
# line per base emoji:
#
#     <emoji>\t<group>\t<name>\t<keywords>
#
# Skin-tone modifier sequences are dropped (base emoji only) to keep the grid
# tidy. Run directly: `scripts/gen_emoji_data.py`.

import re
import sys
import time
import urllib.request
from pathlib import Path

EMOJI_TEST_URL = "https://unicode.org/Public/emoji/latest/emoji-test.txt"

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
OUT = REPO / "modules/launcher/plugins/emoji/emojis.txt"
# Optional English keyword source (checked out under tmp/ during development).
KEYWORDS_SRC = REPO / "tmp/dots-hyprland/dots/.config/hypr/hyprland/scripts/fuzzel-emoji.sh"

# Locales whose Unicode CLDR annotations are merged into the keyword column, so
# the picker searches in these languages. English is included for the richer
# concept words CLDR adds on top of the fuzzel list (e.g. "place of worship",
# which clusters ⛪🕌🕍). Add ISO codes here to support more languages.
CLDR_LOCALES = ["en", "ru", "de", "es", "fr"]
CLDR_URL = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/{loc}.xml"

VS16 = "️"  # emoji variation selector — normalise it away for matching


def _norm(emoji: str) -> str:
    return emoji.replace(VS16, "")


def load_keywords() -> dict[str, str]:
    """emoji char -> extra keyword string, parsed from the fuzzel-emoji list."""
    if not KEYWORDS_SRC.exists():
        print(f"note: no keyword source at {KEYWORDS_SRC}, names only", file=sys.stderr)
        return {}
    out: dict[str, str] = {}
    text = KEYWORDS_SRC.read_text(encoding="utf-8")
    _, _, data = text.partition("### DATA ###")
    for line in data.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(" ", 1)
        if len(parts) != 2:
            continue
        emoji, rest = parts
        out[_norm(emoji)] = rest.strip()
    return out


def load_cldr() -> dict[str, list[str]]:
    """normalised emoji -> list of localised keyword phrases (all CLDR locales)."""
    ann_re = re.compile(r'<annotation cp="([^"]+)"([^>]*)>([^<]*)</annotation>')
    out: dict[str, list[str]] = {}
    for i, loc in enumerate(CLDR_LOCALES):
        url = CLDR_URL.format(loc=loc)
        print(f"fetching CLDR {loc} ...", file=sys.stderr)
        xml = None
        for attempt in range(4):
            if i or attempt:
                time.sleep(1.5 * (attempt + 1))  # be gentle: raw.githubusercontent rate-limits
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "pShell-emoji-gen"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    xml = resp.read().decode("utf-8")
                break
            except Exception as e:  # noqa: BLE001 — best-effort enrichment
                print(f"  warn: {loc} attempt {attempt + 1} failed ({e})", file=sys.stderr)
        if xml is None:
            print(f"  skipping {loc}", file=sys.stderr)
            continue
        for cp, attrs, body in ann_re.findall(xml):
            key = _norm(cp)
            bucket = out.setdefault(key, [])
            # `type="tts"` bodies are the localised name (one phrase); plain
            # bodies are "kw1 | kw2 | …". Both are useful search text.
            for phrase in body.split("|"):
                phrase = phrase.strip().lower()
                if phrase and phrase not in bucket:
                    bucket.append(phrase)
    return out


def main() -> int:
    print(f"fetching {EMOJI_TEST_URL} ...", file=sys.stderr)
    with urllib.request.urlopen(EMOJI_TEST_URL, timeout=30) as resp:
        raw = resp.read().decode("utf-8")

    keywords = load_keywords()
    cldr = load_cldr()
    group = ""
    rows: list[tuple[str, str, str, str]] = []
    seen: set[str] = set()

    for line in raw.splitlines():
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            continue
        if not line or line.startswith("#"):
            continue
        # <codepoints> ; <status> # <emoji> E<ver> <name>
        head, _, comment = line.partition("#")
        if ";" not in head:
            continue
        status = head.split(";", 1)[1].strip()
        if status != "fully-qualified":
            continue
        comment = comment.strip()
        m = re.match(r"^(\S+)\s+E[\d.]+\s+(.*)$", comment)
        if not m:
            continue
        emoji, name = m.group(1), m.group(2).strip()
        # Drop skin-tone modifier sequences; keep base emoji only.
        if "skin tone" in name:
            continue
        if emoji in seen:
            continue
        seen.add(emoji)

        # Merge English fuzzel keywords (individual words) + all CLDR locale
        # phrases (kept whole), deduped case-insensitively into one search blob.
        norm = _norm(emoji)
        parts: list[str] = []
        seen_kw: set[str] = set()
        candidates = keywords.get(norm, "").split() + cldr.get(norm, [])
        for phrase in candidates:
            phrase = phrase.strip()
            low = phrase.lower()
            if phrase and low not in seen_kw:
                seen_kw.add(low)
                parts.append(phrase)
        rows.append((emoji, group, name, " ".join(parts)))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as f:
        for emoji, group, name, kw in rows:
            f.write(f"{emoji}\t{group}\t{name}\t{kw}\n")

    groups = sorted({g for _, g, _, _ in rows})
    print(f"wrote {len(rows)} emojis across {len(groups)} groups -> {OUT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
