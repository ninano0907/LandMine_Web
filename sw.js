const CACHE = 'landmine-web-2f52c4abbc8e4896';
const ASSETS = ["./", "./.last_build_id", "./assets/AssetManifest.bin", "./assets/AssetManifest.bin.json", "./assets/FontManifest.json", "./assets/NOTICES", "./assets/fonts/MaterialIcons-Regular.otf", "./assets/packages/cupertino_icons/assets/CupertinoIcons.ttf", "./assets/shaders/ink_sparkle.frag", "./assets/shaders/stretch_effect.frag", "./canvaskit/canvaskit.js", "./canvaskit/canvaskit.js.symbols", "./canvaskit/canvaskit.wasm", "./canvaskit/chromium/canvaskit.js", "./canvaskit/chromium/canvaskit.js.symbols", "./canvaskit/chromium/canvaskit.wasm", "./canvaskit/skwasm.js", "./canvaskit/skwasm.js.symbols", "./canvaskit/skwasm.wasm", "./canvaskit/skwasm_heavy.js", "./canvaskit/skwasm_heavy.js.symbols", "./canvaskit/skwasm_heavy.wasm", "./favicon.png", "./flutter.js", "./flutter_bootstrap.js", "./icon.svg", "./icons/Icon-192.png", "./icons/Icon-512.png", "./icons/Icon-maskable-192.png", "./icons/Icon-maskable-512.png", "./index.html", "./main.dart.js", "./manifest.json", "./manifest.webmanifest", "./pwa.js", "./version.json"];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('landmine-web-') && key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || (url.origin !== self.location.origin && url.hostname !== 'fonts.gstatic.com')) return;
  event.respondWith(caches.open(CACHE).then(async cache => {
    const hit = await cache.match(event.request);
    if (hit) return hit;
    try {
      const response = await fetch(event.request);
      if (url.hostname === 'fonts.gstatic.com' && (response.ok || response.type === 'opaque')) {
        await cache.put(event.request, response.clone());
      }
      return response;
    }
    catch (error) {
      if (event.request.mode === 'navigate') return cache.match('./index.html');
      throw error;
    }
  }));
});
