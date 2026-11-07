"""Look up each Wikipedia page from the list on Wikidata (via SPARQL), getting
its item ID, short description, coordinates, and country ISO codes. When a
cuisine has no coordinates of its own, it borrows them from the place it is
"located in" (Sichuan cuisine -> Sichuan).

A few queries of ~150 titles each, paced to stay polite to Wikimedia.
Writes raw/wikidata.json keyed by Wikipedia title.

Usage: python3 fetch_wikidata.py data/list_entries.json raw/wikidata.json
"""
import json
import sys
import time
import urllib.parse
import urllib.request

ENDPOINT = "https://query.wikidata.org/sparql"
UA = "CuisineExplorer/0.1 (https://kylepace.net/labs)"

QUERY = """
SELECT ?article ?item ?desc ?coord ?country ?iso3 ?countryCoord ?locCoord WHERE {
  VALUES ?article { %s }
  ?article schema:about ?item ; schema:isPartOf <https://en.wikipedia.org/> .
  OPTIONAL { ?item schema:description ?desc FILTER(LANG(?desc) = "en") }
  OPTIONAL { ?item wdt:P625 ?coord }
  OPTIONAL {
    ?item wdt:P17|wdt:P495 ?country .
    OPTIONAL { ?country wdt:P298 ?iso3 }
    OPTIONAL { ?country wdt:P625 ?countryCoord }
  }
  OPTIONAL { ?item wdt:P131|wdt:P276|wdt:P706|wdt:P1001|wdt:P2341 ?loc . ?loc wdt:P625 ?locCoord }
}
"""


def article_iri(title):
    return "<https://en.wikipedia.org/wiki/" + urllib.parse.quote(
        title.replace(" ", "_"), safe="_()!*,-.:'~") + ">"


def run(query):
    body = urllib.parse.urlencode({"query": query}).encode()
    for attempt in range(5):
        req = urllib.request.Request(ENDPOINT, data=body, headers={
            "User-Agent": UA, "Accept": "application/sparql-results+json",
            "Content-Type": "application/x-www-form-urlencoded"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)["results"]["bindings"]
        except urllib.error.HTTPError as e:
            if e.code in (429, 503):
                time.sleep(15 * (attempt + 1))
                continue
            print(e.read()[:500])
            raise
    raise RuntimeError("SPARQL endpoint kept refusing")


def point(lit):
    # "Point(lon lat)"
    lon, lat = lit[6:-1].split()
    return [round(float(lat), 3), round(float(lon), 3)]


def main(src, dst):
    titles = sorted({e["title"] for e in json.load(open(src)) if e["title"]})
    iri_to_title = {article_iri(t)[1:-1]: t for t in titles}
    out = {}
    for i in range(0, len(titles), 150):
        batch = titles[i:i + 150]
        rows = run(QUERY % " ".join(article_iri(t) for t in batch))
        for r in rows:
            t = iri_to_title.get(r["article"]["value"])
            if not t:
                continue
            o = out.setdefault(t, {"qid": r["item"]["value"].rsplit("/", 1)[1],
                                   "description": None, "coord": None,
                                   "countries": {}, "locCoords": []})
            if "desc" in r:
                o["description"] = r["desc"]["value"]
            if "coord" in r:
                o["coord"] = point(r["coord"]["value"])
            if "country" in r:
                cq = r["country"]["value"].rsplit("/", 1)[1]
                c = o["countries"].setdefault(cq, {"iso3": None, "coord": None})
                if "iso3" in r:
                    c["iso3"] = r["iso3"]["value"]
                if "countryCoord" in r and not c["coord"]:
                    c["coord"] = point(r["countryCoord"]["value"])
            if "locCoord" in r:
                p = point(r["locCoord"]["value"])
                if p not in o["locCoords"]:
                    o["locCoords"].append(p)
        print(f"  {min(i + 150, len(titles))}/{len(titles)}: {len(out)} matched", flush=True)
        time.sleep(2)
    json.dump(out, open(dst, "w"), ensure_ascii=False, indent=1)
    missing = [t for t in titles if t not in out]
    print(f"matched {len(out)}/{len(titles)}; missing {len(missing)}")
    json.dump(missing, open(dst.replace(".json", "_missing.json"), "w"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
