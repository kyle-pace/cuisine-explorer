"""Fill in ingredients from each dish's Wikipedia infobox ("Main ingredients"),
since Wikidata lists ingredients for well under half of the dishes.

Reads dish titles from data/food.json, reads the top of each article's wikitext
(50 per request), keeps the linked names in the infobox's main_ingredient field,
and writes data/infobox_ingredients.json: {dish title: [ingredient article title]}.
fetch_dishes.py merges these in. Non-fatal: on refusal it keeps the last copy.

Usage: python3 fetch_infobox_ingredients.py
"""
import json
import os
import re
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://en.wikipedia.org/w/api.php"
UA = "CuisineExplorer/0.1 (https://kylepace.net/labs)"
FIELD = re.compile(r"\|\s*main[_ ]ingredients?\s*=(.*?)(?=\n\s*\||\n\}\})", re.S | re.I)
LINK = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]")


def main():
    out_path = os.path.join(ROOT, "data/infobox_ingredients.json")
    old = json.load(open(out_path)) if os.path.exists(out_path) else {}
    titles = [d["id"] for d in json.load(open(os.path.join(ROOT, "data/food.json")))["dishes"]]
    out = {}
    try:
        for i in range(0, len(titles), 50):
            batch = titles[i:i + 50]
            q = urllib.parse.urlencode({
                "action": "query", "prop": "revisions", "rvprop": "content", "rvslots": "main",
                "rvsection": "0", "redirects": "1", "titles": "|".join(batch),
                "format": "json", "formatversion": "2"})
            req = urllib.request.Request(API + "?" + q, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)["query"]
            norm = {n["from"]: n["to"] for n in d.get("normalized", [])}
            redir = {n["from"]: n["to"] for n in d.get("redirects", [])}
            pages = {}
            for p in d.get("pages", []):
                revs = p.get("revisions") or []
                if revs:
                    pages[p["title"]] = revs[0]["slots"]["main"]["content"]
            for t in batch:
                final = redir.get(norm.get(t, t), norm.get(t, t))
                text = pages.get(final, "")
                m = FIELD.search(text)
                if m:
                    links = [l.strip() for l in LINK.findall(m.group(1))]
                    links = [l[:1].upper() + l[1:] for l in links if l and ":" not in l]
                    if links:
                        out[t] = links
            time.sleep(1)
    except Exception as e:  # noqa: BLE001
        print(f"infobox fetch stopped early ({e}); keeping earlier copies for the rest")
        for k, v in old.items():
            out.setdefault(k, v)
    json.dump(dict(sorted(out.items())), open(out_path, "w"), ensure_ascii=False, indent=0)
    print(f"{len(out)} of {len(titles)} dishes have infobox ingredients")


if __name__ == "__main__":
    main()
