import { saveGame } from '../core/audio_save.js';
import { P, state, toast } from '../core/runtime_ui.js';
import { ZONES } from '../data/world.js';
import { feedPost } from './communications.js';

export const REGULAR_ACTIONS = Object.freeze(['sit','bother','buy','sell','full_high']);
export const REGULAR_TIERS = Object.freeze(['stranger','counted','furniture','conceded']);
export const REGULAR_THRESHOLDS = Object.freeze({ counted:3, furniture:8, conceded:15 });
export const MAX_RECOGNITION_COUNT = 1000000;
export const REGULAR_VENUES = Object.freeze([
  Object.freeze({id:'park',label:'THE PARK',zoneId:'park',botherIds:Object.freeze(['philosopher','pigeon'])}),
  Object.freeze({id:'laundromat',label:'THE LAUNDROMAT',zoneId:'laundromat',botherIds:Object.freeze(['barb','laundromat_lady','karaoke'])}),
  Object.freeze({id:'underpass',label:'THE UNDERPASS',zoneId:'underpass',botherIds:Object.freeze(['math','biggu'])}),
  Object.freeze({id:'choir_office',label:'CHOIR OFFICE',zoneId:'copper_choir_yard',botherIds:Object.freeze([])}),
]);
export const REGULAR_VENUE_BY_ID = Object.freeze(Object.fromEntries(REGULAR_VENUES.map(venue=>[venue.id,venue])));

const reaction=(pattern,...lines)=>Object.freeze({pattern,lines:Object.freeze(lines)});
export const RECOGNITION_REACTIONS = Object.freeze({
  park:Object.freeze({
    counted:reaction('inverted_authority','the dry committee stops recounting when you pass.','one pigeon keeps the pencil.'),
    furniture:reaction('possum_pattern','the bench develops your dent.','a possum measures it once. the bench remains unchanged.'),
    conceded:reaction('cursed_aside','the philosopher pretends to be asleep.','he is not.'),
  }),
  laundromat:Object.freeze({
    counted:reaction('cursed_aside','the folding lady leaves one shirt unfolded.','the shirt is not yours.'),
    furniture:reaction('bad_trade','the change machine returns your usual quarter.','it is the same quarter.'),
    conceded:reaction('inverted_authority','a child\'s sock has taken the vent.','the dryer waits. the dryer knows.'),
  }),
  underpass:Object.freeze({
    counted:reaction('clerical','the mathematician enters you as present.','the second you remains absent.'),
    furniture:reaction('cursed_aside','the bridge keeps one footstep after you stop.','traffic covers it.'),
    conceded:reaction('bad_trade','the cardboard sign saves your place.','the place is wet.'),
  }),
  choir_office:Object.freeze({
    counted:reaction('clerical','the choir office adds you to attendance.','your name remains pending.'),
    furniture:reaction('clerical','a visitor badge waits at the door.','it expires in b flat.'),
    conceded:reaction('cursed_aside','the choir holds b flat when you arrive.','a loose vent is louder.'),
  }),
});

function naturalCounter(value) {
  return typeof value==='number'&&Number.isFinite(value)&&value>0
    ? Math.min(MAX_RECOGNITION_COUNT,Math.floor(value)) : 0;
}

export function freshRecognition() {
  const ledger=Object.create(null);
  for(const venue of REGULAR_VENUES){
    const counters=Object.create(null);
    for(const action of REGULAR_ACTIONS)counters[action]=0;
    ledger[venue.id]=counters;
  }
  return ledger;
}

export function normalizeRecognition(raw) {
  const ledger=freshRecognition();
  if(!raw||typeof raw!=='object')return ledger;
  for(const venue of REGULAR_VENUES){
    const source=Object.hasOwn(raw,venue.id)&&raw[venue.id]&&typeof raw[venue.id]==='object'?raw[venue.id]:null;
    if(!source)continue;
    for(const action of REGULAR_ACTIONS)if(Object.hasOwn(source,action))ledger[venue.id][action]=naturalCounter(source[action]);
  }
  return ledger;
}

export function recognitionTotal(counters) {
  if(!counters||typeof counters!=='object')return 0;
  return REGULAR_ACTIONS.reduce((total,action)=>total+naturalCounter(counters[action]),0);
}

export function recognitionTier(counters) {
  const total=typeof counters==='number'?naturalCounter(counters):recognitionTotal(counters);
  if(total>=REGULAR_THRESHOLDS.conceded)return 'conceded';
  if(total>=REGULAR_THRESHOLDS.furniture)return 'furniture';
  if(total>=REGULAR_THRESHOLDS.counted)return 'counted';
  return 'stranger';
}

export function recognitionVenueAt(x,y) {
  for(const venue of REGULAR_VENUES){
    const zone=ZONES.find(candidate=>candidate.id===venue.zoneId);
    if(zone&&x>=zone.x&&x<=zone.x+zone.w&&y>=zone.y&&y<=zone.y+zone.h)return venue.id;
  }
  return '';
}

export function freshRecognitionVisit() {
  return {venue:'',seen:Object.create(null)};
}

export function syncRecognitionVisit() {
  const venue=recognitionVenueAt(P.x+P.w/2,P.y+P.h/2);
  if(!state.recognitionVisit||state.recognitionVisit.venue!==venue)state.recognitionVisit={venue,seen:Object.create(null)};
  return venue;
}

function countedVenueCount(ledger) {
  return REGULAR_VENUES.filter(venue=>REGULAR_TIERS.indexOf(recognitionTier(ledger[venue.id]))>=1).length;
}

function acknowledgeTier(venueId,tier,deferMs=0) {
  const venue=REGULAR_VENUE_BY_ID[venueId],beat=RECOGNITION_REACTIONS[venueId]?.[tier];
  if(!venue||!beat)return;
  const receipt='· THE REGULAR ·\n'+venue.label+' · '+tier.toUpperCase()+'\n'+beat.lines.join('\n');
  const show=()=>toast(receipt,3600);
  if(deferMs>0)setTimeout(show,deferMs);else show();
  feedPost(beat.lines.join(' '),'@blocklog');
}

export function recordRecognition(venueId,actionId,sourceId='',options={}) {
  if(!Object.hasOwn(REGULAR_VENUE_BY_ID,venueId)||!REGULAR_ACTIONS.includes(actionId))return {credited:false,tier:'stranger'};
  if(!state.recognition||typeof state.recognition!=='object')state.recognition=freshRecognition();
  const currentVenue=syncRecognitionVisit();
  if(currentVenue!==venueId)return {credited:false,tier:recognitionTier(state.recognition[venueId])};
  if(actionId==='sit'||actionId==='bother'){
    const witness=actionId+':'+String(sourceId||actionId);
    if(state.recognitionVisit.seen[witness])return {credited:false,tier:recognitionTier(state.recognition[venueId])};
    state.recognitionVisit.seen[witness]=true;
  }
  const counters=state.recognition[venueId],beforeTier=recognitionTier(counters),beforeCounted=countedVenueCount(state.recognition);
  const before=counters[actionId];counters[actionId]=Math.min(MAX_RECOGNITION_COUNT,before+1);
  if(counters[actionId]===before)return {credited:false,tier:beforeTier};
  const tier=recognitionTier(counters);
  if(tier!==beforeTier){
    acknowledgeTier(venueId,tier,options.deferMs||0);
    if(beforeCounted===0&&countedVenueCount(state.recognition)>0)feedPost('he is still here. that is the whole post.','@blocklog');
  }
  saveGame();
  return {credited:true,tier,tierChanged:tier!==beforeTier,total:recognitionTotal(counters)};
}

export function recordNpcBother(npcId) {
  for(const venue of REGULAR_VENUES)if(venue.botherIds.includes(npcId))return recordRecognition(venue.id,'bother',npcId);
  return {credited:false,tier:'stranger'};
}

export function recordFullHighAtPlayer(options={}) {
  const venue=recognitionVenueAt(P.x+P.w/2,P.y+P.h/2);
  return venue?recordRecognition(venue,'full_high','high_boundary',options):{credited:false,tier:'stranger'};
}

export function init_recognition() {
  state.recognition=freshRecognition();
  state.recognitionVisit=freshRecognitionVisit();
}
