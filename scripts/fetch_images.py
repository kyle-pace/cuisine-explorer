"""Photos for cuisines, dishes and ingredients, with their credits.

Where they come from:
  - Wikidata's image (P18) for cuisines and dishes
  - Wikipedia's page image, free licenses only (pageimages, pilicense=free), for
    ingredients and for anything Wikidata has no image for
Every file's license and author come from Wikimedia Commons (imageinfo extmetadata).
Only public domain, CC0, CC BY and CC BY-SA files are kept, and none with reuse
restrictions (personality rights, trademarks). Maps, flags, logos and SVGs are skipped.

We only record where each 500 px thumbnail lives (500 is one of Wikimedia's standard
thumbnail widths); kylepace.net fetches each one once and keeps it
(src/pages/labs/cuisines/img/[...path].ts). Requests send a User-Agent with a contact URL,
as Wikimedia's policy asks.

Writes data/images.json:
  {"files": {file name: {"p": path under /wikipedia/commons/, "w", "h", "by", "lic", "licUrl"}},
   "items": {"cuisine:<id>" | "dish:<id>" | "ingredient:<id>": file name}}

Usage: python3 fetch_images.py   (Wikipedia's API rate-limits some networks; runs in CI)
"""
import html
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_wikidata import run as sparql  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)
UA = "CuisineExplorer/1.0 (https://kylepace.net/labs/cuisines/) python-urllib"
WIDTH = 500
SKIP_NAME = re.compile(r"\.svg$|\bmap\b|_map[_.]|flag|locator|location|logo|coat[_ ]of[_ ]arms|emblem|seal[_ ]of|stamp", re.I)
FREE = re.compile(r"^(cc0|public domain|pd\b|pd-|cc[- ]by(-sa)?[- ]\d|cc[- ]by(-sa)?$)", re.I)


def api(base, params, tries=6):
    url = base + "?" + urllib.parse.urlencode({**params, "format": "json", "formatversion": "2"})
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:  # 429 or a hiccup: back off and try again
            wait = 5 * (i + 1)
            print(f"  retry in {wait}s ({e})", file=sys.stderr)
            time.sleep(wait)
    return None


def plain(s, limit=90):
    s = html.unescape(re.sub(r"<[^>]+>", "", s or ""))
    s = re.sub(r"\s+", " ", s).strip()
    return s if len(s) <= limit else s[:limit - 1].rsplit(" ", 1)[0] + "…"


def main():
    cuisines = json.load(open(P("data/cuisines.json")))["cuisines"]
    food = json.load(open(P("data/food.json")))
    items = {}   # key -> file name

    # 1. Wikidata images for cuisines and dishes
    by_qid = {}
    for c in cuisines:
        if c.get("qid"):
            by_qid.setdefault(c["qid"], []).append("cuisine:" + c["id"])
    for d in food["dishes"]:
        if d.get("qid"):
            by_qid.setdefault(d["qid"], []).append("dish:" + d["id"])
    qids = list(by_qid)
    for i in range(0, len(qids), 300):
        vals = " ".join("wd:" + q for q in qids[i:i + 300])
        rows = sparql(f"SELECT ?i ?img WHERE {{ VALUES ?i {{ {vals} }} ?i wdt:P18 ?img }}")
        for r in rows:
            q = r["i"]["value"].rsplit("/", 1)[1]
            name = urllib.parse.unquote(r["img"]["value"].rsplit("/", 1)[1]).replace("_", " ")
            if SKIP_NAME.search(name):
                continue
            for key in by_qid.get(q, []):
                items.setdefault(key, name)
    print(f"images: {len(items)} from Wikidata")

    # 2. Wikipedia's free page images for ingredients, and anything still missing
    titles = {}
    for c in cuisines:
        if "cuisine:" + c["id"] not in items and c.get("title"):
            titles.setdefault(c["title"], []).append("cuisine:" + c["id"])
    for d in food["dishes"]:
        t = d.get("title") or (None if d.get("note") else d["id"])
        if "dish:" + d["id"] not in items and t:
            titles.setdefault(t, []).append("dish:" + d["id"])
    for ing in food["ingredients"]:
        if ing.get("title") and ing.get("dishes", 0) > 0:
            titles.setdefault(ing["title"], []).append("ingredient:" + ing["id"])
    tl = list(titles)
    for i in range(0, len(tl), 50):
        d = api("https://en.wikipedia.org/w/api.php", {"action": "query", "prop": "pageimages", "piprop": "name",
                                                       "pilicense": "free", "redirects": "1", "titles": "|".join(tl[i:i + 50])})
        if not d:
            continue
        q = d.get("query", {})
        back = {}
        for n in q.get("normalized", []) + q.get("redirects", []):
            back[n["to"]] = back.get(n["from"], n["from"])
        for page in q.get("pages", []):
            name = page.get("pageimage")
            if not name:
                continue
            name = name.replace("_", " ")
            if SKIP_NAME.search(name):
                continue
            original = back.get(page["title"], page["title"])
            for key in titles.get(original, []) + titles.get(page["title"], []):
                items.setdefault(key, name)
        time.sleep(0.5)
    print(f"images: {len(items)} with Wikipedia page images")

    # 3. License, author and the 500 px thumbnail for every file, from Commons
    files = {}
    names = sorted(set(items.values()))
    for i in range(0, len(names), 50):
        d = api("https://commons.wikimedia.org/w/api.php", {
            "action": "query", "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": str(WIDTH),
            "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist|Attribution|NonFree|Restrictions",
            "titles": "|".join("File:" + n for n in names[i:i + 50])})
        if not d:
            continue
        for page in d.get("query", {}).get("pages", []):
            info = (page.get("imageinfo") or [None])[0]
            if not info or page.get("missing"):
                continue
            meta = {k: (v or {}).get("value", "") for k, v in (info.get("extmetadata") or {}).items()}
            lic = plain(meta.get("LicenseShortName"), 40)
            if not FREE.match(lic) or str(meta.get("NonFree", "")).lower() == "true" or plain(meta.get("Restrictions")):
                continue
            thumb = info.get("thumburl") or info.get("url") or ""
            m = re.match(r"https://upload\.wikimedia\.org/wikipedia/commons/(.+)$", thumb)
            if not m or (info.get("thumbwidth") and info["thumbwidth"] not in (WIDTH, info.get("width"))):
                continue
            by = plain(meta.get("Attribution")) or plain(meta.get("Artist")) or "Unknown author"
            files[page["title"][5:]] = {"p": m.group(1), "w": info.get("thumbwidth") or info.get("width"),
                                        "h": info.get("thumbheight") or info.get("height"), "by": by,
                                        "lic": lic, "licUrl": meta.get("LicenseUrl", "")}
        time.sleep(0.5)

    kept = {k: v for k, v in items.items() if v in files}
    json.dump({"files": files, "items": kept}, open(P("data/images.json"), "w"), ensure_ascii=False, separators=(",", ":"))
    by_type = {}
    for k in kept:
        t = k.split(":", 1)[0]
        by_type[t] = by_type.get(t, 0) + 1
    print(f"images: kept {len(kept)} ({by_type}) using {len(files)} free files; "
          f"dropped {len(items) - len(kept)} without a free license or a usable thumbnail")


if __name__ == "__main__":
    main()
