"""Give regional cuisines a shape on the map: the provinces or states they come
from, as a middle ground between "no borders" and a single dot.

For each regional cuisine we collect Wikidata IDs for the cuisine itself and
the places it's "located in" (P131, P276, P706, P1001, P2341), then match those
against Natural Earth's 1:10m states and provinces, which carry Wikidata IDs.
Names are a fallback ("Sichuan cuisine" -> Sichuan, "Cuisine of Veracruz" ->
Veracruz), only within the cuisine's own country. Several matches are merged
(Midwestern American cuisine -> twelve states).

Writes data/regions.geojson: one feature per cuisine, property `id`.

Usage: python3 build_regions.py
"""
import json
import os
import re
import subprocess
import sys
import unicodedata
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
from fetch_wikidata import run  # noqa: E402

NE_URL = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/"
          "geojson/ne_10m_admin_1_states_provinces.geojson")
MAX_PARTS = 24  # more than this and it's not really "a region"
LANGS = "en it es fr de pt ca el nl pl ru".split()


def norm(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z]+", " ", s).strip()


def stem(name):
    """'Cuisine of Veracruz' -> 'veracruz', 'Sichuan cuisine' -> 'sichuan'."""
    n = re.sub(r"(?i)^cuisine of (the )?|\s+(cuisine|food|cooking|diet)$", "", name)
    n = re.sub(r"\s*\(.*?\)", "", n)
    return norm(n)


def main():
    P = lambda *a: os.path.join(ROOT, *a)
    cuisines = json.load(open(P("data/cuisines.json")))["cuisines"]
    ne_path = P("raw/ne_10m_admin1.geojson")
    if not os.path.exists(ne_path):
        os.makedirs(P("raw"), exist_ok=True)
        urllib.request.urlretrieve(NE_URL, ne_path)
    provinces = json.load(open(ne_path))["features"]

    hand_ids = set(json.load(open(P("data/overrides.json"))).get("regions", {}))
    targets = [c for c in cuisines if (c["kind"] in ("regional", "peoples") and c.get("qid"))
               or c["id"] in hand_ids or c["name"] in hand_ids]
    # Location IDs for each target cuisine, from Wikidata
    locs = {c["qid"]: {c["qid"]} for c in targets if c.get("qid")}
    qids = sorted(locs)
    for i in range(0, len(qids), 200):
        # The place, and if the place is made of parts (the Midwest, Punjab), the parts
        rows = run("""SELECT ?item ?loc ?part WHERE {
          VALUES ?item { %s }
          ?item wdt:P131|wdt:P276|wdt:P706|wdt:P1001|wdt:P2341 ?loc .
          OPTIONAL { ?loc wdt:P150|wdt:P527 ?part } }""" %
                   " ".join("wd:" + q for q in qids[i:i + 200]))
        for r in rows:
            item = r["item"]["value"].rsplit("/", 1)[1]
            locs[item].add(r["loc"]["value"].rsplit("/", 1)[1])
            if "part" in r:
                locs[item].add(r["part"]["value"].rsplit("/", 1)[1])
    # Names of those places in a few languages, to match regions that Natural Earth
    # only records by name (Italian and Spanish provinces carry their region's name)
    labels = {}
    all_locs = sorted({q for v in locs.values() for q in v})
    for i in range(0, len(all_locs), 300):
        rows = run("""SELECT ?loc ?label WHERE {
          VALUES ?loc { %s }
          ?loc rdfs:label ?label . FILTER(LANG(?label) IN (%s)) }""" %
                   (" ".join("wd:" + q for q in all_locs[i:i + 300]), ",".join(f'"{l}"' for l in LANGS)))
        for r in rows:
            labels.setdefault(r["loc"]["value"].rsplit("/", 1)[1], set()).add(norm(r["label"]["value"]))

    by_qid = {}
    by_name = {}
    by_region = {}
    for f in provinces:
        p = f["properties"]
        if p.get("wikidataid"):
            by_qid.setdefault(p["wikidataid"], []).append(f)
        for n in (p.get("name"), p.get("name_en"), p.get("gn_name"), p.get("woe_name")):
            if n:
                by_name.setdefault((p["adm0_a3"], norm(n)), []).append(f)
        if p.get("region"):
            by_region.setdefault((p["adm0_a3"], norm(p["region"])), []).append(f)
        for alt in (p.get("name_alt") or "").split("|"):
            if alt:
                by_name.setdefault((p["adm0_a3"], norm(alt)), []).append(f)

    hand = json.load(open(P("data/overrides.json"))).get("regions", {})
    unmatched = []

    def lookup(spec):
        iso, name = spec.split(":", 1)
        n = norm(name)
        return by_name.get((iso, n), []) or by_region.get((iso, n), [])

    out, report, matched = [], {}, {}
    for c in targets:
        specs = hand[c["id"]] if c["id"] in hand else hand.get(c["name"])
        if specs is not None:
            hits = {}
            for spec in specs:
                found = lookup(spec)
                if not found:
                    unmatched.append(f"{c['name']}: {spec}")
                for f in found:
                    hits[id(f)] = f
            if hits:
                matched[c["id"]] = hits
            continue
        if not c.get("qid"):
            continue
        hits = {id(f): f for q in locs[c["qid"]] for f in by_qid.get(q, [])}
        if not hits and c.get("iso3"):
            for q in locs[c["qid"]]:
                for lab in labels.get(q, ()):
                    for f in by_region.get((c["iso3"], lab), []) + by_name.get((c["iso3"], lab), []):
                        hits[id(f)] = f
        if not hits and c.get("iso3"):
            s = stem(c["name"])
            for f in by_name.get((c["iso3"], s), []) + by_name.get((c["iso3"], s.rstrip("n")), []):
                hits[id(f)] = f
        if not hits or len(hits) > MAX_PARTS:
            continue
        matched[c["id"]] = hits

    # Cuisines from exactly the same provinces share one shape (Fuzhou, Minnan, Putian: Fujian)
    groups = {}
    for cid, hits in matched.items():
        key = tuple(sorted(id(f) for f in hits.values()))
        groups.setdefault(key, {"ids": [], "hits": hits})["ids"].append(cid)
        report[cid] = sorted(f["properties"]["name"] for f in hits.values())
    for grp in groups.values():
        polys = []
        for f in grp["hits"].values():
            g = f["geometry"]
            polys += [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        out.append({"type": "Feature", "properties": {"key": "|".join(grp["ids"])},
                    "geometry": {"type": "MultiPolygon", "coordinates": polys}})

    tmp = P("raw/_regions_full.geojson")
    json.dump({"type": "FeatureCollection", "features": out}, open(tmp, "w"))
    # Simplify (no dissolve: overlapping regions would lose their shared area), and flip rings to
    # the clockwise winding globe.gl expects
    subprocess.run(["npx", "-y", "mapshaper@0.6", tmp, "-simplify", "8%",
                    "keep-shapes", "-o", P("raw/_regions_simple.geojson"), "precision=0.01",
                    "format=geojson"], check=True)
    g = json.load(open(P("raw/_regions_simple.geojson")))
    g["features"] = [f for f in g["features"] if f.get("geometry")]
    for f in g["features"]:
        f["properties"] = {"ids": f["properties"]["key"].split("|")}

    def area(r):
        return sum(r[i][0] * r[i + 1][1] - r[i + 1][0] * r[i][1] for i in range(len(r) - 1))
    for f in g["features"]:
        geom = f["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for poly in polys:
            for i, ring in enumerate(poly):
                if (area(ring) > 0) == (i == 0):
                    ring.reverse()
    json.dump(g, open(P("data/regions.geojson"), "w"), separators=(",", ":"))
    json.dump(report, open(P("raw/regions_report.json"), "w"), indent=1, ensure_ascii=False)
    for u in unmatched:
        print("  no province named", u)
    print(f"{len(report)} of {len(targets)} regional cuisines have a shape ({len(g['features'])} shapes), "
          f"{os.path.getsize(P('data/regions.geojson')) // 1024} KB")


if __name__ == "__main__":
    main()
