// Draws data/ingredient_map.json as an SVG string. Used by the ingredient map page
// (src/pages/world-cuisine/ingredient-map.astro) and its share card, so both match.
//
// Each ingredient is a link to its page; links between ingredients are drawn faintly and
// light up (with the ingredient's neighbors) when it's hovered or focused. Neighborhood
// names sit above their group. Colors are the explorer's own (design/PLAN.md).

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const list = (names) => (names.length > 1 ? `${names.slice(0, -1).join(', ')} and ${names.at(-1)}` : names[0] ?? '');

/** How many of each neighborhood's ingredients get a label on the map (the rest show on hover). */
export const LABELS_PER_GROUP = 3;

/** One sentence about an ingredient, for its accessible name and the line under the map. */
export function describe(node, byId) {
  const near = node.near.map((id) => (byId.get(id)?.name ?? id).toLowerCase());
  const dishes = `${node.dishes} ${node.dishes === 1 ? 'dish' : 'dishes'}`;
  return near.length ? `${node.name}: in ${dishes}, cooked most with ${list(near)}.` : `${node.name}: in ${dishes}.`;
}

/**
 * @param map  data/ingredient_map.json
 * @param opts { href(node) -> url, id (svg id), title, interactive (links and focus; false for the share card) }
 */
export function mapSvg(map, opts = {}) {
  const { href = (n) => `/world-cuisine/ingredient/${n.slug}/`, id = 'ingredient-map', title = 'Ingredient map', interactive = true } = opts;
  const byId = new Map(map.nodes.map((n) => [n.id, n]));
  // Name each neighborhood's most-used ingredients on the map, skipping any name that
  // would sit on top of one already placed (it still shows when that dot is lit).
  const labelled = new Set();
  const boxes = [];
  const rr0 = (n) => Math.max(4, Math.min(n.r * 0.75, 20));
  for (const g of map.groups) {
    for (const id of g.members.slice(0, LABELS_PER_GROUP)) {
      const n = byId.get(id);
      if (!n) continue;
      const b = { x0: n.x + rr0(n) + 2, x1: n.x + rr0(n) + 6 + n.name.length * 8.2, y0: n.y - 9, y1: n.y + 8 };
      if (boxes.some((o) => b.x0 < o.x1 && b.x1 > o.x0 && b.y0 < o.y1 && b.y1 > o.y0)) continue;
      boxes.push(b);
      labelled.add(id);
    }
  }

  // Dots shrink a little so big ones don't swallow their neighbors
  const r = (n) => Math.max(4, Math.min(n.r * 0.75, 20));

  const links = map.links
    .map((l) => {
      const a = byId.get(l.a), b = byId.get(l.b);
      if (!a || !b) return '';
      // Links between neighborhoods only show while one of their ends is lit
      const cross = a.group !== b.group ? ' class="x"' : '';
      return `<line${cross} x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" data-a="${esc(a.slug)}" data-b="${esc(b.slug)}" stroke-width="${(0.6 + l.w * 3).toFixed(2)}"/>`;
    })
    .join('');

  // In tab order, a neighborhood at a time, most-used first (the same order as the list)
  const inOrder = map.groups.flatMap((g) => g.members.map((id) => byId.get(id)).filter(Boolean));
  const dots = inOrder
    .map((n) => {
      const rr = r(n);
      const label = labelled.has(n.id)
        ? `<text x="${(n.x + rr + 4).toFixed(1)}" y="${(n.y + 5).toFixed(1)}" class="lab">${esc(n.name)}</text>`
        : `<text x="${(n.x + rr + 4).toFixed(1)}" y="${(n.y + 5).toFixed(1)}" class="lab more">${esc(n.name)}</text>`;
      const body = `<circle class="hit" cx="${n.x}" cy="${n.y}" r="${Math.max(rr, 12)}"/><circle class="dot" cx="${n.x}" cy="${n.y}" r="${rr.toFixed(1)}"/>${label}`;
      const near = n.near.map((x) => byId.get(x)?.slug).filter(Boolean).join(' ');
      const data = `data-slug="${esc(n.slug)}" data-near="${esc(near)}" data-group="${n.group}" data-say="${esc(describe(n, byId))}"`;
      return interactive
        ? `<a class="ing" href="${esc(href(n))}" ${data} aria-label="${esc(describe(n, byId))}">${body}</a>`
        : `<g class="ing">${body}</g>`;
    })
    .join('');

  const grounds = map.groups
    .map((g) => `<circle cx="${g.cx}" cy="${g.cy}" r="${g.r}"/>`)
    .join('');

  const names = map.groups
    .map((g) => `<text class="hood" x="${g.x}" y="${Math.max(g.y, 24)}" text-anchor="middle">${esc(g.name)}</text>`)
    .join('');

  return `<svg id="${esc(id)}" tabindex="-1" class="ingredient-map" viewBox="0 0 ${map.width} ${map.height}" role="group" aria-label="${esc(title)}">` +
    `<g class="grounds" aria-hidden="true">${grounds}</g>` +
    `<g class="links" aria-hidden="true">${links}</g>` +
    `<g class="hoods" aria-hidden="true">${names}</g>` +
    `<g class="dots">${dots}</g>` +
    `</svg>`;
}
