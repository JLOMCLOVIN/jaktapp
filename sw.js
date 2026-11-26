// Enkel service worker: gjør siden installerbar. Henter alltid fra nettet,
// slik at nye versjoner kommer med en gang.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => {});
