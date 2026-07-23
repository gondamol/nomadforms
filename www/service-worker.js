// NomadForms service worker — offline app shell.
// Only same-origin assets are precached; the app must open with no network.
// API calls are never cached (submissions queue in IndexedDB instead), so a
// stale response can never be shown as if it were live data.
const CACHE = 'nomadforms-shell-v1';
const SHELL = ['index.html', 'collect.html', 'manifest.json'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ).then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET') return;            // never intercept writes
  if (url.pathname.startsWith('/api/')) return;      // API is network-only
  // Cache-first for the app shell so it launches instantly and offline.
  e.respondWith(
    caches.match(e.request).then(hit => hit || fetch(e.request).then(res => {
      if (res.ok && url.origin === location.origin) {
        const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy));
      }
      return res;
    }).catch(() => caches.match('index.html')))
  );
});
