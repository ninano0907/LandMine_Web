"""Generate an atomic offline cache from the exact Flutter build output."""
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parent.parent
build = root / 'app/build/web'
files = sorted(p for p in build.rglob('*') if p.is_file() and p.name not in ('sw.js', 'flutter_service_worker.js') and not any(part.startswith('.') for part in p.relative_to(build).parts))
version = hashlib.sha256(b''.join(p.read_bytes() for p in files)).hexdigest()[:16]
assets = ['./'] + ['./' + p.relative_to(build).as_posix() for p in files]
(root / 'sw.js').write_text('''const CACHE = 'landmine-web-v2-''' + version + '''';
const ASSETS = ''' + json.dumps(assets) + ''';
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
    // Refresh the entry page and startup script so installed apps receive fixes.
    if (event.request.mode === 'navigate' || url.pathname.endsWith('/pwa.js')) {
      try {
        const response = await fetch(event.request);
        if (response.ok) {
          await cache.put(event.request, response.clone());
          return response;
        }
      } catch (_) {}
    }
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
''')
print(f'Offline cache: {len(assets)} assets, {version}')
