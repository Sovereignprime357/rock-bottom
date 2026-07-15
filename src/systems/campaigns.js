/* Generated from frozen rock_bottom_v19.html.
 * Source seams: office, claims, and curb kingdom campaign.
 * Do not hand-edit; change the source module after the refactor lands.
 */
import { audio, saveGame } from '../core/audio_save.js';
import { P, dialogue, runtime, state, toast, unlockAchievement } from '../core/runtime_ui.js';
import { BUILDINGS, PROPS, interactiveProps } from '../data/props.js';
import { ZONES } from '../data/world.js';
import { HIDEOUT_DOORS, OLD_SCHOOL_DOOR, endingScreen, hideoutOwned, inZone, last, openOffice, questToast } from '../legacy.js';
import { broadcastNews, feedPost } from './communications.js';
import { adjustFaction } from './factions.js';
import { ACHIEVEMENTS, currentBlockRouteStop } from './progression_routes.js';

export let OFFICE_DOOR, OFFICE_UPGRADE_DEFS, OFFICE_UPGRADE_IDS, CLAIM_SITES, CLAIM_SITE_BY_ID, CLAIM_STAGES, WORK_STAGES, KINGDOM_STAGES, KINGDOM_DEFEAT_IDS, KINGDOM_STAGE_RANK, KINGDOM_DOORS, KINGDOM_CLANS, KINGDOM_CLAN_LIST, KINGDOM_EMPEROR, KINGDOM_GUARD_POSTS, QUEST_TARGETS;

export function freshOfficeState(){
  const upgrades=Object.create(null);for(const id of OFFICE_UPGRADE_IDS)upgrades[id]=false;
  return {owned:false,upgrades,claimJob:null,workJob:null,workDay:0,workToday:0,jobsCompleted:0,orderSerial:0,rerollDay:0,lastWorkId:''};
}

export function normalizeDistrictClaims(raw){
  const out=Object.create(null);
  if(raw&&typeof raw==='object')for(const c of CLAIM_SITES)if(raw[c.id]===true)out[c.id]=true;
  return out;
}

export function officeNat(value,max=1000000000){
  const n=Number(value);return Number.isFinite(n)?Math.max(0,Math.min(max,Math.floor(n))):0;
}

export function normalizeOfficeState(raw,claims){
  const out=freshOfficeState(),r=raw&&typeof raw==='object'?raw:{};
  out.owned=!!r.owned;
  if(r.upgrades&&typeof r.upgrades==='object')for(const id of OFFICE_UPGRADE_IDS)out.upgrades[id]=r.upgrades[id]===true;
  const cj=r.claimJob;
  if(cj&&Object.hasOwn(CLAIM_SITE_BY_ID,cj.id)&&CLAIM_STAGES.has(cj.stage)&&!claims[cj.id])out.claimJob={id:cj.id,stage:cj.stage};
  const wj=r.workJob;
  if(wj&&Object.hasOwn(CLAIM_SITE_BY_ID,wj.id)&&WORK_STAGES.has(wj.stage)&&claims[wj.id])out.workJob={id:wj.id,stage:wj.stage,serial:Math.max(1,officeNat(wj.serial))};
  out.workDay=officeNat(r.workDay);
  out.workToday=officeNat(r.workToday,3);
  out.jobsCompleted=officeNat(r.jobsCompleted);
  out.orderSerial=Math.max(out.jobsCompleted,officeNat(r.orderSerial),out.workJob?out.workJob.serial:0);
  out.rerollDay=officeNat(r.rerollDay);
  out.lastWorkId=Object.hasOwn(CLAIM_SITE_BY_ID,r.lastWorkId)?r.lastWorkId:'';
  if(out.claimJob)out.workJob=null;
  // A valid upgrade, claim, or job is stronger recovery evidence than one missing owned bit.
  // This preserves legitimate progress from a partially-written save without granting anything
  // to a pre-v18 save, whose office payload and district ledger are both empty.
  if(!out.owned){
    const hasUpgrade=OFFICE_UPGRADE_DEFS.some(d=>out.upgrades[d.id]);
    out.owned=hasUpgrade||!!out.claimJob||!!out.workJob||out.jobsCompleted>0||CLAIM_SITES.some(d=>claims[d.id]);
  }
  if(out.claimJob||CLAIM_SITES.some(d=>claims[d.id]))out.upgrades.desk=true;
  if(out.workJob||out.jobsCompleted>0)out.upgrades.radio=true;
  if(!out.owned){out.workDay=0;out.workToday=0;out.orderSerial=0;out.rerollDay=0;out.lastWorkId='';}
  return out;
}

export function ensureOfficeState(){
  state.districtClaims=normalizeDistrictClaims(state.districtClaims);
  state.office=normalizeOfficeState(state.office,state.districtClaims);
  return state.office;
}

export function claimedDistrictIds(){
  const claims=state.districtClaims||{};return CLAIM_SITES.filter(c=>claims[c.id]===true).map(c=>c.id);
}

export function officeOwned(){return !!(state.office&&state.office.owned);}

export function activeOfficeContract(){const o=state.office;return !!(o&&(o.claimJob||o.workJob));}

export function officeDailyCap(){return Math.min(3,1+Math.floor(claimedDistrictIds().length/4));}

export function syncOfficeDay(){
  if(!state.office)ensureOfficeState();const o=state.office;if(o.workDay!==state.day){o.workDay=state.day;o.workToday=0;}
}

export function maybeUnlockOfficeQuest(persist=true){
  if(!state.flags||!state.flags.introDone||!state.quests||officeOwned())return false;
  const q=state.quests.office_space;if(!q||q.done||(P.lifetime.routesCompleted||0)<3)return false;
  if(q.available===false){
    q.available=true;
    toast('Â· NEW BAD IDEA Â·\nthe leasing guy has a unit.\nwalk-ins are somehow accepted.',3600);
    feedPost('three routes filed. a leasing guy has noticed.','@crackheadcent');
    if(persist)saveGame();return true;
  }
  return false;
}

export function claimGateReason(def){
  if(!def)return 'not on the form.';
  if((state.districtClaims||{})[def.id])return 'already entered in pen.';
  if(def.faction!=='neutral'&&(!P.faction||(P.faction[def.faction]||0)<10))return def.faction+' must be liked (+10).';
  return '';
}

export function updateOfficeMilestones(persist=true){
  const count=claimedDistrictIds().length;
  let changed=P.lifetime.territoriesClaimed!==count;
  P.lifetime.territoriesClaimed=count;
  const qs=state.quests||{};
  const first=count>=1&&qs.paper_empire&&!qs.paper_empire.done;
  const regional=count>=4&&qs.regional_office&&!qs.regional_office.done;
  const all=count>=CLAIM_SITES.length&&qs.all_business&&!qs.all_business.done;
  const setQuest=(q,key,value)=>{if(q&&q[key]!==value){q[key]=value;changed=true;}};
  // Finish every milestone mutation before one optional save, so no partial snapshot can
  // race the final claim transaction or leave partial-save repairs repeating forever.
  if(count>=1){setQuest(qs.paper_empire,'done',true);setQuest(qs.paper_empire,'available',true);setQuest(qs.regional_office,'available',true);}
  if(count>=4){setQuest(qs.regional_office,'done',true);setQuest(qs.regional_office,'available',true);setQuest(qs.all_business,'available',true);}
  if(count>=CLAIM_SITES.length){setQuest(qs.all_business,'done',true);setQuest(qs.all_business,'available',true);}
  if(first)questToast('PAPER EMPIRE');
  if(regional)questToast('REGIONAL OFFICE');
  if(all)questToast('ALL BUSINESS');
  const earned=[];
  if(count>=1)earned.push('zoning_error');
  if(count>=4)earned.push('regional_office');
  if(count>=8)earned.push('middle_management');
  if(count>=CLAIM_SITES.length)earned.push('paper_everywhere');
  const fresh=earned.filter(id=>ACHIEVEMENTS[id]&&!state.achievements.has(id));
  for(const id of fresh){state.achievements.add(id);changed=true;}
  if(fresh.length){
    const last=fresh[fresh.length-1];toast('· ACHIEVEMENT ·\n'+ACHIEVEMENTS[last].name+(fresh.length>1?'\n'+fresh.length+' office records reconciled.':''),3000);audio.rankUp();
  }
  if(changed&&persist)saveGame();
  return changed;
}

export function currentOfficeObjective(){
  if(!state.flags||!state.flags.introDone||!state.quests)return null;
  const o=state.office||freshOfficeState(),officeQ=state.quests.office_space,paperQ=state.quests.paper_empire;
  if(!o.owned&&officeQ&&!officeQ.done&&officeQ.available===true)return {kind:'office',text:'find the leasing guy in the lot.',x:5400,y:3100};
  if(o.claimJob){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id];
    if(o.claimJob.stage==='survey')return {kind:'office',text:'survey '+d.name.toLowerCase()+'. '+d.survey.task,x:d.survey.x,y:d.survey.y};
    if(o.claimJob.stage==='file')return {kind:'office',text:'return to the office and file '+d.name.toLowerCase()+'.',x:4920,y:3210};
    return {kind:'office',text:'install the claim sign. '+d.sign.task,x:d.sign.x,y:d.sign.y};
  }
  if(o.workJob){
    const d=CLAIM_SITE_BY_ID[o.workJob.id];
    return o.workJob.stage==='inspect'
      ? {kind:'office',text:'order '+o.workJob.serial+' Â· inspect the '+d.name.toLowerCase()+' sign.',x:d.sign.x,y:d.sign.y}
      : {kind:'office',text:'order '+o.workJob.serial+' Â· return to the office and file.',x:4920,y:3210};
  }
  if(o.owned&&paperQ&&!paperQ.done&&paperQ.available===true){
    return {kind:'office',text:o.upgrades&&o.upgrades.desk?'use the office desk. claim the drainage canal.':'put a desk in the office.',x:4920,y:3210};
  }
  return null;
}

export function selectDistrictClaim(id){
  const o=ensureOfficeState(),d=CLAIM_SITE_BY_ID[id];
  if(!o.owned||!o.upgrades.desk||o.claimJob||o.workJob||!d)return false;
  const why=claimGateReason(d);if(why){toast(why,1800);return false;}
  o.claimJob={id,stage:'survey'};
  toast('Â· CLAIM OPENED Â·\n'+d.name+'\nfirst: '+d.survey.task,3200);saveGame();return true;
}

export function cancelDistrictClaim(){
  const o=ensureOfficeState();if(!o.claimJob)return;
  const paid=o.claimJob.stage==='install';o.claimJob=null;
  toast(paid?'the form is canceled.\nthe filing fee is not.':'the form is canceled.\nno one had signed it.',2400);saveGame();
}

export function claimFileCost(){return 20+5*claimedDistrictIds().length;}

export function fileDistrictClaim(){
  const o=ensureOfficeState();if(!o.claimJob||o.claimJob.stage!=='file')return false;
  const cost=claimFileCost();if(P.cash<cost||P.copper<1){toast('filing needs $'+cost+' and 1 pure copper.\nthe desk cannot spot you.',2400);return false;}
  P.cash-=cost;P.copper--;o.claimJob.stage='install';audio.coin();
  const d=CLAIM_SITE_BY_ID[o.claimJob.id];toast('- $'+cost+' Â· - 1 copper\nform filed.\nnow install the sign at '+d.name.toLowerCase()+'.',3400);saveGame();return true;
}

export function tryUseOfficeFieldTarget(){
  if(document.hidden||state.mode!=='playing'||P.stunT>0||state.bossActive||state.brutusOlderActive)return false;
  const o=state.office;if(!o)return false;const pcx=P.x+P.w/2,pcy=P.y+P.h/2;
  if(o.claimJob&&(o.claimJob.stage==='survey'||o.claimJob.stage==='install')){
    const d=CLAIM_SITE_BY_ID[o.claimJob.id],p=o.claimJob.stage==='survey'?d.survey:d.sign;
    const dx=pcx-p.x,dy=pcy-p.y;if(dx*dx+dy*dy>=58*58)return false;
    if(o.claimJob.stage==='survey'){
      o.claimJob.stage='file';audio.coin();toast(p.stamp+'\nreturn to the office. the desk wants money.',3000);saveGame();return true;
    }
    state.districtClaims[d.id]=true;o.claimJob=null;P.cred+=2;updateOfficeMilestones(false);maybeUnlockKingdom(false,true);audio.rankUp();
    toast(p.stamp+'\nÂ· DISTRICT ENTERED Â·  + 2 cred\n'+d.name,3800);feedPost('installed a sign at '+d.name.toLowerCase()+'. the sign has standing.','@crackheadcent');saveGame();return true;
  }
  if(o.workJob&&o.workJob.stage==='inspect'){
    const d=CLAIM_SITE_BY_ID[o.workJob.id],p=d.sign,dx=pcx-p.x,dy=pcy-p.y;
    if(dx*dx+dy*dy>=58*58)return false;
    o.workJob.stage='file';audio.coin();toast('sign inspected.\nit is still leaning.\nreturn to the office.',2600);saveGame();return true;
  }
  return false;
}

export function startOfficeWork(){
  const o=ensureOfficeState();syncOfficeDay();const owned=claimedDistrictIds();
  if(!o.upgrades.radio||!owned.length||o.claimJob||o.workJob||o.workToday>=officeDailyCap())return false;
  let pool=owned.filter(id=>id!==o.lastWorkId);if(!pool.length)pool=owned.slice();
  const id=pool[Math.floor(Math.random()*pool.length)];o.orderSerial++;o.workJob={id,stage:'inspect',serial:o.orderSerial};o.lastWorkId=id;
  const d=CLAIM_SITE_BY_ID[id];toast('Â· WORK ORDER '+o.orderSerial+' Â·\ninspect the sign at '+d.name.toLowerCase()+'.\nbring the condition back.',3200);saveGame();return true;
}

export function fileOfficeWork(){
  const o=ensureOfficeState();syncOfficeDay();if(!o.workJob||o.workJob.stage!=='file')return false;
  if(o.workToday>=officeDailyCap()){toast('the daily ledger is closed.\nthe inspected order waits for morning.',2200);return false;}
  const count=claimedDistrictIds().length,pay=Math.min(12,5+count);o.jobsCompleted++;o.workToday++;
  P.lifetime.officeJobs=o.jobsCompleted;P.cash+=pay;const cred=o.jobsCompleted%5===0?1:0;if(cred)P.cred++;
  const serial=o.workJob.serial;o.workJob=null;audio.coin();
  toast('Â· ORDER '+serial+' FILED Â·\ngross $'+(pay+17)+'. chair rental $17.\nnet + $'+pay+(cred?' Â· + 1 cred':''),3600);saveGame();return true;
}

export function purchaseOfficeUpgrade(id){
  const o=ensureOfficeState(),d=OFFICE_UPGRADE_DEFS.find(x=>x.id===id);if(!o.owned||!d||o.upgrades[id])return false;
  if(P.cash<d.cash||P.copper<d.copper){toast(d.name+' needs $'+d.cash+(d.copper?' and '+d.copper+' pure copper':'')+'.\nthe office does not extend credit.',2200);return false;}
  P.cash-=d.cash;P.copper-=d.copper;o.upgrades[id]=true;audio.rankUp();toast('Â· OFFICE UPGRADE Â·\n'+d.name+' installed.\n'+d.desc,3000);saveGame();return true;
}

export function purchaseOffice(){
  const o=ensureOfficeState();if(o.owned)return false;
  if((P.lifetime.routesCompleted||0)<3||P.cash<40||P.copper<1){toast('the key needs three filed routes, $40, and 1 pure copper.',2400);return false;}
  P.cash-=40;P.copper--;o.owned=true;
  const q=state.quests.office_space;if(q){q.done=true;q.available=true;questToast('THE OFFICE');}
  if(state.quests.paper_empire)state.quests.paper_empire.available=true;
  unlockAchievement('squatters_rights');audio.rankUp();toast('- $40 Â· - 1 copper\n+ one key\nthe office is yours in the sense that no one stopped you.',4200);feedPost('acquired an office. the office was surprised.','@crackheadcent');saveGame();return true;
}

export function leaseGuyDialogue(){
  const o=ensureOfficeState(),routes=P.lifetime.routesCompleted||0;
  if(o.owned){dialogue('THE LEASING GUY','he checks the key ring.\none key is missing.\nhe knows which key.',[{label:'ask about the lease.',action:()=>toast('there is no lease.\nhe says this like a feature.')},{label:'leave.',action:()=>{}}]);return;}
  const ready=routes>=3,PAY=P.cash>=40&&P.copper>=1;
  dialogue('THE LEASING GUY',ready?'he has a key on a fishhook.\nthe unit says TAX HELP.\nthere is no tax help.':'he has a key on a fishhook.\nhe wants three route sheets before he knows your name.\nhe does not want your name.',[
    {label:ready?(PAY?'replace the lock. $40 + 1 pure copper.':'need $40 and 1 pure copper.'):'file three block routes first. ('+routes+'/3)',disabled:!ready||!PAY,action:purchaseOffice},
    {label:'ask what the unit includes.',action:()=>toast('four walls.\none door.\na smell with seniority.')},
    {label:'leave.',action:()=>{}},
  ]);
}

export function gutterGregDialogue(){
  const done=(state.counters.gutterInventoryDay||0)===state.day;
  dialogue('GUTTER GREG','greg is guarding a rubber duck.\nthe duck is in the municipal inventory.\nthe municipality has not been told.',[
    {label:done?'count inventory. (already counted today.)':'count the canal inventory. (+1 scrap)',disabled:done,action:()=>{state.counters.gutterInventoryDay=state.day;adjustFaction('scrap',1);toast('duck: one.\ncart parts: uncertain.\n+ 1 scrap',2400);saveGame();}},
    {label:'ask where the water went.',action:()=>toast('greg points downstream.\nthere is no downstream on the form.')},
    {label:'leave.',action:()=>{}},
  ]);
}

export function freshKingdomState(){
  return {stage:'locked',marks:0,bossId:'',defeats:[],pretenderDay:0,pretenderDefeatedDay:0,pretendersDefeated:0};
}

export function normalizeKingdomState(raw,demoteBoss=false){
  const r=raw&&typeof raw==='object'?raw:{},out=freshKingdomState();
  out.stage=KINGDOM_STAGES.has(r.stage)?r.stage:'locked';
  out.marks=officeNat(r.marks,7);
  if(Array.isArray(r.defeats))for(const id of KINGDOM_DEFEAT_IDS)if(r.defeats.includes(id))out.defeats.push(id);
  out.pretenderDay=officeNat(r.pretenderDay);
  out.pretenderDefeatedDay=officeNat(r.pretenderDefeatedDay);
  out.pretendersDefeated=officeNat(r.pretendersDefeated);
  out.bossId='';
  // Spawned combatants are ephemeral. A loaded fight becomes a full-HP retry at its banner.
  if(demoteBoss&&out.stage==='tarp_boss'){out.stage='tarp_marks';out.marks=7;out.bossId='';}
  else if(demoteBoss&&out.stage==='cart_boss'){out.stage='cart_marks';out.marks=7;out.bossId='';}
  else if(demoteBoss&&out.stage==='wire_boss'){out.stage='wire_marks';out.marks=7;out.bossId='';}
  else if(demoteBoss&&out.stage==='emperor_boss'){out.stage='emperor_gate';out.marks=0;out.bossId='';}
  // A durable defeat is stronger than a stale earlier stage. Advance to the first unpaid
  // hearing before deriving the prerequisite prefix; repair never grants its reward again.
  let rank=KINGDOM_STAGE_RANK[out.stage]||0;
  if(out.defeats.includes('curb_emperor'))out.stage='complete';
  else if(out.defeats.includes('bishop_wire')&&rank<KINGDOM_STAGE_RANK.anoint)out.stage='anoint';
  else if(out.defeats.includes('general_receipt')&&rank<KINGDOM_STAGE_RANK.wire_marks)out.stage='wire_marks';
  else if(out.defeats.includes('darryl_under_blue')&&rank<KINGDOM_STAGE_RANK.cart_marks)out.stage='cart_marks';
  // Later durable stages witness prerequisite victories without replaying their rewards.
  rank=KINGDOM_STAGE_RANK[out.stage]||0;
  if(rank>=KINGDOM_STAGE_RANK.cart_marks&&!out.defeats.includes('darryl_under_blue'))out.defeats.push('darryl_under_blue');
  if(rank>=KINGDOM_STAGE_RANK.wire_marks&&!out.defeats.includes('general_receipt'))out.defeats.push('general_receipt');
  if(rank>=KINGDOM_STAGE_RANK.anoint&&!out.defeats.includes('bishop_wire'))out.defeats.push('bishop_wire');
  if(out.stage==='complete'&&!out.defeats.includes('curb_emperor'))out.defeats.push('curb_emperor');
  out.defeats=KINGDOM_DEFEAT_IDS.filter(id=>out.defeats.includes(id));
  if(!['tarp_marks','cart_marks','wire_marks'].includes(out.stage))out.marks=0;
  const expectedBoss={tarp_boss:'darryl_under_blue',cart_boss:'general_receipt',wire_boss:'bishop_wire',emperor_boss:'curb_emperor'}[out.stage]||'';
  if(!demoteBoss&&expectedBoss&&r.bossId===expectedBoss)out.bossId=expectedBoss;
  return out;
}

export function ensureKingdomState(){
  state.kingdom=normalizeKingdomState(state.kingdom);
  P.lifetime.pretendersDefeated=Math.max(officeNat(P.lifetime.pretendersDefeated),state.kingdom.pretendersDefeated);
  state.kingdom.pretendersDefeated=P.lifetime.pretendersDefeated;
  return state.kingdom;
}

export function kingdomEligible(){
  return officeOwned()&&claimedDistrictIds().length>=4&&!!(state.quests&&state.quests.fallen_king&&state.quests.fallen_king.done);
}

export function maybeUnlockKingdom(persist=true,announce=true){
  const k=ensureKingdomState();if(k.stage!=='locked'||!kingdomEligible())return false;
  k.stage='summons';k.marks=0;
  if(state.quests&&state.quests.hostile_correspondence)state.quests.hostile_correspondence.available=true;
  if(announce){
    toast('· HOSTILE CORRESPONDENCE ·\na radio frequency has billed your curb.\nthe office has the envelope.',4200);
    feedPost('regional office received a kingdom notice. postage due.','@blocklog');
  }
  if(persist)saveGame();return true;
}

export function kingdomStageClan(stage=(state.kingdom&&state.kingdom.stage)){
  return KINGDOM_CLAN_LIST.find(c=>c.marksStage===stage||c.bossStage===stage)||null;
}

export function syncKingdomQuests(){
  if(!state.quests)return;const k=state.kingdom||freshKingdomState(),rank=KINGDOM_STAGE_RANK[k.stage]||0,def=new Set(k.defeats||[]);
  const set=(id,available,done)=>{const q=state.quests[id];if(q){q.available=!!available;q.done=!!done;}};
  set('hostile_correspondence',rank>=1,rank>=2);
  set('blue_weather',rank>=2,def.has('darryl_under_blue'));
  set('cart_appeal',rank>=4,def.has('general_receipt'));
  set('copper_mass',rank>=6,def.has('bishop_wire'));
  set('royal_static',rank>=8,rank>=9);
  set('one_cracklord',rank>=9,k.stage==='complete');
}

export function currentKingdomObjective(){
  const k=state.kingdom;if(!k)return null;
  if(k.stage==='locked'){
    const fallen=state.quests&&state.quests.fallen_king;
    if(officeOwned()&&claimedDistrictIds().length>=4&&fallen&&!fallen.done&&fallen.available!==false){
      return {kind:'kingdom',text:'settle the corner with tre bag tony. the regional envelope needs one local vacancy.',x:1634,y:886};
    }
    return null;
  }
  if(k.stage==='summons'){
    const radio=state.office&&state.office.upgrades&&state.office.upgrades.radio;
    return {kind:'kingdom',text:radio?'answer the hostile radio summons at the office.':'install the office radio. hostile postage is waiting.',x:4920,y:3210};
  }
  const clan=kingdomStageClan(k.stage);
  if(clan){
    if(k.stage===clan.bossStage){
      const b=runtime.npcs.find(n=>n.kingdomBoss&&n.id===clan.bossId&&!n.dead);
      return {kind:'kingdom',text:'defeat '+clan.bossName.toLowerCase()+'. his court has no appeals.',x:b?b.x+b.w/2:clan.boss.x,y:b?b.y+b.h/2:clan.boss.y};
    }
    if(k.marks===7)return {kind:'kingdom',text:'challenge '+clan.bossName.toLowerCase()+' at the court banner.',x:clan.banner.x,y:clan.banner.y};
    const idx=[0,1,2].find(i=>(k.marks&(1<<i))===0),m=clan.marks[idx];
    return {kind:'kingdom',text:clan.name.toLowerCase()+' · '+(bitCount3(k.marks))+'/3 · '+m.task,x:m.x,y:m.y};
  }
  if(k.stage==='anoint')return {kind:'kingdom',text:'smoke one real rock at the block. the crown requires bad reception.',x:1064,y:882};
  if(k.stage==='emperor_gate')return {kind:'kingdom',text:'challenge the curb emperor in the throne ditch.',x:KINGDOM_EMPEROR.banner.x,y:KINGDOM_EMPEROR.banner.y};
  if(k.stage==='emperor_boss'){
    const b=runtime.npcs.find(n=>n.kingdomBoss&&n.id==='curb_emperor'&&!n.dead);
    return {kind:'kingdom',text:'defeat the curb emperor. measure nothing.',x:b?b.x+b.w/2:KINGDOM_EMPEROR.boss.x,y:b?b.y+b.h/2:KINGDOM_EMPEROR.boss.y};
  }
  if(k.stage==='complete'){
    const p=runtime.npcs.find(n=>n.kingdomPretender&&!n.dead);
    if(p)return {kind:'pretender',text:'today\'s curb pretender has filed in person.',x:p.x+p.w/2,y:p.y+p.h/2};
  }
  return null;
}

export function resolveKingdomActionHint(){
  const k=state.kingdom;if(!k)return '';const pcx=P.x+P.w/2,pcy=P.y+P.h/2,clan=kingdomStageClan(k.stage);
  if(clan&&k.stage===clan.marksStage){
    for(let i=0;i<clan.marks.length;i++){if(k.marks&(1<<i))continue;const m=clan.marks[i],dx=pcx-m.x,dy=pcy-m.y;if(dx*dx+dy*dy<58*58)return 'serve the curb correction';}
    if(k.marks===7){const dx=pcx-clan.banner.x,dy=pcy-clan.banner.y;if(dx*dx+dy*dy<72*72)return 'challenge '+clan.bossName.toLowerCase();}
  }
  if(k.stage==='emperor_gate'){const dx=pcx-KINGDOM_EMPEROR.banner.x,dy=pcy-KINGDOM_EMPEROR.banner.y;if(dx*dx+dy*dy<72*72)return 'challenge the curb emperor';}
  return '';
}

export function bitCount3(v){v=officeNat(v,7);return (v&1?1:0)+(v&2?1:0)+(v&4?1:0);}

export function tryKingdomDoor(){
  const pcx=P.x+P.w/2,pcy=P.y+P.h/2;
  for(const d of KINGDOM_DOORS){const dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);if(dx*dx+dy*dy<44*44){toast(d.line,2200);return true;}}
  return false;
}

export function acceptKingdomSummons(){
  const k=ensureKingdomState(),o=ensureOfficeState();if(k.stage!=='summons'||!o.upgrades.radio)return false;
  k.stage='tarp_marks';k.marks=0;
  syncKingdomQuests();audio.radio();
  toast('· CURB WAR OPEN ·\nblue tarp court disputes your weather.\nserve three corrections.',4200);
  broadcastNews('SUCCESSION NOTICE FILED. THREE COURTS OBJECT. ONE DITCH IS LISTENING.');
  feedPost('answered the radio. blue tarp court says the sky belongs to a rope.','@crackheadcent');
  saveGame();return true;
}

export function openKingdomLedger(){
  const k=ensureKingdomState(),o=ensureOfficeState();
  if(k.stage==='summons'){
    dialogue('HOSTILE CORRESPONDENCE','the envelope says OCCUPANT / REGARDING KINGDOM.\nthe return address is a tarp tied to a fence.',[
      {label:o.upgrades.radio?'answer the frequency.':'install the radio first.',disabled:!o.upgrades.radio,action:acceptKingdomSummons},
      {label:'leave it under the stapler.',action:()=>{}},
    ]);return;
  }
  const obj=currentKingdomObjective(),seals=(k.defeats||[]).filter(id=>id!=='curb_emperor').length;
  syncOfficeDay();const claims=claimedDistrictIds().length,cap=officeDailyCap();
  const workLabel=!o.upgrades.radio?'work orders need a radio.'
    :o.workJob?'work order '+o.workJob.serial+' is '+o.workJob.stage+'.'
    :!claims?'work orders need one claimed district.'
    :o.workToday>=cap?'work orders closed today. ('+o.workToday+'/'+cap+')'
    :'take a work order. ('+o.workToday+'/'+cap+' filed today)';
  const opts=[
    {label:'read the succession clause.',action:()=>toast('one curb. one ruler.\nall measurements final.\nno ruler has supplied a ruler.',3000)},
    {label:workLabel,disabled:!o.upgrades.radio||!!o.workJob||!!o.claimJob||!claims||o.workToday>=cap,action:()=>{startOfficeWork();}},
    {label:'back to the office.',action:()=>openOffice()},
  ];
  dialogue('CURB WAR LEDGER',(obj?obj.text:'the chair remains occupied.')+'\n\nseals entered: '+seals+'/3\npretenders removed: '+(k.pretendersDefeated||0),opts);
}

export function tryUseKingdomTarget(){
  if(document.hidden||state.mode!=='playing'||P.stunT>0||state.bossActive||state.brutusOlderActive)return false;
  const k=ensureKingdomState(),pcx=P.x+P.w/2,pcy=P.y+P.h/2,clan=kingdomStageClan(k.stage);
  if(clan&&k.stage===clan.marksStage){
    for(let i=0;i<clan.marks.length;i++){
      if(k.marks&(1<<i))continue;const m=clan.marks[i],dx=pcx-m.x,dy=pcy-m.y;
      if(dx*dx+dy*dy<58*58){k.marks|=(1<<i);audio.coin();toast(m.stamp+'\n['+bitCount3(k.marks)+'/3 corrections served]',3000);if(k.marks===7)toast('all three corrections entered.\n'+clan.bossName.toLowerCase()+' is accepting one appeal.',3600);saveGame();return true;}
    }
    if(k.marks===7){const dx=pcx-clan.banner.x,dy=pcy-clan.banner.y;if(dx*dx+dy*dy<72*72)return startKingdomBoss(clan.id);}
  }
  if(k.stage==='emperor_gate'){
    const dx=pcx-KINGDOM_EMPEROR.banner.x,dy=pcy-KINGDOM_EMPEROR.banner.y;
    if(dx*dx+dy*dy<72*72)return startKingdomBoss('emperor');
  }
  return false;
}

export function makeKingdomActor(def,at,extra={}){
  return {id:extra.id||('kingdom_'+Math.random().toString(36).slice(2,9)),name:extra.name||def.guardName,sprite:extra.sprite||def.guardSprite,
    x:at.x-16,y:at.y-16,w:32,h:32,color:'#3a3028',hp:extra.hp||55,maxHp:extra.hp||55,speed:extra.speed||1.35,dmg:extra.dmg||7,
    hostile:true,aggro:extra.aggro===true,showHp:!!extra.showHp,archetype:extra.archetype||'charger',attackCd:0,wanderT:0,targetX:at.x,targetY:at.y,
    zoneOnly:def.zoneOnly,kingdomClan:def.id||extra.kingdomClan,transient:true,noComboReward:true,...extra};
}

export function startKingdomBoss(id){
  const k=ensureKingdomState();if(state.bossActive||state.brutusOlderActive)return false;
  const emperor=id==='emperor',def=emperor?KINGDOM_EMPEROR:KINGDOM_CLANS[id];if(!def)return false;
  if(emperor?k.stage!=='emperor_gate':(k.stage!==def.marksStage||k.marks!==7))return false;
  const boss=makeKingdomActor(def,def.boss,{id:def.bossId,name:def.bossName,sprite:def.bossSprite,hp:def.bossHp,dmg:def.bossDmg,speed:def.bossSpeed,archetype:def.archetype,showHp:true,aggro:true,kingdomBoss:true,kingdomClan:emperor?'throne':def.id,kingdomPhase:1});
  if(!boss)return false;
  runtime.npcs=runtime.npcs.filter(n=>!(n.kingdomGuard&&(emperor?n.kingdomClan==='throne':n.kingdomClan===def.id)));
  runtime.npcs.push(boss);
  const addSprite=emperor?['blue_tarp_guard','receipt_guard']:null;
  def.adds.forEach((at,i)=>runtime.npcs.push(makeKingdomActor(def,at,{id:'kingdom_add_'+def.bossId+'_'+i,name:emperor?'CURB HOLDOUT':def.guardName,sprite:addSprite?addSprite[i%addSprite.length]:def.guardSprite,hp:45,dmg:6,speed:1.35,archetype:i?'swarmer':'charger',aggro:true,kingdomAdd:true,kingdomClan:emperor?'throne':def.id})));
  k.stage=emperor?'emperor_boss':def.bossStage;k.bossId=def.bossId;
  state.kingdomBattle={id:def.bossId,zoneId:def.zoneId,escapeT:0};state.bossActive=true;state.bossKind='kingdom';state.bossPhase=1;state.bossNPC=boss;
  audio.bossRoar();state.shake=10;
  toast(emperor?'the curb emperor stands from the chair.\nthe chair keeps the title.':def.bossName.toLowerCase()+' accepts the appeal.\ntwo clerks stand with him.',4000);
  saveGame();return true;
}

export function clearKingdomBossGlobals(){
  state.bossActive=false;state.bossKind='';state.bossPhase=0;state.bossNPC=null;state.kingdomBattle=null;
  if(state.kingdom)state.kingdom.bossId='';
}

export function abortKingdomFight(show=false){
  if(state.bossKind!=='kingdom'&&!state.kingdomBattle)return false;
  const k=ensureKingdomState();
  if(k.stage==='tarp_boss'){k.stage='tarp_marks';k.marks=7;}
  else if(k.stage==='cart_boss'){k.stage='cart_marks';k.marks=7;}
  else if(k.stage==='wire_boss'){k.stage='wire_marks';k.marks=7;}
  else if(k.stage==='emperor_boss'){k.stage='emperor_gate';k.marks=0;}
  const doomed=new Set(runtime.npcs.filter(n=>n.kingdomBoss||n.kingdomAdd).map(n=>n.id));
  runtime.npcs=runtime.npcs.filter(n=>!n.kingdomBoss&&!n.kingdomAdd);
  runtime.projectiles=runtime.projectiles.filter(p=>!(p.from&&(p.from.kingdomBoss||p.from.kingdomAdd||doomed.has(p.from.id))));
  clearKingdomBossGlobals();syncKingdomQuests();
  if(show)toast('the appeal is recessed.\nall three corrections remain entered.\nfull hearing available.',2800);
  return true;
}

export function completeKingdomBoss(n){
  const k=ensureKingdomState();if(!n||!n.kingdomBoss||k.bossId!==n.id||state.bossKind!=='kingdom')return false;
  const emperor=n.id==='curb_emperor',clan=emperor?null:KINGDOM_CLAN_LIST.find(c=>c.bossId===n.id);
  if(!emperor&&(!clan||k.stage!==clan.bossStage))return false;
  if(emperor&&k.stage!=='emperor_boss')return false;
  if(k.defeats.includes(n.id))return false;
  k.defeats.push(n.id);P.cash+=emperor?KINGDOM_EMPEROR.rewardCash:clan.rewardCash;P.cred+=emperor?KINGDOM_EMPEROR.rewardCred:clan.rewardCred;
  runtime.npcs=runtime.npcs.filter(x=>!x.kingdomAdd&&x!==n);runtime.projectiles=runtime.projectiles.filter(p=>!(p.from&&(p.from.kingdomBoss||p.from.kingdomAdd)));
  clearKingdomBossGlobals();
  if(!emperor){
    k.stage=clan.nextStage;k.marks=0;state.flags[clan.clearFlag]=true;
    const questName=clan.id==='blue_tarp'?'BLUE WEATHER':clan.id==='cart_cavalry'?'CART APPEAL':'COPPER MASS';
    questToast(questName);audio.rankUp();
    toast('· '+clan.seal+' ENTERED ·\n+ $'+clan.rewardCash+' · + '+clan.rewardCred+' cred\n'+clan.name.toLowerCase()+' retains two objectors.',4400);
    feedPost(clan.bossName.toLowerCase()+' is down. the seal is bent but legible.','@blocklog');
    syncKingdomQuests();syncKingdomForces();saveGame();return true;
  }
  k.stage='complete';k.marks=0;k.pretenderDefeatedDay=state.day;state.flags.throneDitchCleared=true;
  P.lifetime.pretendersDefeated=k.pretendersDefeated;
  if(state.quests&&state.quests.one_cracklord){state.quests.one_cracklord.available=true;state.quests.one_cracklord.done=true;}
  if(ACHIEVEMENTS.one_cracklord)unlockAchievement('one_cracklord');
  syncKingdomQuests();syncKingdomForces();audio.rankUp();
  toast('· ONE CRACKLORD ·\n+ $60 · + 40 cred\nthe throne remains a folding chair.',4800);
  saveGame();setTimeout(()=>endingScreen('kingdom'),2600);return true;
}

export function updateKingdomBattle(dt){
  if(state.bossKind!=='kingdom'||!state.bossNPC||state.bossNPC.dead)return;
  const b=state.bossNPC,battle=state.kingdomBattle,z=ZONES.find(x=>x.id===(battle&&battle.zoneId));if(!z)return;
  const cx=P.x+P.w/2,cy=P.y+P.h/2,inside=cx>=z.x&&cx<=z.x+z.w&&cy>=z.y&&cy<=z.y+z.h;
  battle.escapeT=inside?0:(battle.escapeT||0)+dt;
  if(battle.escapeT>5000){abortKingdomFight(true);syncKingdomForces();saveGame();return;}
  if(b.id==='curb_emperor'){
    const pct=b.hp/b.maxHp;
    if(pct<.66&&b.kingdomPhase===1){b.kingdomPhase=2;b.archetype='ranged';b.speed=1.2;toast('the emperor cites the curb from a distance.\nthe citation is airborne.',2400);}
    else if(pct<.33&&b.kingdomPhase===2){b.kingdomPhase=3;b.archetype='charger';b.berserk=true;b.speed=2.6;b.dmg=15;toast('the emperor breaks the ruler.\nmeasurement is now personal.',2600);audio.bossRoar();}
  }
}

export function syncKingdomForces(){
  if(!Array.isArray(runtime.npcs))return;const k=ensureKingdomState();
  runtime.npcs=runtime.npcs.filter(n=>!n.kingdomGuard&&!n.kingdomPretender);
  const defeated=new Set(k.defeats||[]);
  for(const clan of KINGDOM_CLAN_LIST){
    if(k.stage===clan.bossStage)continue;const posts=KINGDOM_GUARD_POSTS[clan.id],count=defeated.has(clan.bossId)?2:4;
    for(let i=0;i<count;i++)runtime.npcs.push(makeKingdomActor(clan,posts[i],{id:'kingdom_guard_'+clan.id+'_'+state.day+'_'+i,name:clan.guardName,sprite:clan.guardSprite,hp:defeated.has(clan.bossId)?48:58,dmg:7,speed:1.25,archetype:i%3===2?'ranged':i%2?'swarmer':'charger',kingdomGuard:true,transient:false}));
  }
  if(k.stage!=='emperor_boss'){
    const count=k.stage==='complete'?2:3,posts=KINGDOM_GUARD_POSTS.throne,sprites=['blue_tarp_guard','receipt_guard','wire_guard'];
    for(let i=0;i<count;i++)runtime.npcs.push(makeKingdomActor({id:'throne',guardName:'CURB HOLDOUT',guardSprite:sprites[i%3],zoneOnly:KINGDOM_EMPEROR.zoneOnly},posts[i],{id:'kingdom_guard_throne_'+state.day+'_'+i,name:'CURB HOLDOUT',sprite:sprites[i%3],hp:52,dmg:7,speed:1.25,archetype:i===2?'ranged':'charger',kingdomGuard:true,kingdomClan:'throne',transient:false}));
  }
  spawnDailyPretender();
}

export function spawnDailyPretender(){
  const k=state.kingdom;if(!k||k.stage!=='complete'||k.pretenderDefeatedDay===state.day||runtime.npcs.some(n=>n.kingdomPretender&&!n.dead))return null;
  const defs=KINGDOM_CLAN_LIST,index=state.day%defs.length,def=defs[index],at=def.boss;
  k.pretenderDay=state.day;
  const p=makeKingdomActor(def,at,{id:'curb_pretender_'+state.day,name:'CURB PRETENDER No. '+(k.pretendersDefeated+1),sprite:def.guardSprite,hp:100,dmg:9,speed:1.45,archetype:index===2?'ranged':index===1?'grabber':'charger',showHp:true,kingdomPretender:true,kingdomClan:def.id,transient:false});
  runtime.npcs.push(p);return p;
}

export function completeKingdomPretender(n){
  const k=ensureKingdomState();if(!n||!n.kingdomPretender||k.stage!=='complete'||k.pretenderDefeatedDay===state.day)return false;
  k.pretenderDefeatedDay=state.day;k.pretendersDefeated++;P.lifetime.pretendersDefeated=k.pretendersDefeated;P.cash+=10;P.cred+=2;
  toast('· PRETENDER DENIED ·\n+ $10 · + 2 cred\nfiling '+k.pretendersDefeated+' remains nonprecedential.',3400);feedPost('today\'s curb pretender withdrew in person.','@blocklog');saveGame();return true;
}

export function currentPrimaryObjective() {
  const flags=state.flags||{}, qs=state.quests||{};
  if(!flags.introDone){
    if(qs.intro_remember&&!qs.intro_remember.done){
      const pile=runtime.cashPiles.find(c=>c.intro&&!c.collected);
      const earned=(state.counters&&state.counters.introCashEarned)||0;
      return {kind:'intro',text:'find $10 on the block. $'+Math.min(10,earned)+'/10',x:pile?pile.x:1180,y:pile?pile.y:870};
    }
    if((qs.intro_tony&&!qs.intro_tony.done)||((P.rocks||0)+(P.soapRocks||0))<=0){
      return {kind:'intro',text:qs.intro_tony&&qs.intro_tony.done?'buy a rock from tony. talking did not count.':'bother the man at the corner.',x:1634,y:886};
    }
    return {kind:'intro',text:'take the rock back to the milk crate.',x:1064,y:882};
  }
  const officeObjective=currentOfficeObjective();
  if(activeOfficeContract()&&officeObjective)return officeObjective;
  const kingdomObjective=currentKingdomObjective();
  if(kingdomObjective)return kingdomObjective;
  if(officeObjective)return officeObjective;
  const stop=currentBlockRouteStop();
  if(stop){
    const r=state.blockRoute;
    return {kind:'route',text:'route '+r.serial+' · '+(r.cursor+1)+'/3 · '+stop.task,x:stop.x,y:stop.y};
  }
  for(const [id,q] of Object.entries(qs)){
    if(q.done||q.available===false||q.intro)continue;
    if(id==='pigeon_crown'&&state.crownPickup&&!state.crownPickup.collected){
      return {kind:'quest',text:q.flav,x:state.crownPickup.x,y:state.crownPickup.y};
    }
    const target=QUEST_TARGETS[id]; if(target)return {kind:'quest',...target};
  }
  return {kind:'idle',text:'walk until the neighborhood assigns something.',x:P.x+P.w/2,y:P.y+P.h/2};
}

export function objectiveDirection(dx,dy){
  if(Math.abs(dx)<24&&Math.abs(dy)<24)return 'HERE';
  const a=Math.atan2(dy,dx),oct=Math.round(a/(Math.PI/4));
  return ['→','↘','↓','↙','←','↖','↑','↗','→'][(oct+8)%8];
}

export function resolveActionHint(){
  if(document.hidden||state.mode!=='playing'||P.stunT>0||state.bossActive||state.brutusOlderActive)return '';
  const pcx=P.x+P.w/2,pcy=P.y+P.h/2;
  {const d=OFFICE_DOOR,dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);if(dx*dx+dy*dy<44*44)return officeOwned()?'open the office':'test the office key';}
  for(const kind of ['scrap','mom']){
    if(!hideoutOwned(kind))continue;const d=HIDEOUT_DOORS[kind],dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);
    if(dx*dx+dy*dy<40*40)return kind==='mom'?"open mom's door":'open the shed';
  }
  {const d=OLD_SCHOOL_DOOR,dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);if(dx*dx+dy*dy<44*44)return 'test the old school chain';}
  for(const d of KINGDOM_DOORS){const dx=pcx-(d.x+d.w/2),dy=pcy-(d.y+d.h/2);if(dx*dx+dy*dy<44*44)return 'read the court door';}
  const kingdomHint=resolveKingdomActionHint();if(kingdomHint)return kingdomHint;
  const office=state.office;
  if(office&&office.claimJob&&(office.claimJob.stage==='survey'||office.claimJob.stage==='install')){
    const def=CLAIM_SITE_BY_ID[office.claimJob.id],p=office.claimJob.stage==='survey'?def.survey:def.sign,dx=pcx-p.x,dy=pcy-p.y;
    if(dx*dx+dy*dy<58*58)return office.claimJob.stage==='survey'?'survey the district':'install the claim sign';
  }
  if(office&&office.workJob&&office.workJob.stage==='inspect'){
    const p=CLAIM_SITE_BY_ID[office.workJob.id].sign,dx=pcx-p.x,dy=pcy-p.y;if(dx*dx+dy*dy<58*58)return 'inspect the claim sign';
  }
  const routeStop=currentBlockRouteStop();
  if(routeStop&&!activeOfficeContract()){const dx=pcx-routeStop.x,dy=pcy-routeStop.y;if(dx*dx+dy*dy<58*58)return 'stamp the clipboard';}
  let best=null,bestD=60*60;
  for(const n of runtime.npcs){if(n.dead||!n.interact)continue;const dx=pcx-(n.x+n.w/2),dy=pcy-(n.y+n.h/2),d=dx*dx+dy*dy;if(d<bestD){bestD=d;best=n;}}
  if(best)return 'bother '+String(best.name||'somebody').toLowerCase();
  const heistB=BUILDINGS.find(b=>b.locked);
  if(heistB&&pcx>heistB.x-20&&pcx<heistB.x+heistB.w+20&&pcy>heistB.y-20&&pcy<heistB.y+heistB.h+20)return 'test the abandoned boards';
  for(const p of PROPS){if(p.type!=='park_bench')continue;const dx=pcx-(p.x+p.w/2),dy=pcy-(p.y+p.h/2);if(dx*dx+dy*dy<50*50)return state.sittingOnBench?'stand up':'sit on the bench';}
  for(const ip of interactiveProps){if(ip.type!=='trashcan')continue;const dx=pcx-ip.x,dy=pcy-ip.y;if(dx*dx+dy*dy<50*50)return 'kick the can';}
  const phone=PROPS.find(p=>p.type==='pay_phone');
  if(phone&&state.phonePropRingT>0){const dx=pcx-phone.x,dy=pcy-phone.y;if(dx*dx+dy*dy<38*38)return 'answer the public phone';}
  const cart=PROPS.find(p=>p.type==='cart');
  if(cart){if(P.cartMounted&&cart.mounted==='me')return 'abandon the cart';const dx=pcx-cart.x,dy=pcy-cart.y;if(dx*dx+dy*dy<36*36)return 'get in the cart';}
  for(const p of PROPS){if(p.type!=='dumpster')continue;const dx=pcx-(p.x+p.w/2),dy=pcy-(p.y+p.h/2);if(dx*dx+dy*dy<44*44)return p.looted?'look in the empty dumpster':'get in the dumpster';}
  if(inZone(pcx,pcy,'block')){
    if(state.flags&&!state.flags.introDone&&((P.rocks||0)+(P.soapRocks||0))<=0)return '';
    return 'use the milk crate';
  }
  if(inZone(pcx,pcy,'market'))return 'work the marketplace';
  return '';
}

export function updateGuidance(dt){
  state.guidanceT=(state.guidanceT||0)+dt;if(state.guidanceT<120)return;state.guidanceT=0;
  state.primaryObjective=currentPrimaryObjective();
  const o=state.primaryObjective,dx=o.x-(P.x+P.w/2),dy=o.y-(P.y+P.h/2),dist=Math.hypot(dx,dy);
  const el=document.getElementById('objective');
  if(el){el.innerHTML='<b>BAD IDEA</b> · '+o.text+' · '+(dist<28?'HERE':Math.max(1,Math.ceil(dist/10))+' paces '+objectiveDirection(dx,dy));el.classList.toggle('show',state.mode==='playing');}
  const hint=resolveActionHint(),hintEl=document.getElementById('actionHint');
  if(hintEl){const key=state.touchMode?'B':'E';hintEl.innerHTML='<b>'+key+'</b> · '+hint;hintEl.classList.toggle('show',state.mode==='playing'&&!!hint);}
}

export function hideGuidance(){
  const objective=document.getElementById('objective'),hint=document.getElementById('actionHint');
  if(objective)objective.classList.remove('show');
  if(hint)hint.classList.remove('show');
}

export function init_campaigns() {
  // ---------- v18 â€” THE OFFICE + BLOCK AUTHORITY ----------
  OFFICE_DOOR = { x:4908, y:3204, w:24, h:32 };
  OFFICE_UPGRADE_DEFS = [
    { id:'cot',         name:'cot',         cash:30, copper:0, desc:'rest. sleep. wake up in the same room.' },
    { id:'locker',      name:'locker',      cash:45, copper:1, desc:'the shared chest, now with a chain.' },
    { id:'desk',        name:'desk',        cash:60, copper:2, desc:'select and file district claims.' },
    { id:'generator',   name:'generator',   cash:75, copper:2, desc:'light the door. improve office rest.' },
    { id:'radio',       name:'radio',       cash:90, copper:2, desc:'receive bounded work orders.' },
    { id:'route_board', name:'route board', cash:65, copper:1, desc:'replace one unpaid route per day.' },
  ];
  OFFICE_UPGRADE_IDS = new Set(OFFICE_UPGRADE_DEFS.map(x=>x.id));
  
  // Survey and sign anchors are authored away from solids and named NPCs. The claim never
  // owns a person; it owns one damaged sign and a line in a desk ledger.
  CLAIM_SITES = [
    { id:'canal', name:'THE DRAINAGE CANAL', faction:'neutral', survey:{x:5420,y:2070,task:'read the water gauge while the water is absent.',stamp:'gauge says nine.\nwater says nothing.'}, sign:{x:4380,y:2110,task:'install the WATER PENDING sign.',stamp:'the sign leans east.\nthe canal is entered as pending.'} },
    { id:'alley', name:'BACK ALLEY', faction:'street', survey:{x:620,y:1300,task:'measure the alley entrance using your arms.',stamp:'two arms wide.\narm standard not attached.'}, sign:{x:620,y:1640,task:'install the RESIDENT OFFICE sign.',stamp:'the wall accepts one nail.\nthe second nail is theoretical.'} },
    { id:'projects', name:'THE PROJECTS', faction:'street', survey:{x:300,y:1810,task:'record building a as two buildings.',stamp:'one building. letter a.\ntwo entered.'}, sign:{x:130,y:1810,task:'install the BUILDING LETTER sign.',stamp:'the sign says building c.\nthere is no building c.'} },
    { id:'skidrow', name:'SKID ROW', faction:'street', survey:{x:3330,y:2180,task:'count the east curb without entering traffic.',stamp:'one curb.\ntwo opinions.'}, sign:{x:2500,y:1560,task:'install the NO VACANCY sign.',stamp:'no vacancy.\nseveral vacancies object.'} },
    { id:'scrap', name:'SCRAP YARD', faction:'scrap', survey:{x:360,y:420,task:'inventory the gate as two gates.',stamp:'one gate.\ntwo entered.'}, sign:{x:590,y:420,task:'install the METAL OFFICE sign.',stamp:'the sign is mostly rust.\nyuri calls that pure.'} },
    { id:'underpass', name:'HIGHWAY UNDERPASS', faction:'scrap', survey:{x:1070,y:430,task:'count the bridge supports from below.',stamp:'four supports.\none bridge. no receipt.'}, sign:{x:1360,y:250,task:'install the CEILING DEPARTMENT sign.',stamp:'the sign points up.\nthe highway continues ignoring it.'} },
    { id:'oldschool', name:'OLD SCHOOL', faction:'scrap', survey:{x:3460,y:860,task:'inspect the court line for education.',stamp:'chalk. chain.\nno curriculum.'}, sign:{x:4100,y:860,task:'install the ALUMNI OFFICE sign.',stamp:'the school did not attend.\nthe form says present.'} },
    { id:'warehouse_row', name:'WAREHOUSE ROW', faction:'scrap', survey:{x:4930,y:850,task:'compare the manifest to both warehouses.',stamp:'unit 14. returns.\nneither is unit 14.'}, sign:{x:5450,y:850,task:'install the RECEIVING sign.',stamp:'receiving refuses delivery.\nsign delivered.'} },
    { id:'market', name:'MARKETPLACE', faction:'spiritual', survey:{x:740,y:1600,task:'locate the checkout line after checkout.',stamp:'the line moved around you.\nyou were not in it.'}, sign:{x:1390,y:1600,task:'install the CUSTOMER SERVICE sign.',stamp:'no customer requested service.\nservice documented.'} },
    { id:'park', name:'THE PARK', faction:'spiritual', survey:{x:2450,y:1360,task:'ask the dry bench if it is public.',stamp:'the bench remains silent.\npublic entered as yes.'}, sign:{x:2980,y:1360,task:'install the RECREATION OFFICE sign.',stamp:'two pigeons witnessed.\nneither signed.'} },
    { id:'trainyard', name:'TRAIN YARD', faction:'spiritual', survey:{x:1320,y:3200,task:'verify the last rail also goes nowhere.',stamp:'rail continues west.\ntrain continues not arriving.'}, sign:{x:300,y:3200,task:'install the ARRIVALS OFFICE sign.',stamp:'arrivals: zero.\noffice: open.'} },
  ];
  CLAIM_SITE_BY_ID = Object.create(null);
  for(const c of CLAIM_SITES)CLAIM_SITE_BY_ID[c.id]=c;
  CLAIM_STAGES = new Set(['survey','file','install']);
  WORK_STAGES = new Set(['inspect','file']);
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  // ---------- v19 — CURB WAR / ONE CRACKLORD ----------
  // Rival courts are a separate absurd succession system. They never mutate faction reputation,
  // v18 district claims, prices, allegiance, or product supply.
  KINGDOM_STAGES = new Set([
    'locked','summons','tarp_marks','tarp_boss','cart_marks','cart_boss',
    'wire_marks','wire_boss','anoint','emperor_gate','emperor_boss','complete',
  ]);
  KINGDOM_DEFEAT_IDS = ['darryl_under_blue','general_receipt','bishop_wire','curb_emperor'];
  KINGDOM_STAGE_RANK = {
    locked:0,summons:1,tarp_marks:2,tarp_boss:3,cart_marks:4,cart_boss:5,
    wire_marks:6,wire_boss:7,anoint:8,emperor_gate:9,emperor_boss:10,complete:11,
  };
  KINGDOM_DOORS = [
    {id:'blue',x:6818,y:464,w:24,h:32,line:'blue court is in recess. the recess has no end time.'},
    {id:'cart',x:8108,y:1744,w:24,h:32,line:'the keep accepts returns through a different keep.'},
    {id:'wire',x:6818,y:3064,w:24,h:32,line:'choir office hours are b flat to b flat.'},
    {id:'throne',x:8038,y:4484,w:24,h:32,line:'the throne office is closed for succession.'},
  ];
  KINGDOM_CLANS = {
    blue_tarp:{
      id:'blue_tarp',zoneId:'blue_tarp_court',name:'BLUE TARP COURT',seal:'BLUE WEATHER',
      marksStage:'tarp_marks',bossStage:'tarp_boss',nextStage:'cart_marks',clearFlag:'blueTarpCleared',
      guardSprite:'blue_tarp_guard',guardName:'TARP KNIGHT',bossId:'darryl_under_blue',bossName:'DARRYL UNDER BLUE',bossSprite:'darryl_under_blue',
      bossHp:180,bossDmg:10,bossSpeed:1.55,archetype:'charger',rewardCash:24,rewardCred:18,
      banner:{x:6500,y:900},boss:{x:6500,y:760},adds:[{x:6200,y:720},{x:6800,y:720}],
      zoneOnly:{x:5920,y:260,w:1160,h:1060},
      marks:[
        {x:6020,y:1180,task:'enter the bucket as a weather station.',stamp:'bucket: one. weather: inside.\nstation entered as permanent.'},
        {x:6200,y:760,task:'serve a roof notice on the rope.',stamp:'rope received notice.\nroof refused signature.'},
        {x:6940,y:1040,task:'ask the plastic chair to witness the court.',stamp:'chair witnessed.\nchair requested mileage.'},
      ],
    },
    cart_cavalry:{
      id:'cart_cavalry',zoneId:'cart_cavalry_keep',name:'CART CAVALRY KEEP',seal:'CART APPEAL',
      marksStage:'cart_marks',bossStage:'cart_boss',nextStage:'wire_marks',clearFlag:'cartKeepCleared',
      guardSprite:'receipt_guard',guardName:'CART LANCER',bossId:'general_receipt',bossName:'GENERAL RECEIPT',bossSprite:'general_receipt',
      bossHp:200,bossDmg:9,bossSpeed:1.25,archetype:'grabber',rewardCash:30,rewardCred:22,
      banner:{x:7860,y:2320},boss:{x:7860,y:2050},adds:[{x:7500,y:1980},{x:8220,y:1980}],
      zoneOnly:{x:7340,y:1460,w:1040,h:980},
      marks:[
        {x:7440,y:2380,task:'cite the cavalry parking brake.',stamp:'six carts. one brick.\nbrake status: brick.'},
        {x:7580,y:1900,task:'stamp the axle where a horse would go.',stamp:'horse absent. axle present.\ncavalry entered as rolling.'},
        {x:8240,y:2200,task:'return the return policy to itself.',stamp:'return denied.\npolicy returned anyway.'},
      ],
    },
    copper_choir:{
      id:'copper_choir',zoneId:'copper_choir_yard',name:'COPPER CHOIR YARD',seal:'COPPER MASS',
      marksStage:'wire_marks',bossStage:'wire_boss',nextStage:'anoint',clearFlag:'copperChoirCleared',
      guardSprite:'wire_guard',guardName:'WIRE DEACON',bossId:'bishop_wire',bossName:'BISHOP WIRE',bossSprite:'bishop_wire',
      bossHp:210,bossDmg:8,bossSpeed:1.2,archetype:'ranged',rewardCash:36,rewardCred:26,
      banner:{x:6510,y:3700},boss:{x:6510,y:3480},adds:[{x:6140,y:3460},{x:6880,y:3460}],
      zoneOnly:{x:5920,y:2760,w:1220,h:1120},
      marks:[
        {x:7000,y:3760,task:'file the note held by the copper rack.',stamp:'b flat. again.\nnoise entered as inventory.'},
        {x:6100,y:3500,task:'count the wire loops without touching math.',stamp:'three loops. one loose end.\nmath not retained.'},
        {x:6900,y:3260,task:'serve the hubcap with a choir summons.',stamp:'hubcap rang once.\nattendance entered as yes.'},
      ],
    },
  };
  KINGDOM_CLAN_LIST = Object.values(KINGDOM_CLANS);
  KINGDOM_EMPEROR = {
    zoneId:'throne_ditch',bossId:'curb_emperor',bossName:'THE CURB EMPEROR',bossSprite:'curb_emperor',
    bossHp:280,bossDmg:12,bossSpeed:1.45,archetype:'charger_older',rewardCash:60,rewardCred:40,
    banner:{x:7680,y:5200},boss:{x:7680,y:4880},adds:[{x:7240,y:4800},{x:8120,y:4800}],
    zoneOnly:{x:7020,y:4200,w:1320,h:1120},
  };
  KINGDOM_GUARD_POSTS = {
    blue_tarp:[{x:6060,y:660},{x:6140,y:1120},{x:6800,y:700},{x:6500,y:1180}],
    cart_cavalry:[{x:7440,y:1840},{x:7540,y:2240},{x:8240,y:1840},{x:7800,y:1800}],
    copper_choir:[{x:6040,y:3200},{x:6500,y:3200},{x:6940,y:3220},{x:7040,y:3700}],
    throne:[{x:7140,y:4680},{x:7500,y:4700},{x:7800,y:5000}],
  };
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  QUEST_TARGETS = {
    first_rock:    {x:1634,y:886,text:'buy a rock from tre bag tony.'},
    copper_sings:  {x:1740,y:430,text:'test the boards on the abandoned building.'},
    finisher:      {x:1064,y:882,text:'cook something at the milk crate.'},
    conductor:     {x:820,y:2940,text:'find the conductor in the train yard.'},
    priest_mercy:  {x:1800,y:1585,text:'find father o\'malley at the church.'},
    fallen_king:   {x:1634,y:886,text:'settle the corner with tre bag tony.'},
    stripe_package:{x:820,y:2940,text:'take stripe\'s package to the conductor.'},
    barb_crossword:{x:1200,y:1510,text:'find the missing saturday crossword.'},
    fallen_priest: {x:1800,y:1585,text:'go back to the church.'},
    scrap_dog:     {x:560,y:150,text:'check on the scrap yard dog.'},
  };
  
  
  
  
  
  
  
}
