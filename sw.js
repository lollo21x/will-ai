const CACHE = 'will-ai-v5';
const SHELL = ['./', './index.html', './manifest.webmanifest', './icon.svg', './apple-touch-icon.png', './icon-192.png', './icon-512.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL).catch(() => {}))); self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(x => x !== CACHE && !x.startsWith('webllm/')).map(x => caches.delete(x))))); self.clients.claim(); });
const put = (req, r) => { if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return r; };
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.origin === location.origin) {
    // App files: network first, so updates arrive immediately; cache as offline fallback.
    e.respondWith(fetch(e.request).then(r => put(e.request, r)).catch(() => caches.match(e.request)));
  } else if (['cdn.jsdelivr.net', 'fonts.googleapis.com', 'fonts.gstatic.com'].includes(url.hostname)) {
    // Library and fonts: cache first (versions are pinned).
    e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request).then(r => put(e.request, r))));
  }
});
