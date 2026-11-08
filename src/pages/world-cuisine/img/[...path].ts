// Photos for World cuisine: /world-cuisine/img/<path under /wikipedia/commons/>.
//
// Every photo is a freely licensed file on Wikimedia Commons (credited where it's shown).
// The explorer's weekly rebuild lists the ones we use, at one of Wikimedia's standard thumbnail widths
// (data/web/images.json, served at /world-cuisine/app/data/web/images.json); anything else is refused, so this
// can't be used to fetch arbitrary files. Each photo is fetched from Wikimedia once, with a
// User-Agent naming this site as Wikimedia's policy asks, then kept: in the R2 bucket when
// one is bound (CUISINE_IMAGES in wrangler.jsonc), and in Cloudflare's edge cache.
import type { APIRoute } from 'astro';
import { env } from 'cloudflare:workers';

export const prerender = false;

const UA = 'WorldCuisine/1.0 (https://kylepace.dev/world-cuisine/) kylepace.dev-worker';
const YEAR = 60 * 60 * 24 * 365;
const SHAPE = /^(thumb\/)?[0-9a-f]\/[0-9a-f]{2}\/[^/]+(\/\d+px-[^/]+)?$/;

type R2 = {
  get(key: string): Promise<{ body: ReadableStream; httpMetadata?: { contentType?: string } } | null>;
  put(key: string, value: ArrayBuffer, opts?: { httpMetadata?: { contentType?: string } }): Promise<unknown>;
};
type Bindings = { ASSETS?: { fetch(r: Request): Promise<Response> }; CUISINE_IMAGES?: R2 };

// Decoded path -> the path as Wikimedia writes it (percent-encoded)
let allowed: Promise<Map<string, string>> | null = null;
const decode = (s: string) => { try { return decodeURIComponent(s); } catch { return s; } };
function allowList(origin: string, assets?: Bindings['ASSETS']) {
  if (!allowed) {
    const req = new Request(new URL('/world-cuisine/app/data/web/images.json', origin));
    allowed = (assets ? assets.fetch(req) : fetch(req))
      .then((r) => (r.ok ? r.json() : []))
      .then((list) => new Map((list as string[]).map((p) => [decode(p), p])))
      .catch(() => {
        allowed = null;
        return new Map<string, string>();
      });
  }
  return allowed;
}

const image = (body: BodyInit, type: string) =>
  new Response(body, {
    headers: {
      'content-type': type,
      'cache-control': `public, max-age=${YEAR}, immutable`,
      'x-content-type-options': 'nosniff',
      // Kept out of image search, like the explorer's pages
      'x-robots-tag': 'noindex',
    },
  });

export const GET: APIRoute = async ({ params, request, locals }) => {
  const asked = decode(params.path ?? '');
  if (!SHAPE.test(asked)) return new Response('Not found', { status: 404 });

  const cache = typeof caches !== 'undefined' ? (caches as unknown as { default?: Cache }).default : undefined;
  const cacheKey = new Request(new URL(request.url).origin + new URL(request.url).pathname);
  const hit = await cache?.match(cacheKey);
  if (hit) {
    // Copies cached before noindex was added don't carry the header
    const res = new Response(hit.body, hit);
    res.headers.set('x-robots-tag', 'noindex');
    return res;
  }

  const bindings = env as unknown as Bindings;
  const path = (await allowList(request.url, bindings.ASSETS)).get(asked);
  if (!path) return new Response('Not found', { status: 404 });
  const ctx = (locals as { cfContext?: { waitUntil(p: Promise<unknown>): void } }).cfContext;
  const keep = (res: Response) => { if (cache && ctx) ctx.waitUntil(cache.put(cacheKey, res.clone())); return res; };

  // Stored copy first
  const stored = await bindings.CUISINE_IMAGES?.get(path).catch(() => null);
  if (stored) return keep(image(stored.body, stored.httpMetadata?.contentType || 'image/jpeg'));

  // First time anyone asks: fetch it once from Wikimedia
  // Thumbnails come from thumb.wikimedia.org, small originals from upload.wikimedia.org
  const host = path.startsWith('thumb/') ? 'thumb.wikimedia.org' : 'upload.wikimedia.org';
  const upstream = await fetch(`https://${host}/wikipedia/commons/${path}`, { headers: { 'user-agent': UA } }).catch(() => null);
  if (!upstream || !upstream.ok) return new Response('Photo unavailable', { status: 502, headers: { 'cache-control': 'no-store' } });
  const type = upstream.headers.get('content-type') || 'image/jpeg';
  if (!type.startsWith('image/')) return new Response('Not found', { status: 404 });
  const bytes = await upstream.arrayBuffer();
  if (bindings.CUISINE_IMAGES && ctx) ctx.waitUntil(bindings.CUISINE_IMAGES.put(path, bytes, { httpMetadata: { contentType: type } }));
  return keep(image(bytes, type));
};
