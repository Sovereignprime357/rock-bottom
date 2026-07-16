import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const ROOT = path.resolve(import.meta.dirname, '..');

if (typeof vm.SourceTextModule !== 'function') {
  console.error('RUNTIME HARNESS: vm.SourceTextModule unavailable; run with --experimental-vm-modules');
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

export function makeGameContext() {
  const listeners = [], timers = [], frames = [], elements = new Map();
  const gradient = { addColorStop(){} };
  const context2d = new Proxy({
    canvas:null, font:'10px sans-serif',
    measureText(text) {
      const size = Number(String(this.font).match(/(\d+(?:\.\d+)?)px/)?.[1] || 10);
      return { width:String(text ?? '').length * size * 0.6 };
    },
    createLinearGradient(){ return gradient; }, createRadialGradient(){ return gradient; },
    createPattern(){ return {}; }, getImageData(){ return { data:new Uint8ClampedArray(4) }; },
  }, { get(target, key) { return key in target ? target[key] : () => {}; }, set(target, key, value) { target[key]=value; return true; } });

  function makeElement(id='') {
    const element = {
      id, style:{}, dataset:{}, children:[], textContent:'', innerHTML:'', value:'',
      width:800, height:600, clientWidth:800, clientHeight:600,
      classList:{ add(){}, remove(){}, toggle(){}, contains(){ return false; } },
      addEventListener(type, fn){ listeners.push([id,type,fn]); }, removeEventListener(){},
      appendChild(child){ this.children.push(child); return child; }, remove(){}, focus(){}, blur(){}, setAttribute(){},
      querySelector(selector){ return getElement(`${id}:${selector}`); }, querySelectorAll(){ return []; },
      getBoundingClientRect(){ return {left:0,top:0,right:800,bottom:600,width:800,height:600}; },
      getContext(){ context2d.canvas=element; return context2d; },
    };
    return element;
  }
  function getElement(id) { if(!elements.has(id)) elements.set(id,makeElement(id)); return elements.get(id); }
  const document = {
    hidden:false, body:getElement('body'), documentElement:getElement('html'), getElementById:getElement,
    createElement(tag){return makeElement(tag);}, addEventListener(type,fn){listeners.push(['document',type,fn]);},
    removeEventListener(){}, querySelector(selector){return getElement(`document:${selector}`);}, querySelectorAll(){return[];},
  };
  const sandbox = {
    console, document, navigator:{maxTouchPoints:0,vibrate(){}}, innerWidth:800,innerHeight:600,devicePixelRatio:1,
    performance:{now:()=>1000}, Math:seededMath(), indexedDB:null, location:{reload(){}},
    requestAnimationFrame(fn){frames.push(fn);return frames.length;}, cancelAnimationFrame(){},
    setTimeout(fn,ms){timers.push(['timeout',fn,ms]);return timers.length;}, clearTimeout(){},
    setInterval(fn,ms){timers.push(['interval',fn,ms]);return timers.length;}, clearInterval(){},
    AudioContext:function(){}, webkitAudioContext:function(){},
    addEventListener(type,fn){listeners.push(['window',type,fn]);}, removeEventListener(){},
    __qa:{listeners,timers,frames,elements,context2d},
  };
  sandbox.window=sandbox; sandbox.globalThis=sandbox;
  return vm.createContext(sandbox);
}

export async function loadModularGame() {
  const context = makeGameContext();
  const cache = new Map();
  function getModule(file) {
    const full=path.resolve(file);
    if(cache.has(full))return cache.get(full);
    const mod=new vm.SourceTextModule(fs.readFileSync(full,'utf8'),{context,identifier:full});
    cache.set(full,mod);return mod;
  }
  const main=getModule(path.join(ROOT,'src/main.js'));
  await main.link((specifier,parent)=>getModule(path.resolve(path.dirname(parent.identifier),specifier)));
  await main.evaluate();
  await Promise.resolve();
  const module = relative => {
    const found=cache.get(path.join(ROOT,...relative.split('/')));
    if(!found)throw new Error(`Module not loaded: ${relative}`);
    return found.namespace;
  };
  return {context,cache,module};
}
