"""Make a single-file preview (dist/preview.html) with the data inlined, for
places that can't load the JSON files alongside the page.

Usage: python3 build_preview.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def block(id_, path):
    text = open(os.path.join(ROOT, path), encoding="utf-8").read()
    text = text.replace("</", "<\\/")
    return f'<script type="application/json" id="{id_}">{text}</script>'


html = open(os.path.join(ROOT, "index.html"), encoding="utf-8").read()
inline = "\n".join([
    block("data-cuisines", "data/cuisines.json"),
    block("data-countries", "data/countries.geojson"),
    block("data-picks", "data/picks.json"),
] + [block("data-" + name.split(".")[0], f"data/{name}") for name in ("suggestions.json", "summaries.json", "regions.geojson", "food.json", "food_summaries.json", "notes.json", "grown.json")
     if os.path.exists(os.path.join(ROOT, f"data/{name}"))])
html = html.replace("<!--INLINE_DATA-->", inline)
# The preview sits in dist/, one level below the self-hosted fonts and libraries.
html = html.replace('"vendor/', '"../vendor/')
os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
out = os.path.join(ROOT, "dist", "preview.html")
open(out, "w", encoding="utf-8").write(html)
print(out, os.path.getsize(out), "bytes")
