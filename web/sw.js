// LifeCheckpoint Offline-Ready Service Worker (Network-First for App Shell, Cache-First for Map Tiles & Assets)
const CACHE_NAME = 'lifecheckpoint-pwa-v27';
const TILE_CACHE_NAME = 'lifecheckpoint-map-tiles-v1';

// Core app shell precached for instant offline launch
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

  // Cache-First for OpenStreetMap street tiles (fast & low-data offline viewing)
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

  // Never intercept API endpoints or service worker scripts
  if (
    url.pathname.startsWith('/api/') ||
    url.pathname.startsWith('/.netlify/') ||
    url.pathname.endsWith('/sw.js') ||
    url.pathname.endsWith('/flutter_service_worker.js')
  ) {
    return;
  }

  // Network-First with Offline Cache Fallback for navigations & core app bundles
  // Ensures every new deploy loads immediately when online while staying 100% offline-capable
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
      fetch(req)
        .then((response) => {
          if (response && response.status === 200 && response.type === 'basic') {
            const clone = response.clone();
            const cacheKey = req.mode === 'navigate' ? './index.html' : req;
            caches.open(CACHE_NAME).then((cache) => cache.put(cacheKey, clone));
          }
          return response;
        })
        .catch(() =>
          caches.match(req.mode === 'navigate' ? './index.html' : req, {
            ignoreSearch: true,
          }).then((cached) => cached || caches.match('./'))
        )
    );
    return;
  }

  // Cache-First for static icons, fonts, and assets
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
