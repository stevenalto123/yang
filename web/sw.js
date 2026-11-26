// LifeCheckpoint True Offline-First Service Worker
// Network-First (with fast fallback) for App Shell; Cache-First for CanvasKit, Fonts, Assets & Map Tiles
const CACHE_NAME = 'lifecheckpoint-pwa-v37';
const RUNTIME_CACHE_NAME = 'lifecheckpoint-runtime-v1';
const TILE_CACHE_NAME = 'lifecheckpoint-map-tiles-v1';

// Core app shell & assets (automatically expanded with canvaskit/* & assets/** by scripts/build-web.mjs)
const PRECACHE_URLS = [
  './',
  './index.html',
  './manifest.json',
  './flutter_bootstrap.js',
  './main.dart.js',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
  './version.json',
  './assets/FontManifest.json',
  './assets/AssetManifest.bin.json',
  './assets/fonts/MaterialIcons-Regular.otf'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) =>
      // Resilient precache: never abort install if one optional asset fails
      Promise.allSettled(
        PRECACHE_URLS.map((url) =>
          cache.add(new Request(url, { cache: 'reload' })).catch(() => {})
        )
      )
    )
  );
});

self.addEventListener('activate', (event) => {
  const keep = new Set([CACHE_NAME, RUNTIME_CACHE_NAME, TILE_CACHE_NAME]);
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => !keep.has(key))
            .map((oldKey) => caches.delete(oldKey))
        )
      )
      .then(() => self.clients.claim())
  );
});

function isCdnRuntimeAsset(url) {
  return (
    url.hostname === 'www.gstatic.com' ||
    url.hostname === 'fonts.gstatic.com' ||
    url.hostname === 'fonts.googleapis.com'
  );
}

async function networkWithTimeout(req, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(req, { signal: controller.signal });
    clearTimeout(timer);
    return res;
  } catch (err) {
    clearTimeout(timer);
    throw err;
  }
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // 1. Cache-First for OpenStreetMap street tiles (offline map viewing)
  if (url.hostname.endsWith('tile.openstreetmap.org')) {
    event.respondWith(
      caches.open(TILE_CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(req);
        if (cached) return cached;
        try {
          const response = await fetch(req);
          if (response && (response.ok || response.type === 'opaque')) {
            cache.put(req, response.clone()).catch(() => {});
          }
          return response;
        } catch {
          return new Response('', { status: 503, statusText: 'Offline' });
        }
      })
    );
    return;
  }

  // 2. Cache-First for Google Fonts & Flutter CanvasKit CDN fallback (critical for offline boot)
  if (isCdnRuntimeAsset(url)) {
    event.respondWith(
      caches.open(RUNTIME_CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(req);
        if (cached) return cached;
        try {
          const response = await fetch(req);
          if (response && (response.ok || response.type === 'opaque')) {
            cache.put(req, response.clone()).catch(() => {});
          }
          return response;
        } catch {
          return new Response('', { status: 503, statusText: 'Offline' });
        }
      })
    );
    return;
  }

  // Ignore other external APIs (Open-Meteo, USGS, Nominatim) so Flutter's offline fallback handles them
  if (url.origin !== self.location.origin) return;

  // Never intercept backend API routes or service worker scripts
  if (
    url.pathname.startsWith('/api/') ||
    url.pathname.startsWith('/.netlify/') ||
    url.pathname.endsWith('/sw.js') ||
    url.pathname.endsWith('/flutter_service_worker.js')
  ) {
    return;
  }

  // 3. Network-First with fast timeout & instant offline fallback for navigations & core app shell
  const isAppShell =
    req.mode === 'navigate' ||
    url.pathname === '/' ||
    url.pathname.endsWith('/index.html') ||
    url.pathname.endsWith('/main.dart.js') ||
    url.pathname.endsWith('/flutter_bootstrap.js') ||
    url.pathname.endsWith('/version.json') ||
    url.pathname.endsWith('/manifest.json');

  if (isAppShell) {
    event.respondWith(
      (async () => {
        const cache = await caches.open(CACHE_NAME);
        const cacheKey = req.mode === 'navigate' ? './index.html' : req;
        const cached =
          (await cache.match(cacheKey, { ignoreSearch: true })) ||
          (req.mode === 'navigate' ? await cache.match('./') : undefined);

        try {
          // If we already have a cached copy, don't hang longer than 3.5s on dead Wi-Fi
          const response = cached
            ? await networkWithTimeout(req, 3500)
            : await fetch(req);
          if (response && response.status === 200 && response.type === 'basic') {
            cache.put(cacheKey, response.clone()).catch(() => {});
          }
          return response;
        } catch {
          if (cached) return cached;
          const rootFallback = await cache.match('./index.html');
          if (rootFallback) return rootFallback;
          return new Response('Offline — please reconnect once to load LifeCheckpoint.', {
            status: 503,
            headers: { 'Content-Type': 'text/plain; charset=utf-8' },
          });
        }
      })()
    );
    return;
  }

  // 4. Cache-First for bundled CanvasKit, fonts, icons, and Flutter assets
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(req, { ignoreSearch: true });
      if (cached) return cached;
      try {
        const response = await fetch(req);
        if (response && response.status === 200 && response.type === 'basic') {
          cache.put(req, response.clone()).catch(() => {});
        }
        return response;
      } catch {
        return new Response('', { status: 503, statusText: 'Offline' });
      }
    })
  );
});
