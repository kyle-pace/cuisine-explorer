"""Find where list links that are redirects actually point (e.g. "Tex-Mex
cuisine" -> "Tex-Mex"), so Wikidata can match them. Uses the MediaWiki API,
50 titles per request. Non-fatal: if Wikipedia refuses (rate limits), it
keeps whatever was already in raw/redirects.json and the build carries on.

Usage: python3 resolve_redirects.py data/list_entries.json raw/redirects.json
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
    known = json.load(open(dst)) if os.path.exists(dst) else {}
    try:
        for i in range(0, len(titles), 50):
            batch = titles[i:i + 50]
            q = urllib.parse.urlencode({"action": "query", "titles": "|".join(batch),
                                        "redirects": "1", "format": "json", "formatversion": "2"})
            req = urllib.request.Request(API + "?" + q, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)["query"]
            norm = {n["from"]: n["to"] for n in d.get("normalized", [])}
            redir = {n["from"]: n["to"] for n in d.get("redirects", [])}
            for t in batch:
                t2 = norm.get(t, t)
                if t2 in redir:
                    known[t] = redir[t2]
            time.sleep(1)
    except Exception as e:  # noqa: BLE001
        print(f"redirect lookup stopped early ({e}); using {len(known)} known redirects")
    json.dump(known, open(dst, "w"), ensure_ascii=False, indent=1)
    print(f"{len(known)} redirects")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
