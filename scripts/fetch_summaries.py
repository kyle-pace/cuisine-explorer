"""Fetch Wikipedia's page summary for every page on the list: canonical title
(follows redirects), Wikidata ID, coordinates, and the short intro text.

On the live site the explorer fetches these at view time so Wikipedia stays
the source of truth. This snapshot is for the offline preview and as a
fallback. Cached, so reruns only fetch what's new.

Usage: python3 fetch_summaries.py data/list_entries.json raw/summaries.json
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

UA = "CuisineExplorer/0.1 (https://kylepace.net/labs)"
BASE = "https://en.wikipedia.org/api/rest_v1/page/summary/"


def fetch(title):
    url = BASE + urllib.parse.quote(title.replace(" ", "_"), safe="")
    for attempt in range(6):
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code == 429:
                time.sleep(8 * (attempt + 1))
                continue
            raise
    raise RuntimeError("rate limited")


def main(src, dst):
    titles = sorted({e["title"] for e in json.load(open(src)) if e["title"]})
    cache = json.load(open(dst)) if os.path.exists(dst) else {}
    todo = [t for t in titles if t not in cache]
    print(f"{len(todo)} to fetch", flush=True)
    for n, t in enumerate(todo, 1):
        d = fetch(t)
        if d:
            cache[t] = {
                "canonical": d.get("titles", {}).get("canonical", "").replace("_", " "),
                "display": d.get("title"),
                "qid": d.get("wikibase_item"),
                "description": d.get("description"),
                "coord": [d["coordinates"]["lat"], d["coordinates"]["lon"]]
                if d.get("coordinates") else None,
                "extract": d.get("extract"),
                "url": d.get("content_urls", {}).get("desktop", {}).get("page"),
            }
        else:
            cache[t] = None
        if n % 50 == 0:
            json.dump(cache, open(dst, "w"), ensure_ascii=False)
            print(f"  {n}/{len(todo)}", flush=True)
        time.sleep(0.25)
    json.dump(cache, open(dst, "w"), ensure_ascii=False)
    print("done", sum(1 for v in cache.values() if v), "summaries")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
