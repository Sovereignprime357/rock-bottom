const fs = require('fs');
const assert = require('assert');

const html = fs.readFileSync('rock_bottom_v19.html', 'utf8');
const scriptMatch = html.match(/<script>([\s\S]*)<\/script>/);
assert(scriptMatch, 'inline script exists');
new Function(scriptMatch[1]);

const start = scriptMatch[1].indexOf('// ---------- v19 — CURB WAR / ONE CRACKLORD ----------');
const end = scriptMatch[1].indexOf('const QUEST_TARGETS =', start);
assert(start >= 0 && end > start, 'campaign source segment exists');
const campaignSource = scriptMatch[1].slice(start, end);

const state = {
  mode: 'playing', day: 12, bossActive: false, bossKind: '', bossPhase: 0,
  bossNPC: null, kingdomBattle: null, brutusOlderActive: false,
  kingdom: null, achievements: new Set(), flags: {},
  office: {owned: true, upgrades: {radio: false}},
  districtClaims: {},
  quests: {
    fallen_king: {done: true, available: true},
    hostile_correspondence: {}, blue_weather: {}, cart_appeal: {},
    copper_mass: {}, royal_static: {}, one_cracklord: {},
  },
};
const P = {x: 0, y: 0, w: 24, h: 28, stunT: 0, cash: 0, cred: 0, lifetime: {pretendersDefeated: 0}};
let npcs = [];
let projectiles = [];
let saveCount = 0;
const notes = [];
const audio = new Proxy({}, {get: () => () => {}});
const document = {hidden: false};
const ZONES = [
  {id:'blue_tarp_court',x:5920,y:260,w:1160,h:1060},
  {id:'cart_cavalry_keep',x:7340,y:1460,w:1040,h:980},
  {id:'copper_choir_yard',x:5920,y:2760,w:1220,h:1120},
  {id:'throne_ditch',x:7020,y:4200,w:1320,h:1120},
];
const officeNat = (value, max=1000000000) => {
  const n=Number(value); return Number.isFinite(n)?Math.max(0,Math.min(max,Math.floor(n))):0;
};
const officeOwned = () => !!state.office.owned;
const claimedDistrictIds = () => Object.keys(state.districtClaims).filter(id => state.districtClaims[id] === true);
const ensureOfficeState = () => state.office;
const saveGame = () => { saveCount++; };
const toast = (...args) => notes.push(['toast', ...args]);
const feedPost = (...args) => notes.push(['feed', ...args]);
const broadcastNews = (...args) => notes.push(['news', ...args]);
const questToast = (...args) => notes.push(['quest', ...args]);
const unlockAchievement = id => state.achievements.add(id);

const buildCampaign = new Function(
  'state','P','npcs','projectiles','audio','document','ZONES','officeNat','officeOwned',
  'claimedDistrictIds','ensureOfficeState','saveGame','toast','feedPost','broadcastNews',
  'questToast','unlockAchievement','setTimeout',
  `${campaignSource}\nreturn {
    KINGDOM_CLANS,KINGDOM_CLAN_LIST,KINGDOM_EMPEROR,KINGDOM_GUARD_POSTS,
    freshKingdomState,normalizeKingdomState,ensureKingdomState,kingdomEligible,
    maybeUnlockKingdom,acceptKingdomSummons,tryUseKingdomTarget,startKingdomBoss,
    abortKingdomFight,completeKingdomBoss,syncKingdomForces,spawnDailyPretender,
    completeKingdomPretender,currentKingdomObjective,syncKingdomQuests,
    getNpcs:()=>npcs,getProjectiles:()=>projectiles
  };`
);
const api = buildCampaign(
  state,P,npcs,projectiles,audio,document,ZONES,officeNat,officeOwned,claimedDistrictIds,
  ensureOfficeState,saveGame,toast,feedPost,broadcastNews,questToast,unlockAchievement,
  fn => fn()
);

const malformed = api.normalizeKingdomState({
  stage:'tarp_marks', marks:99,
  defeats:['darryl_under_blue','darryl_under_blue','not_a_ruler'],
  pretenderDay:-4, pretendersDefeated:'6.9', bossId:'general_receipt',
});
assert.equal(malformed.stage, 'cart_marks');
assert.equal(malformed.marks, 0);
assert.deepEqual(malformed.defeats, ['darryl_under_blue']);
assert.equal(malformed.pretenderDay, 0);
assert.equal(malformed.pretendersDefeated, 6);
assert.equal(malformed.bossId, '');
assert.equal(api.normalizeKingdomState({stage:'emperor_boss',bossId:'curb_emperor'}, true).stage, 'emperor_gate');
assert.equal(api.normalizeKingdomState({stage:'tarp_boss',marks:7,bossId:'darryl_under_blue'}).bossId, 'darryl_under_blue');
assert.equal(api.normalizeKingdomState({stage:'locked',defeats:['curb_emperor']}).stage, 'complete');

state.kingdom = api.freshKingdomState();
state.districtClaims = {a:true,b:true,c:true};
assert.equal(api.maybeUnlockKingdom(false,false), false);
state.districtClaims.d = true;
assert.equal(api.maybeUnlockKingdom(false,false), true);
assert.equal(state.kingdom.stage, 'summons');
assert.equal(api.acceptKingdomSummons(), false);
state.office.upgrades.radio = true;
assert.equal(api.acceptKingdomSummons(), true);
assert.equal(state.kingdom.stage, 'tarp_marks');

const moveTo = p => { P.x=p.x-P.w/2; P.y=p.y-P.h/2; };
for (const mark of api.KINGDOM_CLANS.blue_tarp.marks) {
  moveTo(mark);
  assert.equal(api.tryUseKingdomTarget(), true);
}
assert.equal(state.kingdom.marks, 7);
moveTo(api.KINGDOM_CLANS.blue_tarp.banner);
assert.equal(api.tryUseKingdomTarget(), true);
assert.equal(state.kingdom.stage, 'tarp_boss');
assert.equal(api.getNpcs().filter(n => n.kingdomBoss).length, 1);
assert.equal(api.getNpcs().filter(n => n.kingdomAdd).length, 2);
assert.equal(api.abortKingdomFight(false), true);
assert.equal(state.kingdom.stage, 'tarp_marks');
assert.equal(state.kingdom.marks, 7);
assert.equal(state.bossActive, false);
assert.equal(api.getNpcs().filter(n => n.kingdomBoss || n.kingdomAdd).length, 0);

moveTo(api.KINGDOM_CLANS.blue_tarp.banner);
assert.equal(api.startKingdomBoss('blue_tarp'), true);
let boss = api.getNpcs().find(n => n.kingdomBoss);
const cashBeforeDarryl = P.cash;
assert.equal(api.completeKingdomBoss(boss), true);
assert.equal(state.kingdom.stage, 'cart_marks');
assert.equal(P.cash-cashBeforeDarryl, 24);
const cashAfterDarryl = P.cash;
assert.equal(api.completeKingdomBoss(boss), false);
assert.equal(P.cash, cashAfterDarryl);

for (const clanId of ['cart_cavalry','copper_choir']) {
  const clan = api.KINGDOM_CLANS[clanId];
  state.kingdom.stage = clan.marksStage;
  state.kingdom.marks = 7;
  moveTo(clan.banner);
  assert.equal(api.startKingdomBoss(clanId), true);
  boss = api.getNpcs().find(n => n.kingdomBoss);
  assert.equal(api.completeKingdomBoss(boss), true);
}
assert.equal(state.kingdom.stage, 'anoint');
assert(html.includes("P.rocks--; P.rockedT = 18000; P.crashT = 0"));
assert(html.includes("state.kingdom.stage='emperor_gate'"));
assert(html.includes('P.crashT = 8000'));
state.kingdom.stage = 'emperor_gate';
moveTo(api.KINGDOM_EMPEROR.banner);
assert.equal(api.startKingdomBoss('emperor'), true);
boss = api.getNpcs().find(n => n.kingdomBoss);
const finalCash = P.cash;
assert.equal(api.completeKingdomBoss(boss), true);
assert.equal(state.kingdom.stage, 'complete');
assert.equal(P.cash-finalCash, 60);
assert(state.achievements.has('one_cracklord'));
assert.equal(api.getNpcs().filter(n => n.kingdomPretender && !n.dead).length, 0);

state.day++;
api.syncKingdomForces();
let pretender = api.getNpcs().find(n => n.kingdomPretender && !n.dead);
assert(pretender);
const pretenderCash = P.cash;
assert.equal(api.completeKingdomPretender(pretender), true);
assert.equal(P.cash-pretenderCash, 10);
const paidCash = P.cash;
assert.equal(api.completeKingdomPretender(pretender), false);
assert.equal(P.cash, paidCash);
api.syncKingdomForces();
assert.equal(api.getNpcs().filter(n => n.kingdomPretender && !n.dead).length, 0);

state.kingdom.stage = 'locked';
state.quests.fallen_king.done = false;
state.quests.fallen_king.available = true;
const prerequisite = api.currentKingdomObjective();
assert(prerequisite && prerequisite.x === 1634 && prerequisite.y === 886);

assert(html.includes("state.loadedNpcDeaths = new Set"));
assert(html.includes("if(state.loadedNpcDeaths instanceof Set)"));
assert(html.includes("no payment authorized."));
assert(!html.includes("if(n.kingdomGuard){n.dead=true;audio.hurt();P.cred+=1"));

console.log(JSON.stringify({
  syntax:'ok', stateMachine:'ok', normalization:'ok', retry:'ok', rewards:'ok',
  pretender:'ok', tonyPrerequisite:'ok', highMs:18000, crashMs:8000,
  savesObserved:saveCount, notesObserved:notes.length
}, null, 2));
