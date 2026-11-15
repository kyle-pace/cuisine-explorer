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

# Every ingredient: design plan

**Subject and who it's for.** `/world-cuisine/ingredients/`: every ingredient in World cuisine, in one place, for the same curious eaters as the globe. Each name is a door to that ingredient's page.

**Concept: a spice merchant's ledger, by where things come from.** The globe is how the site is organized, so the list is too: continents, then parts of the world (Southeast Asia, the British Isles), each holding the ingredients most at home there. Things found everywhere (garlic, sugar, egg) open the page as "All over the world". The same list also reads A to Z, each name followed by where it's at home.

**The one bold element: the part-of-the-world names**, in the page's accent color, under plain continent headings. Everything else is plain text: no dots, lines, cards or chips, and the ingredient names carry no underlines until pointed at (every word in a list is a link, and nothing else there is).

**Controls.** Native ones only: a search field, a select with the parts grouped by continent, and two radio buttons for the order. They sit in one row on wide screens and stack on phones, and only appear when the script runs; without it, a row of links to each part takes their place.

**What came before.** On November 14, 2026 this was first a drawing of ingredients grouped by what they're cooked with (too crowded: unlabeled dots, colliding names), then the same groups as shelves of words (readable, but the groups felt arbitrary). Words stayed; the grouping changed to place.

**Colors.** The site's own tokens (kp-design, accent tangerine), light and dark: ink for names, ink-muted for the line under each part and the part after each name in A to Z, accent-ink for part names, radio buttons, focus rings and the marked ingredient when you arrive from its page.

**Type.** Atkinson Hyperlegible Next. Continents step-3; parts step-2 bold; the most-used ingredients step-1 bold; the rest body size.

**Layout**

```
World cuisine / Every ingredient
Every ingredient
All 1,344 ingredients ... each under the part of the world where it's most at home.
Find an ingredient [_______]  Part of the world [Everywhere v]  Order (o) By part of the world ( ) A to Z
--------------------------------------------------------------------------------
All over the world
Wheat flour  Sugar  Egg  Rice  Onion  Chili pepper
Almond  Animal fats and oils  Apple  ...                            (wraps)

Asia
Southeast Asia
240 ingredients, most at home in Indonesian, Javanese and Thai dishes.
Lemongrass  Ginger  Galangal  Palm sugar  Rice flour  Candlenut
Acetic acid  Adzuki bean  Agar  ...

A to Z:   A                 (names in columns, 17rem wide)
          Acetic acid  Southeast Asia      Allspice  Central and North Asia
```

One column of text up to 72rem wide; the word lists wrap and the A to Z columns fall to one on phones.
