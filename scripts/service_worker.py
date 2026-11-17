"""Generate an atomic offline cache from the exact Flutter build output."""
import argparse
import hashlib
import json
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument('--namespace', default='landmine-web')
parser.add_argument('--output', type=Path)
parser.add_argument('--build-dir', type=Path, help='Flutter web output directory')
args = parser.parse_args()
if not args.namespace.replace('-', '').isalnum():
    parser.error('namespace must contain only letters, digits, and hyphens')
root = Path(__file__).resolve().parent.parent
build = args.build_dir or root / 'app/build/web'
if not (build / 'index.html').is_file():
    parser.error(f'Flutter web output is missing: {build}')
files = sorted(p for p in build.rglob('*') if p.is_file() and p.name not in ('sw.js', 'flutter_service_worker.js') and not any(part.startswith('.') for part in p.relative_to(build).parts))
version = hashlib.sha256(b''.join(p.read_bytes() for p in files)).hexdigest()[:16]
assets = ['./'] + ['./' + p.relative_to(build).as_posix() for p in files]
(args.output or root / 'sw.js').write_text('''const CACHE = ''' + json.dumps(args.namespace + '-v2-' + version) + ''';
const CACHE_PREFIX = ''' + json.dumps(args.namespace + '-') + ''';
const ASSETS = ''' + json.dumps(assets) + ''';
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim()));
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
