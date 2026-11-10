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
