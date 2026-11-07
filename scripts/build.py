"""Combine the parsed list, Wikidata lookups, hand overrides, and picks into
data/cuisines.json, the one file the explorer page loads.

Each cuisine gets:
  kind      national | regional | diaspora | peoples | religious | historical | style
  iso3      country it belongs to (when one is clear)
  loc       [lat, lon] if it can be placed on the globe
  parent    the cuisine it sits under on Wikipedia's list
  links     other cuisines it is connected to in a different country
            (these become the arcs on the globe)

Usage: python3 build.py
"""
import json
import os
import re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)

DIASPORA_HINT = re.compile(
    r"(American|Canadian|Caribbean|Overseas|Mexican|French|Indonesian|Thai|Burmese|"
    r"Vietnamese|Indian|Arab|Fijian|Korean|Australian|British|Peruvian|Japanese)[- ]"
    r"(Chinese|Indian|Arab|American|Mexican|Fijian|Jewish|Korean|Japanese|Italian|Thai)"
    r"|Indo[- ]|Chifa|Yoshoku|Chinese[- ](American|Canadian|Caribbean)|fusion", re.I)


def load(path, default=None):
    path = P(path)
    return json.load(open(path)) if os.path.exists(path) else default


def main():
    entries = load("data/list_entries.json")
    wd = load("raw/wikidata.json", {})
    redirects = load("raw/redirects.json", {})
    overrides = load("data/overrides.json", {}).get("coords", {})
    picks = load("data/picks.json", {}).get("cuisines", {})
    countries = load("data/countries.geojson")
    shape_iso = {f["properties"]["ADM0_A3"] for f in countries["features"]}
    shape_iso |= {f["properties"]["ISO_A3_EH"] for f in countries["features"]}

    by_key = {e["key"]: e for e in entries}

    def info(e):
        t = e["title"]
        if not t:
            return None
        return wd.get(t) or wd.get(redirects.get(t, ""))

    def real_parent(key, seen=()):
        """Walk up through plain-text group labels to the first linked cuisine."""
        e = by_key.get(key)
        if not e or key in seen:
            return None
        if not e["group"]:
            return key
        for p in e["parents"]:
            r = real_parent(p, seen + (key,))
            if r:
                return r
        return None

    out = {}
    for e in entries:
        if e["group"]:
            continue
        w = info(e) or {}
        cs = w.get("countries", {})
        isos = [c["iso3"] for c in cs.values() if c.get("iso3")]
        parents = [rp for rp in (real_parent(p) for p in e["parents"]) if rp]
        loc = overrides.get(e["key"]) or overrides.get(e["title"]) or w.get("coord")
        if not loc and w.get("locCoords"):
            loc = w["locCoords"][0]
        loc_source = "pinned" if loc else None
        region = [s for s in e["sections"][0] if s] if e["sections"] else []
        url = "https://en.wikipedia.org/wiki/" + e["title"].replace(" ", "_")
        if e["anchor"]:
            url += "#" + e["anchor"].replace(" ", "_")
        out[e["key"]] = {
            "id": e["key"],
            "name": e["label"],
            "title": e["title"],
            "url": url,
            "qid": w.get("qid"),
            "description": w.get("description"),
            "isos": isos,
            "countryLoc": next((c["coord"] for c in cs.values() if c.get("coord")), None),
            "loc": loc,
            "locSource": loc_source,
            "parents": parents,
            "region": region,
            "sections": [x for x in e["sections"] if x],
            "listKind": e["kind"],
            "also": e.get("also", []),
        }

    # Country name stems ("Chin" for China) so names can fill gaps in Wikidata
    stems = []
    for f in countries["features"]:
        name = f["properties"]["NAME"]
        if "." in name or len(name) < 4:
            continue
        stem = name[:max(4, len(name) - 1)]
        stems.append((stem, f["properties"]["ISO_A3_EH"] if
                      f["properties"]["ISO_A3_EH"] not in ("-99", None)
                      else f["properties"]["ADM0_A3"]))
    stems.sort(key=lambda s: -len(s[0]))

    def name_iso(name):
        for stem, iso in stems:
            if re.search(r"(^|[\s(-])" + re.escape(stem), name):
                return iso
        return None

    iso_overrides = load("data/overrides.json", {}).get("iso", {})
    for k, c in out.items():
        forced = iso_overrides.get(k) or iso_overrides.get(c["title"]) or iso_overrides.get(c["name"])
        if forced:
            c["isos"] = [forced]
            c["nameIso"] = c["isos"][0]
            continue
        n_iso = name_iso(c["name"])
        c["nameIso"] = n_iso
        if not n_iso or c["listKind"] != "regional" or DIASPORA_HINT.search(c["name"]):
            continue
        if not c["isos"] or len(c["isos"]) > 1 or (not c["parents"] and n_iso not in c["isos"]):
            c["isos"] = [n_iso]

    # Primary country: own single ISO, else inherit from first parent
    def primary_iso(k, depth=0):
        c = out[k]
        if len(c["isos"]) == 1:
            return c["isos"][0]
        if depth < 6:
            for p in c["parents"]:
                if p in out:
                    r = primary_iso(p, depth + 1)
                    if r:
                        return r
        return c["isos"][0] if c["isos"] else None

    for k, c in out.items():
        c["iso3"] = primary_iso(k)

    # Continent per country by majority of where its cuisines sit on the list,
    # so a cuisine first listed under another continent (German cuisine under
    # Pennsylvania Dutch) still gets its home continent's color.
    votes = defaultdict(lambda: defaultdict(int))
    for c in out.values():
        if c["iso3"] and c["region"]:
            votes[c["iso3"]][c["region"][0]] += 1
    for c in out.values():
        if not c["iso3"] or c["iso3"] not in votes:
            continue
        home = max(votes[c["iso3"]].items(), key=lambda kv: kv[1])[0]
        if c["region"] and c["region"][0] != home:
            alt = next((sec for sec in c["sections"] if sec and sec[0] == home), None)
            c["region"] = alt or [home]

    def ancestors(k, seen=None):
        seen = seen or set()
        for p in out[k]["parents"]:
            if p in out and p not in seen:
                seen.add(p)
                ancestors(p, seen)
        return seen

    # Pick the national cuisine for each country shape
    candidates = defaultdict(list)
    for k, c in out.items():
        if c["listKind"] != "regional" or not c["iso3"]:
            continue
        if any(out[a]["iso3"] == c["iso3"] for a in ancestors(k)):
            continue
        score = (c.get("nameIso") != c["iso3"], len(c["isos"]) != 1, len(c["parents"]) > 0,
                 not re.search(r"cuisine$", c["name"], re.I), len(c["name"]))
        candidates[c["iso3"]].append((score, k))
    national = {iso: sorted(v)[0][1] for iso, v in candidates.items()}
    # Hand picks win: "national": {"PNG": "Papua New Guinean cuisine"}
    for iso, key in load("data/overrides.json", {}).get("national", {}).items():
        if key in out:
            out[key]["iso3"] = iso
            national[iso] = key
    national_keys = set(national.values())

    for k, c in out.items():
        if k in national_keys:
            c["kind"] = "national"
            if not c["loc"]:
                c["loc"] = c["countryLoc"]
                c["locSource"] = "country"
        elif c["listKind"] in ("religious", "historical", "style"):
            c["kind"] = c["listKind"]
        elif DIASPORA_HINT.search(c["name"]):
            c["kind"] = "diaspora"
        elif not c["iso3"]:
            c["kind"] = "peoples"
        else:
            c["kind"] = "regional"

    # Unplaced cuisines borrow a parent's location (one hop) so they can
    # still draw an arc, but they aren't drawn as points of their own.
    for k, c in out.items():
        if not c["loc"]:
            for p in c["parents"]:
                if p in out and out[p]["loc"]:
                    c["arcFrom"] = out[p]["loc"]
                    break

    # Demonyms from national cuisine names ("Chinese" -> CHN) for diaspora names
    demonyms = {"Indo": "IND", "Chifa": "CHN"}
    for iso, k in national.items():
        m = re.match(r"^(.*?) cuisine$", out[k]["name"])
        if m and not m.group(1).startswith("Cuisine"):
            demonyms[m.group(1)] = iso
    dem_sorted = sorted(demonyms, key=len, reverse=True)
    SETTLER = {"USA", "CAN", "AUS", "NZL"}

    def diaspora_pair(c):
        """(origin_iso, host_iso) for a diaspora cuisine, from its name."""
        name, found = c["name"], []
        for d in dem_sorted:
            m = re.search(r"(^|(?<!Latin)[\s-])" + re.escape(d) + r"(?=[\s-]|$)", name)
            if m and demonyms[d] not in [f[1] for f in found]:
                found.append((m.start(), demonyms[d]))
                name = name[:m.start()] + " " * len(m.group(0)) + name[m.end():]
        found.sort()
        if len(found) >= 2:
            a, b = found[0][1], found[1][1]
            if re.match(r"Indo[- ]", c["name"]):
                return (a, b)
            if c["iso3"] and c["iso3"] not in (a, b):
                return None  # e.g. Korean-Mexican fusion, which is from L.A.
            # "Chinese American" = Chinese food in America; "Peruvian Chinese" = in Peru
            return (a, b) if b in SETTLER else (b, a)
        isos = []
        for p in c["parents"]:
            pi = out[p]["iso3"] if p in out else None
            if pi and pi not in isos:
                isos.append(pi)
        return None

    # Arcs: diaspora cuisines (origin country -> host country), and regional
    # cuisines shaped by another country's cuisine (French -> Cajun)
    nat_loc = {iso: out[k]["loc"] for iso, k in national.items() if out[k]["loc"]}
    for k, c in out.items():
        c["arc"] = None
        c["links"] = []
        if c["kind"] == "diaspora":
            pair = diaspora_pair(c)
            if pair and pair[0] in nat_loc and pair[1] in nat_loc and pair[0] != pair[1]:
                c["arc"] = {"from": pair[0], "to": pair[1]}
                c["iso3"] = pair[1]
                if c["locSource"] != "pinned":
                    c["loc"] = None  # drawn as an arc, not a point
            continue
        if c["kind"] in ("national", "religious", "historical", "style") or not c["loc"]:
            continue
        for p in c["parents"]:
            pc = out.get(p)
            if pc and pc["kind"] == "national" and pc["loc"] and pc["iso3"] != c["iso3"]:
                c["links"].append(p)

    children = defaultdict(list)
    for k, c in out.items():
        for p in c["parents"]:
            children[p].append(k)

    result = []
    for k, c in out.items():
        r = {
            "id": k, "name": c["name"], "url": c["url"], "title": c["title"],
            "kind": c["kind"], "iso3": c["iso3"], "loc": c["loc"],
            "desc": c["description"], "qid": c["qid"],
            "parents": c["parents"], "children": sorted(children.get(k, [])),
            "links": c["links"], "arc": c["arc"], "region": c["region"],
        }
        if c["locSource"] == "country":
            r["approx"] = True
        if k in picks:
            r["picks"] = picks[k]
        result.append({kk: v for kk, v in r.items() if v not in (None, [], {})})

    meta = {
        "source": "https://en.wikipedia.org/wiki/List_of_cuisines",
        "count": len(result),
        "placed": sum(1 for r in result if r.get("loc")),
        "national": len(national_keys),
        "countriesWithShape": sum(1 for iso in national if iso in shape_iso),
    }
    json.dump({"meta": meta, "cuisines": result}, open(P("data/cuisines.json"), "w"),
              ensure_ascii=False, separators=(",", ":"))
    kinds = defaultdict(int)
    for r in result:
        kinds[r["kind"]] += 1
    print(meta, dict(kinds))
    print("influence arcs:", sum(len(r.get("links", [])) for r in result),
          "diaspora arcs:", sum(1 for r in result if r.get("arc")))


if __name__ == "__main__":
    main()
