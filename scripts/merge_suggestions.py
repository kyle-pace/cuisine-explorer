"""Merge research/suggestions-*.json into data/suggestions.json, with checks:
keys must be cuisines in data/cuisines.json, links must be https, ISBN-13s
must pass their checksum (bad ones are dropped, the book is kept), and
duplicates are removed. Prints anything it had to drop.

Usage: python3 merge_suggestions.py
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TYPES = {"blog", "youtube", "site", "magazine"}


def isbn13_ok(s):
    d = re.sub(r"[^0-9X]", "", str(s))
    if len(d) == 10:  # convert ISBN-10 to 13
        if not re.fullmatch(r"\d{9}[\dX]", d):
            return None
        total = sum((10 - i) * (10 if ch == "X" else int(ch)) for i, ch in enumerate(d))
        if total % 11:
            return None
        d = "978" + d[:9]
        d += str((10 - sum((1 if i % 2 == 0 else 3) * int(ch) for i, ch in enumerate(d)) % 10) % 10)
        return d
    if len(d) != 13 or not d.isdigit():
        return None
    check = (10 - sum((1 if i % 2 == 0 else 3) * int(ch) for i, ch in enumerate(d[:12])) % 10) % 10
    return d if check == int(d[12]) else None


def clean_note(n):
    n = (n or "").strip().replace(" — ", ", ").replace("—", ", ")
    return n


def main():
    ids = {c["id"] for c in json.load(open(os.path.join(ROOT, "data/cuisines.json")))["cuisines"]}
    out, dropped = {}, []
    for path in sorted(glob.glob(os.path.join(ROOT, "research/suggestions-*.json"))):
        try:
            batch = json.load(open(path))
        except json.JSONDecodeError as e:
            dropped.append(f"{os.path.basename(path)}: not valid JSON ({e})")
            continue
        for cid, entry in batch.items():
            if cid not in ids:
                dropped.append(f"unknown cuisine id: {cid}")
                continue
            dest = out.setdefault(cid, {"sites": [], "cookbooks": []})
            for s in entry.get("sites", []) or []:
                url = (s.get("url") or "").strip()
                if not s.get("name") or not url.startswith("https://"):
                    dropped.append(f"{cid}: site without name or https link: {s}")
                    continue
                if any(x["url"].rstrip("/") == url.rstrip("/") for x in dest["sites"]):
                    continue
                dest["sites"].append({
                    "name": s["name"].strip(), "url": url,
                    "type": s.get("type") if s.get("type") in TYPES else "site",
                    "note": clean_note(s.get("note")),
                })
            for b in entry.get("cookbooks", []) or []:
                if not b.get("title"):
                    continue
                if any(x["title"].lower() == b["title"].strip().lower() for x in dest["cookbooks"]):
                    continue
                book = {"title": b["title"].strip(), "author": (b.get("author") or "").strip()}
                if b.get("year"):
                    book["year"] = b["year"]
                if b.get("isbn"):
                    good = isbn13_ok(b["isbn"])
                    if good:
                        book["isbn"] = good
                    else:
                        dropped.append(f"{cid}: bad ISBN {b['isbn']} on {b['title']}")
                if b.get("url", "").startswith("https://"):
                    book["url"] = b["url"]
                book["note"] = clean_note(b.get("note"))
                dest["cookbooks"].append(book)
    out = {k: {kk: vv for kk, vv in v.items() if vv} for k, v in out.items()}
    out = {k: v for k, v in out.items() if v}
    doc = {
        "_about": "Research suggestions for recipe sites and cookbooks, not yet reviewed. "
                  "Move the ones you like into picks.json; the explorer shows picks first "
                  "and marks these as suggested.",
        "cuisines": dict(sorted(out.items())),
    }
    json.dump(doc, open(os.path.join(ROOT, "data/suggestions.json"), "w"), ensure_ascii=False, indent=1)
    n_sites = sum(1 for v in out.values() if v.get("sites"))
    n_books = sum(1 for v in out.values() if v.get("cookbooks"))
    print(f"{len(out)} cuisines: {n_sites} with sites, {n_books} with cookbooks")
    for d in dropped:
        print("  dropped:", d)


if __name__ == "__main__":
    main()
