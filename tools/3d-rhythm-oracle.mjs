import fs from 'node:fs';
import path from 'node:path';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..'),game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js'),spawns=game.module('src/data/npc_spawns.js');
const recognition=game.module('src/systems/recognition.js');
const sequence=[0,1,2,3,3,2,1,0],rolls=sequence.map(i=>(i+.1)/4);
const clone=x=>JSON.parse(JSON.stringify(x));
const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
const snapshot=()=>({cash:ui.P.cash,cred:ui.P.cred,achievements:[...ui.state.achievements].sort(),recognition:clone(ui.state.recognition),mode:ui.state.mode});
const specs=[...Array.from({length:9},(_,hits)=>({id:'hits_'+hits,hits})),...[0,4,7].map(after=>({id:'forfeit_'+after,stop:'forfeit',after})),{id:'escape_4',stop:'escape',after:4},{id:'perfect_repeat',hits:8,rounds:2}];
const cases=[];
for(const spec of specs){
 ui.init_runtime_ui();spawns.spawnNpcs();recognition.init_recognition();ui.P.cash=20;ui.P.cred=0;ui.state.mode='playing';
 const actor=ui.runtime.npcs.find(n=>n.id==='karaoke');
 ui.P.x=actor.x+(actor.w-ui.P.w)/2;ui.P.y=actor.y+(actor.h-ui.P.h)/2;
 const rounds=[];
 for(let round=0;round<(spec.rounds||1);round++){
  actor.interact(actor);const sing=ui.activeDialogue.opts[0];ui.closeDialogue();
  let cursor=0;game.context.Math.random=()=>rolls[cursor++%rolls.length];sing.action();
  const started=menu(),steps=[];
  const count=spec.stop?spec.after:8;
  for(let index=0;index<count;index++){
   const choice=index<(spec.hits??8)?sequence[index]:(sequence[index]+1)%4;
   const action=ui.activeDialogue.opts[choice];ui.closeDialogue();action.action();
   steps.push({choice,after:menu(),state:snapshot()});
  }
  if(spec.stop){
   const action=ui.activeDialogue?.opts[4];ui.closeDialogue();
   if(spec.stop==='forfeit')action.action();
   steps.push({choice:spec.stop,after:menu(),state:snapshot()});
  }
  rounds.push({started,steps});
 }
 cases.push({id:spec.id,sequence,rounds});
}
const target=path.join(root,'game3d/tests/fixtures/rhythm_reference.json');
const output=JSON.stringify({source:'unchanged source paid Karaoke callback and untimed startRhythmMini menus',cases},null,2)+'\n';
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw new Error('Rhythm oracle drift; regenerate deliberately');}
else fs.writeFileSync(target,output);
console.log('3D RHYTHM ORACLE: PASS ('+cases.length+' source fixtures;0–8hits,exact note/history menus,forfeit,Escape,repeat)');
