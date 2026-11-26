// Service worker for Jaktlaget
// - Appen (siden, Leaflet, Supabase-biblioteket, ikoner) lagres, så den starter uten dekning.
// - Topokart fra Kartverket hentes fra lageret først (offline-kart), og nye kartbiter lagres når de lastes.
// - Alt annet (posisjoner, meldinger, vær, flyfoto) går rett mot nettet.

const APP = 'jakt-app-v1';
const KART = 'jakt-kart';
const APPFILER = [
  './', 'index.html', 'manifest.json', 'ikon-180.png', 'ikon-192.png', 'ikon-512.png',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
  'https://unpkg.com/leaflet@1.9.4/dist/images/layers.png',
  'https://unpkg.com/leaflet@1.9.4/dist/images/layers-2x.png',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(APP).then(c => Promise.all(APPFILER.map(u =>
    fetch(u, { cache: 'no-cache' }).then(r => r.ok && c.put(u, r)).catch(() => {})))));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(k => Promise.all(
    k.filter(n => n.startsWith('jakt-app-') && n !== APP).map(n => caches.delete(n))))
    .then(() => self.clients.claim()));
});

function medTidsavbrudd(p, ms) {
  return new Promise((ok, feil) => { const t = setTimeout(() => feil(new Error('tidsavbrudd')), ms); p.then(v => { clearTimeout(t); ok(v); }, e => { clearTimeout(t); feil(e); }); });
}

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Topokart: lageret først, ellers nett (og lagre)
  if (url.hostname === 'cache.kartverket.no') {
    e.respondWith(caches.open(KART).then(async c => {
      const lagret = await c.match(req.url);
      if (lagret) return lagret;
      const svar = await fetch(req.url, { mode: 'cors' });
      if (svar.ok) c.put(req.url, svar.clone());
      return svar;
    }));
    return;
  }

  // Selve siden: nett først (ny versjon med en gang), lageret ved dårlig/ingen dekning
  if (req.mode === 'navigate' || (url.origin === location.origin && url.pathname.endsWith('/index.html'))) {
    e.respondWith((async () => {
      const c = await caches.open(APP);
      try {
        const svar = await medTidsavbrudd(fetch(req, { cache: 'no-cache' }), 5000);
        if (svar.ok) c.put('index.html', svar.clone());
        return svar;
      } catch (_) {
        return (await c.match('index.html')) || (await c.match('./')) || Response.error();
      }
    })());
    return;
  }

  // Biblioteker og ikoner: lageret først
  if (APPFILER.some(f => req.url === f || req.url.endsWith('/' + f))) {
    e.respondWith(caches.open(APP).then(async c => (await c.match(req.url)) || fetch(req).then(svar => {
      if (svar.ok) c.put(req.url, svar.clone());
      return svar;
    })));
  }
});
