"""Parse Wikipedia's List of cuisines wikitext into a flat list of entries.

Each entry keeps where it sits on the page: the section path (continent,
subregion, national heading) and its parent bullet, so the hierarchy on the
explorer mirrors Wikipedia's own.

Usage: python3 parse_list.py raw/list.wikitext data/list_entries.json
"""
import json
import re
import sys

LINK = re.compile(r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]")
HEADING = re.compile(r"^(=+)\s*(.*?)\s*\1\s*$")

THEMATIC = {
    "Cuisine styles": "style",
    "Religious cuisines": "religious",
    "Historical cuisines": "historical",
}
STOP = {"References", "External links", "See also"}


def clean_title(t):
    t = t.strip().replace("_", " ")
    return t[:1].upper() + t[1:] if t else t


def main(src, dst):
    lines = open(src, encoding="utf-8").read().splitlines()
    headings = {}  # level -> text
    section_kind = "regional"
    bullet_stack = []  # list of (depth, key)
    entries = {}
    order = []

    for line in lines:
        h = HEADING.match(line)
        if h:
            level, text = len(h.group(1)), h.group(2)
            if text in STOP:
                break
            headings = {k: v for k, v in headings.items() if k < level}
            headings[level] = text
            if level == 2:
                section_kind = THEMATIC.get(text, "regional")
            bullet_stack = []
            continue

        m = re.match(r"^(\*+)\s*(.*)$", line)
        if not m:
            continue
        depth, body = len(m.group(1)), m.group(2).strip()
        link = LINK.search(body)
        if link and body.startswith("[["):
            target, label = link.group(1), link.group(2)
            if target.startswith(("File:", "Image:", "Category:")):
                continue
            page, _, anchor = target.partition("#")
            page = clean_title(page)
            label = (label or page).strip()
            key = page + ("#" + anchor if anchor else "")
            is_group = False
        else:
            # Plain-text group label such as "Northern Chinese Cuisine"
            label = LINK.sub(lambda x: x.group(2) or x.group(1), body).strip()
            if not label:
                continue
            page, anchor = None, ""
            key = "group:" + label
            is_group = True

        while bullet_stack and bullet_stack[-1][0] >= depth:
            bullet_stack.pop()
        parent = bullet_stack[-1][1] if bullet_stack else None

        # A level-5 heading ("Chinese cuisine") acts as the national parent
        # for top-level bullets under it.
        national = headings.get(5)
        if parent is None and national and section_kind == "regional":
            parent = "heading:" + national

        section = [headings[k] for k in sorted(headings) if k >= 3]
        if key not in entries:
            entries[key] = {
                "key": key,
                "title": page,
                "anchor": anchor,
                "label": label,
                "group": is_group,
                "kind": section_kind,
                "sections": [section],
                "parents": [parent] if parent else [],
            }
            order.append(key)
        else:
            e = entries[key]
            if section not in e["sections"]:
                e["sections"].append(section)
            if parent and parent not in e["parents"]:
                e["parents"].append(parent)
            # Thematic placement wins over regional when both exist
            if section_kind != "regional":
                e.setdefault("also", []).append(section_kind)
        bullet_stack.append((depth, key))

    # National headings themselves become entries if not already linked
    for e in list(entries.values()):
        for p in e["parents"]:
            if p.startswith("heading:"):
                name = p.split(":", 1)[1]
                if name not in entries:
                    entries[name] = {
                        "key": name, "title": name, "anchor": "", "label": name,
                        "group": False, "kind": "regional",
                        "sections": [e["sections"][0][:-1]], "parents": [],
                    }
                    order.append(name)
    for e in entries.values():
        e["parents"] = [p.split(":", 1)[1] if p.startswith("heading:") else p
                        for p in e["parents"]]

    out = [entries[k] for k in order]
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    linked = [e for e in out if not e["group"]]
    print(f"{len(out)} entries, {len(linked)} linked, "
          f"{len({e['title'] for e in linked})} unique pages")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
