import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {loadModularGame} from './runtime-harness.mjs';
const root=path.resolve(import.meta.dirname,'..'),game=await loadModularGame();
const ui=game.module('src/core/runtime_ui.js'),com=game.module('src/systems/communications.js');
const props=game.module('src/data/props.js'),save=game.module('src/core/audio_save.js'),start=game.module('src/core/start.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const pick=(o,keys)=>Object.fromEntries(keys.filter(k=>o[k]!==undefined).map(k=>[k,clone(o[k])]));
const initialProps=clone(props.PROPS),now=1000000;
vm.runInContext('Date.now=()=>1000000',game.context);
const playerKeys=['cash','cred','hp','maxHp','brain','inventory'];
const flagKeys=['momIntroFired','momProudCallDay','silenceUntilT'];
const dumps=()=>props.PROPS.map((p,i)=>({p,i})).filter(({p})=>p.type==='dumpster').map(({p,i})=>({id:'prop:'+i,looted:!!p.looted,tipsJar:!!p.tipsJar,diveCdT:p.diveCdT||0}));
const snapshot=()=>({player:pick(ui.P,playerKeys),flags:pick(ui.state.flags,flagKeys),phone:clone(com.phoneState),news_text:game.context.document.getElementById('tape').textContent,news_index:com.newsState.idx,props:dumps()});
const specs=[
 ...Array.from({length:12},(_,i)=>({id:'call_'+i,ops:[{kind:'call',index:i}]})),
 {id:'call_random',rolls:[0.55],ops:[{kind:'call',index:-1}]},
 {id:'call_silent_resource_still_applies',flags:{silenceUntilT:now+1},ops:[{kind:'call',index:2}]},
 {id:'call_dialogue_noop',state:{mode:'dialogue'},ops:[{kind:'call',index:2}]},
 {id:'call_brain_floor',player:{brain:2},ops:[{kind:'call',index:1}]},
 {id:'call_brain_cap',player:{brain:99},ops:[{kind:'call',index:6},{kind:'call',index:11}]},
 {id:'intro_once',ops:[{kind:'intro'},{kind:'intro'}]},
 {id:'intro_silence_bypasses_call_only',flags:{silenceUntilT:now+1},ops:[{kind:'intro'}]},
 {id:'intro_dialogue_noop',state:{mode:'dialogue'},ops:[{kind:'intro'}]},
 {id:'proud_boundary_once',spiritual:10,rolls:[0],player:{brain:99},ops:[{kind:'proud'},{kind:'proud'}]},
 {id:'proud_below',spiritual:9,ops:[{kind:'proud'}]},
 {id:'proud_silence',spiritual:10,flags:{silenceUntilT:now+1},ops:[{kind:'proud'}]},
 {id:'proud_silence_equality',spiritual:10,flags:{silenceUntilT:now},rolls:[0.999],ops:[{kind:'proud'}]},
 {id:'proud_dialogue',spiritual:10,state:{mode:'dialogue'},ops:[{kind:'proud'}]},
 ...com.WORLD_EVENTS.map((event,index)=>({id:'event_'+event.id,rolls:[(index+.1)/com.WORLD_EVENTS.length,0.2999],ops:[{kind:'event'}]})),
 {id:'event_news_boundary',rolls:[.1/com.WORLD_EVENTS.length,.3],ops:[{kind:'event'}]},
 {id:'event_silence_still_changes_resource',flags:{silenceUntilT:now+1},rolls:[(2+.1)/com.WORLD_EVENTS.length,.1],ops:[{kind:'event'}]},
 {id:'event_philosopher_poor',player:{cash:4},rolls:[(27+.1)/com.WORLD_EVENTS.length,.75],ops:[{kind:'event'}]},
 {id:'event_forget_floor',player:{brain:1},rolls:[(8+.1)/com.WORLD_EVENTS.length,.75],ops:[{kind:'event'}]},
 {id:'event_meatball_cap',player:{hp:99},rolls:[(23+.1)/com.WORLD_EVENTS.length,.75],ops:[{kind:'event'}]},
 {id:'feed_eight_newest',ops:Array.from({length:10},(_,i)=>({kind:'post',text:'post '+i,author:'@qa'}))},
 {id:'feed_fallback_handle',rolls:[0,.999],ops:[{kind:'post',text:'one',author:''},{kind:'post',text:'two',author:''}]},
 {id:'feed_silent_no_handle_rng',flags:{silenceUntilT:now+1},rolls:[.5],ops:[{kind:'post',text:'suppressed',author:''},{kind:'broadcast',text:'suppressed'}]},
 {id:'feed_silence_equal_expired',flags:{silenceUntilT:now},ops:[{kind:'post',text:'allowed',author:'@qa'}]},
 {id:'feed_visibility',ops:[{kind:'show'},{kind:'show'},{kind:'toggle'},{kind:'toggle'}]},
 {id:'ticker_rotation_erases_breaking',ops:[{kind:'broadcast',text:'one'},{kind:'broadcast',text:'two'},{kind:'rotate',count:1}]},
 {id:'ticker_ignores_silence',flags:{silenceUntilT:now+1},ops:[{kind:'rotate',count:1}]},
 {id:'ticker_seven_intervals',ops:[{kind:'rotate',count:7}]},
 {id:'garbage_real_flags',garbage:true,rolls:[.6],ops:[{kind:'garbage'}]},
 {id:'garbage_dialogue_silence',garbage:true,state:{mode:'dialogue'},flags:{silenceUntilT:now+1},rolls:[0],ops:[{kind:'garbage'}]}
];
const cases=[];
for(const spec of specs){
 ui.init_runtime_ui();com.init_communications();props.PROPS.splice(0,props.PROPS.length,...clone(initialProps));
 Object.assign(ui.state,{mode:'playing',day:1},spec.state||{});Object.assign(ui.P,clone(spec.player||{}));
 Object.assign(ui.state.flags,{momIntroFired:false,momProudCallDay:0,silenceUntilT:0},spec.flags||{});
 if(spec.spiritual!==undefined)ui.P.faction.spiritual=spec.spiritual;
 game.context.document.getElementById('tape').textContent='';com.rotateNews();
 if(spec.garbage){const d=props.PROPS.filter(p=>p.type==='dumpster');d[0].looted=true;d[0].tipsJar=true;d[0].diveCdT=5000;d[1].looted=true;}
 let cursor=0;const rolls=spec.rolls||[];
 game.context.Math.random=()=>rolls[cursor++]??.75;
 const setup={player:pick(ui.P,playerKeys),state:pick(ui.state,['mode','day']),flags:pick(ui.state.flags,flagKeys),spiritual:ui.P.faction.spiritual,props:dumps()};
 const steps=[];
 for(const operation of spec.ops){
  switch(operation.kind){
   case'call':com.ringPhone(operation.index<0?undefined:com.PHONE_CALL_LINES[operation.index]);break;
   case'intro':com.fireMomIntroTipOnce();break;
   case'proud':com.maybeFireMomProudCall();break;
   case'event':com.fireRandomEvent();break;
   case'post':com.feedPost(operation.text,operation.author);break;
   case'broadcast':com.broadcastNews(operation.text);break;
   case'show':if(!com.phoneState.visible){com.phoneState.visible=true;com.renderPhone();}break;
   case'toggle':com.phoneState.visible=!com.phoneState.visible;com.renderPhone();break;
   case'rotate':for(let i=0;i<operation.count;i++)com.rotateNews();break;
   case'garbage':com.garbageTruckRumble();break;
  }
  steps.push({operation,expected:snapshot(),draws:cursor});
 }
 cases.push({id:spec.id,rolls,setup,steps});
}
// Separately characterize actual source fresh/load overlay behavior (not a rewritten oracle).
ui.init_runtime_ui();com.init_communications();props.PROPS.splice(0,props.PROPS.length,...clone(initialProps));
let d=props.PROPS.filter(p=>p.type==='dumpster');d[0].looted=true;d[0].tipsJar=true;
com.feedPost('retained before fresh','@qa');
start.startGame(false);
const fresh={looted:!!d[0].looted,tipsJar:!!d[0].tipsJar,postRetained:com.phoneState.posts.some(p=>p.t==='retained before fresh')};
const persisted={version:22,player:clone(ui.P),lootedDumpsters:[d[1].x+','+d[1].y]};
game.context.storage={get:async()=>({value:persisted}),set:async()=>{}};
const loadOK=await save.loadGame();
const lifecycle={fresh,load:{ok:loadOK,priorLooted:!!d[0].looted,addedLooted:!!d[1].looted,tipsJar:!!d[0].tipsJar}};
const target=path.join(root,'game3d/tests/fixtures/communications_reference.json');
const output=JSON.stringify({source:'unchanged active communications callbacks, source props and actual startGame/loadGame',now,cases,lifecycle},null,2)+'\n';
if(process.argv.includes('--check')){if(!fs.existsSync(target)||fs.readFileSync(target,'utf8')!==output)throw new Error('Communications oracle drift; regenerate deliberately');}
else fs.writeFileSync(target,output);
console.log('3D COMMUNICATIONS ORACLE: PASS ('+cases.length+' source fixtures;12 calls/29 events/feed/ticker/garbage;fresh-load characterization='+JSON.stringify(lifecycle)+')');
