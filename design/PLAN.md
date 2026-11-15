# Dish drop: design plan

**Subject and who it's for.** A daily guessing game on World cuisine's globe: you see a photo of a dish and drop a pin where you think it comes from. For curious eaters, not trivia experts. Every reveal leads back into the explorer's dish and cuisine pages.

**The one bold element: the order ticket.** The dish arrives on a paper kitchen ticket clipped over the globe: rice-paper card, torn bottom edge, the photo, "Order 2 of 5". At the reveal the ticket fills in like a filled order (name, cuisine, distance, points) and at the end it becomes a receipt listing all five. Everything else (globe, controls) stays quiet and dark so the ticket carries the page.

**Colors** (the explorer's own palette, so the game feels like part of World cuisine):

| Name | Hex | Use |
| --- | --- | --- |
| Aubergine | `#1b1424` | page, ocean |
| Plum | `#3a3045` | land |
| Rice | `#ede6da` | ticket paper, text on dark |
| Squid ink | `#241b2f` | text on the ticket |
| Saffron | `#f0b340` | your pin and the arc; focus ring |
| Chili | `#a8381a` | the answer's label on the ticket (on rice: 6.1:1) |

The explorer is dark only (the globe is the page), so the game is too; the ticket is light paper on it, so both kinds of contrast get checked.

**Layout**

```
Desktop                                  Phone
+-------------------------------------+  +-----------------+
| < World cuisine                     |  | < World cuisine |
| +---------+                         |  | +-------------+ |
| | TICKET  |        globe            |  | | ticket:     | |
| | photo   |                         |  | | photo strip | |
| | Order 2 |                         |  | +-------------+ |
| +--/\/\---+                         |  |     globe       |
|                                     |  |                 |
|        [ Or type a country ][Drop]  |  | [country][Drop] |
+-------------------------------------+  +-----------------+
```

**Checked against the generated defaults:** no headline-plus-pill hero, no card grid, no dot decoration, no small labels over headings. The pill shape is kept only where the explorer already uses it (inputs), the ticket has its own square-cornered, torn-edge shape.

---

# Ingredient map: design plan

**Subject and who it's for.** `/world-cuisine/ingredient-map/`: every ingredient that shows up in three or more of World cuisine's dishes, placed near the ones it's cooked with, so neighborhoods form on their own: Southeast Asian aromatics, flour-and-butter baking, Eastern European potato and dill. For the same curious eaters as the globe; every dot is a door to that ingredient's page.

**Concept: a market seen from above.** Each neighborhood is a district of stalls; each dot is a stall, sized by how many dishes use it. District names are painted on the ground above their stalls. Point at a stall and the paths to its five closest neighbors light up.

**The one bold element: the lit paths.** The map sits quiet (dim stalls, faint paths) until you hover or focus an ingredient; then it and its neighbors go saffron and everything else steps back. Everything around the map is the site's usual page.

**Colors** (the explorer's dark palette, inside the frame only):

| Name | Hex | Use |
| --- | --- | --- |
| Aubergine | `#1b1424` | the map's ground |
| Stall | `#8a7a9c` | dots (4.6:1 on aubergine, so they read as UI) |
| Rice | `#ede6da` | ingredient names, dot outlines (14:1) |
| Saffron | `#f0b340` | district names, the lit ingredient, its paths, focus ring (9.5:1) |
| Path | `#4a3f57` | faint paths between ingredients (decorative) |

**Type.** Atkinson Hyperlegible Next. District names 22px bold in saffron; ingredient names 15px in rice with an aubergine halo so they read over paths. Only each district's three most-used ingredients are named until you point at one.

**Layout**

```
Desktop                                    Phone
World cuisine / Ingredient map             World cuisine / Ingredient map
Ingredient map                             Ingredient map
+----------------------------------------+ +-------------------+
|  Chili pepper     Wheat flour          | | map, pans sideways|
|  and ginger       and sugar      ...   | | inside its frame  |
|   o o  o         O  o o                | +-------------------+
|  o  O o         o O  o                 | Lemongrass: in 25 ...
+----------------------------------------+ The neighborhoods
Lemongrass: in 25 dishes, cooked most ...  ## Chili pepper and ginger
The neighborhoods (list, same links)       chili pepper, ginger, ...
```

The list under the map is the same map in words: every neighborhood, the cuisines its dishes come from, and every ingredient as a link. It's the way in for screen readers and keyboards, and the easier one on phones.

**Checked against the generated defaults:** no hero or pill button; no card grid (the neighborhoods are a plain list); no colored dots as decoration (dots are the data, and districts are told apart by name and place, never by color); no monospace or eyebrow labels.
