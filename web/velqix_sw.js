/* VelQix — service worker : l'application s'ouvre SANS connexion internet.
 *
 * • Coquille de l'app (HTML, JS, CanvasKit, polices, icônes) : mise en cache au
 *   premier chargement, puis servie depuis le cache.
 * • Pages : réseau d'abord (version à jour), cache si hors connexion.
 * • Photos d'annonces (Cloudinary / Unsplash) : gardées pour l'affichage hors connexion.
 * • API (velqix.onrender.com), appels, polices Google… : jamais interceptés.
 *
 * __BUILD_ID__ est remplacé à chaque déploiement (vercel-build.sh) : un nouveau
 * déploiement crée un nouveau cache, l'ancien est supprimé.
 */
const BUILD_ID = '__BUILD_ID__';
const APP_CACHE = 'velqix-app-' + BUILD_ID;
const IMG_CACHE = 'velqix-img-v1';
const IMG_HOSTS = ['res.cloudinary.com', 'images.unsplash.com'];
const MAX_IMAGES = 150;
const CORE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(APP_CACHE);
    // Un fichier absent ne doit pas faire échouer l'installation
    await Promise.all(
      CORE.map((url) => cache.add(new Request(url, { cache: 'reload' })).catch(() => {}))
    );
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(
      names
        .filter((n) => n !== APP_CACHE && n !== IMG_CACHE)
        .filter((n) => n.startsWith('velqix-app-') || n.startsWith('flutter-'))
        .map((n) => caches.delete(n))
    );
    await self.clients.claim();
  })());
});

function withTimeout(promise, ms) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('timeout')), ms);
    promise.then((v) => { clearTimeout(t); resolve(v); },
                 (e) => { clearTimeout(t); reject(e); });
  });
}

// Pages : réseau d'abord (4 s max), sinon la coquille de l'app en cache
async function navigate(request) {
  const cache = await caches.open(APP_CACHE);
  try {
    const fresh = await withTimeout(fetch(request), 4000);
    if (fresh && fresh.ok) cache.put('index.html', fresh.clone());
    return fresh;
  } catch (_) {
    return (await cache.match('index.html')) ||
           (await cache.match('./')) ||
           Response.error();
  }
}

// Fichiers de l'app : le cache est propre à chaque déploiement → cache d'abord
async function cacheFirst(request) {
  const cache = await caches.open(APP_CACHE);
  const hit = await cache.match(request);
  if (hit) return hit;
  const res = await fetch(request);
  if (res && res.ok && res.type === 'basic') cache.put(request, res.clone());
  return res;
}

// Photos d'annonces : déjà vues = visibles hors connexion
async function imageStrategy(request) {
  const cache = await caches.open(IMG_CACHE);
  const hit = await cache.match(request.url);
  if (hit) return hit;
  try {
    const res = await fetch(request);
    if (res && res.ok && (res.type === 'cors' || res.type === 'basic')) {
      await cache.put(request.url, res.clone());
      const keys = await cache.keys();
      if (keys.length > MAX_IMAGES) {
        await Promise.all(keys.slice(0, keys.length - MAX_IMAGES).map((k) => cache.delete(k)));
      }
    }
    return res;
  } catch (_) {
    return Response.error();
  }
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  if (req.headers.has('range')) return; // vidéos : pas de mise en cache partielle

  const url = new URL(req.url);

  if (IMG_HOSTS.includes(url.hostname)) {
    event.respondWith(imageStrategy(req));
    return;
  }
  if (url.origin !== self.location.origin) return; // API, polices, Agora… : réseau normal

  if (req.mode === 'navigate') {
    event.respondWith(navigate(req));
    return;
  }
  event.respondWith(cacheFirst(req));
});
