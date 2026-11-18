import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {ROOT,loadSeededSource,ensureVmFlag,stableStringify,sourceFiles} from './export-3d-content.mjs';
const OUTPUT=path.join(ROOT,'game3d/tests/fixtures/campaign_reference.json');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const copy=value=>JSON.parse(JSON.stringify(value));
const QUESTS=['office_space','paper_empire','regional_office','all_business','hostile_correspondence','blue_weather','cart_appeal','copper_mass','royal_static','one_cracklord'];
const FLAGS=['blueTarpCleared','cartKeepCleared','copperChoirCleared','throneDitchCleared'];

export async function buildCampaignOracle(){
  const game=await loadSeededSource(),ui=game.module('src/core/runtime_ui.js'),start=game.module('src/core/start.js');
  const campaign=game.module('src/systems/campaigns.js'),audio=game.module('src/core/audio_save.js');
  let saved=null,writes=0,randoms=0;
  game.context.storage={async set(_key,value){saved=copy(value);writes++;},async get(){return {value:saved};}};
  const reset=()=>{ui.init_runtime_ui();start.startGame(false);game.context.__qa.timers.length=0;writes=0;randoms=0;game.context.Math.random=()=>{randoms++;return .4;};};
  const snapshot=()=>({office:copy(ui.state.office),claims:copy(ui.state.districtClaims),kingdom:copy(ui.state.kingdom),
    lifetime:Object.fromEntries(['officeJobs','territoriesClaimed','pretendersDefeated','routesCompleted'].map(k=>[k,ui.P.lifetime[k]||0])),
    quests:Object.fromEntries(QUESTS.map(id=>[id,{done:!!ui.state.quests[id].done,available:ui.state.quests[id].available??null}])),
    flags:Object.fromEntries(FLAGS.map(k=>[k,!!ui.state.flags[k]])),achievements:[...ui.state.achievements].sort(),
    cash:ui.P.cash,copper:ui.P.copper,cred:ui.P.cred,day:ui.state.day,bossActive:ui.state.bossActive,bossKind:ui.state.bossKind,
    actors:ui.runtime.npcs.filter(n=>n.kingdomGuard||n.kingdomPretender).map(copy)});
  const nat=[];
  for(const value of [null,false,true,-1,0,1.9,1e12,'5.8','  ','0x10','0b11','0o10','junk',[],[4],[true],{},[1,2]]) nat.push({value,expected:campaign.officeNat(value),bounded:campaign.officeNat(value,7)});
  const offices=[];
  const claimsVariants=[{}, {canal:true},{alley:true,park:true},{canal:1,invented:true,park:false}];
  const rawOffices=[null,{},false,{owned:true},{owned:'yes',upgrades:{cot:true,generator:1,unknown:true}},
    {owned:[],workDay:12,workToday:9},{upgrades:{locker:true}},
    {claimJob:{id:'canal',stage:'survey'},workJob:{id:'park',stage:'file',serial:0}},
    {claimJob:{id:'invented',stage:'install'},workJob:{id:'canal',stage:'inspect',serial:'8.9'},orderSerial:2,lastWorkId:'canal'},
    {owned:false,jobsCompleted:4,orderSerial:2,workToday:99,workDay:'12.9',rerollDay:-1},
    {owned:false,workToday:2,workDay:9,rerollDay:9,orderSerial:100,lastWorkId:'park'},
    {owned:true,claimJob:{id:'canal',stage:'file'},workJob:{id:'park',stage:'inspect',serial:99},jobsCompleted:2},
  ];
  for(const raw of rawOffices)for(const claims of claimsVariants){const normalized=campaign.normalizeDistrictClaims(claims);offices.push({raw,claims,normalizedClaims:copy(normalized),expected:copy(campaign.normalizeOfficeState(raw,normalized))});}
  const kingdoms=[];
  for(const stage of [...campaign.KINGDOM_STAGES,'invented'])for(const demote of [false,true])for(const marks of [0,7,99]){
    const boss={tarp_boss:'darryl_under_blue',cart_boss:'general_receipt',wire_boss:'bishop_wire',emperor_boss:'curb_emperor'}[stage]||'invented';
    const raw={stage,marks,bossId:boss,pretendersDefeated:3,pretenderDay:2,pretenderDefeatedDay:1};
    kingdoms.push({raw,demote,expected:copy(campaign.normalizeKingdomState(raw,demote))});
  }
  for(const defeats of [[],['darryl_under_blue'],['bishop_wire'],['curb_emperor'],['general_receipt','darryl_under_blue','general_receipt','unknown']]){
    const raw={stage:'locked',marks:'4.7',defeats,pretendersDefeated:'12.9'};
    kingdoms.push({raw,demote:true,expected:copy(campaign.normalizeKingdomState(raw,true))});
  }
  const forces=[];
  for(const stage of campaign.KINGDOM_STAGES)for(const day of [7,8,9]){
    reset();ui.state.day=day;ui.state.kingdom={...campaign.freshKingdomState(),stage,marks:7,pretendersDefeated:2};ui.P.lifetime.pretendersDefeated=4;
    const before={day,kingdom:copy(ui.state.kingdom),pretenders:ui.P.lifetime.pretendersDefeated};
    randoms=0;campaign.syncKingdomForces();
    forces.push({before,kingdom:copy(ui.state.kingdom),pretenders:ui.P.lifetime.pretendersDefeated,actors:snapshot().actors,randomCalls:randoms});
  }
  for(const defeatedToday of [false,true])for(const lifetime of [0,8]){
    reset();ui.state.day=12;ui.state.kingdom={...campaign.freshKingdomState(),stage:'complete',pretenderDefeatedDay:defeatedToday?12:11,pretendersDefeated:5};ui.P.lifetime.pretendersDefeated=lifetime;
    const before={day:12,kingdom:copy(ui.state.kingdom),pretenders:lifetime};randoms=0;campaign.syncKingdomForces();
    forces.push({before,kingdom:copy(ui.state.kingdom),pretenders:ui.P.lifetime.pretendersDefeated,actors:snapshot().actors,randomCalls:randoms});
  }
  const milestones=[];
  for(const count of [0,1,3,4,7,8,10,11]){
    reset();for(const def of campaign.CLAIM_SITES.slice(0,count))ui.state.districtClaims[def.id]=true;
    const before=snapshot();writes=0;const changed=campaign.updateOfficeMilestones();const after=snapshot();
    const firstWrites=writes;const repeated=campaign.updateOfficeMilestones();
    milestones.push({count,before,after,changed,repeated,firstWrites,totalWrites:writes});
  }
  const restores=[];
  const repairs=[
    {id:'empty'},
    {id:'partial_upgrades',office:{upgrades:{cot:true}}},
    {id:'lifetime_office_jobs',office:{owned:false,orderSerial:2},lifetime:{officeJobs:5}},
    {id:'paper_witness_no_claim_recreation',lifetime:{territoriesClaimed:8}},
    {id:'squatters_witness',achievements:['squatters_rights']},
    {id:'paper_quest_witness',quests:{paper_empire:{done:true}}},
    {id:'clan_flag_witness',flags:{copperChoirCleared:true}},
    {id:'clan_quest_witness',quests:{cart_appeal:{done:true}}},
    {id:'summons_quest_witness',quests:{hostile_correspondence:{done:true}}},
    {id:'royal_quest_witness',quests:{royal_static:{done:true}}},
    {id:'emperor_achievement_witness',achievements:['one_cracklord']},
    {id:'boss_retry',kingdom:{stage:'cart_boss',marks:0,bossId:'general_receipt'}},
    {id:'boss_retry_later_defeat',kingdom:{stage:'tarp_boss',marks:0,defeats:['general_receipt']}},
    {id:'boss_retry_later_flag',kingdom:{stage:'tarp_boss',marks:0},flags:{cartKeepCleared:true}},
    {id:'boss_retry_royal_witness',kingdom:{stage:'tarp_boss',marks:0},quests:{royal_static:{done:true}}},
    {id:'emperor_retry',kingdom:{stage:'emperor_boss',bossId:'curb_emperor'}},
    {id:'pretender_max',kingdom:{pretendersDefeated:8},lifetime:{pretendersDefeated:2}},
    {id:'eligible_summons',office:{owned:true},claims:Object.fromEntries(campaign.CLAIM_SITES.slice(0,4).map(d=>[d.id,true])),quests:{fallen_king:{done:true}}},
  ];
  for(const spec of repairs){
    reset();await audio.saveGame();const data=copy(saved);
    if(spec.office)data.office=copy(spec.office);
    if(spec.kingdom)data.kingdom=copy(spec.kingdom);
    if(spec.claims)data.districtClaims=copy(spec.claims);
    Object.assign(data.player.lifetime,spec.lifetime||{});Object.assign(data.flags,spec.flags||{});
    if(spec.achievements)data.achievements=spec.achievements.slice();
    for(const [id,fields]of Object.entries(spec.quests||{}))Object.assign(data.quests[id],fields);
    saved=copy(data);writes=0;assert.equal(await audio.loadGame(),true);start.startGame(true);
    restores.push({spec,save:data,expected:snapshot()});
  }
  const hashes=Object.fromEntries([...sourceFiles(),path.join(ROOT,'VIBE.md')].map(file=>[path.relative(ROOT,file).replaceAll('\\','/'),hash(fs.readFileSync(file))]));
  return {schema:1,format:'rock-bottom-campaign-foundation-reference',source:{authority:'unchanged source normalizers, force refresh, milestone and async save/load/start functions',hashes,corpusSha256:hash(stableStringify(hashes)),generatorSha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),harnessSha256:hash(fs.readFileSync(path.join(ROOT,'tools/runtime-harness.mjs')))},counts:{nat:nat.length,offices:offices.length,kingdoms:kingdoms.length,forces:forces.length,milestones:milestones.length,restores:restores.length,upgrades:6,claims:11,stages:12,posts:15},nat,offices,kingdoms,forces,milestones,restores,scope:'P13a state/force foundation only; office transactions and Kingdom battle actions remain P13b/c.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  ensureVmFlag(fileURLToPath(import.meta.url));const output=stableStringify(await buildCampaignOracle());
  if(process.argv.includes('--check'))assert.equal(fs.readFileSync(OUTPUT,'utf8'),output,'Campaign oracle drift; regenerate deliberately.');
  else{fs.mkdirSync(path.dirname(OUTPUT),{recursive:true});fs.writeFileSync(OUTPUT,output);}
  const r=JSON.parse(output);console.log(`3D CAMPAIGN ORACLE: PASS (${['nat','offices','kingdoms','forces','milestones','restores'].reduce((sum,key)=>sum+r.counts[key],0)} P13a source cases; office actions/battles remain separate)`);
}
