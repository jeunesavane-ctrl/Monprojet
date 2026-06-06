const CACHE = 'ml-v4';
const STATIC = [
  'index.html','dashboard.html','rapport.html','historique.html',
  'produits.html','rh.html','finances.html','parametres.html',
  'associes.html','shared.css','shared.js'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(STATIC)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  if (e.request.url.includes('supabase.co') || e.request.url.includes('googleapis')) {
    e.respondWith(fetch(e.request).catch(() => new Response('', {status:503})));
    return;
  }
  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request))
  );
});
