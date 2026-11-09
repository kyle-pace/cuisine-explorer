<!-- BEGIN principles: synced from github.com/kyle-pace/principles. Edit them there; changes made here are overwritten. -->

## Development principles

These apply to every project Kyle builds, on any platform, with any agent. The project's own section of this file adds specifics and can override a default for that project. Kyle's direct instructions in a session override both.

### Priority order

When two goals conflict, the higher one wins:

1. Accessibility
2. Privacy
3. Correctness and reliability
4. Performance
5. Polish

### Accessibility comes first

Accessibility is designed in from the first commit, not audited in at the end.

- Meet WCAG 2.2 AA at minimum. Text contrast is at least 4.5:1 (3:1 for large text and for UI parts like borders and icons), in both light and dark mode.
- Use semantic, native elements first (`button`, `a`, `label`, headings in order, landmarks). Add ARIA only when no native element does the job.
- Everything interactive works with a keyboard, has a visible focus style and has an accessible name. Touch targets are at least 24×24 px; aim for 44×44.
- Never carry meaning with color alone. Meaningful images get alt text; decorative ones get empty alt.
- Respect user settings: reduced motion, light/dark preference, text zoom to 200% without breaking layout. On Apple platforms: Dynamic Type, VoiceOver labels and hints, Reduce Motion, Increase Contrast.
- Motion is short (under 300 ms for interface animation), never `ease-in`, and on the web only runs inside `@media (prefers-reduced-motion: no-preference)`.

### Every screen size from day one

Layouts are designed for phones, tablets and big screens from the first commit, not stretched or squeezed in later.

- **Apps** are built for both phone and tablet from day one. On Apple platforms that means one universal iPhone and iPad app that supports iPad multitasking (Split View, Slide Over, Stage Manager) and resizable windows. On iPad, support every orientation. On iPhone, portrait is the default; add landscape only where it helps the app (video, maps, wide charts, a recipe propped up while cooking). Use size classes and adaptive SwiftUI layouts (`NavigationSplitView`, `ViewThatFits`, grids) so iPad gets a layout that uses the space, not a blown-up phone screen.
- **Web projects** are fully responsive: mobile first, fluid from 320 px wide up to large desktop monitors. No sideways scrolling at 320 px. Cap line length for reading (about 70 characters), and let wider screens add columns instead of stretching text.
- Prefer fluid layouts (flexbox, grid, `clamp()`, container queries) over many fixed breakpoints. Handle touch, mouse and keyboard on every size, and respect safe areas and notches.

### Type

- Atkinson Hyperlegible Next for all text and Atkinson Hyperlegible Mono for code, in every product.
- Self-host the fonts: on the web use the `@fontsource/atkinson-hyperlegible-next` and `@fontsource/atkinson-hyperlegible-mono` packages; in apps, bundle the font files. Never load fonts from Google Fonts or any other font CDN.
- Offering a setting to switch to the device's own font is fine.

### Privacy comes second, and right behind

- Collect the least data that answers a real product question. No ad or marketing pixels, no fingerprinting, no selling or sharing data.
- Never put personal information in analytics: no names, emails, free-text input or precise location.
- Respect Global Privacy Control and Do Not Track by sending no analytics at all, and give people an opt-out.
- No cookies for analytics (keep the ID in `localStorage`), so no cookie banner is needed.
- Analytics only runs on the live production domain, never on localhost or preview builds.
- In Apple apps, keep personal data on the device or in the user's own iCloud unless a feature truly needs a server.
- Any project that collects data has a short, plain-language privacy page.
- Secrets never go in Git. (Browser API keys that are public by design, like Amplitude's, are fine in code.)

### Default stack

Use these unless the project's section says otherwise. **Do not add any other third-party service, SDK, script, font or paid tool without asking Kyle first.**

- **Product analytics: Amplitude**, set up the private way (on the web, use `startAnalytics` from kp-design's `kp-design/analytics`, which does all of this):
  - autocapture on, IP address tracking off, identity in `localStorage`
  - off under GPC, Do Not Track or the opt-out; only on the live domain
  - Session Replay only if the project wants it: a small sample (about 5%), conservative masking, and its code only loaded for sampled sessions
  - custom events follow the naming rules under "Analytics events" below
- **Backend: Firebase** (Auth, Firestore, Functions, Storage) when a project needs accounts or shared data.
  - Security rules deny by default and are locked down before anything ships.
  - Firebase Analytics stays off; Amplitude covers analytics.
- **Web hosting: Cloudflare** (Workers with static assets). GitHub Pages is fine for a simple static site.
- **Design system for Kyle's websites: [kp-design](https://github.com/kyle-pace/kp-design)**, installed from GitHub and pinned to a commit. It holds the tokens, self-hosted Atkinson, header, footer, display settings and analytics; projects on kylepace.dev use its `DevLayout`. Don't copy these into a project; change them in kp-design. (Apple apps don't use it.)
- **Apple apps:** native Swift and SwiftUI.
- Put each outside service behind its own module (one file talks to Amplitude, one to Firebase), so switching tools means changing one file.
- Keep running costs near zero: prefer static pages, free tiers and on-device work, and ask before adding anything that bills.

### Analytics events

Every project uses the same rules, so charts read the same way everywhere.

- **Event names:** Title Case, past-tense verb first, then the object: "Saved Recipe", "Viewed Deal", "Completed Onboarding". Not "Recipe Saved" and not `save_recipe`. Use the same verb for the same action across projects (Viewed, Opened, Tapped, Added, Removed, Changed, Saved, Completed).
- **Property names:** lowercase `snake_case` (`deal_id`, `stores_picked`). Keep names and values the same across events and projects when they mean the same thing.
- Leave Amplitude's own `[Amplitude] …` events alone. Add custom events only for actions that answer a real product question; autocapture covers page views and clicks.
- **One Amplitude project per product.** kylepace.dev and every experiment on it share the kylepace.dev project, so each experiment's custom events also send `experiment` with the project's slug (`experiment: "skill-tree"`).
- **Tracking plan first:** add each new event to the project's tracking plan in Amplitude, with a description and category, when it ships. Nothing should arrive as "unexpected".
- **Renaming an event:** rename it in code, then merge the old name into the new one in Amplitude so history stays connected. Don't rename in Amplitude alone.
- **New product:** create its Amplitude project and add a row for it to the "All projects overview" dashboard. A new experiment on kylepace.dev needs neither: it appears there by page path.

### Self-host everything; approve outside hosts one at a time

- Serve libraries, fonts and assets from the project itself. Install them from npm and bundle them, or keep a pinned copy in the repo (for example in `vendor/`) with a script that refreshes it. Never load them from a CDN like jsDelivr, unpkg or cdnjs.
- **Scripts, styles, fonts and APIs** from an outside host need Kyle's OK every time. Approvals are per project and per host. Once he approves, add the host to that project's `.agents/allowed-hosts.txt` with a comment saying what it's for and the date he approved it.
- **Images** are lighter, because an outside image can only learn that someone visited, not run code. An image host can be added without asking when the image belongs to the content being shown (a recipe site's own photo on a result for its recipe, a book's cover from the library that lists it). Load those images with `referrerpolicy="no-referrer"` and `loading="lazy"`, add the host to `.agents/allowed-hosts.txt` with a comment saying what it's for, and mention the new host to Kyle when you report back. Decorative images, stock photos and anything that looks like tracking still need his OK.
- All of this applies to hosts that JavaScript calls at runtime too, even though the CI check only sees HTML and CSS. List those in the same file.

### Look and feel: no generated defaults

- Before building a page or app's look, write a short plan in `design/PLAN.md`: the subject and who it's for, the one bold element, 4 to 6 named colors (light and dark), and the layout as a sketch. Take the ideas from the subject's own world, not from other websites. If a frontend-design skill is available, load it.
- Check the plan against the generated defaults and change anything that matches: a big headline over a muted sentence and a pill button; pills or one corner radius on everything; grids of identical cards; small labels above headings; colored dots or squares as decoration; details joined with middle dots; monospace for small labels; copy that explains the interface instead of using it.
- Spend boldness in one place and keep the rest quiet. Look at screenshots (phone and desktop, light and dark) before calling it done.
- Experiments on kylepace.dev are their own pages (kp-design's `LabLayout`) with their own look. The app comes first; the explanation goes in an About section linked from the top bar.

### How things get built

- Static and simple by default. Add JavaScript, servers or dependencies only where they earn it.
- Colors, type and spacing live in one tokens file. Light and dark mode exist from the start.
- Copy is plain language, written for the person using it.
- Don't add "Built with AI" lines or other AI credits to sites or apps unless Kyle asks.

### Teach Kyle as you go

Kyle is a product leader building his development skills through this work. Treat each session as a chance to teach, briefly.

- When a change involves a real decision (data structure, architecture, a library, security, performance, a tradeoff), explain it in plain language: what you chose, the main alternative, and why. A short paragraph, not a lecture.
- After making changes, show the most important part of the diff and walk through what it does in plain terms. Point out one thing worth learning from it.
- Define jargon the first time it comes up in a session.
- When a change is small and safe (a color, copy, a value, spacing), offer to let Kyle make it by hand, and tell him which file and line to change.
- Skip all of this for trivial changes like typos and formatting.

### Every new page or project ships with

- A share card (Open Graph image, 1200×630) in dark mode, using Atkinson. Follow `.agents/skills/share-card/SKILL.md`.
- A real title, description and favicon.
- A privacy note if it collects anything.

### Before you call it done

- The build passes, and so do any tests and linters.
- Run an accessibility check on what changed (axe on the web, Accessibility Inspector on Apple platforms), fix what it finds, and tab through new UI with the keyboard.
- Look at it in both light and dark mode at phone, tablet and desktop sizes: on the web at least 320, 768, 1280 and 1920 px wide; for Apple apps on the smallest iPhone, a large iPhone and an iPad in portrait, landscape and Split View.
- CI runs a third-party check that fails if a page loads scripts, styles, fonts or images from a host that isn't allowed. Don't add a host just to get past it: ask Kyle, or for a content image follow the image rule above.

<!-- END principles -->

## This project: World cuisine

A globe and a linked-page browser for the world's cuisines, with Wikipedia as the source of truth and Kyle's hand-picked cookbooks and recipe sites on top. Live at [kylepace.dev/world-cuisine](https://kylepace.dev/world-cuisine/), one of the experiments on the [kylepace.dev](https://github.com/kyle-pace/kylepace.dev) hub. It was called Cuisine Explorer and lived at kylepace.net/labs/cuisines/ (which now redirects). See README.md for how the data works.

- **The explorer itself** is two static pages, `index.html` (the globe) and `web.html` (the page browser), plus `data/`, `vendor/` and `render_item.js`. They stay at the repo root as the source. `scripts/update.sh` rebuilds the data and runs weekly in GitHub Actions.
- **The site around it** is Astro on its own Cloudflare Worker (`world-cuisine`), mounted on `kylepace.dev/world-cuisine` by the routes in `wrangler.jsonc`:
  - `src/pages/world-cuisine/index.astro`: the framed page with the header, credits and counts.
  - `src/pages/world-cuisine/[type]/[slug].astro`: about 3,600 cuisine, dish and ingredient pages, rendered on request with `render_item.js` (noindex).
  - `src/pages/world-cuisine/img/[...path].ts`: the photo route. Fetches each listed Wikimedia photo once and keeps it in the R2 bucket `kylepace-cuisine-images` (binding `CUISINE_IMAGES`).
  - `scripts/stage-app.mjs` copies the explorer into `public/world-cuisine/app/` before every build (gitignored). A new top-level file the pages need has to be added there too.
- **Everything this site serves lives under `/world-cuisine/`.** Don't use Astro's `base` option; with the Cloudflare adapter it serves files from the wrong folder.
- **The page shell comes from [kp-design](https://github.com/kyle-pace/kp-design)** (`DevLayout`: header, footer, tokens, display settings and analytics to the shared kylepace.dev Amplitude project), pinned to a commit in package.json.
- **Search:** only `/world-cuisine/` is indexed. The full-screen app (`public/_headers`), item pages and photos are noindex so they don't swamp kylepace.dev in search.
- The iOS app in `ios/` links to `kylepace.dev/world-cuisine/<type>/<slug>/` for sharing.
- The font (Atkinson Hyperlegible Next) and the graph libraries (globe.gl, force-graph) are self-hosted in `vendor/`. Change versions in `scripts/update-vendor.sh` and run it; don't link to a CDN.
- The share card is `scripts/og-card.html`, rendered to `og.png` by `node scripts/render-og.mjs`.
- Kyle picks the cookbooks and recipe sites himself in `data/picks.json`. Don't add picks unless he asks.
- Run `npm run build` before pushing; it must pass. Cloudflare Workers Builds deploys `main`.
