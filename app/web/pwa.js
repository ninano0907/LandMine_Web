let audio;
function unlockAudio() {
  const Audio = window.AudioContext || window.webkitAudioContext;
  if (!Audio) return;
  audio ||= new Audio();
  if (audio.state === 'suspended') audio.resume().catch(() => {});
}
document.addEventListener('pointerdown', unlockAudio, {passive:true});
window.landmineBeep = () => {
  if (!audio || audio.state !== 'running') return;
  const tone = audio.createOscillator(), gain = audio.createGain(), now = audio.currentTime;
  tone.frequency.value = 880;
  gain.gain.setValueAtTime(0, now);
  gain.gain.linearRampToValueAtTime(.18, now + .005);
  gain.gain.linearRampToValueAtTime(0, now + .08);
  tone.connect(gain); gain.connect(audio.destination);
  tone.start(now); tone.stop(now + .08);
};
document.addEventListener('contextmenu', event => event.preventDefault());
window.addEventListener('flutter-first-frame', () => document.getElementById('loading')?.remove());
const install = document.getElementById('install');
let prompt;
window.addEventListener('beforeinstallprompt', event => {
  event.preventDefault(); prompt = event; install.hidden = false;
});
install.addEventListener('click', async () => {
  if (!prompt) return;
  await prompt.prompt(); prompt = null; install.hidden = true;
});
window.addEventListener('appinstalled', () => { install.hidden = true; });
function startGame() {
  const bootstrap = document.createElement('script');
  bootstrap.src = 'flutter_bootstrap.js';
  bootstrap.async = true;
  bootstrap.onerror = () => { document.querySelector('#loading p').textContent = '로딩에 실패했습니다. 인터넷 연결을 확인하고 새로고침해 주세요.'; };
  document.body.appendChild(bootstrap);
}
// Local development must not keep rendering a previously cached game.
const localGame = typeof location !== 'undefined' &&
  ['localhost', '127.0.0.1', '[::1]'].includes(location.hostname);
async function startLocalGame() {
  let controlled = false;
  if ('serviceWorker' in navigator) {
    const ownWorker = worker => worker && /\/(sw|flutter_service_worker)\.js(?:\?|$)/.test(worker.scriptURL);
    controlled = !!ownWorker(navigator.serviceWorker.controller);
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.filter(registration =>
      ownWorker(registration.active || registration.waiting || registration.installing)
    ).map(registration => registration.unregister()));
  }
  if (typeof caches !== 'undefined') {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith('landmine-web-') ||
      key.startsWith('rts-preview-')).map(key => caches.delete(key)));
  }
  if (controlled && !sessionStorage.getItem('frontier-local-cache-cleaned')) {
    sessionStorage.setItem('frontier-local-cache-cleaned', '1');
    location.reload();
    return;
  }
  if (!controlled) sessionStorage.removeItem('frontier-local-cache-cleaned');
  startGame();
}
if (localGame) {
  startLocalGame().catch(error => { console.error(error); startGame(); });
} else {
  // Start immediately; a failed or offline service worker must not block play.
  startGame();
  if ('serviceWorker' in navigator) {
    let reloadingForUpdate = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      // An updated worker owns a new asset cache. Reload to use that build.
      if (!reloadingForUpdate) {
        reloadingForUpdate = true;
        location.reload();
      }
    });
    navigator.serviceWorker.register('./sw.js', {updateViaCache: 'none'})
      .then(registration => {
        registration.update().catch(console.error);
        window.addEventListener('pageshow', () => {
          registration.update().catch(console.error);
        });
        document.addEventListener('visibilitychange', () => {
          if (document.visibilityState === 'visible') {
            registration.update().catch(console.error);
          }
        });
      })
      .catch(console.error);
  }
}
