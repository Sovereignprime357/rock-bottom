import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT=path.resolve(import.meta.dirname,'..');
const {context,module}=await loadModularGame();
context.window._rb.startGame(false);

const layoutModule=module('src/ui/layout.js');
const hudModule=module('src/ui/hud.js');
const propsModule=module('src/data/props.js');
const runtime=module('src/core/runtime_ui.js');
const interactions=module('src/systems/interactions.js');
const campaigns=module('src/systems/campaigns.js');
const dialogueB=module('src/dialogue/neighborhood_b.js');
const audioSave=module('src/core/audio_save.js');
const failures=[];
const near=(a,b,epsilon=.001)=>Math.abs(a-b)<=epsilon;
const strictOverlap=(a,b)=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;
const contains=(outer,inner)=>inner.x>=outer.x-.001&&inner.y>=outer.y-.001&&inner.x+inner.w<=outer.x+outer.w+.001&&inner.y+inner.h<=outer.y+outer.h+.001;

const fixtures=[
  {name:'800x600 breakpoint',viewport:[800,600],stage:[800,600],mobile:true},
  {name:'1024x480 desktop',viewport:[1024,480],stage:[640,480],mobile:false},
  {name:'1024x360 desktop',viewport:[1024,360],stage:[480,360],mobile:false},
  {name:'1280x300 desktop',viewport:[1280,300],stage:[400,300],mobile:false},
  {name:'390x844 touch',viewport:[390,844],stage:[390,844],mobile:true},
  {name:'844x390 touch',viewport:[844,390],stage:[844,390],mobile:true},
];

for(const fixture of fixtures){
  const [stageW,stageH]=fixture.stage;
  const resolved=layoutModule.resolvePresentationLayout(stageW,stageH,fixture.mobile);
  const left={x:resolved.hud.x,y:resolved.hud.y,w:resolved.hud.columnWidth,h:resolved.hud.fontSize*1.3*4};
  const right={x:resolved.hud.x+resolved.hud.columnWidth+resolved.hud.gap,y:resolved.hud.y,w:resolved.hud.columnWidth,h:left.h};
  if(!contains(resolved.game,left)||!contains(resolved.game,right))failures.push(`${fixture.name}: HUD leaves game rectangle`);
  if(strictOverlap(left,right))failures.push(`${fixture.name}: HUD columns intersect`);
  if(resolved.hud.compact!==(resolved.game.w<=layoutModule.HUD_COMPACT_WIDTH))failures.push(`${fixture.name}: compact threshold drift`);
  if(fixture.mobile&&strictOverlap(resolved.ticker,resolved.topbar))failures.push(`${fixture.name}: ticker/topbar overlap`);

  const stage=context.document.getElementById('stage'),hud=context.document.getElementById('hud');
  stage.clientWidth=stageW;stage.clientHeight=stageH;
  context.window.innerWidth=fixture.viewport[0];context.window.innerHeight=fixture.viewport[1];
  context.navigator.maxTouchPoints=fixture.mobile?1:0;
  // v22 display fix: mobile is now detected via a coarse pointer, not innerWidth/maxTouchPoints.
  context.window.matchMedia=(q)=>({matches:fixture.mobile&&/coarse/.test(String(q)),media:String(q)});
  hudModule.syncPresentationLayout();
  const topbar=context.document.querySelector('#mobile-ctrls .topbar'),ticker=context.document.getElementById('ticker');
  if(!near(parseFloat(hud.style.left),resolved.hud.x)||!near(parseFloat(hud.style.right),resolved.hud.right)||!near(parseFloat(hud.style.top),resolved.hud.y))failures.push(`${fixture.name}: production HUD styles diverge from resolver`);
  if(!near(parseFloat(topbar.style.width),resolved.topbar.w)||!near(parseFloat(ticker.style.right),resolved.ticker.right))failures.push(`${fixture.name}: production chrome styles diverge from resolver (${topbar.style.width||'unset'}/${ticker.style.right||'unset'} vs ${resolved.topbar.w}/${resolved.ticker.right})`);
}

const html=fs.readFileSync(path.join(ROOT,'index.html'),'utf8');
for(const contract of ['flex:1 1 0;min-width:0;max-width:50%','overflow-wrap:anywhere','#stage.hud-compact #hud .keyhint{display:none}','width:auto;min-width:0;flex:1 1 0']){
  if(!html.includes(contract))failures.push(`HUD containment CSS missing: ${contract}`);
}

// v22 display fix: mobile chrome keys off a coarse pointer only, never viewport width.
if(!html.includes('@media (pointer: coarse){'))failures.push('mobile media query must be @media (pointer: coarse){ - coarse-pointer gated');
if(html.includes('max-width: 820px'))failures.push('mobile media query still width-gated (max-width: 820px) - desktop zoom would re-show mobile chrome');
const carts=propsModule.PROPS.filter(prop=>prop.type==='cart');
if(carts.length!==1)failures.push(`rideable cart count ${carts.length}, expected 1`);
const cart=carts[0];
if(cart){
  if(cart.x!==propsModule.RIDEABLE_CART_SPAWN.x||cart.y!==propsModule.RIDEABLE_CART_SPAWN.y)failures.push('rideable cart is not at its authored fresh anchor');
  if(Object.prototype.hasOwnProperty.call(cart,'mounted'))failures.push('cart prop still owns parallel mounted state');
}

const interactiveNpcs=context.window._rb.npcs.filter(npc=>!npc.dead&&typeof npc.interact==='function');
let nearestNpc=null,nearestDistance=Infinity;
if(cart)for(const npc of interactiveNpcs){
  const distance=Math.hypot(cart.x-(npc.x+npc.w/2),cart.y-(npc.y+npc.h/2));
  if(distance<nearestDistance){nearestDistance=distance;nearestNpc=npc;}
}
if(!(nearestDistance>96))failures.push(`cart spawn shadowed by ${nearestNpc?.name||'unknown'} at ${nearestDistance.toFixed(3)}px (must exceed 96)`);

if(cart){
  runtime.P.x=cart.x-runtime.P.w/2;runtime.P.y=cart.y-runtime.P.h/2;
  runtime.state.blockRoute=null;runtime.state.mode='playing';
  interactions.tryInteract();
  if(!runtime.P.cartMounted||runtime.P.maxHp!==110||!near(runtime.P.speed,3.7))failures.push('ordinary cart mount or unchanged stats failed');
  if(campaigns.resolveActionHint()!=='abandon the cart')failures.push('mounted cart action hint is not abandon');
  interactions.tryInteract();
  if(runtime.P.cartMounted||runtime.P.maxHp!==100||!near(runtime.P.speed,2.2))failures.push('ordinary cart dismount or base-stat restore failed');

  propsModule.resetRideableCart();runtime.P.copper=5;runtime.P.cartMounted=false;
  dialogueB.bigguDialogue();
  const trade=runtime.activeDialogue?.opts?.find(option=>String(option.label).includes('trade 5 PURE COPPER'));
  if(!trade||trade.disabled)failures.push('THE BIG GUY cart acquisition option unavailable in fixture');
  else { runtime.closeDialogue();trade.action(); }
  await Promise.resolve();
  const bigGuyHint=campaigns.resolveActionHint();
  if(!runtime.P.cartMounted||Object.prototype.hasOwnProperty.call(cart,'mounted')||bigGuyHint!=='abandon the cart')failures.push(`THE BIG GUY did not enter the single mounted-cart state (${runtime.P.cartMounted}/${String(cart.mounted)}/${bigGuyHint})`);

  await audioSave.saveGame();
  runtime.P.cartMounted=false;
  const loaded=await audioSave.loadGame();
  const stored=await context.window.storage.get(audioSave.SAVE_KEY);
  if(!loaded||!runtime.P.cartMounted||stored?.value?.version!==10||stored?.value?.player?.cartMounted!==true)failures.push('mounted save/load did not restore the existing player field');

  cart.x=77;cart.y=88;
  context.window._rb.startGame(false);
  if(runtime.P.cartMounted||cart.x!==propsModule.RIDEABLE_CART_SPAWN.x||cart.y!==propsModule.RIDEABLE_CART_SPAWN.y)failures.push('fresh game did not clear and reset the unique cart');
}

const splitState=[];
for(const rel of ['src/render/props.js','src/systems/interactions.js','src/systems/campaigns.js']){
  const source=fs.readFileSync(path.join(ROOT,rel),'utf8');
  if(/cart\.mounted/.test(source))splitState.push(rel);
}
if(splitState.length)failures.push(`parallel cart.mounted authority returned in ${splitState.join(', ')}`);

if(failures.length){
  console.error(`PRESENTATION GATE: ${failures.length} failure(s)`);
  failures.forEach(failure=>console.error(`- ${failure}`));
  process.exit(1);
}
console.log(`PRESENTATION GATE: PASS (${fixtures.length} viewport fixtures, ${carts.length} rideable cart, ${nearestDistance.toFixed(1)}px nearest NPC, ordinary/Big Guy/save paths)`);
