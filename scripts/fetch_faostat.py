"""Where ingredients are grown: FAOSTAT crop and livestock production by country.

Downloads FAOSTAT's bulk Production_Crops_Livestock file (FAO, CC BY 4.0),
averages the latest five years of production for the items in
data/fao_items.json, and ties them to ingredients in data/food.json by name.

Writes data/grown.json:
  {"meta": {...}, "items": {ingredient id: {"fao": item, "unit": "t",
    "world": tonnes, "top": [[iso3, tonnes], ...]}}}

Usage: python3 fetch_faostat.py
"""
import csv
import io
import json
import os
import re
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)
URL = "https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_All_Data.zip"
CSV = "Production_Crops_Livestock_E_All_Data_NOFLAG.csv"
TOP = 40


def norm(s):
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()


def main():
    os.makedirs(P("raw"), exist_ok=True)
    zpath = P("raw", "faostat_qcl.zip")
    if not os.path.exists(zpath):
        req = urllib.request.Request(URL, headers={"User-Agent": "CuisineExplorer/0.1 (https://kylepace.net/labs)"})
        with urllib.request.urlopen(req, timeout=600) as r, open(zpath, "wb") as f:
            f.write(r.read())

    m49 = json.load(open(P("data/m49_iso3.json")))
    wanted = json.load(open(P("data/fao_items.json")))["items"]
    # The bulk file writes "Almonds, in shell" where the item list says "Almonds; in shell"
    item_key = {norm(k): k for k in wanted}
    food = json.load(open(P("data/food.json")))
    by_name = {}
    for i in food["ingredients"]:
        for n in (i["id"], i["name"], i.get("title") or ""):
            if n:
                by_name.setdefault(norm(n), i["id"])

    prod = {}   # item -> {iso3: tonnes}
    years = None
    with zipfile.ZipFile(zpath) as z, z.open(CSV) as fh:
        rows = csv.DictReader(io.TextIOWrapper(fh, encoding="latin-1"))
        ycols = sorted(c for c in rows.fieldnames if re.fullmatch(r"Y\d{4}", c))
        years = ycols[-5:]
        for r in rows:
            item = item_key.get(norm(r["Item"]))
            if not item or r["Element"] != "Production" or r["Unit"] != "t":
                continue
            iso = m49.get(r["Area Code (M49)"].strip("'"))
            if not iso:
                continue
            vals = [float(r[y]) for y in years if r[y] not in ("", None)]
            if vals and sum(vals) > 0:
                prod.setdefault(item, {})[iso] = sum(vals) / len(vals)

    out, unmatched = {}, []
    for item, names in wanted.items():
        if item not in prod:
            unmatched.append(item + " (no data)")
            continue
        top = sorted(prod[item].items(), key=lambda kv: -kv[1])
        entry = {"fao": item, "world": round(sum(prod[item].values())),
                 "top": [[iso, round(t)] for iso, t in top[:TOP] if t >= 1]}
        hits = {by_name[norm(n)] for n in names if norm(n) in by_name}
        if not hits:
            unmatched.append(item)
        for iid in hits:
            # One ingredient can match two items (lamb and mutton): keep the bigger
            if iid not in out or out[iid]["world"] < entry["world"]:
                out[iid] = entry
    meta = {"source": "FAO, FAOSTAT: Crops and livestock products", "url": "https://www.fao.org/faostat/en/#data/QCL",
            "license": "CC BY 4.0", "years": f"{years[0][1:]} to {years[-1][1:]}", "unit": "tonnes a year, averaged"}
    json.dump({"meta": meta, "items": out}, open(P("data/grown.json"), "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"grown: {len(out)} ingredients from {len(wanted) - len(unmatched)} FAOSTAT items, {meta['years']}")
    if unmatched:
        print("FAOSTAT items with no matching ingredient:", ", ".join(unmatched))


if __name__ == "__main__":
    main()
