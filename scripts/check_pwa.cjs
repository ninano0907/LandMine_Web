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
(async () => {
  await checkBoot(() => new Promise(() => {}));
  await checkBoot(() => Promise.reject(new Error('Cache install failed')));
  await checkBoot(() => Promise.resolve({}));
  const sw = fs.readFileSync('sw.js', 'utf8');
  const assets = JSON.parse(sw.match(/const ASSETS = (.*);/)[1]);
  const tracked = new Set(execFileSync('git', ['ls-files'], {encoding:'utf8'}).trim().split('\n'));
  for (const asset of assets) {
    if (asset === './') continue;
    const file = asset.replace(/^\.\//, '');
    assert(tracked.has(file), `Precache asset must be deployed: ${file}`);
    assert(fs.existsSync(file));
  }
  console.log(`PASS: boot with pending/failed/ready service worker; ${assets.length} deployed cache assets.`);
})().catch(error => {console.error(error); process.exitCode = 1;});
