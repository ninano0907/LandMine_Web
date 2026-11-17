const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {execFileSync} = require('node:child_process');
const source = fs.readFileSync('app/web/pwa.js', 'utf8');
assert.equal(source, fs.readFileSync('pwa.js', 'utf8'));
async function checkBoot(register) {
  const scripts = [];
  const button = {addEventListener() {}};
  const context = {
    console: {error() {}},
    document: {
      addEventListener() {},
      getElementById() {return button;},
      createElement() {return {};},
      body: {appendChild(script) {scripts.push(script);}},
    },
    window: {addEventListener() {}},
    navigator: {serviceWorker: {register, ready: new Promise(() => {})}},
  };
  vm.runInNewContext(source, context);
  assert.equal(scripts.length, 1, 'Game must boot without waiting for service worker readiness');
  assert.equal(scripts[0].src, 'flutter_bootstrap.js');
  await new Promise(resolve => setImmediate(resolve));
}
async function checkLocalBoot(controlled) {
  const scripts = [], removed = [], deleted = [];
  let reloads = 0;
  const storage = new Map();
  const context = {
    console: {error() {}},
    document: {addEventListener() {}, getElementById() {return {addEventListener() {}};}, createElement() {return {};}, body: {appendChild(script) {scripts.push(script);}}},
    window: {addEventListener() {}},
    location: {hostname: 'localhost', reload() {reloads++;}},
    sessionStorage: {getItem(key) {return storage.get(key);}, setItem(key, value) {storage.set(key, value);}, removeItem(key) {storage.delete(key);}},
    navigator: {serviceWorker: {
      controller: controlled ? {scriptURL: 'http://localhost:8081/sw.js'} : null,
      register() {throw new Error('Local builds must not register an offline worker');},
      async getRegistrations() {return ['sw.js', 'flutter_service_worker.js', 'other-worker.js'].map(name => ({active: {scriptURL: `http://localhost:8081/${name}`}, async unregister() {removed.push(name); return true;}}));},
    }},
    caches: {async keys() {return ['landmine-web-old', 'rts-preview-old', 'unrelated-cache'];}, async delete(key) {deleted.push(key); return true;}},
  };
  vm.runInNewContext(source, context);
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(removed.sort(), ['flutter_service_worker.js', 'sw.js']);
  assert.deepEqual(deleted.sort(), ['landmine-web-old', 'rts-preview-old']);
  assert.equal(reloads, controlled ? 1 : 0);
  assert.equal(scripts.length, controlled ? 0 : 1);
}
(async () => {
  await checkLocalBoot(true);
  await checkLocalBoot(false);
  await checkBoot(() => new Promise(() => {}));
  await checkBoot(() => Promise.reject(new Error('Cache install failed')));
  await checkBoot(() => Promise.resolve({}));
  const sw = fs.readFileSync('sw.js', 'utf8');
  const assets = JSON.parse(sw.match(/const ASSETS = (.*);/)[1]);
  const gitArgs = process.argv.includes('--working-tree')
    ? ['ls-files', '--cached', '--others', '--exclude-standard'] : ['ls-files'];
  const tracked = new Set(execFileSync('git', gitArgs, {encoding:'utf8'}).trim().split('\n'));
  for (const asset of assets) {
    if (asset === './') continue;
    const file = asset.replace(/^\.\//, '');
    assert(tracked.has(file), `Precache asset must be deployed: ${file}`);
    assert(fs.existsSync(file));
  }
  console.log(`PASS: local stale-cache cleanup, production boot with pending/failed/ready service worker; ${assets.length} deployed cache assets.`);
})().catch(error => {console.error(error); process.exitCode = 1;});
