"""Short Wikipedia intros (first paragraph) for every dish and ingredient, into
data/food_summaries.json keyed by article title. The explorer shows these on
dish and ingredient cards, and fetches live from Wikipedia when one is missing.
20 titles per request, follows redirects, non-fatal on refusal.

Usage: python3 fetch_food_summaries.py
"""
import json
import os
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://en.wikipedia.org/w/api.php"
UA = "CuisineExplorer/0.1 (https://kylepace.net/labs)"


def main():
    out_path = os.path.join(ROOT, "data/food_summaries.json")
    old = json.load(open(out_path)) if os.path.exists(out_path) else {}
    food = json.load(open(os.path.join(ROOT, "data/food.json")))
    titles = sorted({d["id"] for d in food["dishes"]} | {i["title"] for i in food["ingredients"]})
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
            norm = {n["from"]: n["to"] for n in d.get("normalized", [])}
            redir = {n["from"]: n["to"] for n in d.get("redirects", [])}
            pages = {p["title"]: p.get("extract", "") for p in d.get("pages", [])}
            for t in batch:
                final = redir.get(norm.get(t, t), norm.get(t, t))
                text = (pages.get(final) or "").strip()
                if text:
                    first = next((p for p in text.split("\n") if p.strip()), "")
                    out[t] = first[:900]
            time.sleep(0.6)
    except Exception as e:  # noqa: BLE001
        print(f"food summary fetch stopped early ({e}); keeping earlier copies for the rest")
        for k, v in old.items():
            out.setdefault(k, v)
    json.dump(dict(sorted(out.items())), open(out_path, "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"{len(out)} of {len(titles)} dish and ingredient intros")


if __name__ == "__main__":
    main()
