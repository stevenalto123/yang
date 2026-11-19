// LifeCheckpoint Offline-First Service Worker
const CACHE_NAME = 'lifecheckpoint-pwa-v8';
const TILE_CACHE_NAME = 'lifecheckpoint-map-tiles-v1';

// Populated cleanly from build/web/ during build (or core fallback shell)
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
  './version.json'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key !== CACHE_NAME && key !== TILE_CACHE_NAME)
            .map((oldKey) => caches.delete(oldKey))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // Cache OpenStreetMap street tiles for offline map viewing
  if (url.hostname.endsWith('tile.openstreetmap.org')) {
    event.respondWith(
      caches.open(TILE_CACHE_NAME).then((cache) =>
        cache.match(req).then((cached) => {
          if (cached) return cached;
          return fetch(req).then((response) => {
            if (response && response.ok) {
              cache.put(req, response.clone());
            }
            return response;
          });
        })
      )
    );
    return;
  }

  if (url.origin !== self.location.origin) return;

  // Never intercept API endpoints or stale service worker scripts
  if (
    url.pathname.startsWith('/api/') ||
    url.pathname.startsWith('/.netlify/') ||
    url.pathname.endsWith('/sw.js') ||
    url.pathname.endsWith('/flutter_service_worker.js')
  ) {
    return;
  }

  if (req.mode === 'navigate') {
    event.respondWith(
      caches.match('./index.html').then((cached) => {
        return cached || fetch(req).catch(() => caches.match('./'));
      })
    );
    return;
  }

  event.respondWith(
    caches.match(req, { ignoreSearch: true }).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((response) => {
        if (response && response.status === 200 && response.type === 'basic') {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
        }
        return response;
      });
    })
  );
});
