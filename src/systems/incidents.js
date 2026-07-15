/* Generated from frozen rock_bottom_v19.html.
 * Source seams: living-neighborhood incidents.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, runtime, state, toast } from '../core/runtime_ui.js';
import { ROAD_SEGMENTS, WORLD } from '../data/world.js';
import { clamp, ctx, currentZone, isNight, visibleWorldRect } from '../legacy.js';
import { SPRITE_CACHE } from '../render/sprites.js';
import { feedPost } from './communications.js';

export let INCIDENT_IDS, INCIDENT_DEFS;

export function ensureIncidentFlags() {
  if (!state.flags) state.flags={};
  if (state.flags.incidentDay !== state.day) {
    state.flags.incidentDay=state.day;
    state.flags.incidentMask=0;
    state.flags.incidentsToday=0;
  }
  state.flags.incidentMask=state.flags.incidentMask||0;
  state.flags.incidentsToday=state.flags.incidentsToday||0;
  state.flags.lastIncidentId=state.flags.lastIncidentId||'';
}

export function incidentNpc(id) {
  return runtime.npcs.find(n=>n.id===id&&!n.dead);
}

export function incidentCombatBusy() {
  if (state.bossActive || state.brutusOlderActive) return true;
  const cx=P.x+P.w/2, cy=P.y+P.h/2;
  return runtime.npcs.some(n=>!n.dead&&n.aggro&&Math.hypot(n.x+n.w/2-cx,n.y+n.h/2-cy)<320);
}

export function incidentScriptBusy() {
  return runtime.npcs.some(n=>!n.dead&&(n.isDay3Visitor||n.id==='bus_driver'));
}

export function nearestIncidentRoad() {
  const cx=P.x+P.w/2, cy=P.y+P.h/2;
  let best=ROAD_SEGMENTS[0], bestD=Infinity;
  for(const r of ROAD_SEGMENTS){
    const qx=clamp(cx,r.x,r.x+r.w), qy=clamp(cy,r.y,r.y+r.h);
    const d=(qx-cx)*(qx-cx)+(qy-cy)*(qy-cy);
    if(d<bestD){bestD=d;best=r;}
  }
  return best;
}

export function startIncident(id) {
  const def=INCIDENT_DEFS[id]; if(!def)return;
  const inc={id,t:0,beat:-1,duration:def.duration,actors:[],bumped:false};
  if(id==='runaway_mattress'){
    const r=nearestIncidentRoad(), horizontal=r.axis==='h';
    const center=horizontal?P.x+P.w/2:P.y+P.h/2;
    const lo=horizontal?r.x:r.y, hi=horizontal?r.x+r.w:r.y+r.h;
    const projected=clamp(center,lo+18,hi-18);
    const roomForward=hi-projected, roomBack=projected-lo;
    const dir=roomForward>=roomBack?1:-1;
    const start=clamp(projected-dir*380,lo+18,hi-18), end=clamp(projected+dir*560,lo+18,hi-18);
    inc.road=r; inc.dir=dir;
    inc.actors=[{kind:'mattress',x:horizontal?start:r.x+r.w/2,y:horizontal?r.y+r.h/2:start,
      sx:horizontal?start:r.x+r.w/2,sy:horizontal?r.y+r.h/2:start,
      ex:horizontal?end:r.x+r.w/2,ey:horizontal?r.y+r.h/2:end}];
  } else if(id==='possum_inventory') {
    inc.actors=[{kind:'forklift',x:720,y:1515}];
  } else if(id==='laundromat_walkout') {
    inc.actors=[{kind:'dryer',x:1540,y:1190}];
  } else if(id==='yuri_receipt') {
    const dog=incidentNpc('brutus');
    inc.anchor={x:310,y:220,tx:dog?dog.x+dog.w/2:570,ty:dog?dog.y+dog.h/2:150};
    if(!dog)inc.overrideBeat2='the wind wraps the leash post.\nthe post remains employed.';
  } else if(id==='park_dry_committee') {
    inc.anchor={x:2600,y:1280}; inc.sprayAngle=-.4;
  } else if(id==='ticketed_luggage') {
    inc.actors=[{kind:'suitcase',x:360,y:2985}];
  }
  state.incident=inc;
  ensureIncidentFlags();
  const bit=1<<INCIDENT_IDS.indexOf(id);
  state.flags.incidentMask|=bit;
  state.flags.incidentsToday++;
  state.flags.lastIncidentId=id;
  saveGame();
  feedPost(def.beats[0][1].split('\n')[0], '@local_eyewitness');
}

export function finishIncident(interrupted=false) {
  if(!state.incident)return;
  state.incident=null;
  state.incidentT=(interrupted?45000:70000)+Math.random()*(interrupted?20000:40000);
}

export function incidentRequiredValid(inc) {
  const def=INCIDENT_DEFS[inc.id];
  if(!def||!def.required)return true;
  const n=incidentNpc(def.required);
  return !!n&&!n.aggro&&!n.hostile;
}

export function pointSegmentDistance(px,py,x1,y1,x2,y2){
  const dx=x2-x1,dy=y2-y1,l2=dx*dx+dy*dy;
  const t=l2?clamp(((px-x1)*dx+(py-y1)*dy)/l2,0,1):0;
  return Math.hypot(px-(x1+t*dx),py-(y1+t*dy));
}

export function updateActiveIncident(inc,dt) {
  const p=Math.min(1,inc.t/inc.duration), ease=p*p*(3-2*p);
  if(inc.id==='runaway_mattress'){
    const a=inc.actors[0];
    a.x=a.sx+(a.ex-a.sx)*ease; a.y=a.sy+(a.ey-a.sy)*ease+Math.sin(inc.t/240)*3;
    if(!inc.bumped&&inc.t>1800&&Math.abs(a.x-(P.x+P.w/2))<25&&Math.abs(a.y-(P.y+P.h/2))<25){
      inc.bumped=true; state.shake=Math.max(state.shake,5);
      P.x=clamp(P.x+Math.sign(a.ex-a.sx)*14,0,WORLD.w-P.w);
      P.y=clamp(P.y+Math.sign(a.ey-a.sy)*14,0,WORLD.h-P.h);
      toast('the mattress has insurance.\nyou do not.',1800);
    }
  } else if(inc.id==='possum_inventory'){
    const a=inc.actors[0], q=Math.min(1,inc.t/24500);
    a.x=720+q*620; a.y=1515+Math.sin(inc.t/430)*5;
  } else if(inc.id==='laundromat_walkout'){
    const a=inc.actors[0], q=Math.min(1,inc.t/24500);
    a.x=1540+q*360; a.y=1190+q*45+Math.sin(inc.t/170)*3;
  } else if(inc.id==='yuri_receipt'){
    const a=inc.anchor, cx=P.x+P.w/2,cy=P.y+P.h/2;
    if(inc.t>5000&&pointSegmentDistance(cx,cy,a.x,a.y,a.tx,a.ty)<20) state.incidentPaperT=4000;
  } else if(inc.id==='park_dry_committee'){
    const a=inc.anchor,cx=P.x+P.w/2,cy=P.y+P.h/2;
    inc.sprayAngle=inc.t>12000&&inc.t<23000?Math.atan2(cy-a.y,cx-a.x):Math.sin(inc.t/900)*.7-.5;
    const dist=Math.hypot(cx-a.x,cy-a.y);
    if(inc.t>12000&&inc.t<23000&&dist<175) state.incidentWetT=4000;
  } else if(inc.id==='ticketed_luggage'){
    const a=inc.actors[0];
    if(inc.t<9000)a.x=360+(inc.t/9000)*310;
    else if(inc.t<14500)a.x=670;
    else a.x=670+Math.min(1,(inc.t-14500)/12500)*650;
    a.y=2985+Math.sin(inc.t/260)*3;
    if(Math.abs(a.x-(P.x+P.w/2))<32&&Math.abs(a.y-(P.y+P.h/2))<28)a.y+=28;
  }
}

export function updateIncidents(dt,introActive,silenceActive) {
  state.incidentPaperT=Math.max(0,(state.incidentPaperT||0)-dt);
  state.incidentWetT=Math.max(0,(state.incidentWetT||0)-dt);
  if(state.incident){
    if(silenceActive||incidentCombatBusy()||incidentScriptBusy()||!incidentRequiredValid(state.incident)){
      finishIncident(true); return;
    }
    const inc=state.incident, def=INCIDENT_DEFS[inc.id];
    inc.t+=dt;
    updateActiveIncident(inc,dt);
    while(inc.beat+1<def.beats.length&&inc.t>=def.beats[inc.beat+1][0]){
      inc.beat++;
      const beatText=(inc.beat===2&&inc.overrideBeat2)||def.beats[inc.beat][1];
      toast(beatText,inc.beat===def.beats.length-1?2600:3200);
      if(inc.beat===1&&def.sfx&&audio[def.sfx])audio[def.sfx]();
    }
    if(inc.t>=inc.duration)finishIncident(false);
    return;
  }
  if(introActive||silenceActive||state.bossActive||state.brutusOlderActive||incidentCombatBusy()||incidentScriptBusy())return;
  ensureIncidentFlags();
  if(state.flags.incidentsToday>=3)return;
  state.incidentT=(state.incidentT==null?35000+Math.random()*20000:state.incidentT)-dt;
  if(state.incidentT>0)return;
  const z=currentZone(), unseen=id=>!(state.flags.incidentMask&(1<<INCIDENT_IDS.indexOf(id)));
  let choices=INCIDENT_IDS.filter(id=>{
    const d=INCIDENT_DEFS[id];
    if(!unseen(id))return false;
    if(d.zone&&(!z||z.id!==d.zone))return false;
    if(d.clearDay&&(state.weather!=='clear'||isNight()))return false;
    if(d.required){const n=incidentNpc(d.required);if(!n||n.aggro||n.hostile)return false;}
    return true;
  });
  const specific=choices.filter(id=>INCIDENT_DEFS[id].zone);
  if(specific.length)choices=specific;
  if(!choices.length){state.incidentT=30000;return;}
  let pick=choices[Math.floor(Math.random()*choices.length)];
  if(choices.length>1&&pick===state.flags.lastIncidentId)pick=choices.find(id=>id!==pick)||pick;
  startIncident(pick);
}

export function drawIncidentSprite(key,x,y,frame=0) {
  const sp=SPRITE_CACHE[key+'_'+frame]||SPRITE_CACHE[key+'_0'];
  if(sp&&visibleWorldRect(x-20,y-36,44,48,16))ctx.drawImage(sp,Math.round(x-16),Math.round(y-28),32,32);
}

export function drawIncidents() {
  const inc=state.incident;if(!inc)return;
  const t=state.visualNow||performance.now(), frame=Math.floor(t/320)%2;
  if(inc.id==='runaway_mattress'){
    const a=inc.actors[0];
    ctx.fillStyle='rgba(0,0,0,.36)';ctx.beginPath();ctx.ellipse(a.x,a.y+5,18,4,0,0,Math.PI*2);ctx.fill();
    drawIncidentSprite('incident_mattress',a.x,a.y,frame);
  } else if(inc.id==='possum_inventory'){
    const a=inc.actors[0];drawIncidentSprite('incident_forklift',a.x,a.y,frame);
    const ps=SPRITE_CACHE['possum_'+frame];if(ps)ctx.drawImage(ps,Math.round(a.x-13),Math.round(a.y-39),32,32);
    ctx.fillStyle='#d4c896';ctx.fillRect(Math.round(a.x+12),Math.round(a.y-22),7,9);
  } else if(inc.id==='laundromat_walkout'){
    const a=inc.actors[0];drawIncidentSprite('incident_dryer',a.x,a.y,frame);
    ctx.fillStyle='rgba(136,192,255,.45)';
    for(let i=0;i<6;i++){const bx=a.x-10+((i*13+t/80)%28),by=a.y-25-Math.abs(Math.sin(t/400+i))*18;ctx.fillRect(bx,by,2,2);}
  } else if(inc.id==='yuri_receipt'){
    const a=inc.anchor, reveal=clamp((inc.t-3500)/9000,0,1), count=Math.floor(12*reveal);
    for(let i=0;i<count;i++){
      const q=i/11,x=a.x+(a.tx-a.x)*q,y=a.y+(a.ty-a.y)*q+Math.sin(q*15+t/240)*8;
      ctx.save();ctx.translate(x,y);ctx.rotate(Math.sin(q*9)*.35);ctx.fillStyle='#d4c896';ctx.fillRect(-7,-3,14,6);ctx.fillStyle='#5a4828';ctx.fillRect(-5,-1,7,1);ctx.restore();
    }
  } else if(inc.id==='park_dry_committee'){
    const a=inc.anchor;drawIncidentSprite('incident_sprinkler',a.x,a.y,frame);
    if(inc.t<23000){
      ctx.strokeStyle='rgba(136,192,255,.55)';ctx.lineWidth=2;ctx.setLineDash([3,5]);
      ctx.beginPath();ctx.moveTo(a.x,a.y-12);ctx.lineTo(a.x+Math.cos(inc.sprayAngle)*170,a.y-12+Math.sin(inc.sprayAngle)*170);ctx.stroke();ctx.setLineDash([]);
    }
    for(let i=0;i<6;i++){
      const ang=-2.8+i*.52,px=a.x+Math.cos(ang)*78,py=a.y+Math.sin(ang)*48;
      const ps=SPRITE_CACHE['pigeon_'+((frame+i)&1)];if(ps)ctx.drawImage(ps,Math.round(px-16),Math.round(py-24),32,32);
    }
  } else if(inc.id==='ticketed_luggage'){
    const a=inc.actors[0];drawIncidentSprite('incident_suitcase',a.x,a.y,frame);
    if(inc.t>14000)for(let i=0;i<3;i++){
      const ps=SPRITE_CACHE['pigeon_'+((frame+i)&1)],px=a.x-30-i*26,py=a.y+8+(i&1)*5;
      if(ps)ctx.drawImage(ps,Math.round(px-16),Math.round(py-24),32,32);
    }
  }
}

export function drawIncidentPlayerCosmetics(){
  if(state.incidentPaperT>0){ctx.fillStyle='#d4c896';ctx.fillRect(P.x+P.w-3,P.y+7,9,5);ctx.fillStyle='#5a4828';ctx.fillRect(P.x+P.w-1,P.y+9,5,1);}
  if(state.incidentWetT>0){
    const t=(state.visualNow||performance.now())/120;ctx.fillStyle='#88c0ff';
    for(let i=0;i<3;i++)ctx.fillRect(P.x+3+i*8,P.y+P.h+((t+i*3)%7),2,3);
  }
}

export function init_incidents() {
  // ---------- v15 living-neighborhood incidents ----------
  // These are scene actors, never NPCs. They cannot be targeted, killed, saved as corpses,
  // scanned by interaction priority, or counted by faction/economy systems.
  INCIDENT_IDS = [
    'runaway_mattress','possum_inventory','laundromat_walkout',
    'yuri_receipt','park_dry_committee','ticketed_luggage'
  ];
  INCIDENT_DEFS = {
    runaway_mattress:{
      zone:null, duration:25000, sfx:'traffic', required:null,
      beats:[
        [0,'a mattress enters traffic.'],
        [5200,'traffic yields.\nthe mattress does not.'],
        [12800,'it changes lanes without signaling.\nit has no driver.'],
        [21000,'the mattress exits.\nright of way is restored.'],
      ]
    },
    possum_inventory:{
      zone:'market', duration:30000, sfx:'kick', required:'possum',
      beats:[
        [0,'the marketplace begins inventory.'],
        [5800,'a possum arrives with a forklift and a clipboard.'],
        [14200,'he counts you twice.\nhe does not correct it.'],
        [24800,'inventory closes.'],
      ]
    },
    laundromat_walkout:{
      zone:'laundromat', duration:29000, sfx:'kick', required:'barb',
      beats:[
        [0,'a dryer starts thumping.'],
        [5400,'it rolls out with one wet sock inside.'],
        [13700,'it takes the bus lane.\nbarb fills in 12 down.'],
        [24000,'the dryer stops at a red light.'],
      ]
    },
    yuri_receipt:{
      zone:'scrap', duration:28000, sfx:'radio', required:'yuri',
      beats:[
        [0,'yuri weighs one hubcap.'],
        [5000,'the scale prints fourteen feet of receipt.'],
        [12800,'the wind wraps the dog.\nthe dog remains employed.'],
        [23000,'yuri starts over.'],
      ]
    },
    park_dry_committee:{
      zone:'park', duration:28000, sfx:'holyWaterHit', required:null, clearDay:true,
      beats:[
        [0,'the park sprinkler turns on.'],
        [5200,'six pigeons form a dry committee.'],
        [12600,'the sprinkler turns toward you.\nthey take minutes.'],
        [23000,'the water stops.\nmeeting adjourned.'],
      ]
    },
    ticketed_luggage:{
      zone:'trainyard', duration:31000, sfx:'traffic', required:'conductor',
      beats:[
        [0,'a suitcase rolls into the train yard.'],
        [6000,'the conductor punches its ticket.'],
        [14500,'three pigeons stand behind it.\nthe suitcase leaves on foot.'],
        [26000,'the train does not.'],
      ]
    },
  };
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
}
