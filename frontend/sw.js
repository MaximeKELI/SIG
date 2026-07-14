const CACHE = 'sig-sols-v14';

// Ne pré-cache plus le JS/CSS (évite les écrans noirs après déploiement local)
const ASSETS = [
  '/frontend/index.html',
  '/frontend/manifest.json',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))),
    ).then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (e) => {
  const url = e.request.url;
  if (url.includes('/api/')) return;
  if (e.request.method !== 'GET') return;
  // Network-first pour CSS/JS — pas de stale cache
  if (url.includes('/css/') || url.includes('/js/') || url.includes('.css') || url.includes('.js')) {
    e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
    return;
  }
  e.respondWith(
    caches.match(e.request).then((cached) => {
      const fetched = fetch(e.request).then((res) => {
        if (res.ok && url.includes('/frontend/') && !url.includes('/css/') && !url.includes('/js/')) {
          const clone = res.clone();
          caches.open(CACHE).then((c) => c.put(e.request, clone));
        }
        return res;
      });
      return cached || fetched;
    }),
  );
});
