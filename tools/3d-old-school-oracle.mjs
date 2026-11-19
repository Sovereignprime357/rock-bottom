import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/old_school_reference.json');
const copy=value=>JSON.parse(JSON.stringify(value));
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
export async function buildOldSchoolOracle(){
  const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),places=game.module('src/dialogue/vendors_places.js');
  const audio=game.module('src/core/audio_save.js'),comms=game.module('src/systems/communications.js'),interactions=game.module('src/systems/interactions.js');
  let trace=[],draws=0,rolls=[],cursor=0,pendingToast=null,text='';
  const record=(kind,payload={})=>trace.push({kind,payload,copper:ui.P.copper,counter:ui.state.counters.copperStripped||0,mode:ui.state.mode});
  Object.defineProperty(ui.toastEl,'textContent',{configurable:true,get:()=>text,set:value=>{text=String(value);pendingToast=text;}});
  const timeout=game.context.setTimeout;game.context.setTimeout=(fn,ms)=>{if(pendingToast!==null){record('toast',{text:pendingToast,duration_ms:ms});pendingToast=null;}return timeout(fn,ms);};
  audio.audio.glassBreak=()=>record('sound',{id:'glassBreak'});audio.audio.rankUp=()=>record('sound',{id:'rankUp'});
  game.context.storage={async set(){record('save');},async get(){return null;}};
  const body=(dead=false)=>({id:'os_brutus',name:'OLD SCHOOL BRUTUS',sprite:'os_brutus',x:3730,y:780,w:36,h:28,color:'#604030',hp:dead?0:250,maxHp:250,speed:1.5,hostile:true,aggro:true,dmg:35,archetype:'charger',showHp:true,chargeState:'idle',chargeT:0,grabFreezeT:0,isOsBrutus:true,...dead?{dead:true}:{}});
  const reset=spec=>{ui.init_runtime_ui();ui.closeDialogue();comms.init_communications();
    Object.assign(ui.P,{x:3760,y:700,rank:3,copper:0,hp:100,stunT:0},copy(spec.player||{}));
    if(spec.distance!==undefined)ui.P.x=3760+spec.distance;
    ui.state.mode='playing';ui.state.bossKind=spec.bossKind||'';ui.state.bossActive=!!spec.bossKind;ui.state.day=1;
    ui.state.flags.osBrutusKilled=!!spec.killed;ui.state.flags.silenceUntilT=0;ui.state.counters.copperStripped=spec.counter||0;
    if(spec.achievement)ui.state.achievements.add('copper_singer');
    ui.runtime.npcs=spec.actor==='live'?[body()]:spec.actor==='dead'?[body(true)]:[];ui.runtime.cashPiles=[];
    trace=[];draws=0;rolls=spec.rolls||[.75];cursor=0;pendingToast=null;text='';game.context.__qa.timers.length=0;
    comms.phoneState.posts.length=0;comms.phoneState.posts.unshift=function(post){record('feed',{text:post.t,author:post.h});return Array.prototype.unshift.call(this,post);};
    game.context.Math.random=()=>{const value=rolls[cursor++]??.75;draws++;record('random',{value});return value;};
  };
  const menu=()=>ui.activeDialogue?{title:ui.activeDialogue.name,text:ui.activeDialogue.text,options:ui.activeDialogue.opts.map(o=>({label:o.label,enabled:!o.disabled}))}:null;
  const outcome=()=>({copper:ui.P.copper,counter:ui.state.counters.copperStripped||0,hp:ui.P.hp,stun:ui.P.stunT,rank:ui.P.rank,mode:ui.state.mode,killed:!!ui.state.flags.osBrutusKilled,achievements:[...ui.state.achievements],actors:copy(ui.runtime.npcs),trace:copy(trace),draws,menu:menu()});
  const entries=[];
  for(const rank of [0,2,2.999,3,4])for(const distance of [0,43.999999,44,44.000001]){const setup={player:{rank},distance};reset(setup);const entered=places.tryEnterOldSchool();entries.push({setup,entered,expected:outcome()});}
  for(const bossKind of ['tony','kingdom']){const setup={bossKind};reset(setup);interactions.tryInteract();entries.push({setup,entered:!!ui.activeDialogue,expected:outcome()});}
  const specs=[];
  for(const actor of ['absent','live','dead'])for(const killed of [false,true])for(const roll of [0,.399999,.4,.999999])specs.push({id:`rip_${actor}_${killed}_${roll}`,actor,killed,rolls:[roll],actions:['rip']});
  for(const counter of [7,8,9,10])for(const achievement of [false,true])specs.push({id:`threshold_${counter}_${achievement}`,actor:'live',counter,achievement,actions:['rip']});
  specs.push({id:'forced_then_live',actions:['rip','open','rip','rip','leave']},
    {id:'corpse_hit_then_miss',actor:'dead',killed:true,rolls:[.2,.9],actions:['rip','open','rip','leave']},
    {id:'legacy_dead_forced_repeat',actor:'dead',killed:false,actions:['rip','open','rip']},
    {id:'captured_live_now_dead',actor:'live',afterActor:'dead',actions:['rip']},
    {id:'captured_live_now_removed',actor:'live',afterActor:'absent',actions:['rip']},
    {id:'captured_absent_now_live',afterActor:'live',actions:['rip']},
    {id:'captured_absent_now_dead',afterActor:'dead',actions:['rip']},
    {id:'captured_rank_reduced',afterPlayer:{rank:0},actions:['rip']},
    {id:'captured_relocated',afterPlayer:{x:0,y:0},actions:['rip']},
    {id:'captured_boss_changed',afterBoss:'kingdom',actions:['rip']},
    {id:'captured_killed_flag_changed',afterKilled:true,rolls:[.8],actions:['rip']},
    {id:'raw_negative_hp_stun',player:{hp:-4,stunT:999},actions:['rip']},
    {id:'ordinary_boss',bossKind:'tony',actions:['rip']},
    {id:'leave',actions:['leave']},{id:'escape',actions:['escape']},{id:'rank_locked_leave',player:{rank:2},actions:['leave']});
  const cases=[];
  for(const setup of specs){reset(setup);assert.equal(places.tryEnterOldSchool(),true);const initial=menu();
    if(setup.afterActor)ui.runtime.npcs=setup.afterActor==='live'?[body()]:setup.afterActor==='dead'?[body(true)]:[];
    Object.assign(ui.P,copy(setup.afterPlayer||{}));if(setup.afterBoss)ui.state.bossKind=setup.afterBoss;if(setup.afterKilled!==undefined)ui.state.flags.osBrutusKilled=setup.afterKilled;
    const steps=[];
    for(const action of setup.actions){
      if(action==='open'){assert.equal(places.tryEnterOldSchool(),true);steps.push({action,expected:outcome()});continue;}
      const choice=action==='escape'?null:ui.activeDialogue.opts.find(o=>o.label.startsWith(action==='rip'?'rip copper':'leave.'));
      if(action!=='escape')assert.ok(choice&&!choice.disabled,setup.id+' choice '+action);
      ui.closeDialogue();choice?.action?.();steps.push({action,expected:outcome()});
    }
    cases.push({setup,initial,steps});
  }
  const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
  return {schema:1,format:'rock-bottom-old-school-reference',source:{authority:'unchanged tryEnterOldSchool/openOldSchoolInterior/spawnOldSchoolBrutus callbacks; actual kingdom E blanket',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url)))},body:body(),counts:{entries:entries.length,cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0)},entries,cases};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  ensureVmFlag(fileURLToPath(import.meta.url));const result=await buildOldSchoolOracle();const out=stableStringify(result);
  if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),out,'OldSchool oracle drift.');else fs.writeFileSync(OUTPUT,out);
  console.log(`3D OLD SCHOOL ORACLE: PASS (${result.counts.entries} entries / ${result.counts.cases} paths / ${result.counts.steps} steps; unchanged source)`);
}
