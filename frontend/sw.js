const CACHE = 'sig-sols-v10';
const ASSETS = [
  '/frontend/index.html',
  '/frontend/css/style.css',
  '/frontend/css/enhancements.css',
  '/frontend/css/animations.css',
  '/frontend/css/features-extended.css',
  '/frontend/css/ux-shell.css',
  '/frontend/css/luxury.css',
  '/frontend/js/init.js',
  '/frontend/js/api.js',
  '/frontend/js/auth.js',
  '/frontend/js/features.js',
  '/frontend/js/map.js',
  '/frontend/js/parcel.js',
  '/frontend/js/core/parcelExternal.js',
  '/frontend/js/sentinelMap.js',
  '/frontend/js/weatherMap.js',
  '/frontend/js/dashboard.js',
  '/frontend/js/quiz.js',
  '/frontend/js/tools.js',
  '/frontend/js/chat.js',
  '/frontend/js/videos.js',
  '/frontend/js/community.js',
  '/frontend/js/featuresHub.js',
  '/frontend/js/animations.js',
  '/frontend/js/app.js',
  '/frontend/js/core/toast.js',
  '/frontend/js/core/i18n.js',
  '/frontend/js/core/theme.js',
  '/frontend/js/core/ui.js',
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
  // JS/CSS : network-first pour éviter UI stale (flicker / features fantômes)
  const isCode = /\.(js|mjs|css)(\?|$)/i.test(url) || url.includes('/js/') || url.includes('/css/');
  if (isCode) {
    e.respondWith(
      fetch(e.request)
        .then((res) => {
          if (res.ok && url.includes('/frontend/')) {
            const clone = res.clone();
            caches.open(CACHE).then((c) => c.put(e.request, clone));
          }
          return res;
        })
        .catch(() => caches.match(e.request)),
    );
    return;
  }
  e.respondWith(
    caches.match(e.request).then((cached) => {
      const fetched = fetch(e.request).then((res) => {
        if (res.ok && url.includes('/frontend/')) {
          const clone = res.clone();
          caches.open(CACHE).then((c) => c.put(e.request, clone));
        }
        return res;
      });
      return cached || fetched;
    }),
  );
});
