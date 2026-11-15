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

**Concept: a pantry's shelves.** Things cooked together are kept together. Each shelf is named for its two most-used ingredients, holds its eight most-used up front in bold, then everything else A to Z. A last shelf, "On their own", holds what doesn't fit anywhere yet.

**The one bold element: the shelf names**, in the page's accent color at a size that reads as a sign. Everything else is plain text: no dots, lines, cards or chips, and the ingredient names carry no underlines until pointed at (every word on a shelf is a link, and nothing else there is).

**Why not a drawing.** The first version (November 14, 2026) drew the same groups as a map of dots. With hundreds of ingredients the dots went unlabeled, names collided and highlight lines crossed the whole map. Words are the content, so the page is words.

**Colors.** The site's own tokens (kp-design, accent tangerine), light and dark: ink for names, ink-muted for the line under each shelf name, accent-ink for shelf names, focus rings and the marked ingredient when you arrive from its page.

**Type.** Atkinson Hyperlegible Next. Shelf names step-2 bold; the most-used ingredients step-1 bold; the rest body size.

**Layout**

```
World cuisine / Every ingredient
Every ingredient
All 1,344 ingredients ... shelved with the ones they're cooked with.
Find an ingredient [__________]        (shown only with JavaScript)
-------------------------------------------------------------
Wheat flour and sugar  Cinnamon and almond  Chili pepper ...   (jump links)
-------------------------------------------------------------
Wheat flour and sugar
208 ingredients, mostly in Indonesian, American and Italian dishes.
Wheat flour  Sugar  Egg  Butter  Milk  Yeast  Lard  Puff pastry
Adzuki bean  Agaricus  Akkawi cheese  Alkali  Allspice  ...  (wraps)
```

One column, up to 72rem wide; the word lists wrap, so phones get the same page with shorter lines.
