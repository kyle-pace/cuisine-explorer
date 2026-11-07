"""Fetch the full intro (lead section, plain text) of every cuisine's Wikipedia
article into data/summaries.json, keyed by the page title used in
cuisines.json. Follows redirects. 20 titles per request (the API's limit for
intros), paced to stay polite.

Non-fatal: if Wikipedia refuses partway, it keeps what it already has.

Usage: python3 fetch_summaries.py data/list_entries.json data/summaries.json
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

API = "https://en.wikipedia.org/w/api.php"
UA = "CuisineExplorer/0.1 (https://kylepace.net/labs)"


def main(src, dst):
    titles = sorted({e["title"] for e in json.load(open(src)) if e["title"]})
    old = json.load(open(dst)) if os.path.exists(dst) else {}
    out = {}
    try:
        for i in range(0, len(titles), 20):
            batch = titles[i:i + 20]
            q = urllib.parse.urlencode({
                "action": "query", "prop": "extracts", "exintro": "1", "explaintext": "1",
                "exlimit": "20", "redirects": "1", "titles": "|".join(batch),
                "format": "json", "formatversion": "2"})
            req = urllib.request.Request(API + "?" + q, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)["query"]
            # Map each requested title through normalization and redirects
            norm = {n["from"]: n["to"] for n in d.get("normalized", [])}
            redir = {n["from"]: n["to"] for n in d.get("redirects", [])}
            pages = {p["title"]: p.get("extract", "") for p in d.get("pages", [])}
            for t in batch:
                final = norm.get(t, t)
                final = redir.get(final, final)
                text = (pages.get(final) or "").strip()
                if text:
                    out[t] = text
            time.sleep(1)
    except Exception as e:  # noqa: BLE001
        print(f"summary fetch stopped early ({e}); keeping earlier copies for the rest")
        for t, v in old.items():
            out.setdefault(t, v)
    json.dump(dict(sorted(out.items())), open(dst, "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"{len(out)} of {len(titles)} intros")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
