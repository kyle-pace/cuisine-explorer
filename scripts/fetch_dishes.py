"""Dishes and ingredients for every cuisine, from Wikidata.

Dishes: items whose "cuisine" (P2012) is one of our cuisines and that have an
English Wikipedia article. Ingredients: what those dishes are "made from"
(P186) or "have as parts" (P527), also limited to things with an English article.

Cleanup so the ingredient maps mean something:
  - generic parts are dropped (water, salt, dough, filling, food...)
  - the same ingredient under several items is merged by name ("Chicken" and
    "Chicken meat" -> Chicken), with hand merges in data/food_overrides.json
  - an "ingredient" that is itself one of our dishes stays a dish link

Writes data/food.json:
  {"dishes": [{id, name, qid, cuisines: [cuisine id], ingredients: [ingredient id]}],
   "ingredients": [{id, name, qid, dishes: n}]}

Usage: python3 fetch_dishes.py
"""
import json
import os
import re
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
from fetch_wikidata import run  # noqa: E402

P = lambda *a: os.path.join(ROOT, *a)

GENERIC = {
    "water", "salt", "food", "ingredient", "dish", "meat", "vegetable", "fruit", "spice", "herb",
    "seasoning", "condiment", "liquid", "mixture", "dough", "filling", "batter", "topping",
    "garnish", "sauce", "stuffing", "crust", "cooking oil", "oil", "fat", "flavoring",
    "food additive", "edible mushroom", "leaf vegetable", "root vegetable", "nut (fruit)",
    "seafood", "fish as food", "poultry", "grain", "cereal", "legume", "dairy product",
    "beverage", "drink", "alcoholic drink", "plant", "animal", "bread", "pastry", "soup",
}
# Common doubles, folded into one name
MERGE = {
    "chicken meat": "Chicken", "chicken as food": "Chicken", "beef": "Beef", "pork": "Pork",
    "egg as food": "Egg", "eggs": "Egg", "eggs as food": "Egg", "chicken egg": "Egg", "egg yolk": "Egg yolk",
    "rice": "Rice", "cooked rice": "Rice", "white rice": "Rice", "glutinous rice": "Glutinous rice",
    "wheat flour": "Wheat flour", "flour": "Wheat flour", "all-purpose flour": "Wheat flour",
    "chili pepper": "Chili pepper", "capsicum": "Bell pepper", "bell pepper": "Bell pepper",
    "black pepper": "Black pepper", "tomato": "Tomato", "potato": "Potato", "onion": "Onion",
    "garlic": "Garlic", "milk": "Milk", "cow's milk": "Milk", "butter": "Butter",
    "lamb and mutton": "Lamb", "lamb (food)": "Lamb", "mutton": "Lamb", "goat meat": "Goat",
    "shrimp": "Shrimp", "prawn": "Shrimp", "shrimp and prawn as food": "Shrimp",
    "fish": "Fish", "olive oil": "Olive oil", "coconut milk": "Coconut milk", "coconut": "Coconut",
    "sugar": "Sugar", "white sugar": "Sugar", "cane sugar": "Sugar", "cheese": "Cheese",
}


def norm(s):
    return re.sub(r"\s+", " ", (s or "").strip().lower())


def title_of(url):
    return urllib.parse.unquote(url.rsplit("/wiki/", 1)[1]).replace("_", " ")


def main():
    cuisines = json.load(open(P("data/cuisines.json")))["cuisines"]
    hand = {}
    if os.path.exists(P("data/food_overrides.json")):
        hand = json.load(open(P("data/food_overrides.json")))
    merge = {**MERGE, **{norm(k): v for k, v in hand.get("merge", {}).items()}}
    generic = GENERIC | {norm(x) for x in hand.get("generic", [])}

    by_qid = {}
    for c in cuisines:
        if c.get("qid"):
            by_qid.setdefault(c["qid"], []).append(c["id"])
    qids = sorted(by_qid)

    dishes = {}
    raw_ings = {}  # ingredient qid -> title
    for i in range(0, len(qids), 120):
        rows = run("""SELECT ?cuisine ?dish ?article ?ing ?ingArticle WHERE {
          VALUES ?cuisine { %s }
          ?dish wdt:P2012 ?cuisine .
          ?article schema:about ?dish ; schema:isPartOf <https://en.wikipedia.org/> .
          OPTIONAL {
            ?dish wdt:P186|wdt:P527 ?ing .
            ?ingArticle schema:about ?ing ; schema:isPartOf <https://en.wikipedia.org/> .
          } }""" % " ".join("wd:" + q for q in qids[i:i + 120]))
        for r in rows:
            dq = r["dish"]["value"].rsplit("/", 1)[1]
            cq = r["cuisine"]["value"].rsplit("/", 1)[1]
            d = dishes.setdefault(dq, {"qid": dq, "title": title_of(r["article"]["value"]),
                                       "cuisines": set(), "ings": set()})
            d["cuisines"].update(by_qid.get(cq, []))
            if "ing" in r:
                iq = r["ing"]["value"].rsplit("/", 1)[1]
                raw_ings[iq] = title_of(r["ingArticle"]["value"])
                d["ings"].add(iq)
        print(f"  {min(i + 120, len(qids))}/{len(qids)} cuisines: {len(dishes)} dishes", flush=True)

    # Everyday English names for ingredients (Wikidata labels), since many articles
    # are titled by scientific name ("Cymbopogon citratus" is lemongrass)
    labels = {}
    iqs = sorted(raw_ings)
    for i in range(0, len(iqs), 300):
        rows = run("""SELECT ?i ?label WHERE { VALUES ?i { %s } ?i rdfs:label ?label FILTER(LANG(?label) = "en") }"""
                   % " ".join("wd:" + q for q in iqs[i:i + 300]))
        for r in rows:
            labels[r["i"]["value"].rsplit("/", 1)[1]] = r["label"]["value"]
    sci = re.compile(r"^[A-Z][a-z]+ [a-z]+( [a-z]+)?$")  # Genus species

    # Ingredient ids are names after merging; dishes listed as ingredients of other
    # dishes stay ingredients too (dashi in miso soup), which is what cooks expect
    def ing_name(iq):
        t = raw_ings[iq]
        lab = labels.get(iq)
        if lab and (sci.match(t) or "(" in t) and not sci.match(lab[:1].upper() + lab[1:]):
            t = lab[:1].upper() + lab[1:]
        n = norm(re.sub(r"\s*\((food|plant|spice|fruit|vegetable|ingredient)\)$", "", t, flags=re.I))
        if n in generic or norm(t) in generic:
            return None
        return merge.get(norm(t)) or merge.get(n) or re.sub(r"\s*\((food|ingredient)\)$", "", t)

    ingredients = {}
    out_dishes = []
    drop = {norm(x) for x in hand.get("drop_dishes", [])}
    infobox = {}
    if os.path.exists(P("data/infobox_ingredients.json")):
        infobox = json.load(open(P("data/infobox_ingredients.json")))

    def title_name(t):
        n = norm(re.sub(r"\s*\((food|plant|spice|fruit|vegetable|ingredient|condiment|sauce)\)$", "", t, flags=re.I))
        if n in generic or norm(t) in generic:
            return None
        return merge.get(norm(t)) or merge.get(n) or re.sub(r"\s*\((food|ingredient)\)$", "", t)

    for d in dishes.values():
        if norm(d["title"]) in drop:
            continue
        names = {n for n in (ing_name(q) for q in d["ings"]) if n}
        for t in infobox.get(d["title"], []):
            n = title_name(t)
            if n:
                names.add(n)
                ingredients.setdefault(n, {"id": n, "name": n, "titles": set(), "dishes": 0})["titles"].add(t)
        names = sorted(names)
        for n in names:
            ing = ingredients.setdefault(n, {"id": n, "name": n, "titles": set(), "dishes": 0})
            ing["dishes"] += 1
        for q in d["ings"]:
            n = ing_name(q)
            if n:
                ingredients[n]["titles"].add(raw_ings[q])
        out_dishes.append({"id": d["title"], "name": d["title"], "qid": d["qid"],
                           "cuisines": sorted(d["cuisines"]), "ingredients": names})

    for ing in ingredients.values():
        # Link to the article whose title matches the merged name, else the most common
        titles = sorted(ing.pop("titles"))
        ing["title"] = next((t for t in titles if norm(t) == norm(ing["name"])), titles[0] if titles else ing["name"])

    out_dishes.sort(key=lambda d: d["name"].lower())
    out_ings = sorted(ingredients.values(), key=lambda x: (-x["dishes"], x["name"].lower()))
    json.dump({"dishes": out_dishes, "ingredients": out_ings},
              open(P("data/food.json"), "w"), ensure_ascii=False, separators=(",", ":"))
    with_ing = sum(1 for d in out_dishes if d["ingredients"])
    print(f"{len(out_dishes)} dishes ({with_ing} with ingredients), {len(out_ings)} ingredients, "
          f"{os.path.getsize(P('data/food.json')) // 1024} KB")
    print("top ingredients:", [(x["name"], x["dishes"]) for x in out_ings[:25]])


if __name__ == "__main__":
    main()
