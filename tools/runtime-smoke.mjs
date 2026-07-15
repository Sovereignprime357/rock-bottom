import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const ROOT = path.resolve(import.meta.dirname, '..');

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
  async function load(file) {
    const full = path.resolve(file);
    if (cache.has(full)) return cache.get(full);
    const mod = new vm.SourceTextModule(fs.readFileSync(full, 'utf8'), { context, identifier:full });
    cache.set(full, mod);
    await mod.link((specifier, parent) => load(path.resolve(path.dirname(parent.identifier), specifier)));
    return mod;
  }
  const main = await load(path.join(ROOT, 'src/main.js'));
  await main.evaluate();
  await Promise.resolve();
  return context;
}

function snapshot(context) {
  const rb = context.window._rb;
  if (!rb) throw new Error('window._rb was not installed');
  return {
    player:{ x:rb.P.x, y:rb.P.y, cash:rb.P.cash, rocks:rb.P.rocks, hp:rb.P.hp, rank:rb.P.rank },
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

await modular.window.storage.set('qa_roundtrip', { value:19, possum:true });
const saved = await modular.window.storage.get('qa_roundtrip');
if (!saved || saved.value?.value !== 19 || saved.value?.possum !== true) {
  console.error('RUNTIME SMOKE: window.storage round-trip failed');
  process.exit(1);
}

console.log(`RUNTIME SMOKE: PASS (${snapshot(modular).npcCount} NPCs, ${snapshot(modular).spriteKeys.length} sprite keys, storage round-trip)`);
