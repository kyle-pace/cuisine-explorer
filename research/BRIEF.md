# Research brief: recipe sites and cookbooks per cuisine

You are filling in *suggestions* for a cuisine explorer website (a globe of the world's cuisines, built from Wikipedia's List of cuisines). The site owner will review everything before it's promoted, so accuracy beats volume. A wrong or invented link is far worse than an empty entry.

## Input
`/home/claude/cuisine-explorer/research/todo-<BATCH>.json`: a list of `{id, name, kind, country}`. `id` is the Wikipedia page title and is the key you must use in the output.

## What to find for each cuisine
- **sites**: 1 to 3 recipe sources dedicated to that cuisine: blogs, YouTube channels, or sites by home cooks or chefs from that culture are best; a strong dedicated section on an established food site is fine. Avoid content farms, SEO recipe spam, AI-generated recipe sites, Pinterest, Facebook groups, and generic "best X recipes" listicles.
- **cookbooks**: 1 to 3 well-regarded cookbooks focused on that cuisine (in English if possible).

## Rules
1. Only use URLs you actually saw in a WebSearch result or fetched with WebFetch. Never guess or construct a URL. The shell cannot reach the web here, so use WebSearch/WebFetch only.
2. Cookbooks must be real: confirm title and author from a search result, Open Library, or the publisher. Include an ISBN-13 only if you saw it on Open Library, the publisher, or a bookseller page; otherwise leave `isbn` out. `url` should be an Open Library or publisher page you saw.
3. `note`: one short factual line in your own words (what it is, who's behind it). No quotes from the source, no marketing language, no em dashes.
4. Work in priority order: `kind: "national"` first (biggest, most-cooked cuisines first), then regional/diaspora, then the rest. Obscure entries with nothing good are fine to skip: omit them entirely.
5. Be efficient: one or two searches per cuisine is usually enough (e.g. `<cuisine> recipes blog`, `best <cuisine> cookbook`). Don't fetch pages you don't need.
6. Save progress often: every ~10 cuisines, write the full output file (overwrite) so partial work survives.

## Output
Write `/home/claude/cuisine-explorer/research/suggestions-<BATCH>.json`:

```json
{
  "Thai cuisine": {
    "sites": [
      {"name": "Hot Thai Kitchen", "url": "https://hot-thai-kitchen.com/", "type": "youtube", "note": "Pailin Chongchitnant's recipes and videos, with background on technique."}
    ],
    "cookbooks": [
      {"title": "Thai Food", "author": "David Thompson", "year": 2002, "isbn": "9781580084628", "url": "https://openlibrary.org/...", "note": "Encyclopedic reference on Thai cooking."}
    ]
  }
}
```
`type` is one of: blog, youtube, site, magazine. Valid JSON only.

When done, reply with: how many cuisines got sites, how many got cookbooks, and any you were unsure about.
