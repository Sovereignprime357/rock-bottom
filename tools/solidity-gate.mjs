// THE HONEST MAP — v21 Wave 4.1 solidity + traversal gate.
//
// This gate holds the distinction the render layer used to omit:
// every structure declares `solid:true` or a registered `flat` reason. It also
// proves the declaration reaches behavior. Schema-only green is specifically
// insufficient: save restoration, player/projectile collision, actor detours,
// and real-path runway readings all exercise the one merged collision source.
//
// Traversal metric (OD-11): arbitrary-heading analog walk at the live base speed.
// That is a real supported input path and isolates collision detour. Literal
// eight-way WASD has an octile lower bound that already exceeds the runway on the
// two ceiling legs; those sensitivity readings are printed, never hidden.
// Exact objective anchors remain exact when standable. Only an impossible anchor
// is projected into its live action region, deterministically toward the opposite
// endpoint. Baseline and v21 use the same projected points; collision regression
// is AFTER minus BASELINE, never traversal minus an unreachable raw anchor.

import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT=path.resolve(import.meta.dirname,'..');
const FULL=process.argv.includes('--full');
const failures=[];
const fail=message=>failures.push(message);
const own=(value,key)=>Object.prototype.hasOwnProperty.call(value,key);
const near=(a,b,tolerance=1e-6)=>Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<=tolerance;
const px=value=>Number.isFinite(value)?`${value.toFixed(1)}px`:'unreachable';
const seconds=(value,speed)=>Number.isFinite(value)?`${(value/speed).toFixed(3)}s`:'unreachable';
const aabbOverlaps=(a,b)=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;

const EXPECTED_FACADE_IDS=[
  'checks','rooms_no','former_dentist','boxes','tire_2','car_wash','used_mattress','motel',
  'projects_a','self_storage','carpet','meat','loading','no_refunds','tax','unit_4',
  'cold_not','plastic_chair','water_dry','leasing_later','tarp_wholesale','family_court_2',
  'wheel_witness','coin_return','wire_less','b_flat_storage','chair_annex','ditch_clerk',
];
const EXPECTED_DOOR_GAP_IDS=[
  'rooms_no','boxes','tire_2','motel','projects_a','self_storage','carpet','meat','loading',
  'no_refunds','tax','unit_4','cold_not','plastic_chair','water_dry','tarp_wholesale',
  'family_court_2','wheel_witness','wire_less','b_flat_storage','chair_annex',
];
const EXPECTED_STOREFRONT_NO_GAP_IDS=[
  'checks','former_dentist','car_wash','used_mattress','leasing_later','coin_return','ditch_clerk',
];
const EXPECTED_LEGACY_ACTOR_STRUCTURES=Object.freeze({
  tony:1,pete:0,priest:3,barb:4,laundromat_lady:4,priests_son:3,karaoke:4,skid_sherri:13,
});
const FACADE_GEOMETRY_HASH='0a4c66978aa62d29a54390bab8486bdf8ba315c598ed41fcf4354bb0aa5652c5';

const {context,module}=await loadModularGame();
context.window._rb.startGame(false);

const runtimeUi=module('src/core/runtime_ui.js');
const campaigns=module('src/systems/campaigns.js');
const progression=module('src/systems/progression_routes.js');
const props=module('src/data/props.js');
const world=module('src/data/world.js');
const physicality=module('src/systems/physicality.js');
const npcAi=module('src/systems/npc_ai.js');
const audioSave=module('src/core/audio_save.js');

const {P,state,runtime}=runtimeUi;
const freshNpcCount=runtime.npcs.length;
const freshNpcs=[...runtime.npcs];
const freshPlayerCenter={x:P.x+P.w/2,y:P.y+P.h/2};
const {BUILDINGS,PROPS}=props;
const {LANDMARK_FACADES,ROAD_SEGMENTS,WORLD,ZONES}=world;
const {
  STRUCTURES,FLAT_STRUCTURE_REASONS,structureBlocksRect,firstBlockingStructure,
  structureDoorAccepts,resolveStructureMotion,ensureClearPlacement,commitActorStructureMotion,
}=physicality;
const {ROUTE_STOPS,routeLegBudgetPx}=progression;

// ---- 1. declarations: no default, no anonymous flat ------------------------
function declarationFailure(structure,label) {
  const hasSolid=own(structure,'solid'),hasFlat=own(structure,'flat');
  if(hasSolid===hasFlat)return `${label}: expected exactly one physicality declaration (solid:true OR flat:<registered reason>)`;
  if(hasSolid&&structure.solid!==true)return `${label}: solid must be the explicit literal true`;
  if(hasFlat){
    if(typeof structure.flat!=='string'||!structure.flat.trim())return `${label}: flat must name a registered reason`;
    if(!own(FLAT_STRUCTURE_REASONS,structure.flat))return `${label}: flat reason "${structure.flat}" is not registered`;
    const reason=FLAT_STRUCTURE_REASONS[structure.flat];
    if(typeof reason!=='string'||!reason.trim())return `${label}: registered flat reason "${structure.flat}" is empty`;
  }
  return '';
}

for(const [index,structure] of BUILDINGS.entries()){
  const problem=declarationFailure(structure,`BUILDINGS[${index}] ${structure.name||'(unnamed)'}`);if(problem)fail(problem);
}
for(const [index,structure] of LANDMARK_FACADES.entries()){
  const problem=declarationFailure(structure,`LANDMARK_FACADES[${index}] ${structure.id||'(missing id)'}`);if(problem)fail(problem);
}

// Counterexamples keep the validator honest even when the live corpus is 28/0.
if(!declarationFailure({},'synthetic undeclared'))fail('declaration validator accepted a structure nobody classified');
if(!declarationFailure({flat:'not_registered'},'synthetic bad flat'))fail('declaration validator accepted an unregistered flat reason');
if(declarationFailure({flat:'painted_surface'},'synthetic registered flat'))fail('declaration validator rejected a registered flat reason');

const actualIds=LANDMARK_FACADES.map(f=>f.id).sort();
const expectedIds=[...EXPECTED_FACADE_IDS].sort();
if(JSON.stringify(actualIds)!==JSON.stringify(expectedIds))fail(`facade identity set drifted: expected ${expectedIds.join(', ')}, got ${actualIds.join(', ')}`);
const doorGapIds=LANDMARK_FACADES.filter(f=>f.doorGap===true).map(f=>f.id).sort();
const storefrontNoGapIds=LANDMARK_FACADES.filter(f=>!own(f,'doorGap')).map(f=>f.id).sort();
if(JSON.stringify(doorGapIds)!==JSON.stringify([...EXPECTED_DOOR_GAP_IDS].sort()))fail(`door-gap facade set drifted: got ${doorGapIds.join(', ')||'none'}`);
if(JSON.stringify(storefrontNoGapIds)!==JSON.stringify([...EXPECTED_STOREFRONT_NO_GAP_IDS].sort()))fail(`storefront-no-gap facade set drifted: got ${storefrontNoGapIds.join(', ')||'none'}`);
for(const facade of LANDMARK_FACADES){
  if(facade.doorGap!==true&&own(facade,'doorGap'))fail(`${facade.id}: doorGap must be literal true or absent, never an implicit false convention`);
  for(const road of ROAD_SEGMENTS)if(aabbOverlaps(facade,road))fail(`${facade.id}: facade footprint overlaps road segment ${road.id}`);
}
const facadeGeometryHash=createHash('sha256').update(JSON.stringify(
  LANDMARK_FACADES.map(({id,x,y,w,h,kind,sign})=>[id,x,y,w,h,kind,sign])
)).digest('hex');
if(facadeGeometryHash!==FACADE_GEOMETRY_HASH)fail(`facade geometry/sign/kind corpus drifted: ${facadeGeometryHash}`);
const facadeSolid=LANDMARK_FACADES.filter(f=>f.solid===true).length;
const facadeFlat=LANDMARK_FACADES.filter(f=>own(f,'flat')).length;
if(LANDMARK_FACADES.length!==28||facadeSolid!==28||facadeFlat!==0){
  fail(`reachability decision drifted: expected 28 facades = 28 solid / 0 flat, got ${LANDMARK_FACADES.length} = ${facadeSolid} solid / ${facadeFlat} flat`);
}
if(BUILDINGS.length!==25)fail(`legacy building inventory drifted: expected 25, got ${BUILDINGS.length}`);
if(WORLD.w!==8600||WORLD.h!==5600)fail(`zero-content world bounds drifted: expected 8600x5600, got ${WORLD.w}x${WORLD.h}`);
if(ZONES.length!==23)fail(`zero-content zone inventory drifted: expected 23, got ${ZONES.length}`);
if(PROPS.length!==166)fail(`zero-content prop inventory drifted: expected 166, got ${PROPS.length}`);
if(freshNpcCount!==56)fail(`zero-content fresh NPC inventory drifted: expected 56, got ${freshNpcCount}`);
if(ROAD_SEGMENTS.length!==28)fail(`zero-content road inventory drifted: expected 28, got ${ROAD_SEGMENTS.length}`);
if(!Array.isArray(STRUCTURES))fail('STRUCTURES is not the initialized merged collision source');
else {
  if(STRUCTURES.length!==BUILDINGS.length+LANDMARK_FACADES.length)fail(`STRUCTURES has ${STRUCTURES.length} entries; expected ${BUILDINGS.length}+${LANDMARK_FACADES.length}`);
  const expectedRefs=[...BUILDINGS,...LANDMARK_FACADES];
  for(const structure of expectedRefs){
    const copies=STRUCTURES.filter(candidate=>candidate===structure).length;
    if(copies!==1)fail(`merged collision source contains ${copies} reference(s) to ${structure.id||structure.name||'(unnamed)'}, expected exactly one`);
  }
}
const declaredLegacyActors=freshNpcs.filter(actor=>own(actor,'legacyStructureIndex'));
if(declaredLegacyActors.length!==Object.keys(EXPECTED_LEGACY_ACTOR_STRUCTURES).length){
  fail(`legacy actor footprint declaration count drifted: expected 8, got ${declaredLegacyActors.length}`);
}
for(const actor of declaredLegacyActors){
  const expectedIndex=EXPECTED_LEGACY_ACTOR_STRUCTURES[actor.id];
  if(!Number.isInteger(expectedIndex))fail(`${actor.id}: unexpected legacyStructureIndex declaration`);
  else if(actor.legacyStructureIndex!==expectedIndex)fail(`${actor.id}: legacyStructureIndex ${actor.legacyStructureIndex}, expected ${expectedIndex}`);
  else if(firstBlockingStructure(actor)!==BUILDINGS[expectedIndex])fail(`${actor.id}: declared legacy footprint is not its actual blocking BUILDINGS entry ${expectedIndex}`);
}

// ---- 2. topology: one merged source, one iteration -------------------------
const sourceFiles={
  update:fs.readFileSync(path.join(ROOT,'src/core/update.js'),'utf8'),
  npc:fs.readFileSync(path.join(ROOT,'src/systems/npc_ai.js'),'utf8'),
  save:fs.readFileSync(path.join(ROOT,'src/core/audio_save.js'),'utf8'),
  physicality:fs.readFileSync(path.join(ROOT,'src/systems/physicality.js'),'utf8'),
  landmarks:fs.readFileSync(path.join(ROOT,'src/render/landmarks_a.js'),'utf8'),
};
const directLegacyLoop=/for\s*\([^)]*\bof\s+(?:BUILDINGS|LANDMARK_FACADES)\b[^)]*\)/g;
for(const [label,source] of [['update.js',sourceFiles.update],['npc_ai.js',sourceFiles.npc]]){
  const loops=source.match(directLegacyLoop)||[];
  if(loops.length)fail(`${label} retains ${loops.length} direct BUILDINGS/LANDMARK_FACADES collision loop(s); consumers must use the one merged source`);
}
const structureLoops=sourceFiles.physicality.match(/for\s*\([^)]*\bof\s+STRUCTURES\b[^)]*\)/g)||[];
if(structureLoops.length!==1)fail(`physicality.js has ${structureLoops.length} direct iterations over STRUCTURES; expected exactly one visitor loop`);
const mergedLiteral=(sourceFiles.physicality.match(/\.\.\.BUILDINGS\s*,\s*\.\.\.LANDMARK_FACADES/g)||[]).length;
if(mergedLiteral!==1)fail(`physicality.js constructs the BUILDINGS + LANDMARK_FACADES merge ${mergedLiteral} times; expected exactly once`);
if(!/moveBodyAgainstStructures\s*\(\s*P\s*,/.test(sourceFiles.update))fail('player movement does not call the shared structure motion seam');
if(!/firstBlockingStructure\s*\(\s*\{\s*x\s*:\s*pr\.x/.test(sourceFiles.update))fail('projectile update does not query the shared structure source');
if(!/commitActorStructureMotion\s*\(/.test(sourceFiles.npc))fail('generic NPC/cop update does not commit through shared structure motion');
if(!/ensureClearPlacement\s*\(\s*P\s*\)/.test(sourceFiles.save))fail('save load does not eject the player through ensureClearPlacement(P)');
const paintedDoorBranches=sourceFiles.landmarks.match(/if\s*\(\s*f\.doorGap\s*\)/g)||[];
if(paintedDoorBranches.length!==1)fail(`landmark renderer has ${paintedDoorBranches.length} if(f.doorGap) aperture branches, expected exactly one`);
if(!/const\s+doorW\s*=\s*60\b/.test(sourceFiles.landmarks))fail('landmark renderer doorway is not the canonical 60px aperture');
if(!/doorX\s*=\s*x\s*\+\s*\(\s*f\.w\s*-\s*doorW\s*\)\s*\/\s*2/.test(sourceFiles.landmarks))fail('landmark renderer doorway is not centered on the facade');

// ---- 3. ejection + production collision consumers -------------------------
const overlaps=(a,b)=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;
// Exact tangency is clear. Ignore sub-nanometre floating residue while still
// failing any real geometric penetration, independently of doorway exemptions.
const penetrates=(a,b,tolerance=1e-7)=>a.x<b.x+b.w-tolerance&&a.x+a.w>b.x+tolerance
  &&a.y<b.y+b.h-tolerance&&a.y+a.h>b.y+tolerance;
const overlapsAnySolid=body=>STRUCTURES.some(structure=>structure.solid===true&&penetrates(body,structure));
const embeddedPlayer=facade=>({x:facade.x+8,y:facade.y+8,w:P.w,h:P.h});
const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
function nearestCardinalEjection(facade,body){
  const maxX=WORLD.w-body.w,maxY=WORLD.h-body.h;
  const candidates=[
    {side:'north',x:body.x,y:facade.y-body.h},
    {side:'east',x:facade.x+facade.w,y:body.y},
    {side:'south',x:body.x,y:facade.y+facade.h},
    {side:'west',x:facade.x-body.w,y:body.y},
  ].map((candidate,order)=>{
    const x=clamp(candidate.x,0,maxX),y=clamp(candidate.y,0,maxY);
    return {...candidate,x,y,order,d2:(x-body.x)**2+(y-body.y)**2};
  }).filter(candidate=>!firstBlockingStructure({x:candidate.x,y:candidate.y,w:body.w,h:body.h}))
    .sort((a,b)=>a.d2-b.d2||a.order-b.order);
  return candidates[0]||null;
}
let directEjections=0,saveEjections=0,doorPreservations=0,playerBlocks=0,projectileBlocks=0;
let actorHelperTraversals=0,productionActorTraversals=0,facadeActorEjections=0,legacySpawnChecks=0;
let chargeWallStops=0,unregisteredLegacyActorEjections=0,misplacedLegacyActorEjections=0;

for(const facade of LANDMARK_FACADES){
  const a=embeddedPlayer(facade),b=embeddedPlayer(facade);
  const expected=nearestCardinalEjection(facade,a);
  if(!overlaps(a,facade)){fail(`${facade.id}: ejection fixture was not placed inside its footprint`);continue;}
  if(!expected){fail(`${facade.id}: no clear cardinal ejection candidate exists for the fixture`);continue;}
  const ra=ensureClearPlacement(a),rb=ensureClearPlacement(b);
  if(ra.failed||rb.failed||!ra.moved||!rb.moved)fail(`${facade.id}: deterministic ejection failed to move an embedded 24x28 player`);
  else if(!near(a.x,b.x)||!near(a.y,b.y))fail(`${facade.id}: identical embedded placements ejected to different coordinates (${a.x},${a.y}) vs (${b.x},${b.y})`);
  else if(!near(a.x,expected.x)||!near(a.y,expected.y))fail(`${facade.id}: ejection chose (${a.x},${a.y}), expected nearest cardinal ${expected.side} (${expected.x},${expected.y})`);
  else if(firstBlockingStructure(a)||firstBlockingStructure(b))fail(`${facade.id}: ejection returned another blocking overlap`);
  else if(a.x<0||a.y<0||a.x+a.w>WORLD.w||a.y+a.h>WORLD.h)fail(`${facade.id}: ejection left world bounds at (${a.x},${a.y})`);
  else directEjections++;
}

// A doorway is a legal shallow recess, not a trapped save. Placement and motion
// must agree on that fact before persistence is involved.
for(const facade of LANDMARK_FACADES.filter(candidate=>candidate.doorGap)){
  const body={x:facade.x+facade.w/2-P.w/2,y:facade.y+facade.h-15,w:P.w,h:P.h};
  const before={x:body.x,y:body.y};
  const offsetBody=offset=>({x:facade.x+facade.w/2+offset-P.w/2,y:facade.y+facade.h-15,w:P.w,h:P.h});
  const insideWest=offsetBody(-29),insideEast=offsetBody(29),outsideWest=offsetBody(-31),outsideEast=offsetBody(31);
  if(!overlaps(body,facade)||!structureDoorAccepts(body,facade))fail(`${facade.id}: doorway fixture is not a legal overlapping recess`);
  else if(!structureDoorAccepts(insideWest,facade)||!structureDoorAccepts(insideEast,facade)
    ||structureBlocksRect(insideWest,facade)||structureBlocksRect(insideEast,facade))fail(`${facade.id}: collision aperture does not admit the centered inner 58px`);
  else if(structureDoorAccepts(outsideWest,facade)||structureDoorAccepts(outsideEast,facade)
    ||!structureBlocksRect(outsideWest,facade)||!structureBlocksRect(outsideEast,facade))fail(`${facade.id}: collision aperture extends beyond the centered 60px`);
  else if(firstBlockingStructure(body))fail(`${facade.id}: shared blocker rejects its declared doorway recess`);
  else {
    const placement=ensureClearPlacement(body);
    const motion=resolveStructureMotion(body,before.x,before.y);
    if(placement.failed||placement.moved||!near(body.x,before.x)||!near(body.y,before.y))fail(`${facade.id}: ensureClearPlacement ejected a legal doorway placement`);
    else if(motion.failed||motion.blocked||!near(motion.x,before.x)||!near(motion.y,before.y))fail(`${facade.id}: motion resolver disagrees with legal doorway placement`);
    else doorPreservations++;
  }
}

await audioSave.saveGame();
const stored=await context.window.storage.get(audioSave.SAVE_KEY);
if(!stored?.value)fail('could not obtain a valid save fixture for load-time ejection');
else {
  const cleanSave=JSON.parse(JSON.stringify(stored.value));
  await context.window.storage.set(audioSave.SAVE_KEY,JSON.parse(JSON.stringify(cleanSave)));
  const cleanLoaded=await audioSave.loadGame();
  if(!cleanLoaded)fail('loadGame rejected the untouched clean save fixture');
  else if(P.x!==cleanSave.player.x||P.y!==cleanSave.player.y)fail(`untouched clean save moved from (${cleanSave.player.x},${cleanSave.player.y}) to (${P.x},${P.y})`);

  for(const facade of LANDMARK_FACADES.filter(candidate=>candidate.doorGap)){
    const fixture=JSON.parse(JSON.stringify(cleanSave));
    fixture.player.x=facade.x+facade.w/2-P.w/2;
    fixture.player.y=facade.y+facade.h-15;
    await context.window.storage.set(audioSave.SAVE_KEY,fixture);
    const loaded=await audioSave.loadGame();
    if(!loaded)fail(`${facade.id}: loadGame rejected the legal doorway save fixture`);
    else if(P.x!==fixture.player.x||P.y!==fixture.player.y)fail(`${facade.id}: legal doorway save moved from (${fixture.player.x},${fixture.player.y}) to (${P.x},${P.y})`);
  }

  for(const facade of LANDMARK_FACADES){
    const embedded=embeddedPlayer(facade),expected=nearestCardinalEjection(facade,embedded);
    const loadOnce=async()=>{
      const fixture=JSON.parse(JSON.stringify(cleanSave));
      fixture.player.x=embedded.x;fixture.player.y=embedded.y;
      await context.window.storage.set(audioSave.SAVE_KEY,fixture);
      const loaded=await audioSave.loadGame();
      return {loaded,x:P.x,y:P.y,clear:!firstBlockingStructure(P)};
    };
    const first=await loadOnce(),second=await loadOnce();
    if(!expected){fail(`${facade.id}: save fixture has no clear cardinal ejection candidate`);continue;}
    if(!first.loaded||!second.loaded)fail(`${facade.id}: loadGame rejected the embedded save fixture`);
    else if(!first.clear||!second.clear)fail(`${facade.id}: loadGame left the player inside a solid structure`);
    else if(!near(first.x,second.x)||!near(first.y,second.y))fail(`${facade.id}: save-load ejection was nondeterministic (${first.x},${first.y}) vs (${second.x},${second.y})`);
    else if(!near(first.x,expected.x)||!near(first.y,expected.y))fail(`${facade.id}: save-load ejection chose (${first.x},${first.y}), expected nearest cardinal ${expected.side} (${expected.x},${expected.y})`);
    else if(near(first.x,facade.x+8)&&near(first.y,facade.y+8))fail(`${facade.id}: loadGame returned the embedded coordinates unchanged`);
    else saveEjections++;
  }
}

// Restore a fresh runtime after the 56 load operations above.
context.window._rb.startGame(false);
state.mode='playing';
runtime.npcs.length=0;
runtime.projectiles.length=0;

function wallLane(facade,w,h,margin=12){
  const centerY=facade.y+Math.min(20,Math.max(8,facade.h/3));
  return {
    start:{x:facade.x-w/2-margin,y:centerY},
    target:{x:facade.x+facade.w+w/2+margin,y:centerY},
  };
}

// The actual player caller must reject a one-frame move into every facade.
for(const facade of LANDMARK_FACADES){
  const centerY=facade.y+Math.min(20,Math.max(8,facade.h/3));
  P.x=facade.x-P.w-.25;P.y=centerY-P.h/2;
  P.rockedT=0;P.crashT=0;P.slowT=0;P.stunT=0;P.hp=P.maxHp;P.shakes=20;
  state.keys.clear();state.stickX=1;state.stickY=0;state.stickMag=1;
  const before=P.x;
  context.window._rb.updateWorld(16);
  state.stickMag=0;
  if(!near(P.x,before,1e-7))fail(`${facade.id}: production player movement entered the west wall (${before} -> ${P.x})`);
  else if(firstBlockingStructure(P))fail(`${facade.id}: production player wall probe ended embedded`);
  else playerBlocks++;
}

// The actual projectile caller must query the same source. Start immediately
// west of each facade so no unrelated structure can claim the collision first.
P.x=1064-P.w/2;P.y=882-P.h/2;ensureClearPlacement(P);
for(const facade of LANDMARK_FACADES){
  runtime.projectiles.length=0;
  runtime.projectiles.push({
    x:facade.x-1,y:facade.y+Math.min(20,Math.max(8,facade.h/3)),
    vx:320,vy:0,life:5000,rot:0,rotVel:0,dmg:1,kind:'bottle',from:null,
  });
  context.window._rb.updateWorld(16);
  if(runtime.projectiles.length!==0)fail(`${facade.id}: production projectile crossed into a declared solid`);
  else projectileBlocks++;
}

function traverseActorAcross(facade,cop){
  const body={
    id:`qa_${cop?'cop':'npc'}_${facade.id}`,cop,w:28,h:32,speed:3,
    x:0,y:0,structureCollisionReady:true,structurePath:null,structurePathTarget:null,
  };
  const lane=wallLane(facade,body.w,body.h,18);
  body.x=lane.start.x-body.w/2;body.y=lane.start.y-body.h/2;
  if(firstBlockingStructure(body))return {ok:false,error:'start is blocked'};
  const targetRect={x:lane.target.x-body.w/2,y:lane.target.y-body.h/2,w:body.w,h:body.h};
  if(firstBlockingStructure(targetRect))return {ok:false,error:'target is blocked'};
  const first=physicality.firstSegmentBlockingStructure(body,lane.target);
  if(first!==facade)return {ok:false,error:`nearest direct blocker is ${first?.id||first?.name||'none'}`};
  let detoured=false,travel=0,stale=0;
  for(let frame=0;frame<10000;frame++){
    const cx=body.x+body.w/2,cy=body.y+body.h/2,dx=lane.target.x-cx,dy=lane.target.y-cy,d=Math.hypot(dx,dy);
    if(d<=3.1)return {ok:detoured,travel,error:detoured?'':'never entered detour mode'};
    const oldX=body.x,oldY=body.y,step=Math.min(body.speed,d);
    const movement=commitActorStructureMotion(body,oldX,oldY,oldX+dx/d*step,oldY+dy/d*step,lane.target,true);
    detoured=detoured||movement.detouring===true;
    if(firstBlockingStructure(body))return {ok:false,error:'actor became embedded'};
    const moved=Math.hypot(body.x-oldX,body.y-oldY);travel+=moved;
    stale=moved<1e-8?stale+1:0;
    if(stale>4)return {ok:false,error:'actor wedged'};
  }
  return {ok:false,error:'actor traversal exceeded 10,000 frames'};
}

for(const facade of LANDMARK_FACADES){
  for(const cop of [false,true]){
    const result=traverseActorAcross(facade,cop);
    if(!result.ok)fail(`${facade.id}: generic ${cop?'cop':'NPC'} traversal failed (${result.error})`);
    else actorHelperTraversals++;
  }
}

function syntheticActor(facade,cop,suffix='cross'){
  return {
    id:`qa_${suffix}_${cop?'cop':'npc'}_${facade.id}`,name:'QA ACTOR',cop,
    x:0,y:0,w:28,h:32,speed:3,hp:100,maxHp:100,dmg:1,
    hostile:true,aggro:true,dead:false,attackCd:0,hitStun:0,
    chatterT:0,chatterCd:1e9,frame:0,frameT:0,
  };
}

// Drive the real NPC update, not only its collision helper. Both generic NPCs
// and cops must route from one side of every new structure to the other.
function productionActorAcross(facade,cop){
  const actor=syntheticActor(facade,cop),lane=wallLane(facade,actor.w,actor.h,18);
  actor.x=lane.start.x-actor.w/2;actor.y=lane.start.y-actor.h/2;
  const targetRect={x:lane.target.x-actor.w/2,y:lane.target.y-actor.h/2,w:actor.w,h:actor.h};
  if(firstBlockingStructure(actor))return {ok:false,error:'start is blocked'};
  if(firstBlockingStructure(targetRect))return {ok:false,error:'target is blocked'};
  const first=physicality.firstSegmentBlockingStructure(actor,lane.target);
  if(first!==facade)return {ok:false,error:`nearest direct blocker is ${first?.id||first?.name||'none'}`};
  P.x=lane.target.x-P.w/2;P.y=lane.target.y-P.h/2;P.hp=P.maxHp;P.stunT=0;P.slowT=0;
  runtime.npcs=[actor];
  let leftLane=false,maxDisplacementY=0;
  for(let frame=0;frame<2000;frame++){
    const distance=Math.hypot(lane.target.x-(actor.x+actor.w/2),lane.target.y-(actor.y+actor.h/2));
    if(distance<=42)return {ok:leftLane,frames:frame,error:leftLane?'':'actor reached far side without a visible detour'};
    npcAi.updateNpcActors(16);
    if(overlapsAnySolid(actor))return {ok:false,error:`actor geometrically overlapped a solid on frame ${frame+1}`};
    maxDisplacementY=Math.max(maxDisplacementY,Math.abs(actor.y+actor.h/2-lane.start.y));
    leftLane=leftLane||maxDisplacementY>.1;
  }
  return {ok:false,error:'production update exceeded 2,000 frames'};
}

for(const facade of LANDMARK_FACADES){
  for(const cop of [false,true]){
    const result=productionActorAcross(facade,cop);
    if(!result.ok)fail(`${facade.id}: production ${cop?'cop':'NPC'} traversal failed (${result.error})`);
    else productionActorTraversals++;
  }
}

// A charge is a committed line, not an obstacle-following path. Exercise both
// shipped lunge state machines diagonally into every facade: neither axis may
// slide, no detour may survive, and the existing cooldown must begin next tick.
for(const facade of LANDMARK_FACADES){
  for(const archetype of ['charger','priest_fallen']){
    const actor=syntheticActor(facade,false,`${archetype}_wall`);
    const centerY=facade.y+Math.min(20,Math.max(8,facade.h/3));
    actor.archetype=archetype;actor.chargeState='lunge';actor.chargeT=1000;
    actor.lungeVx=Math.SQRT1_2;actor.lungeVy=Math.SQRT1_2;
    if(archetype==='priest_fallen'){actor.hp=40;actor.maxHp=100;actor.fallenPhase2=true;}
    actor.x=facade.x-actor.w;actor.y=centerY-actor.h/2;
    const before={x:actor.x,y:actor.y};
    P.x=facade.x+facade.w+100;P.y=centerY+100;P.hp=P.maxHp;P.stunT=0;P.slowT=0;
    runtime.npcs=[actor];npcAi.updateNpcActors(16);
    if(actor.x!==before.x||actor.y!==before.y)fail(`${facade.id}: diagonal ${archetype} charge slid from (${before.x},${before.y}) to (${actor.x},${actor.y})`);
    else if(actor.structurePath?.length)fail(`${facade.id}: blocked ${archetype} charge retained a structure detour`);
    else if(actor.structureChargeHit!==true)fail(`${facade.id}: blocked ${archetype} charge did not register a wall hit`);
    else {
      npcAi.updateNpcActors(16);
      if(actor.chargeState!=='cooldown')fail(`${facade.id}: wall-hit ${archetype} charge did not enter its existing cooldown`);
      else if(actor.x!==before.x||actor.y!==before.y)fail(`${facade.id}: wall-hit ${archetype} cooldown moved the actor after impact`);
      else chargeWallStops++;
    }
  }
}

// A newly-solid landmark spawn is new physical state and must be ejected before
// its ordinary AI step. This is distinct from the grandfathered legacy spawns.
for(const facade of LANDMARK_FACADES){
  const actor=syntheticActor(facade,false,'embedded'),lane=wallLane(facade,actor.w,actor.h,18);
  actor.x=facade.x+8;actor.y=facade.y+8;
  const expected=nearestCardinalEjection(facade,actor);
  const start={x:actor.x,y:actor.y};
  if(firstBlockingStructure(actor)!==facade)fail(`${facade.id}: embedded actor fixture is not blocked by its target facade`);
  else if(!expected)fail(`${facade.id}: embedded actor has no cardinal ejection candidate`);
  else {
    P.x=lane.target.x-P.w/2;P.y=lane.target.y-P.h/2;P.hp=P.maxHp;P.stunT=0;P.slowT=0;
    runtime.npcs=[actor];npcAi.updateNpcActors(16);
    const ejectionDistance=Math.hypot(expected.x-start.x,expected.y-start.y);
    const actualDistance=Math.hypot(actor.x-start.x,actor.y-start.y);
    if(actor.structureCollisionReady!==true)fail(`${facade.id}: newly-solid actor did not enter shared collision mode`);
    else if(firstBlockingStructure(actor)||overlapsAnySolid(actor))fail(`${facade.id}: newly-solid actor remained embedded after its first production update`);
    else if(actualDistance<ejectionDistance-actor.speed-1e-6||actualDistance>ejectionDistance+actor.speed+1e-6)fail(`${facade.id}: newly-solid actor moved ${actualDistance.toFixed(3)}px; nearest ejection plus one AI step permits ${ejectionDistance.toFixed(3)}px ± ${actor.speed}px`);
    else facadeActorEjections++;
  }
}

// Eight shipped actors intentionally begin inside legacy BUILDINGS. They get a
// one-way exit exemption, not a load-time teleport. Seven are stationary; the
// eighth may take exactly its ordinary swarmer step and nothing larger.
const LEGACY_EMBEDDED_ACTORS=Object.keys(EXPECTED_LEGACY_ACTOR_STRUCTURES);
for(const id of LEGACY_EMBEDDED_ACTORS){
  context.window._rb.startGame(false);
  const actor=runtime.npcs.find(candidate=>candidate.id===id);
  if(!actor){fail(`legacy embedded actor ${id} did not spawn`);continue;}
  const expectedIndex=EXPECTED_LEGACY_ACTOR_STRUCTURES[id];
  const legacyOverlap=firstBlockingStructure(actor);
  if(actor.legacyStructureIndex!==expectedIndex){fail(`${id}: runtime legacy footprint declaration drifted`);continue;}
  if(legacyOverlap!==BUILDINGS[expectedIndex]){fail(`legacy embedded fixture ${id} no longer occupies BUILDINGS[${expectedIndex}]; retire or update the regression`);continue;}
  runtime.npcs=[actor];
  const before={x:actor.x,y:actor.y};
  npcAi.updateNpcActors(16);
  const moved=Math.hypot(actor.x-before.x,actor.y-before.y);
  if(actor.structureCollisionReady!==false)fail(`${id}: grandfathered legacy overlap entered collision-ready mode before exiting`);
  if(id==='skid_sherri'){
    const ordinaryMax=actor.speed*1.4;
    if(!(moved>0&&moved<=ordinaryMax+1e-6))fail(`${id}: first update moved ${moved.toFixed(6)}px; ordinary swarmer step is >0 and <= ${ordinaryMax.toFixed(6)}px`);
    else legacySpawnChecks++;
  }else if(actor.x!==before.x||actor.y!==before.y){
    fail(`${id}: stationary legacy spawn jumped from (${before.x},${before.y}) to (${actor.x},${actor.y})`);
  }else legacySpawnChecks++;
}

// The compatibility ruling belongs to those eight authored identities, not to
// BUILDINGS as a class. An unrelated actor first observed inside an old solid
// must join collision immediately and eject just like any other dynamic spawn.
{
  const legacyStructure=BUILDINGS.find(structure=>structure.solid===true&&!structure.doorGap);
  const actor=syntheticActor({id:'legacy_structure'},false,'unregistered_legacy');
  actor.hostile=false;actor.aggro=false;
  actor.x=legacyStructure.x+8;actor.y=legacyStructure.y+8;
  const expected=nearestCardinalEjection(legacyStructure,actor);
  runtime.npcs=[actor];npcAi.updateNpcActors(16);
  if(!expected)fail('unregistered legacy actor fixture has no cardinal ejection candidate');
  else if(actor.structureCollisionReady!==true)fail('unregistered legacy actor received the grandfathered exit exemption');
  else if(firstBlockingStructure(actor)||overlapsAnySolid(actor))fail('unregistered legacy actor remained embedded after its first production update');
  else if(!near(actor.x,expected.x)||!near(actor.y,expected.y))fail(`unregistered legacy actor ejected to (${actor.x},${actor.y}), expected (${expected.x},${expected.y})`);
  else unregisteredLegacyActorEjections++;
}

// Even a registered identity loses the exemption outside its exact authored
// footprint. Move canonical Tony into PAWN and require immediate production
// ejection; an id-wide or declaration-wide ghost pass fails here.
{
  context.window._rb.startGame(false);
  const actor=runtime.npcs.find(candidate=>candidate.id==='tony'),wrongStructure=BUILDINGS[0];
  actor.x=wrongStructure.x+8;actor.y=wrongStructure.y+8;
  const expected=nearestCardinalEjection(wrongStructure,actor);
  runtime.npcs=[actor];npcAi.updateNpcActors(16);
  if(!expected)fail('misplaced registered legacy actor fixture has no cardinal ejection candidate');
  else if(actor.structureCollisionReady!==true)fail('registered legacy actor retained its exemption inside the wrong legacy footprint');
  else if(firstBlockingStructure(actor)||overlapsAnySolid(actor))fail('registered legacy actor remained embedded in the wrong legacy footprint');
  else if(!near(actor.x,expected.x)||!near(actor.y,expected.y))fail(`misplaced registered legacy actor ejected to (${actor.x},${actor.y}), expected (${expected.x},${expected.y})`);
  else misplacedLegacyActorEjections++;
}

// ---- 4. collision-aware analog traversal ----------------------------------
const NAV_CLEAR=.01;
const EPS=1e-8;
const LEGACY_SOLIDS=BUILDINGS.filter(structure=>structure.solid===true);
const V21_SOLIDS=STRUCTURES.filter(structure=>structure.solid===true);

function doorAccepts(body,structure,probe=body){
  if(!structure.doorGap)return false;
  const bottom=probe.y+probe.h,centerX=probe.x+probe.w/2;
  return bottom>structure.y+structure.h-30&&bottom<structure.y+structure.h+30
    &&centerX>structure.x+structure.w/2-30&&centerX<structure.x+structure.w/2+30;
}

// The merged helper may centralize the legacy door convention, but it may not
// silently change it. Probe both accepted and rejected edges on every old door.
for(const structure of BUILDINGS.filter(candidate=>candidate.doorGap)){
  for(const xOffset of [-31,-29,0,29,31])for(const bottomOffset of [-31,-29,0,29,31]){
    const probe={
      x:structure.x+structure.w/2+xOffset-P.w/2,
      y:structure.y+structure.h+bottomOffset-P.h,
      w:P.w,h:P.h,
    };
    if(structureDoorAccepts(probe,structure)!==doorAccepts(probe,structure)){
      fail(`legacy doorway convention drifted at (${xOffset},${bottomOffset}) on BUILDINGS entry`);
    }
  }
}
function blocksInSet(body,structure,probe=body){
  return structure.solid===true&&overlaps(body,structure)&&!doorAccepts(body,structure,probe);
}
function firstBlockInSet(body,structures,probe=body){
  return structures.find(structure=>blocksInSet(body,structure,probe))||null;
}
function legacyFrameMove(position,dx,dy,w,h){
  const newX=position.x+dx,newY=position.y+dy,full={x:newX,y:newY,w,h};
  const xRect={x:newX,y:position.y,w,h},yRect={x:position.x,y:newY,w,h};
  const blockedX=!!firstBlockInSet(xRect,LEGACY_SOLIDS,full);
  const blockedY=!!firstBlockInSet(yRect,LEGACY_SOLIDS,yRect);
  return {x:blockedX?position.x:newX,y:blockedY?position.y:newY};
}
let legacyDoorMotionProbes=0;
for(const structure of BUILDINGS.filter(candidate=>candidate.doorGap)){
  for(const centerOffset of [-29,0,29])for(const dx of [-1,1])for(const dy of [3,4]){
    const body={
      x:structure.x+structure.w/2+centerOffset-P.w/2,
      y:structure.y+structure.h-2,
      w:P.w,h:P.h,
    };
    const expected=legacyFrameMove(body,dx,dy,body.w,body.h);
    const actual=resolveStructureMotion(body,body.x+dx,body.y+dy);
    if(!near(actual.x,expected.x)||!near(actual.y,expected.y)){
      fail(`legacy doorway resolver drifted at center ${centerOffset}, delta (${dx},${dy}): expected (${expected.x},${expected.y}), got (${actual.x},${actual.y})`);
    }else legacyDoorMotionProbes++;
  }
}
function openInterval(origin,delta,low,high){
  if(Math.abs(delta)<EPS)return origin>low+EPS&&origin<high-EPS?[-Infinity,Infinity]:null;
  let a=(low-origin)/delta,b=(high-origin)/delta;if(a>b)[a,b]=[b,a];return [a,b];
}
function segmentCrossesOpenRect(start,end,rect){
  const dx=end.x-start.x,dy=end.y-start.y;
  const ix=openInterval(start.x,dx,rect.x1,rect.x2),iy=openInterval(start.y,dy,rect.y1,rect.y2);
  if(!ix||!iy)return false;
  return Math.max(ix[0],iy[0],EPS)<Math.min(ix[1],iy[1],1-EPS)-EPS;
}

function makeNavigator(structures,w,h,mode){
  const solids=structures.filter(structure=>structure.solid===true);
  const blocks=(body,structure)=>mode==='baseline'?blocksInSet(body,structure):structureBlocksRect(body,structure);
  const accepts=(body,structure)=>mode==='baseline'?doorAccepts(body,structure):structureDoorAccepts(body,structure);
  const rects=solids.map(structure=>({
    x1:structure.x-w/2-NAV_CLEAR,x2:structure.x+structure.w+w/2+NAV_CLEAR,
    y1:structure.y-h/2-NAV_CLEAR,y2:structure.y+structure.h+h/2+NAV_CLEAR,
    structure,
  }));
  const insideOpen=(point,rect)=>point.x>rect.x1+EPS&&point.x<rect.x2-EPS&&point.y>rect.y1+EPS&&point.y<rect.y2-EPS;
  const lineOpen=(start,end)=>!rects.some(rect=>segmentCrossesOpenRect(start,end,rect));
  const cornerMap=new Map();
  for(const rect of rects){
    for(const point of [{x:rect.x1,y:rect.y1},{x:rect.x1,y:rect.y2},{x:rect.x2,y:rect.y1},{x:rect.x2,y:rect.y2}]){
      if(point.x<w/2||point.x>WORLD.w-w/2||point.y<h/2||point.y>WORLD.h-h/2)continue;
      if(rects.some(other=>insideOpen(point,other)))continue;
      cornerMap.set(`${point.x},${point.y}`,point);
    }
  }
  const corners=[...cornerMap.values()];
  const cornerAdj=Array.from({length:corners.length},()=>[]);
  for(let i=0;i<corners.length;i++)for(let j=i+1;j<corners.length;j++){
    if(!lineOpen(corners[i],corners[j]))continue;
    const distance=Math.hypot(corners[j].x-corners[i].x,corners[j].y-corners[i].y);
    cornerAdj[i].push([j,distance]);cornerAdj[j].push([i,distance]);
  }

  function prepareEndpoint(point){
    const body={x:point.x-w/2,y:point.y-h/2,w,h};
    const overlapping=solids.filter(structure=>overlaps(body,structure));
    const blockers=overlapping.filter(structure=>blocks(body,structure));
    if(blockers.length)return {bad:blockers.map(s=>s.id||s.name||'(unnamed)'),point,connector:[]};
    if(!overlapping.length)return {bad:[],point,connector:[]};
    const door=overlapping.find(structure=>accepts(body,structure));
    if(!door)return {bad:overlapping.map(s=>s.id||s.name||'(unnamed)'),point,connector:[]};
    const portal={x:point.x,y:door.y+door.h+h/2+NAV_CLEAR};
    return {bad:[],point:portal,connector:[point,portal]};
  }

  function shortest(rawStart,rawEnd){
    const startPlan=prepareEndpoint(rawStart),endPlan=prepareEndpoint(rawEnd);
    if(startPlan.bad.length||endPlan.bad.length)return {length:Infinity,path:[],badStart:startPlan.bad,badEnd:endPlan.bad};
    const nodes=[startPlan.point,endPlan.point,...corners],adj=Array.from({length:corners.length+2},()=>[]);
    for(let i=0;i<corners.length;i++)for(const [next,weight] of cornerAdj[i])adj[i+2].push([next+2,weight]);
    if(lineOpen(nodes[0],nodes[1])){
      const direct=Math.hypot(nodes[1].x-nodes[0].x,nodes[1].y-nodes[0].y);
      adj[0].push([1,direct]);adj[1].push([0,direct]);
    }
    for(let endpoint=0;endpoint<2;endpoint++)for(let i=0;i<corners.length;i++){
      if(!lineOpen(nodes[endpoint],corners[i]))continue;
      const distance=Math.hypot(corners[i].x-nodes[endpoint].x,corners[i].y-nodes[endpoint].y);
      adj[endpoint].push([i+2,distance]);adj[i+2].push([endpoint,distance]);
    }
    const distance=Array(nodes.length).fill(Infinity),previous=Array(nodes.length).fill(-1),visited=Array(nodes.length).fill(false);
    distance[0]=0;
    for(let pass=0;pass<nodes.length;pass++){
      let current=-1;
      for(let i=0;i<nodes.length;i++)if(!visited[i]&&(current<0||distance[i]<distance[current]-EPS))current=i;
      if(current<0||!Number.isFinite(distance[current])||current===1)break;
      visited[current]=true;
      for(const [next,weight] of adj[current])if(distance[current]+weight<distance[next]-EPS){distance[next]=distance[current]+weight;previous[next]=current;}
    }
    if(!Number.isFinite(distance[1]))return {length:Infinity,path:[],badStart:[],badEnd:[]};
    const navPath=[];
    for(let cursor=1;cursor>=0;cursor=previous[cursor]){navPath.push(nodes[cursor]);if(cursor===0)break;}
    navPath.reverse();
    const path=[...(startPlan.connector.length?startPlan.connector:[rawStart]),...navPath.slice(1)];
    if(endPlan.connector.length)path.push(rawEnd);
    const connectorLength=(startPlan.connector.length?Math.hypot(startPlan.connector[1].x-startPlan.connector[0].x,startPlan.connector[1].y-startPlan.connector[0].y):0)
      +(endPlan.connector.length?Math.hypot(endPlan.connector[1].x-endPlan.connector[0].x,endPlan.connector[1].y-endPlan.connector[0].y):0);
    return {length:distance[1]+connectorLength,path,badStart:[],badEnd:[]};
  }
  return {shortest,w,h};
}

function replayPath(path,mode,w,h,step){
  if(!Array.isArray(path)||path.length<2)return {ok:false,length:Infinity,error:'no traversal path'};
  const body={x:path[0].x-w/2,y:path[0].y-h/2,w,h};
  let length=0,frames=0,stale=0;
  for(const target of path.slice(1)){
    for(;;){
      const cx=body.x+w/2,cy=body.y+h/2,dx=target.x-cx,dy=target.y-cy,distance=Math.hypot(dx,dy);
      if(distance<1e-6)break;
      if(++frames>100000)return {ok:false,length:Infinity,error:`frame limit before (${target.x},${target.y})`};
      const travel=Math.min(step,distance),oldX=body.x,oldY=body.y;
      if(mode==='baseline'){
        const next=legacyFrameMove(body,dx/distance*travel,dy/distance*travel,w,h);body.x=next.x;body.y=next.y;
      }else{
        const next=resolveStructureMotion(body,body.x+dx/distance*travel,body.y+dy/distance*travel);body.x=next.x;body.y=next.y;
      }
      const moved=Math.hypot(body.x-oldX,body.y-oldY);length+=moved;
      stale=moved<1e-9?stale+1:0;
      if(stale>3)return {ok:false,length:Infinity,error:`wedged at (${cx.toFixed(2)},${cy.toFixed(2)})`};
    }
  }
  return {ok:true,length,frames,error:''};
}

// ---- 5. live mandatory-leg inventory + action-region endpoint repair -------
context.window._rb.startGame(false);
const spawn=freshPlayerCenter;
const baseStep=P.speed;
const walkPxPerSec=P.speed*1000/16;
const legBudget=routeLegBudgetPx();
const tony=runtime.npcs.find(npc=>npc.id==='tony');
const tonyAnchor=tony?{x:tony.x+tony.w/2,y:tony.y+tony.h/2}:null;
const interactionSource=fs.readFileSync(path.join(ROOT,'src/systems/interactions.js'),'utf8');
const NPC_ACTION_RADIUS=60;
if(!tonyAnchor)fail('Tony runtime anchor unavailable; impossible objective endpoints cannot be projected honestly');
if(!/bestNpcD\s*=\s*60\s*\*\s*60/.test(interactionSource))fail('live generic NPC interaction radius is no longer the audited 60px; update action-region traversal semantics');

const samePoint=(a,b)=>a&&b&&near(a.x,b.x,1e-6)&&near(a.y,b.y,1e-6);
function clearCenter(point,structures,w=P.w,h=P.h){
  const body={x:point.x-w/2,y:point.y-h/2,w,h};
  return body.x>=0&&body.y>=0&&body.x+w<=WORLD.w&&body.y+h<=WORLD.h&&!firstBlockInSet(body,structures);
}
function projectActionPoint(anchor,radius,opposite,structures,w=P.w,h=P.h){
  const effective=radius-.05,clearance=.02,candidates=[];
  const add=(x,y)=>{
    if(!Number.isFinite(x)||!Number.isFinite(y))return;
    const point={x,y};
    if(Math.hypot(x-anchor.x,y-anchor.y)>effective+1e-7||!clearCenter(point,structures,w,h))return;
    candidates.push(point);
  };
  // Circle sampling is a deterministic fallback for future non-rectangular
  // combinations; edge projections below provide the exact axis-aligned optimum.
  for(let i=0;i<1440;i++){
    const angle=i*Math.PI*2/1440;add(anchor.x+Math.cos(angle)*effective,anchor.y+Math.sin(angle)*effective);
  }
  for(const structure of structures.filter(s=>s.solid===true)){
    const left=structure.x-w/2-clearance,right=structure.x+structure.w+w/2+clearance;
    const top=structure.y-h/2-clearance,bottom=structure.y+structure.h+h/2+clearance;
    for(const y of [top,bottom]){
      const dy=y-anchor.y;if(Math.abs(dy)>effective)continue;
      const span=Math.sqrt(Math.max(0,effective*effective-dy*dy)),lo=anchor.x-span,hi=anchor.x+span;
      add(Math.max(lo,Math.min(hi,opposite.x)),y);add(lo,y);add(hi,y);
    }
    for(const x of [left,right]){
      const dx=x-anchor.x;if(Math.abs(dx)>effective)continue;
      const span=Math.sqrt(Math.max(0,effective*effective-dx*dx)),lo=anchor.y-span,hi=anchor.y+span;
      add(x,Math.max(lo,Math.min(hi,opposite.y)));add(x,lo);add(x,hi);
    }
  }
  candidates.sort((a,b)=>{
    const ad=(a.x-opposite.x)**2+(a.y-opposite.y)**2,bd=(b.x-opposite.x)**2+(b.y-opposite.y)**2;
    return ad-bd||a.x-b.x||a.y-b.y;
  });
  return candidates[0]||null;
}

function resolveEndpoint(anchor,opposite){
  if(clearCenter(anchor,LEGACY_SOLIDS))return {point:{x:anchor.x,y:anchor.y},projected:false};
  if(!samePoint(anchor,tonyAnchor))return {point:null,projected:false,error:`unstandable raw anchor (${anchor.x},${anchor.y}) has no registered live action region`};
  const point=projectActionPoint(anchor,NPC_ACTION_RADIUS,opposite,LEGACY_SOLIDS);
  if(!point)return {point:null,projected:true,error:`Tony action region contains no standable point within ${NPC_ACTION_RADIUS}px`};
  return {point,projected:true};
}

const campaignLegs=[];
const addCampaign=(name,a,b)=>campaignLegs.push({family:'campaign',name,a:{x:a.x,y:a.y},b:{x:b.x,y:b.y}});
function need(objective,label){
  if(!objective||!Number.isFinite(objective.x)||!Number.isFinite(objective.y)){
    fail(`objective selector returned no finite anchor for ${label}`);return {x:NaN,y:NaN};
  }
  return objective;
}
const {
  currentPrimaryObjective,currentOfficeObjective,currentKingdomObjective,
  CLAIM_SITES,KINGDOM_CLAN_LIST,
}=campaigns;

const oPile=need(currentPrimaryObjective(),'intro find-cash');
state.quests.intro_remember.done=true;
const oTony=need(currentPrimaryObjective(),'intro Tony');
state.quests.intro_tony.done=true;P.rocks=1;
const oCrate=need(currentPrimaryObjective(),'intro crate');P.rocks=0;
addCampaign('intro spawn -> find-cash',spawn,oPile);
addCampaign('intro find-cash -> tony',oPile,oTony);
addCampaign('intro tony -> crate',oTony,oCrate);
state.flags.introDone=true;
state.quests.office_space.available=true;
const oLot=need(currentOfficeObjective(),'office leasing guy');
addCampaign('crate -> leasing guy (office_space)',oCrate,oLot);
state.office.owned=true;state.office.upgrades.desk=true;
state.office.claimJob={id:CLAIM_SITES[0].id,stage:'file'};
const OFFICE=need(currentOfficeObjective(),'office file anchor');
addCampaign('leasing guy -> office',oLot,OFFICE);
for(const site of CLAIM_SITES){
  state.office.claimJob={id:site.id,stage:'survey'};const survey=need(currentOfficeObjective(),`${site.id} survey`);
  state.office.claimJob={id:site.id,stage:'install'};const sign=need(currentOfficeObjective(),`${site.id} sign`);
  addCampaign(`claim ${site.id}: office -> survey`,OFFICE,survey);
  addCampaign(`claim ${site.id}: survey -> office`,survey,OFFICE);
  addCampaign(`claim ${site.id}: office -> sign`,OFFICE,sign);
  addCampaign(`work ${site.id}: sign -> office`,sign,OFFICE);
}
state.office.claimJob=null;
for(const id of CLAIM_SITES.slice(0,4).map(site=>site.id))state.districtClaims[id]=true;
const kingdom=state.kingdom;kingdom.stage='locked';
const oCorner=need(currentKingdomObjective(),'kingdom prereq');
addCampaign('kingdom prereq: office -> corner',OFFICE,oCorner);
kingdom.stage='summons';state.office.upgrades.radio=true;
const oSummons=need(currentKingdomObjective(),'kingdom summons');
addCampaign('kingdom summons: corner -> office',oCorner,oSummons);
let previous=oSummons,previousName='office';
for(const clan of KINGDOM_CLAN_LIST){
  kingdom.stage=clan.marksStage;
  for(const [marks,index] of [[0,0],[1,1],[3,2]]){
    kingdom.marks=marks;const objective=need(currentKingdomObjective(),`${clan.id} mark${index}`);
    addCampaign(`kingdom ${clan.id}: ${previousName} -> mark${index}`,previous,objective);
    previous=objective;previousName=`mark${index}`;
  }
  kingdom.marks=7;const banner=need(currentKingdomObjective(),`${clan.id} banner`);
  addCampaign(`kingdom ${clan.id}: ${previousName} -> banner`,previous,banner);
  kingdom.stage=clan.bossStage;kingdom.marks=0;const boss=need(currentKingdomObjective(),`${clan.id} boss`);
  addCampaign(`kingdom ${clan.id}: banner -> boss`,banner,boss);
  previous=boss;previousName=`${clan.id} boss`;
}
kingdom.stage='anoint';const anoint=need(currentKingdomObjective(),'kingdom anoint');
addCampaign(`kingdom anoint: ${previousName} -> block`,previous,anoint);
kingdom.stage='emperor_gate';const throneBanner=need(currentKingdomObjective(),'emperor gate');
addCampaign('kingdom emperor: block -> throne banner',anoint,throneBanner);
kingdom.stage='emperor_boss';const emperor=need(currentKingdomObjective(),'emperor boss');
addCampaign('kingdom emperor: banner -> boss',throneBanner,emperor);
if(campaignLegs.length!==69)fail(`campaign traversal inventory has ${campaignLegs.length} legs, expected 69 from the live selectors`);

// ---- 6. before/after traversal ledger -------------------------------------
const baselineNavigator=makeNavigator(LEGACY_SOLIDS,P.w,P.h,'baseline');
const v21Navigator=makeNavigator(V21_SOLIDS,P.w,P.h,'v21');
let projectedEndpointOccurrences=0;

function measureMandatoryLeg(leg,countProjection=false){
  const resolvedA=resolveEndpoint(leg.a,leg.b),resolvedB=resolveEndpoint(leg.b,leg.a);
  if(resolvedA.error||resolvedB.error||!resolvedA.point||!resolvedB.point){
    fail(`${leg.name}: endpoint resolution failed (${resolvedA.error||resolvedB.error||'no point'})`);
    return {...leg,rawStraight:Math.hypot(leg.b.x-leg.a.x,leg.b.y-leg.a.y),baseline:Infinity,v21:Infinity,delta:Infinity};
  }
  if(countProjection)projectedEndpointOccurrences+=Number(resolvedA.projected)+Number(resolvedB.projected);
  const a=resolvedA.point,b=resolvedB.point;
  const baselinePlan=baselineNavigator.shortest(a,b),v21Plan=v21Navigator.shortest(a,b);
  if(!Number.isFinite(baselinePlan.length)){
    fail(`${leg.name}: baseline traversal is unreachable (start blockers ${baselinePlan.badStart?.join(',')||'none'}; end blockers ${baselinePlan.badEnd?.join(',')||'none'})`);
  }
  if(!Number.isFinite(v21Plan.length)){
    fail(`${leg.name}: v21 traversal is unreachable (start blockers ${v21Plan.badStart?.join(',')||'none'}; end blockers ${v21Plan.badEnd?.join(',')||'none'})`);
  }
  const baselineReplay=replayPath(baselinePlan.path,'baseline',P.w,P.h,baseStep);
  const v21Replay=replayPath(v21Plan.path,'v21',P.w,P.h,baseStep);
  if(!baselineReplay.ok)fail(`${leg.name}: baseline traversal replay failed (${baselineReplay.error})`);
  if(!v21Replay.ok)fail(`${leg.name}: v21 traversal replay failed (${v21Replay.error})`);
  const baseline=baselineReplay.length,v21=v21Replay.length;
  return {
    ...leg,a,b,projectedA:resolvedA.projected,projectedB:resolvedB.projected,
    rawStraight:Math.hypot(leg.b.x-leg.a.x,leg.b.y-leg.a.y),
    actionStraight:Math.hypot(b.x-a.x,b.y-a.y),baseline,v21,delta:v21-baseline,
    baselineFrames:baselineReplay.frames,v21Frames:v21Replay.frames,
  };
}

const campaignMeasurements=campaignLegs.map(leg=>measureMandatoryLeg(leg,true));
if(projectedEndpointOccurrences!==4)fail(`campaign endpoint register projected ${projectedEndpointOccurrences} impossible anchor occurrence(s), expected the four Tony-center occurrences`);

const routeMeasurements=[],excludedRouteMeasurements=[];
for(let i=0;i<ROUTE_STOPS.length;i++)for(let j=i+1;j<ROUTE_STOPS.length;j++){
  const a=ROUTE_STOPS[i],b=ROUTE_STOPS[j],rawStraight=Math.hypot(b.x-a.x,b.y-a.y);
  const leg={family:'route',name:`route ${a.id} <-> ${b.id}`,a,b};
  if(rawStraight<=legBudget+EPS)routeMeasurements.push(measureMandatoryLeg(leg));
  else excludedRouteMeasurements.push(measureMandatoryLeg({...leg,family:'route-excluded'}));
}
if(ROUTE_STOPS.length!==23)fail(`route traversal inventory has ${ROUTE_STOPS.length} stops, expected 23`);
if(routeMeasurements.length!==252)fail(`assignable route traversal inventory has ${routeMeasurements.length} pairs, expected 252`);
if(excludedRouteMeasurements.length!==1||excludedRouteMeasurements[0]?.name!=='route scrap_gate <-> ditch_gauge'){
  fail(`route exclusion inventory drifted: expected only scrap_gate <-> ditch_gauge, got ${excludedRouteMeasurements.map(row=>row.name).join(', ')||'none'}`);
}

const finiteReadings=[...campaignMeasurements,...routeMeasurements].filter(row=>Number.isFinite(row.baseline)&&Number.isFinite(row.v21));
const newBudgetCrossings=finiteReadings.filter(row=>row.baseline<=legBudget+EPS&&row.v21>legBudget+EPS);
for(const row of newBudgetCrossings)fail(`${row.name}: collision detour crosses runway budget (${px(row.baseline)} baseline -> ${px(row.v21)} v21; budget ${px(legBudget)})`);

// The two ceiling controls pin the metric to the audited pre-change traversal,
// so an accidentally permissive pathfinder cannot make the new ledger look safe.
const introReading=campaignMeasurements.find(row=>row.name==='intro spawn -> find-cash');
const emperorReading=campaignMeasurements.find(row=>row.name==='kingdom emperor: block -> throne banner');
const pawnDitchReading=routeMeasurements.find(row=>row.name==='route pawn_sill <-> ditch_gauge');
if(!introReading)fail('fresh-spawn traversal control is missing');
else if(!near(introReading.rawStraight,119.080,.2)||!near(introReading.baseline,119.080,.2))fail(`fresh-spawn control measured ${px(introReading.rawStraight)} straight / ${px(introReading.baseline)} baseline, expected 119.1px; a fixture likely reused mutated player state`);
if(!emperorReading)fail('emperor commute traversal control is missing');
else if(!near(emperorReading.baseline,7939.352,1))fail(`emperor baseline control measured ${px(emperorReading.baseline)}, expected 7939.4px ± 1px`);
if(!pawnDitchReading)fail('pawn_sill <-> ditch_gauge traversal control is missing');
else if(!near(pawnDitchReading.baseline,8123.864,1))fail(`pawn_sill <-> ditch_gauge baseline control measured ${px(pawnDitchReading.baseline)}, expected 8123.9px ± 1px`);

// Every newly-solid facade also receives an end-to-end player-sized route replay
// through the production resolver. Wall rejection alone would not prove escape.
let playerFacadeTraversals=0;
for(const facade of LANDMARK_FACADES){
  const lane=wallLane(facade,P.w,P.h,18),probe={x:lane.start.x-P.w/2,y:lane.start.y-P.h/2,w:P.w,h:P.h};
  const blocker=physicality.firstSegmentBlockingStructure(probe,lane.target);
  const plan=v21Navigator.shortest(lane.start,lane.target);
  const replay=replayPath(plan.path,'v21',P.w,P.h,baseStep);
  if(blocker!==facade)fail(`${facade.id}: player traversal probe names ${blocker?.id||blocker?.name||'no'} nearest blocker`);
  else if(!replay.ok)fail(`${facade.id}: player traversal around facade failed (${replay.error})`);
  else playerFacadeTraversals++;
}

function octileLowerBound(a,b){
  const dx=Math.abs(b.x-a.x),dy=Math.abs(b.y-a.y),diagonal=Math.min(dx,dy);
  return diagonal*Math.SQRT2+Math.max(dx,dy)-diagonal;
}
const emperorWasd=emperorReading?octileLowerBound(emperorReading.a,emperorReading.b):Infinity;
const pawnDitchWasd=pawnDitchReading?octileLowerBound(pawnDitchReading.a,pawnDitchReading.b):Infinity;
if(emperorReading&&emperorWasd<=legBudget)fail(`WASD sensitivity premise drifted: emperor octile lower bound ${px(emperorWasd)} no longer exceeds ${px(legBudget)}`);
if(pawnDitchReading&&pawnDitchWasd<=legBudget)fail(`WASD sensitivity premise drifted: pawn_sill <-> ditch_gauge octile lower bound ${px(pawnDitchWasd)} no longer exceeds ${px(legBudget)}`);

const worstCampaign=[...campaignMeasurements].filter(row=>Number.isFinite(row.delta)).sort((a,b)=>b.delta-a.delta)[0];
const worstRoute=[...routeMeasurements].filter(row=>Number.isFinite(row.delta)).sort((a,b)=>b.delta-a.delta)[0];
const formatReading=row=>`${row.name}: straight ${px(row.rawStraight)} | baseline traversal ${px(row.baseline)} | v21 traversal ${px(row.v21)} | collision delta ${row.delta>=0?'+':''}${px(row.delta)} | ${seconds(row.v21,walkPxPerSec)} = ${(row.v21/legBudget*100).toFixed(3)}% budget`;

if(failures.length){
  console.error('SOLIDITY GATE: FAIL');
  for(const failure of failures)console.error(`  - ${failure}`);
  process.exit(1);
}

console.log('SOLIDITY TRAVERSAL READINGS (arbitrary-heading analog; production collision replay)');
console.log(`  ${formatReading(emperorReading)}`);
console.log(`  ${formatReading(pawnDitchReading)}`);
console.log(`  campaign maximum collision delta — ${formatReading(worstCampaign)}`);
console.log(`  route maximum collision delta — ${formatReading(worstRoute)}`);
console.log(`  excluded ledger control — ${formatReading(excludedRouteMeasurements[0])}`);
console.log(`  WASD sensitivity (unobstructed octile lower bound): emperor ${px(emperorWasd)} = ${(emperorWasd/legBudget*100).toFixed(3)}%; pawn_sill <-> ditch_gauge ${px(pawnDitchWasd)} = ${(pawnDitchWasd/legBudget*100).toFixed(3)}%`);
console.log(`  measured ${campaignMeasurements.length} campaign legs + ${routeMeasurements.length} assignable route pairs; ${projectedEndpointOccurrences} impossible Tony-center occurrences resolved within the live ${NPC_ACTION_RADIUS}px action region; ${newBudgetCrossings.length} new budget crossings${FULL?'':' (use --full for every row)'}`);
if(FULL){
  console.log('SOLIDITY FULL MANDATORY-LEG LEDGER');
  for(const row of campaignMeasurements)console.log(`  [campaign] ${formatReading(row)}`);
  for(const row of routeMeasurements)console.log(`  [route] ${formatReading(row)}`);
  console.log(`  [ratified exclusion; not generator-assignable] ${formatReading(excludedRouteMeasurements[0])}`);
}
console.log(`SOLIDITY GATE: PASS (${BUILDINGS.length+LANDMARK_FACADES.length} declared structures, ${facadeSolid} solid facades/${facadeFlat} flat, ${LANDMARK_FACADES.length} road-clear facades, frozen ${WORLD.w}x${WORLD.h}/${ZONES.length} zones/${PROPS.length} props/${freshNpcCount} NPCs, one collision source, ${directEjections} direct + ${saveEjections} save ejections, ${doorPreservations} doorway preservations + ${legacyDoorMotionProbes} legacy motion probes, ${playerBlocks} player/${projectileBlocks} projectile blocks, ${playerFacadeTraversals} player + ${productionActorTraversals} production actor traversals, ${chargeWallStops} charge wall stops, ${facadeActorEjections} facade + ${unregisteredLegacyActorEjections} unregistered + ${misplacedLegacyActorEjections} misplaced legacy actor ejections, ${legacySpawnChecks} exact legacy spawns preserved, ${campaignMeasurements.length} campaign legs, ${routeMeasurements.length} assignable route pairs, ${newBudgetCrossings.length} new budget crossings)`);
