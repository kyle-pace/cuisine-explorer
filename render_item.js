// Renders one page of the web of cuisines from its page model (built by
// scripts/build_web.mjs). No imports and no browser APIs, so the same file runs in
// the web view (web.html) and on kylepace.net's server-rendered pages.

export const slug = s => String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
  .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

// Which of the 256 bucket files a page lives in (FNV-1a hash of its address)
export function bucketOf(ref) {
  let h = 0x811c9dc5;
  for (let i = 0; i < ref.length; i++) { h ^= ref.charCodeAt(i); h = Math.imul(h, 0x01000193); }
  return ((h >>> 0) & 255).toString(16).padStart(2, "0");
}

const esc = s => String(s ?? "").replace(/[&<>"']/g, ch => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch]));
const ARROW = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const TYPE_LABEL = { cuisine: "Cuisine", dish: "Dish", ingredient: "Ingredient", site: "Recipe site", book: "Cookbook" };
export const tonnes = t => t >= 1e6 ? `${(t / 1e6).toFixed(t >= 1e7 ? 0 : 1)} million tonnes`
  : t >= 1000 ? `${Math.round(t / 1000).toLocaleString("en-US")} thousand tonnes` : `${Math.round(t).toLocaleString("en-US")} tonnes`;

// Plain text of the first paragraph, for meta descriptions and hover previews
export function summaryOf(m, max = 200) {
  const p = (m.intro || [])[0];
  let t = p ? p.map(x => Array.isArray(x) ? x[0] : x).join("") : m.sub || "";
  if (t.length > max) t = t.slice(0, max - 1).replace(/\s+\S*$/, "") + "…";
  return t;
}

/**
 * @param m     page model
 * @param opts  { href(ref) -> url for another page, globe(hash) -> url on the globe,
 *                correct(name) -> url to suggest a correction, external: attrs for outside links }
 * @returns     HTML for the page body
 */
export function renderItem(m, opts) {
  const ext = ' target="_blank" rel="noopener"';
  const a = ([name, ref]) => ref ? `<a href="${esc(opts.href(ref))}">${esc(name)}</a>` : esc(name);
  const links = arr => `<ul class="links">${arr.map(x => `<li>${a(x)}</li>`).join("")}</ul>`;
  const para = segs => `<p class="inline">${segs.map(x => Array.isArray(x) ? a(x) : esc(x)).join("")}</p>`;
  const row = r => `<li class="row"><span class="mark${r.shape === "cuisine" ? " dot" : ""}" style="background:${esc(r.color)}${r.shape === "cuisine" ? "" : ";border-radius:2px"}"></span><div>
      ${r.ref ? `<a class="name" href="${esc(opts.href(r.ref))}">${esc(r.name)}</a>` : `<b>${esc(r.name)}</b>`}${r.suggested ? `<span class="tag">Suggested</span>` : ""}
      <small>${esc(r.sub || "")}${r.note ? `<br>${esc(r.note)}` : ""}</small></div>
      ${r.url ? `<a class="out" href="${esc(r.url)}"${ext} aria-label="Open ${esc(r.name)}">${ARROW}</a>` : ""}</li>`;
  const section = s => {
    let body = "";
    if (s.rows) body = `<ul class="rows">${s.rows.map(row).join("")}</ul>`;
    else if (s.links) body = links(s.links) + (s.note ? `<p class="source" style="margin-top:8px">${esc(s.note)}</p>` : "");
    else if (s.groups) body = `<ul class="grouped">${s.groups.map(([name, ref, l]) => `<li><b>${a([name, ref])}</b> <span class="n">${l.length}</span>${links(l)}</li>`).join("")}</ul>`;
    else if (s.grown) {
      const g = s.grown, max = g.top[0]?.[2] || 1;
      body = `<p class="empty" style="margin-bottom:10px">Top producers of ${esc(g.what)}, averaged over ${esc(g.years)}.</p>
        <ol class="grown">${g.top.map(([name, ref, t]) => `<li><span>${a([name, ref])}</span><span class="n">${tonnes(t)}</span><i style="width:${Math.max(2, 100 * t / max).toFixed(1)}%"></i></li>`).join("")}</ol>
        <p class="source" style="margin-top:8px">Production data from <a href="${esc(g.url)}"${ext}>FAO, FAOSTAT</a>, CC BY 4.0. The world grows about ${tonnes(g.world)} a year.</p>`;
    } else if (s.empty) body = `<p class="empty">${esc(s.empty)}${s.tryLinks?.length ? `. Try ${s.tryLinks.map(a).join(" or ")}` : ""}.</p>`;
    return `<h2>${esc(s.h)}${s.count ? ` <small>${s.count}</small>` : ""}</h2>${body}`;
  };
  const action = x => x.kind === "globe" ? `<a class="btn" href="${esc(opts.globe(x.hash))}">Show on the globe</a>`
    : x.kind === "wiki" ? `<a class="btn" href="${esc(x.url)}"${ext}>Wikipedia ${ARROW}</a>`
    : `<a class="btn" href="${esc(x.url)}"${ext}>${esc(x.label)} ${ARROW}</a>`;
  const dot = m.dot || m.c;
  return `
    <p class="crumb">${m.crumb.map(c => c[1] ? `<a href="${esc(opts.href(c[1]))}">${esc(c[0])}</a>` : esc(c[0])).join(" / ")}</p>
    ${m.isbn ? `<div class="cover"><img alt="" src="https://covers.openlibrary.org/b/isbn/${esc(m.isbn)}-M.jpg?default=false" onerror="this.remove()"><span>${esc(m.n)}</span></div>` : ""}
    <h1>${esc(m.n)}</h1>
    <p class="sub"><i style="background:${esc(dot)}${m.square ? ";border-radius:2px" : ""}"></i>${esc(m.sub)}${m.suggested ? `<span class="tag">Suggested</span>` : ""}</p>
    ${m.names ? `<p class="sub">${esc(m.names)}</p>` : ""}
    <div class="intro" id="intro"${m.wiki ? ` data-wiki="${esc(m.wiki)}"` : ""}>${(m.intro || []).map(para).join("")}</div>
    ${m.src === "wikipedia" ? `<p class="source">Intro from Wikipedia, shared under CC BY-SA.</p>` : ""}
    ${m.src === "note" ? `<p class="source">Written for this explorer${m.sources?.length ? " from " + m.sources.map(x => `<a href="${esc(x.url)}"${ext}>${esc(x.name)}</a>`).join(", ") : ""}.</p>` : ""}
    <div class="actions">${(m.actions || []).map(action).join("")}${opts.extraActions || ""}</div>
    ${m.sections.map(section).join("")}
    ${m.isbn ? `<p class="source" style="clear:both">ISBN ${esc(m.isbn)}</p>` : ""}
    <p class="correct">Something wrong or missing? <a href="${esc(opts.correct(m.n))}"${ext}>Suggest a correction</a>.</p>`;
}

export const typeLabel = t => TYPE_LABEL[t];
