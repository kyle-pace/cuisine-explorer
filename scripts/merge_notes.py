"""Merge hand-written notes from content/ into the generated data.

Notes are Markdown files with YAML frontmatter and [[wikilinks]], the same
format Obsidian uses, so the content/ folder can be opened as a vault. They fill
gaps Wikipedia leaves, starting with Indigenous foodways.

  content/cuisines/*.md     type: cuisine
  content/dishes/*.md       type: dish
  content/ingredients/*.md  type: ingredient

A note with `wikipedia: <list entry or article title>` adds to that existing
entry (fixes its place, adds text and links). A note without one is a new entry
written for this site. Links resolve by name, id or alias, across all three types.

Writes:
  data/cuisines.json  existing entries patched, new ones added (note: true)
  data/food.json      dishes and ingredients added or linked
  data/notes.json     our own text, sources and suggested sites and cookbooks

Safe to run more than once. Usage: python3 merge_notes.py
"""
import glob
import json
import os
import re
import sys
import unicodedata

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)
LINK = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?\]\]")


def norm(s):
    s = unicodedata.normalize("NFD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def read_note(path):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    if not m:
        sys.exit(f"{path}: missing frontmatter")
    meta = yaml.safe_load(m.group(1)) or {}
    meta["_body"] = m.group(2).strip()
    meta["_file"] = os.path.relpath(path, ROOT)
    for key in ("name", "type"):
        if not meta.get(key):
            sys.exit(f"{path}: needs a `{key}`")
    return meta


def link_target(value):
    """'[[Seal oil|oil]]' -> 'Seal oil'; plain strings pass through."""
    m = LINK.search(str(value))
    return m.group(1).strip() if m else str(value).strip()


def body_text(body):
    """Body Markdown to plain paragraphs, keeping links as {kind, id, text} spans."""
    return [p.strip() for p in re.split(r"\n\s*\n", body) if p.strip() and not p.lstrip().startswith("#")]


def main():
    notes = [read_note(f) for f in sorted(glob.glob(P("content", "*", "*.md")))]
    data = json.load(open(P("data/cuisines.json")))
    food = json.load(open(P("data/food.json")))
    old_note_ids = {c["id"] for c in data["cuisines"] if c.get("note")}
    cuisines = [c for c in data["cuisines"] if not c.get("note")]
    for c in cuisines:
        c.pop("noted", None)
    by_id = {c["id"]: c for c in cuisines}
    dishes = [d for d in food["dishes"] if not d.get("note")]
    ings = [i for i in food["ingredients"] if not i.get("note")]
    for d in dishes:
        d["cuisines"] = [x for x in d["cuisines"] if x not in old_note_ids]
    dish_by_id = {d["id"]: d for d in dishes}
    ing_by_id = {i["id"]: i for i in ings}

    # Resolve every note to an id first, so links between notes work in any order
    index = {"cuisine": {}, "dish": {}, "ingredient": {}}

    def add_names(kind, ident, *names):
        for n in names:
            if n:
                index[kind].setdefault(norm(n), ident)

    for c in cuisines:
        add_names("cuisine", c["id"], c["id"], c["name"], c.get("title"))
    for d in dishes:
        add_names("dish", d["id"], d["id"], d["name"])
    for i in ings:
        add_names("ingredient", i["id"], i["id"], i["name"], i.get("title"))

    for n in notes:
        kind = n["type"]
        if kind not in index:
            sys.exit(f"{n['_file']}: type must be cuisine, dish or ingredient")
        wiki = n.get("wikipedia")
        ident = None
        if wiki:
            ident = index[kind].get(norm(wiki))
            if not ident and kind == "cuisine":
                sys.exit(f"{n['_file']}: no cuisine on the list called {wiki!r}")
            ident = ident or wiki
        n["_id"] = ident or n["name"]
        n["_new"] = not (ident and (ident in by_id or ident in dish_by_id or ident in ing_by_id))
        # A note's own names win over generated ones
        for name in [n["name"], n["_id"], wiki] + list(n.get("aliases") or []):
            if name:
                index[kind][norm(name)] = n["_id"]

    missing = []

    def resolve(value, kinds, where):
        target = link_target(value)
        for k in kinds:
            hit = index[k].get(norm(target))
            if hit:
                return k, hit
        missing.append(f"{where}: [[{target}]]")
        return None, None

    out_notes = {"cuisines": {}, "dishes": {}, "ingredients": {}}

    def store(n, bucket):
        paras = body_text(n["_body"])
        links = []
        for p in paras:
            for m in LINK.finditer(p):
                k, ident = resolve(m.group(1), ("cuisine", "dish", "ingredient"), n["_file"])
                if ident:
                    links.append({"text": m.group(1).strip(), "kind": k, "id": ident})
        entry = {"file": n["_file"], "text": paras, "links": links}
        if n.get("sources"):
            entry["sources"] = n["sources"]
        if n.get("area"):
            entry["area"] = n["area"]
        if n.get("names"):
            entry["names"] = n["names"]
        sug = n.get("suggested") or {}
        if sug.get("sites"):
            entry["sites"] = sug["sites"]
        if sug.get("cookbooks"):
            entry["cookbooks"] = sug["cookbooks"]
        out_notes[bucket][n["_id"]] = entry

    # Cuisines
    for n in (x for x in notes if x["type"] == "cuisine"):
        if n["_new"]:
            c = {"id": n["_id"], "name": n["name"], "note": True}
            cuisines.append(c)
            by_id[c["id"]] = c
        c = by_id[n["_id"]]
        c["noted"] = True
        for key in ("kind", "iso3", "loc"):
            if n.get(key) is not None:
                c[key] = n[key]
        if n.get("indigenous"):
            c["indigenous"] = True
        if n.get("parent"):
            parents = [resolve(p, ("cuisine",), n["_file"])[1] for p in
                       (n["parent"] if isinstance(n["parent"], list) else [n["parent"]])]
            c["parents"] = [p for p in parents if p]
        if n.get("region"):
            c["region"] = n["region"]
        elif not c.get("region") and c.get("parents"):
            c["region"] = by_id[c["parents"][0]].get("region", [])
        if n.get("desc"):
            c["desc"] = n["desc"]
        store(n, "cuisines")

    # Children lists follow the (possibly changed) parents
    for c in cuisines:
        c.pop("children", None)
    for c in cuisines:
        for p in c.get("parents", []):
            if p in by_id:
                by_id[p].setdefault("children", []).append(c["id"])
    for c in cuisines:
        if c.get("children"):
            c["children"] = sorted(set(c["children"]))

    # Ingredients before dishes, so dishes can link to new ones
    for n in (x for x in notes if x["type"] == "ingredient"):
        if n["_new"]:
            i = {"id": n["_id"], "name": n["name"], "note": True}
            if n.get("wikipedia"):
                i["title"] = n["wikipedia"]
            ings.append(i)
            ing_by_id[i["id"]] = i
        store(n, "ingredients")

    for n in (x for x in notes if x["type"] == "dish"):
        if n["_new"]:
            d = {"id": n["_id"], "name": n["name"], "cuisines": [], "ingredients": [], "note": True}
            if n.get("wikipedia"):
                d["title"] = n["wikipedia"]
            dishes.append(d)
            dish_by_id[d["id"]] = d
        d = dish_by_id[n["_id"]]
        for v in n.get("cuisines") or []:
            cid = resolve(v, ("cuisine",), n["_file"])[1]
            if cid and cid not in d["cuisines"]:
                d["cuisines"].append(cid)
        for v in n.get("ingredients") or []:
            iid = resolve(v, ("ingredient",), n["_file"])[1]
            if iid and iid not in d["ingredients"]:
                d["ingredients"].append(iid)
        store(n, "dishes")

    # Cuisine notes can list dishes too ("dishes: [[[Akutaq]]]")
    for n in (x for x in notes if x["type"] == "cuisine"):
        for v in n.get("dishes") or []:
            did = resolve(v, ("dish",), n["_file"])[1]
            if did and n["_id"] not in dish_by_id[did]["cuisines"]:
                dish_by_id[did]["cuisines"].append(n["_id"])

    counts = {}
    for d in dishes:
        for i in d["ingredients"]:
            counts[i] = counts.get(i, 0) + 1
    for i in ings:
        i["dishes"] = counts.get(i["id"], 0)

    if missing:
        print("Links that don't resolve (fix the name, or write that note):")
        for m in missing:
            print("  ", m)

    data["cuisines"] = cuisines
    data["meta"]["count"] = len(cuisines)
    data["meta"]["notes"] = len(notes)
    food["dishes"] = dishes
    food["ingredients"] = ings
    dump = lambda obj, f: json.dump(obj, open(P(f), "w"), ensure_ascii=False, separators=(",", ":"))
    dump(data, "data/cuisines.json")
    dump(food, "data/food.json")
    dump(out_notes, "data/notes.json")
    print(f"notes: {len(notes)} ({sum(1 for n in notes if n['_new'])} new entries), "
          f"{len(missing)} unresolved links")


if __name__ == "__main__":
    main()
