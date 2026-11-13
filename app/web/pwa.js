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
async function startGame() {
  if ('serviceWorker' in navigator) {
    try {
      await navigator.serviceWorker.register('./sw.js');
      await navigator.serviceWorker.ready;
      if (!navigator.serviceWorker.controller) {
        await Promise.race([
          new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once:true})),
          new Promise(resolve => setTimeout(resolve, 4000))
        ]);
      }
    } catch (error) { console.error(error); }
  }
  const bootstrap = document.createElement('script');
  bootstrap.src = 'flutter_bootstrap.js';
  bootstrap.async = true;
  bootstrap.onerror = () => { document.querySelector('#loading p').textContent = '로딩에 실패했습니다. 인터넷 연결을 확인하고 새로고침해 주세요.'; };
  document.body.appendChild(bootstrap);
}
startGame();
