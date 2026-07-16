import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const ROOT = path.resolve(import.meta.dirname, '..');

if (typeof vm.SourceTextModule !== 'function') {
  console.error('RUNTIME SMOKE: vm.SourceTextModule unavailable; run with --experimental-vm-modules');
  process.exit(1);
}

function seededMath() {
  let seed = 0x19c0ffee;
  const math = Object.create(Math);
  math.random = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 0x100000000;
  };
  return math;
}

function makeContext() {
  const listeners = [];
  const timers = [];
  const frames = [];
  const elements = new Map();
  const gradient = { addColorStop(){} };
  const context2d = new Proxy({
    canvas:null,
    measureText(text){ return { width:String(text ?? '').length * 6 }; },
    createLinearGradient(){ return gradient; },
    createRadialGradient(){ return gradient; },
    createPattern(){ return {}; },
    getImageData(){ return { data:new Uint8ClampedArray(4) }; },
  }, { get(target, key) { if (key in target) return target[key]; return () => {}; }, set(target, key, value) { target[key] = value; return true; } });

  function makeElement(id='') {
    const element = {
      id, style:{}, dataset:{}, children:[], textContent:'', innerHTML:'', value:'',
      width:800, height:600, clientWidth:800, clientHeight:600,
      classList:{ add(){}, remove(){}, toggle(){}, contains(){ return false; } },
      addEventListener(type, fn){ listeners.push([id, type, fn]); },
      removeEventListener(){}, appendChild(child){ this.children.push(child); return child; },
      remove(){}, focus(){}, blur(){}, setAttribute(){},
      querySelector(selector){ return getElement(`${id}:${selector}`); },
      querySelectorAll(){ return []; },
      getBoundingClientRect(){ return { left:0, top:0, right:800, bottom:600, width:800, height:600 }; },
      getContext(){ context2d.canvas = element; return context2d; },
    };
    return element;
  }
  function getElement(id) {
    if (!elements.has(id)) elements.set(id, makeElement(id));
    return elements.get(id);
  }
  const document = {
    hidden:false, body:getElement('body'), documentElement:getElement('html'),
    getElementById:getElement,
    createElement(tag){ return makeElement(tag); },
    addEventListener(type, fn){ listeners.push(['document', type, fn]); },
    removeEventListener(){}, querySelector(selector){ return getElement(`document:${selector}`); },
    querySelectorAll(){ return []; },
  };
  const sandbox = {
    console, document, navigator:{ maxTouchPoints:0, vibrate(){} },
    innerWidth:800, innerHeight:600, devicePixelRatio:1,
    performance:{ now:() => 1000 }, Math:seededMath(),
    requestAnimationFrame(fn){ frames.push(fn); return frames.length; },
    cancelAnimationFrame(){},
    setTimeout(fn, ms){ timers.push(['timeout', fn, ms]); return timers.length; },
    clearTimeout(){},
    setInterval(fn, ms){ timers.push(['interval', fn, ms]); return timers.length; },
    clearInterval(){},
    AudioContext:function(){}, webkitAudioContext:function(){},
    location:{ reload(){} }, indexedDB:null,
    addEventListener(type, fn){ listeners.push(['window', type, fn]); },
    removeEventListener(){},
    __qa:{ listeners, timers, frames, elements },
  };
  sandbox.window = sandbox;
  sandbox.globalThis = sandbox;
  return vm.createContext(sandbox);
}

async function runReference() {
  const context = makeContext();
  const html = fs.readFileSync(path.join(ROOT, 'rock_bottom_v19.html'), 'utf8');
  const match = html.match(/<script>([\s\S]*?)<\/script>/);
  if (!match) throw new Error('Reference inline script missing');
  new vm.Script(match[1], { filename:'rock_bottom_v19.inline.js' }).runInContext(context);
  await Promise.resolve();
  return context;
}

async function runModules() {
  const context = makeContext();
  const cache = new Map();
  function getModule(file) {
    const full = path.resolve(file);
    if (cache.has(full)) return cache.get(full);
    const mod = new vm.SourceTextModule(fs.readFileSync(full, 'utf8'), { context, identifier:full });
    cache.set(full, mod);
    return mod;
  }
  const main = getModule(path.join(ROOT, 'src/main.js'));
  await main.link((specifier, parent) => getModule(path.resolve(path.dirname(parent.identifier), specifier)));
  await main.evaluate();
  await Promise.resolve();
  return context;
}

function snapshot(context) {
  const rb = context.window._rb;
  if (!rb) throw new Error('window._rb was not installed');
  return {
    player:{ x:rb.P.x, y:rb.P.y, cash:rb.P.cash, rocks:rb.P.rocks, hp:rb.P.hp, rank:rb.P.rank, shakes:rb.P.shakes, rockedT:rb.P.rockedT, crashT:rb.P.crashT },
    state:{ mode:rb.state.mode, day:rb.state.day, weather:rb.state.weather, questCount:Object.keys(rb.state.quests).length },
    npcCount:rb.npcs.length,
    spriteKeys:Object.keys(rb.sprites).sort(),
    palKeys:Object.keys(rb.pals).sort(),
    routeStops:rb.routeStops.map(stop => stop.id),
    scheduledFrames:context.__qa.frames.length,
    scheduledIntervals:context.__qa.timers.filter(timer => timer[0] === 'interval').length,
  };
}

const reference = await runReference();
const modular = await runModules();
const expected = JSON.stringify(snapshot(reference));
const actual = JSON.stringify(snapshot(modular));
if (actual !== expected) {
  console.error('RUNTIME SMOKE: parity mismatch');
  console.error(`reference ${expected}`);
  console.error(`modular   ${actual}`);
  process.exit(1);
}

reference.window._rb.startGame(false);
modular.window._rb.startGame(false);
const startedReference = JSON.stringify(snapshot(reference));
const startedModular = JSON.stringify(snapshot(modular));
if (startedModular !== startedReference || modular.window._rb.state.mode !== 'playing' || modular.window._rb.npcs.length < 50) {
  console.error('RUNTIME SMOKE: new-game start parity failed');
  console.error(`reference ${startedReference}`);
  console.error(`modular   ${startedModular}`);
  process.exit(1);
}

const beforeMove = { x:modular.window._rb.P.x, y:modular.window._rb.P.y };
for (const context of [reference, modular]) {
  context.window._rb.state.keys.add('w');
  context.window._rb.state.keys.add('d');
  context.window._rb.updateWorld(16);
  context.window._rb.state.keys.clear();
}
if (modular.window._rb.P.x <= beforeMove.x || modular.window._rb.P.y >= beforeMove.y) {
  console.error('RUNTIME SMOKE: simultaneous W+D movement did not move diagonally');
  process.exit(1);
}
if (JSON.stringify(snapshot(modular)) !== JSON.stringify(snapshot(reference))) {
  console.error('RUNTIME SMOKE: one-tick movement/world parity failed');
  process.exit(1);
}

const afterDiagonal={x:modular.window._rb.P.x,y:modular.window._rb.P.y};
for(const context of [reference,modular]){
  context.window._rb.state.keys.add('w');
  context.window._rb.updateWorld(16);
  context.window._rb.state.keys.clear();
}
if(Math.abs(modular.window._rb.P.x-afterDiagonal.x)>0.001||modular.window._rb.P.y>=afterDiagonal.y){
  console.error('RUNTIME SMOKE: releasing D did not continue W without lateral drift');
  process.exit(1);
}
if(JSON.stringify(snapshot(modular))!==JSON.stringify(snapshot(reference))){
  console.error('RUNTIME SMOKE: partial-release movement parity failed');
  process.exit(1);
}

for (const context of [reference, modular]) {
  const tony = context.window._rb.npcs.find(npc => npc.id === 'tony');
  if (!tony || typeof tony.interact !== 'function') throw new Error('Tony dialogue actor missing');
  tony.interact();
}
const referenceDialogue = reference.document.getElementById('dialogue').innerHTML;
const modularDialogue = modular.document.getElementById('dialogue').innerHTML;
if (!modularDialogue || modularDialogue !== referenceDialogue) {
  console.error('RUNTIME SMOKE: NPC dialogue parity failed');
  process.exit(1);
}

for(const context of [reference,modular]){
  context.window._rb.state.mode='playing';
  context.window._rb.P.rockedT=18000;
  context.window._rb.P.crashT=0;
  context.window._rb.updateWorld(18000);
}
if(modular.window._rb.P.rockedT!==0||modular.window._rb.P.crashT!==8000){
  console.error(`RUNTIME SMOKE: exact high transition failed (${modular.window._rb.P.rockedT} -> ${modular.window._rb.P.crashT})`);
  process.exit(1);
}
for(const context of [reference,modular])context.window._rb.updateWorld(8000);
if(modular.window._rb.P.crashT!==0||JSON.stringify(snapshot(modular))!==JSON.stringify(snapshot(reference))){
  console.error('RUNTIME SMOKE: exact 8-second crash or status parity failed');
  process.exit(1);
}

await modular.window.storage.set('qa_roundtrip', { value:19, possum:true });
const saved = await modular.window.storage.get('qa_roundtrip');
if (!saved || saved.value?.value !== 19 || saved.value?.possum !== true) {
  console.error('RUNTIME SMOKE: window.storage round-trip failed');
  process.exit(1);
}

modular.window._rb.P.cash = 319;
await modular.window._rb.saveGame();
modular.window._rb.P.cash = 1;
const loaded = await modular.window._rb.loadGame();
if (!loaded || modular.window._rb.P.cash !== 319) {
  console.error('RUNTIME SMOKE: game save/load round-trip failed');
  process.exit(1);
}

console.log(`RUNTIME SMOKE: PASS (${snapshot(modular).npcCount} NPCs, WASD chord/release, exact 18s->8s status, dialogue, ${snapshot(modular).spriteKeys.length} sprite keys, save/load)`);
