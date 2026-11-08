"""Photos for cuisines, dishes and ingredients, with their credits.

Where they come from:
  - Wikidata's image (P18) for cuisines and dishes
  - Wikipedia's page image, free licenses only (pageimages, pilicense=free), for
    ingredients and for anything Wikidata has no image for
Every file's license and author come from Wikimedia Commons (imageinfo extmetadata).
Only public domain, CC0, CC BY and CC BY-SA files are kept, and none with reuse
restrictions (personality rights, trademarks). Maps, flags, logos and SVGs are skipped.

We only record where each 500 px thumbnail lives (500 is one of Wikimedia's standard
thumbnail widths); kylepace.dev fetches each one once and keeps it
(src/pages/world-cuisine/img/[...path].ts). Requests send a User-Agent with a contact URL,
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
UA = "WorldCuisine/1.0 (https://kylepace.dev/world-cuisine/) python-urllib"
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
    from_page = {}   # key -> the article its page image came from
    for i in range(0, len(tl), 50):
        d = api("https://en.wikipedia.org/w/api.php", {"action": "query", "prop": "pageimages", "piprop": "name",
                                                       "pilicense": "free", "redirects": "1", "titles": "|".join(tl[i:i + 50])})
        if not d:
            continue
        q = d.get("query", {})
        back = {}
        for n in q.get("normalized", []) + q.get("redirects", []):
            # A redirect to a section of another article (Tlingit cuisine -> Tlingit#Cuisine)
            # would hand us that article's picture, so skip it
            if n.get("tofragment"):
                continue
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
                if key not in items:
                    items[key] = name
                    from_page[key] = page["title"]
        time.sleep(0.5)
    # The same page image on several different articles is a series sidebar picture
    # ("Part of a series on American cuisine"), not a photo of the subject: drop it
    # Sidebars sit on cuisine articles; two ingredient articles sharing a plant photo
    # (basil, Genovese basil) is fine, so only cuisines, or four or more articles, count
    pages_by_file, cuisine_files = {}, set()
    for key, page in from_page.items():
        pages_by_file.setdefault(items[key], set()).add(page)
        if key.startswith("cuisine:"):
            cuisine_files.add(items[key])
    shared = {f for f, pages in pages_by_file.items()
              if len(pages) > 3 or (len(pages) > 1 and f in cuisine_files)}
    for key in [k for k in from_page if items[k] in shared]:
        del items[key]
    print(f"images: {len(items)} with Wikipedia page images "
          f"(dropped {len(shared)} sidebar pictures shared across articles: {sorted(shared)[:8]})")

    # 3. License, author and the 500 px thumbnail for every file, from Commons
    files = {}
    names = sorted(set(items.values()))
    def commons_pages(batch):
        # imageinfo with extmetadata answers only a few files per request and asks
        # to continue for the rest, so follow "continue" until the batch is done
        params = {"action": "query", "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": str(WIDTH),
                  "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist|Attribution|NonFree|Restrictions",
                  "titles": "|".join("File:" + n for n in batch)}
        got, extra = {}, {}
        for _ in range(60):
            d = api("https://commons.wikimedia.org/w/api.php", {**params, **extra})
            if not d:
                break
            for page in d.get("query", {}).get("pages", []):
                if page.get("imageinfo"):
                    got[page["title"]] = page
            if "continue" not in d:
                break
            extra = d["continue"]
            time.sleep(0.2)
        return got.values()

    STEPS = {20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840}
    dropped = {}
    samples = []
    def drop(reason, page, extra=""):
        dropped[reason] = dropped.get(reason, 0) + 1
        if len(samples) < 6 and reason not in [x[0] for x in samples]:
            samples.append((reason, page.get("title"), extra))
    for i in range(0, len(names), 50):
        for page in commons_pages(names[i:i + 50]):
            info = (page.get("imageinfo") or [None])[0]
            if not info or page.get("missing"):
                drop("no info", page)
                continue
            meta = {k: (v or {}).get("value", "") for k, v in (info.get("extmetadata") or {}).items()}
            lic = plain(meta.get("LicenseShortName"), 40)
            if not FREE.match(lic):
                drop("license", page, lic)
                continue
            if str(meta.get("NonFree", "")).lower() == "true" or plain(meta.get("Restrictions")):
                drop("restricted", page, plain(meta.get("Restrictions")))
                continue
            # Drop the tracking query Wikimedia adds; keep originals only when they're small
            thumb = (info.get("thumburl") or info.get("url") or "").split("?", 1)[0]
            m = re.match(r"https://(?:upload|thumb)\.wikimedia\.org/wikipedia/commons/(.+)$", thumb)
            if not m:
                drop("not on commons", page, thumb)
                continue
            if "/thumb/" in thumb:
                px = re.search(r"/(\d+)px-[^/]+$", thumb)
                if not px or int(px.group(1)) not in STEPS:
                    drop("odd thumb width", page, thumb[-60:])
                    continue
            elif (info.get("width") or 0) > 960:
                drop("big original", page, str(info.get("width")))
                continue
            by = plain(meta.get("Attribution")) or plain(meta.get("Artist")) or "Unknown author"
            files[page["title"][5:]] = {"p": m.group(1), "w": info.get("thumbwidth") or info.get("width"),
                                        "h": info.get("thumbheight") or info.get("height"), "by": by,
                                        "lic": lic, "licUrl": meta.get("LicenseUrl", "")}
        time.sleep(0.5)
        if i % 1000 == 0:
            print(f"  commons: {min(i + 50, len(names))} of {len(names)} files, {len(files)} free", file=sys.stderr)
    print(f"images: dropped files by reason {dropped}; examples {samples}")

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
