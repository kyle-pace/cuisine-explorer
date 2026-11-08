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

- **Product analytics: Amplitude**, set up the private way (see `src/lib/analytics.ts` in kylepace.net):
  - autocapture on, IP address tracking off, identity in `localStorage`
  - off under GPC, Do Not Track or the opt-out; only on the live domain
  - Session Replay only if the project wants it: a small sample (about 5%), conservative masking, and its code only loaded for sampled sessions
  - custom event names in Title Case, past-tense verb first: "Clicked Resume", "Saved Recipe"
- **Backend: Firebase** (Auth, Firestore, Functions, Storage) when a project needs accounts or shared data.
  - Security rules deny by default and are locked down before anything ships.
  - Firebase Analytics stays off; Amplitude covers analytics.
- **Web hosting: Cloudflare** (Workers with static assets). GitHub Pages is fine for a simple static site.
- **Apple apps:** native Swift and SwiftUI.
- Put each outside service behind its own module (one file talks to Amplitude, one to Firebase), so switching tools means changing one file.
- Keep running costs near zero: prefer static pages, free tiers and on-device work, and ask before adding anything that bills.

### Self-host everything; approve outside hosts one at a time

- Serve libraries, fonts and assets from the project itself. Install them from npm and bundle them, or keep a pinned copy in the repo (for example in `vendor/`) with a script that refreshes it. Never load them from a CDN like jsDelivr, unpkg or cdnjs.
- If a project needs something from an outside host (cover images from a book API, say), ask Kyle. Approvals are per project and per host. Once he approves, add the host to that project's `.agents/allowed-hosts.txt` with a comment saying what it's for and the date he approved it.
- This applies to hosts that JavaScript calls at runtime too (images, APIs), even though the CI check only sees HTML and CSS. List those in the same file.

### How things get built

- Static and simple by default. Add JavaScript, servers or dependencies only where they earn it.
- Colors, type and spacing live in one tokens file. Light and dark mode exist from the start.
- Copy is plain language, written for the person using it.
- Don't add "Built with AI" lines or other AI credits to sites or apps unless Kyle asks.

### Every new page or project ships with

- A share card (Open Graph image, 1200×630) in dark mode, using Atkinson. Follow `.agents/skills/share-card/SKILL.md`.
- A real title, description and favicon.
- A privacy note if it collects anything.

### Before you call it done

- The build passes, and so do any tests and linters.
- Run an accessibility check on what changed (axe on the web, Accessibility Inspector on Apple platforms), fix what it finds, and tab through new UI with the keyboard.
- Look at it in both light and dark mode, and at a narrow phone width.
- CI runs a third-party check that fails if a page loads scripts, styles, fonts or images from a host that isn't allowed. Don't add a host to get past it; ask Kyle.

<!-- END principles -->

## This project: Cuisine Explorer

A globe and a linked-page browser for the world's cuisines, with Wikipedia as the source of truth and Kyle's hand-picked cookbooks and recipe sites on top. See README.md for how the data works.

- It's two static pages, `index.html` (the globe) and `web.html` (the page browser), plus `data/`. There's no build step for the pages; `scripts/update.sh` rebuilds the data and runs weekly in GitHub Actions.
- kylepace.net copies `index.html`, `web.html`, `render_item.js`, `vendor/` and `data/` into `/labs/cuisines/app/` daily (its `.github/workflows/cuisine-explorer.yml`). If you add a new top-level file the pages need, add it to that copy step too.
- The font (Atkinson Hyperlegible Next) and the graph libraries (globe.gl, force-graph) are self-hosted in `vendor/`. Change versions in `scripts/update-vendor.sh` and run it; don't link to a CDN.
- Kyle picks the cookbooks and recipe sites himself in `data/picks.json`. Don't add picks unless he asks.
