// v21 Wave 4.2 — permanent character-sprite migration gate.
//
// This gate can prove that the sprite machinery remains pixel-disciplined and
// structurally complete. It cannot prove that any sprite is good art. The eye
// remains the acceptance gate for that, exactly as SPEC-v21-sprite-ceiling says.

import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT=path.resolve(import.meta.dirname,'..');
const RED_CASE=process.argv.find(argument=>argument.startsWith('--red='))?.slice('--red='.length)||'';
const REGISTRY_RED_CASES=new Set(['undeclared','invalid-size','key-count','frame-loss','blank-frame']);
const RED_CASES=new Set([...REGISTRY_RED_CASES,'character-palette','environment-palette','draw-site']);
const failures=[];
const fail=message=>failures.push(message);
const own=(value,key)=>Object.prototype.hasOwnProperty.call(value,key);
const sorted=value=>[...value].sort();
const sameSet=(a,b)=>JSON.stringify(sorted(a))===JSON.stringify(sorted(b));
const DIRS=['down','up','left','right'];

const PLAYER_BASES=['player','playerhi','playerattack','playerattackhi','attack_smear'];
// v22 wave 5.5 — 'crowbar' added (the break-in tool, EQUIPMENT slot 'tool').
// Additive snapshot extension: 93→94 bases, 373→377 keys; the 373 prior keys'
// palette records are untouched and the new hash is ratified below.
const GEAR_IDS=[
  'airpods','bathrobe','cowboy','crocs','crowbar','helmet','mesh_cap','parka','pigeon_crown',
  'priest_collar','propane_torch','ski_mask','trench','vibrams','walmart_sneak','windbreaker',
];
const WEAPON_IDS=['baguette','brick','broken_bottle','cart_wheel','fists','knife','microphone','pipe','shoe'];
const HUMANOID_BASES=[
  'barb','biggu','bishop_wire','blue_tarp_guard','brendan','busker','conductor','cop',
  'cubscout','curb_emperor','darryl_under_blue','dave','dogwalker','foodtruck',
  'general_receipt','gutter_greg','jogger','karaoke','larry','launderlady','lease_guy',
  'lurch','math','mayorscousin','metermaid','mom','paulie','pete','philosopher',
  'phoneguy','pinky','price_guy','priest','priestson','receipt_guard','sherri','stripe',
  'tony','train_hopper','vapelord','wire_guard','yuri',
];
const STATE_BASES=['dave_sleep','tony_coat_2','tony_coat_1','tony_bare','priest_fallen'];
const SPECIAL_BASES=['possum','brutus','scrap_dog','os_brutus','pigeon','horsecop','pothole'];
const INCIDENT_BASES=['incident_mattress','incident_forklift','incident_dryer','incident_suitcase','incident_sprinkler'];
const EXPECTED_ENV_KEYS=[
  'storm_drain','news_box','road_barrier','claim_sign','clan_banner_blue',
  'clan_banner_receipt','clan_banner_wire','clan_banner_curb','rail_signal','utility_top','utility_base',
];
const GEAR_BASES=GEAR_IDS.map(id=>`gear_${id}`);
const WEAPON_BASES=WEAPON_IDS.map(id=>`weapon_${id}`);
const ROUTE_BASES=[1,2,3,4].map(tier=>`route_patch_${tier}`);

function expectedGrammar(){
  const result=new Map();
  const add=(base,keys)=>{
    if(result.has(base))throw new Error(`duplicate expected sprite base ${base}`);
    result.set(base,keys);
  };
  for(const base of ['player','playerhi'])add(base,DIRS.flatMap(dir=>[0,1,2,3].map(frame=>`${base}_${dir}_${frame}`)));
  for(const base of ['playerattack','playerattackhi','attack_smear'])add(base,DIRS.flatMap(dir=>[0,1].map(frame=>`${base}_${dir}_${frame}`)));
  for(const base of GEAR_BASES)add(base,DIRS.map(dir=>`${base}_${dir}`));
  for(const base of WEAPON_BASES)add(base,DIRS.flatMap(dir=>[0,1].map(frame=>`${base}_${dir}_${frame}`)));
  for(const base of ROUTE_BASES)add(base,DIRS.map(dir=>`${base}_${dir}`));
  add('cart_underlay',DIRS.map(dir=>`cart_underlay_${dir}`));
  for(const base of HUMANOID_BASES)add(base,[0,1,2].map(frame=>`${base}_${frame}`));
  add('dave_sleep',[0,1].map(frame=>`dave_sleep_${frame}`));
  for(const base of STATE_BASES.filter(base=>base!=='dave_sleep'))add(base,[0,1,2].map(frame=>`${base}_${frame}`));
  for(const base of SPECIAL_BASES)add(base,[...Array(base==='pothole'?3:2).keys()].map(frame=>`${base}_${frame}`));
  for(const base of INCIDENT_BASES)add(base,[0,1].map(frame=>`${base}_${frame}`));
  return result;
}

const EXPECTED_BASE_KEYS=expectedGrammar();
const EXPECTED_BASES=[...EXPECTED_BASE_KEYS.keys()];
const EXPECTED_KEY_BASES=Object.create(null);
for(const [base,keys] of EXPECTED_BASE_KEYS)for(const key of keys){
  if(own(EXPECTED_KEY_BASES,key))throw new Error(`duplicate expected sprite key ${key}`);
  EXPECTED_KEY_BASES[key]=base;
}
const EXPECTED_KEYS=Object.keys(EXPECTED_KEY_BASES);
if(EXPECTED_BASES.length!==94||EXPECTED_KEYS.length!==377){
  throw new Error(`sprite-gate grammar is internally wrong (${EXPECTED_BASES.length} bases / ${EXPECTED_KEYS.length} keys)`);
}

function registryProblems({sizes,keyBases,cache,pixelCounts,expectedBaseKeys=EXPECTED_BASE_KEYS,requireBoth=false}){
  const problems=[];
  const declared=sizes&&typeof sizes==='object'?sizes:{};
  const mapped=keyBases&&typeof keyBases==='object'?keyBases:{};
  const sprites=cache&&typeof cache==='object'?cache:{};
  const painted=pixelCounts&&typeof pixelCounts==='object'?pixelCounts:{};
  const expectedBases=[...expectedBaseKeys.keys()];
  const expectedKeyBases=Object.create(null);
  for(const [base,keys] of expectedBaseKeys)for(const key of keys)expectedKeyBases[key]=base;
  const expectedKeys=Object.keys(expectedKeyBases),actualKeys=Object.keys(sprites);

  const undeclared=expectedBases.filter(base=>!own(declared,base));
  const extraDeclarations=Object.keys(declared).filter(base=>!expectedBaseKeys.has(base));
  if(undeclared.length)problems.push(`undeclared logical size: ${undeclared.join(', ')}`);
  if(extraDeclarations.length)problems.push(`unexpected base declarations: ${extraDeclarations.join(', ')}`);
  for(const base of expectedBases)if(own(declared,base)&&declared[base]!==16&&declared[base]!==32){
    problems.push(`${base}: logical size must be explicit 16 or 32, got ${JSON.stringify(declared[base])}`);
  }
  if(requireBoth){
    const values=expectedBases.filter(base=>own(declared,base)).map(base=>declared[base]);
    if(!values.includes(16)||!values.includes(32))problems.push('16- and 32-logical sprites must coexist during migration');
  }

  if(actualKeys.length!==expectedKeys.length)problems.push(`sprite key count ${actualKeys.length}, expected exactly ${expectedKeys.length}`);
  const missing=expectedKeys.filter(key=>!own(sprites,key)),unexpected=actualKeys.filter(key=>!own(expectedKeyBases,key));
  if(missing.length)problems.push(`missing expected sprite keys: ${missing.join(', ')}`);
  if(unexpected.length)problems.push(`unexpected sprite keys: ${unexpected.join(', ')}`);
  for(const [base,keys] of expectedBaseKeys){
    const missingForBase=keys.filter(key=>!own(sprites,key));
    if(missingForBase.length)problems.push(`${base}: lost direction/frame key(s) ${missingForBase.join(', ')}`);
  }

  const mappingKeys=Object.keys(mapped);
  const missingMappings=actualKeys.filter(key=>!own(mapped,key)),extraMappings=mappingKeys.filter(key=>!own(sprites,key));
  if(missingMappings.length)problems.push(`cache keys without base mapping: ${missingMappings.join(', ')}`);
  if(extraMappings.length)problems.push(`base mappings without cache key: ${extraMappings.join(', ')}`);
  for(const key of actualKeys){
    if(own(expectedKeyBases,key)&&mapped[key]!==expectedKeyBases[key]){
      problems.push(`${key}: mapped to ${JSON.stringify(mapped[key])}, expected ${expectedKeyBases[key]}`);
    }
    const canvas=sprites[key];
    if(!canvas||canvas.width!==32||canvas.height!==32){
      problems.push(`${key}: cache output must remain exactly 32x32, got ${canvas?.width}x${canvas?.height}`);
    }
    if(!Number.isInteger(painted[key])||painted[key]<=0){
      problems.push(`${key}: frame has no painted logical pixels`);
    }
  }
  const extraPaintCounts=Object.keys(painted).filter(key=>!own(sprites,key));
  if(extraPaintCounts.length)problems.push(`painted-pixel records without cache keys: ${extraPaintCounts.join(', ')}`);
  return problems;
}

// Validator counterexamples. These are deliberately tiny and independent of
// production state so a broken validator cannot congratulate the live corpus.
function syntheticFixture(){
  const expected=new Map([
    ['walker',['walker_down_0','walker_up_0']],
    ['prop',['prop_0']],
  ]);
  return {
    expected,
    sizes:Object.freeze({walker:32,prop:16}),
    keyBases:{walker_down_0:'walker',walker_up_0:'walker',prop_0:'prop'},
    pixelCounts:{walker_down_0:1,walker_up_0:1,prop_0:1},
    cache:{walker_down_0:{width:32,height:32},walker_up_0:{width:32,height:32},prop_0:{width:32,height:32}},
  };
}
const cleanSynthetic=syntheticFixture();
if(registryProblems({...cleanSynthetic,expectedBaseKeys:cleanSynthetic.expected,requireBoth:true}).length)fail('sprite registry validator rejects its valid synthetic control');
function requireCounterexample(name,mutate,pattern){
  const source=syntheticFixture();
  const fixture={
    expected:source.expected,
    sizes:{...source.sizes},keyBases:{...source.keyBases},pixelCounts:{...source.pixelCounts},
    cache:Object.fromEntries(Object.entries(source.cache).map(([key,value])=>[key,{...value}])),
  };
  mutate(fixture);
  const problems=registryProblems({...fixture,expectedBaseKeys:fixture.expected,requireBoth:true});
  if(!problems.some(problem=>pattern.test(problem)))fail(`validator counterexample ${name} did not fire (${problems.join('; ')||'no errors'})`);
}
requireCounterexample('undeclared size',fixture=>{delete fixture.sizes.walker;},/undeclared logical size/);
requireCounterexample('invalid size',fixture=>{fixture.sizes.walker=24;},/explicit 16 or 32/);
requireCounterexample('key loss',fixture=>{delete fixture.cache.walker_up_0;delete fixture.keyBases.walker_up_0;},/lost direction\/frame/);
requireCounterexample('key replacement',fixture=>{delete fixture.cache.prop_0;fixture.cache.prop_1={width:32,height:32};delete fixture.keyBases.prop_0;fixture.keyBases.prop_1='prop';},/missing expected sprite keys/);
requireCounterexample('mapping drift',fixture=>{fixture.keyBases.walker_down_0='prop';},/mapped to/);
requireCounterexample('output resize',fixture=>{fixture.cache.prop_0.width=31;},/exactly 32x32/);
requireCounterexample('lost coexistence',fixture=>{fixture.sizes.prop=32;},/must coexist/);
requireCounterexample('blank frame',fixture=>{fixture.pixelCounts.walker_down_0=0;},/no painted logical pixels/);

let loaded;
try{loaded=await loadModularGame();}
catch(error){
  console.error(`SPRITE GATE: FAIL (game did not link: ${error.message})`);
  process.exit(1);
}
const {context,module}=loaded;
let sprites={},toolkit=null,geography={};
try{sprites=module('src/render/sprites.js');}
catch(error){fail(`sprite module unavailable: ${error.message}`);}
try{toolkit=module('src/render/sprite_toolkit.js');}
catch(error){fail(`sprite toolkit is not linked through the running game: ${error.message}`);}
try{geography=module('src/render/canvas_geography.js');}
catch(error){fail(`environment sprite cache is not linked through the running game: ${error.message}`);}

const sizes=sprites.SPRITE_BASE_SIZES;
const keyBases=sprites.SPRITE_KEY_BASES;
const cache=sprites.SPRITE_CACHE;
const pixelCounts=sprites.SPRITE_PIXEL_COUNTS;
if(RED_CASE&&!RED_CASES.has(RED_CASE))fail(`unknown intentional red case ${JSON.stringify(RED_CASE)}; use ${[...RED_CASES].join(', ')}`);
if(REGISTRY_RED_CASES.has(RED_CASE)){
  const redSizes={...(sizes||{})},redKeyBases={...(keyBases||{})},redCache={...(cache||{})};
  const redPixelCounts={...(pixelCounts||{})};
  if(RED_CASE==='undeclared')delete redSizes.player;
  if(RED_CASE==='invalid-size')redSizes.player=24;
  if(RED_CASE==='key-count'){
    delete redCache.pothole_2;delete redKeyBases.pothole_2;delete redPixelCounts.pothole_2;
  }
  if(RED_CASE==='frame-loss'){
    const canvas=redCache.player_down_3;
    delete redCache.player_down_3;delete redKeyBases.player_down_3;
    const count=redPixelCounts.player_down_3;delete redPixelCounts.player_down_3;
    redCache.__replacement_key__=canvas;redKeyBases.__replacement_key__='player';redPixelCounts.__replacement_key__=count;
  }
  if(RED_CASE==='blank-frame')redPixelCounts.player_down_3=0;
  const redProblems=registryProblems({sizes:redSizes,keyBases:redKeyBases,cache:redCache,pixelCounts:redPixelCounts,requireBoth:false});
  if(!redProblems.length)fail(`intentional red case ${RED_CASE} did not make the registry validator fail`);
  else for(const problem of redProblems)fail(`[intentional red ${RED_CASE}] ${problem}`);
}
if(!sizes||typeof sizes!=='object')fail('SPRITE_BASE_SIZES export is missing; every base must declare 16 or 32');
else if(!Object.isFrozen(sizes))fail('SPRITE_BASE_SIZES must be frozen after its explicit 93-base declaration');
for(const problem of registryProblems({sizes,keyBases,cache,pixelCounts,requireBoth:false}))fail(problem);

// Wave 4.2's final tree migrates all 93 character bases. Coexistence is with the
// environment's explicit 16-logical cache below, not a stale character holdout.
if(sizes&&typeof sizes==='object'){
  const non32=EXPECTED_BASES.filter(base=>sizes[base]!==32);
  if(non32.length)fail(`Wave 4.2 character migration is incomplete; non-32 bases: ${non32.join(', ')}`);
  const playerUnit=[...PLAYER_BASES,...GEAR_BASES],unitSizes=new Set(playerUnit.map(base=>sizes[base]));
  if(unitSizes.size!==1)fail(`player + gear migration unit has mixed declarations: ${[...unitSizes].join(', ')}`);
}

// All cache writes and key-to-base declarations must pass one runtime helper.
// A second direct assignment is how metadata and output silently diverge.
const spriteSource=fs.readFileSync(path.join(ROOT,'src/render/sprites.js'),'utf8');
const toolkitSource=fs.readFileSync(path.join(ROOT,'src/render/sprite_toolkit.js'),'utf8');
const manifestSource=fs.readFileSync(path.join(ROOT,'src/render/sprite_manifest.js'),'utf8');
const geographySource=fs.readFileSync(path.join(ROOT,'src/render/canvas_geography.js'),'utf8');
const cacheWrites=spriteSource.match(/SPRITE_CACHE\s*\[[^\]]+\]\s*=/g)||[];
const keyBaseWrites=spriteSource.match(/SPRITE_KEY_BASES\s*\[[^\]]+\]\s*=/g)||[];
if(cacheWrites.length!==1)fail(`sprites.js has ${cacheWrites.length} indexed SPRITE_CACHE writes; expected one central registration helper`);
if(keyBaseWrites.length!==1)fail(`sprites.js has ${keyBaseWrites.length} indexed SPRITE_KEY_BASES writes; expected one central registration helper`);
if(!/SPRITE_BASE_SIZES\s*=\s*Object\.freeze\s*\(\s*\{/.test(manifestSource))fail('SPRITE_BASE_SIZES is not an explicit frozen object declaration');
const cacheHelper=spriteSource.match(/export\s+function\s+cacheSprite\s*\([^)]*\)\s*\{[\s\S]*?\n\}/)?.[0]||'';
if(!/logicalSize\s*=\s*SPRITE_BASE_SIZES\s*\[\s*base\s*\]/.test(cacheHelper))fail('central cache helper does not read the base declaration without inference');
if(!/if\s*\(\s*!logicalSize\s*\)\s*throw/.test(cacheHelper))fail('central cache helper does not reject an undeclared base');
if(!/rasterize\s*\([\s\S]*\{\s*\.\.\.options\s*,\s*logicalSize\s*\}\s*\)/.test(cacheHelper))fail('central cache helper does not pass the declared logicalSize into rasterize');

// Exercise both supported logical grids through the production rasterizer and
// observe its internal logical canvas plus invariant 32x32 output canvas.
function expectThrow(label,fn){
  let threw=false;
  try{fn();}catch{threw=true;}
  if(!threw)fail(`${label}: production toolkit accepted an invalid sprite input`);
}
if(toolkit){
  const originalCreate=context.document.createElement.bind(context.document);
  const context2d=context.__qa.context2d;
  const originalDrawImage=context2d.drawImage;
  const originalLinear=context2d.createLinearGradient,originalRadial=context2d.createRadialGradient;
  const probe=size=>{
    const created=[],draws=[];let gradients=0;
    context.document.createElement=tag=>{const element=originalCreate(tag);created.push(element);return element;};
    context2d.drawImage=(...args)=>{draws.push(args);};
    context2d.createLinearGradient=()=>{gradients++;return {addColorStop(){}};};
    context2d.createRadialGradient=()=>{gradients++;return {addColorStop(){}};};
    const grid=Array.from({length:size},()=>Array(size).fill(0));grid[1][1]=1;
    let output;
    try{output=toolkit.rasterize(grid,['transparent','#1a1810'],{logicalSize:size,noOutline:true});}
    catch(error){fail(`${size}-logical raster probe threw: ${error.message}`);return;}
    finally{
      context.document.createElement=originalCreate;
      context2d.drawImage=originalDrawImage;
      context2d.createLinearGradient=originalLinear;context2d.createRadialGradient=originalRadial;
    }
    const [logical,rendered]=created;
    if(created.length!==2)fail(`${size}-logical raster created ${created.length} canvases, expected logical + output`);
    if(!logical||logical.width!==size||logical.height!==size)fail(`${size}-logical raster used ${logical?.width}x${logical?.height} logical canvas`);
    if(!rendered||rendered!==output||rendered.width!==32||rendered.height!==32)fail(`${size}-logical raster output is not the observed 32x32 cache canvas`);
    if(draws.length!==1||draws[0][0]!==logical||draws[0][1]!==0||draws[0][2]!==0||draws[0][3]!==32||draws[0][4]!==32){
      fail(`${size}-logical raster does not use exact integer drawImage(logical,0,0,32,32)`);
    }
    if(context2d.imageSmoothingEnabled!==false)fail(`${size}-logical raster left image smoothing enabled`);
    if(gradients!==0)fail(`${size}-logical raster created ${gradients} gradient(s)`);
  };
  probe(16);probe(32);
  const grid16=()=>Array.from({length:16},()=>Array(16).fill(0));
  expectThrow('missing logical size',()=>toolkit.rasterize(grid16(),['transparent','#1a1810']));
  expectThrow('unsupported logical size',()=>toolkit.rasterize(Array.from({length:24},()=>Array(24).fill(0)),['transparent'],{logicalSize:24}));
  expectThrow('row-width mismatch',()=>{const grid=grid16();grid[0].pop();toolkit.rasterize(grid,['transparent'],{logicalSize:16});});
  expectThrow('fractional palette index',()=>{const grid=grid16();grid[0][0]=1.5;toolkit.rasterize(grid,['transparent','#1a1810'],{logicalSize:16});});
  expectThrow('negative palette index',()=>{const grid=grid16();grid[0][0]=-1;toolkit.rasterize(grid,['transparent'],{logicalSize:16});});
  expectThrow('undeclared palette index',()=>{const grid=grid16();grid[0][0]=2;toolkit.rasterize(grid,['transparent','#1a1810'],{logicalSize:16});});
  if(typeof sprites.cacheSprite!=='function')fail('central cacheSprite export is missing');
  else expectThrow('undeclared base registration',()=>sprites.cacheSprite('__undeclared__','__qa_key__',grid16(),['transparent'],{}));
  if(typeof toolkit.blankSpriteGrid!=='function')fail('parameterized blankSpriteGrid export is missing');
  else for(const size of [16,32]){
    let grid;
    try{grid=toolkit.blankSpriteGrid(size);}
    catch(error){fail(`blankSpriteGrid(${size}) threw: ${error.message}`);continue;}
    if(grid.length!==size||grid.some(row=>row.length!==size))fail(`blankSpriteGrid(${size}) did not return ${size}x${size}`);
  }
}

// I-BOTH-SIZES is a live-game property after the character migration: all 93
// character bases are 32, while these eleven environment sprites deliberately
// remain explicit 16-logical consumers of the same rasterizer.
const envCache=geography.ENV_SPRITE_CACHE&&typeof geography.ENV_SPRITE_CACHE==='object'?geography.ENV_SPRITE_CACHE:{};
const envKeys=Object.keys(envCache);
if(!sameSet(envKeys,EXPECTED_ENV_KEYS)){
  fail(`environment sprite key set drifted: expected ${EXPECTED_ENV_KEYS.join(', ')}, got ${envKeys.join(', ')||'none'}`);
}
for(const key of EXPECTED_ENV_KEYS){
  const canvas=envCache[key];
  if(!canvas||canvas.width!==32||canvas.height!==32)fail(`environment sprite ${key} lost its 32x32 output canvas`);
}
if(!/const\s+make\s*=\s*\(\s*key\s*,\s*rows\s*,\s*pal\s*\)/.test(geographySource)||
   !/ENV_SPRITE_PALETTES\s*\[\s*key\s*\]\s*=/.test(geographySource)||
   !/rasterize\s*\(\s*parseGrid\s*\(\s*rows\s*\)\s*,\s*pal\s*,\s*\{\s*logicalSize\s*:\s*16\s*\}\s*\)/.test(geographySource)){
  fail('environment sprite cache no longer declares its shared 16-logical raster path explicitly');
}

// Freeze the palettes actually consumed by every cache key. Looking only at exported
// named groups misses an inline cache palette; looking only at characters misses the
// eleven environment consumers of the same rasterizer.
const clonePaletteMap=source=>Object.fromEntries(Object.entries(source).map(([key,palette])=>[
  key,Array.isArray(palette)?palette.slice():{...palette},
]));
const rawCharacterPalettes=sprites.SPRITE_KEY_PALETTES&&typeof sprites.SPRITE_KEY_PALETTES==='object'
  ? sprites.SPRITE_KEY_PALETTES:{};
const rawEnvironmentPalettes=geography.ENV_SPRITE_PALETTES&&typeof geography.ENV_SPRITE_PALETTES==='object'
  ? geography.ENV_SPRITE_PALETTES:{};
const characterPalettes=clonePaletteMap(rawCharacterPalettes);
const environmentPalettes=clonePaletteMap(rawEnvironmentPalettes);
if(RED_CASE==='character-palette')characterPalettes.player_down_0[1]='#fff';
if(RED_CASE==='environment-palette')environmentPalettes.storm_drain[1]='#fff';
if(!sameSet(Object.keys(characterPalettes),EXPECTED_KEYS))fail('character palette-use records do not cover the exact 373-key grammar');
if(!sameSet(Object.keys(environmentPalettes),EXPECTED_ENV_KEYS))fail('environment palette-use records do not cover the exact 11-key cache');
function checkPalette(name,palette,{transparentIndex=false,authorityBlue=false}={}){
  const indexed=Array.isArray(palette),values=indexed?palette:Object.values(palette||{});
  if(indexed){
    if(palette.length<2||palette.length>8)fail(`${name}: palette must contain 2..8 indexed entries`);
    if(transparentIndex&&palette[0]!=='transparent')fail(`${name}: palette index 0 must be transparent`);
  }else{
    const indices=Object.keys(palette||{});
    if(!indices.length||indices.some(index=>!/^[1-7]$/.test(index)))fail(`${name}: environment palette must declare numeric indices 1..7`);
  }
  for(const raw of values){
    const color=String(raw).trim().toLowerCase();
    if(color!=='transparent'&&!/^#[0-9a-f]{3}(?:[0-9a-f]{3})?$/.test(color))fail(`${name}: non-indexed color literal ${JSON.stringify(raw)}`);
    if(color==='#fff'||color==='#ffffff')fail(`${name}: pure white is forbidden`);
    if((color==='#00f'||color==='#0000ff')&&!authorityBlue)fail(`${name}: bright blue is cops-only`);
  }
}
for(const [key,palette] of Object.entries(characterPalettes)){
  checkPalette(`sprite ${key}`,palette,{transparentIndex:true,authorityBlue:['cop','horsecop','brendan'].includes(keyBases?.[key])});
}
for(const [key,palette] of Object.entries(environmentPalettes))checkPalette(`environment sprite ${key}`,palette);
const characterPaletteSnapshot=Object.entries(characterPalettes).sort(([a],[b])=>a.localeCompare(b));
const environmentPaletteSnapshot=Object.entries(environmentPalettes).sort(([a],[b])=>a.localeCompare(b));
const characterPaletteHash=createHash('sha256').update(JSON.stringify(characterPaletteSnapshot)).digest('hex');
const environmentPaletteHash=createHash('sha256').update(JSON.stringify(environmentPaletteSnapshot)).digest('hex');
// v22 wave 5.5 ratified snapshot: adds the 4 gear_crowbar_* keys. Audit: the art
// module edit only ADDED the crowbar branch — no prior key's draw code changed,
// so the 373 previous records are byte-identical inside the new snapshot.
const EXPECTED_CHARACTER_PALETTE_HASH='1d36333e3aee34e657cdfcaf43891b195996a135e9b7e32c4b85eea84385d8ac';
const EXPECTED_ENVIRONMENT_PALETTE_HASH='ab49d9868ec172f3d3e487ed0230df09319ba395f8df3f8e4d6baaa734348bd3';
if(characterPaletteHash!==EXPECTED_CHARACTER_PALETTE_HASH)fail(`character palette-use corpus drifted (${characterPaletteHash}); audit and ratify a new snapshot`);
if(environmentPaletteHash!==EXPECTED_ENVIRONMENT_PALETTE_HASH)fail(`environment palette-use corpus drifted (${environmentPaletteHash}); audit and ratify a new snapshot`);

const pixelSources=`${spriteSource}\n${toolkitSource}`;
if(/create(?:Linear|Radial)Gradient\s*\(/.test(pixelSources))fail('sprite generation contains a gradient; character art must remain palette-indexed pixels');
if(/imageSmoothingEnabled\s*=\s*true/.test(pixelSources))fail('sprite generation enables image smoothing');
const smoothingOff=toolkitSource.match(/imageSmoothingEnabled\s*=\s*false/g)||[];
if(smoothingOff.length<2)fail(`sprite toolkit disables smoothing ${smoothingOff.length} time(s), expected logical and output canvases`);
const indexSource=fs.readFileSync(path.join(ROOT,'index.html'),'utf8');
if(!/canvas#game\s*\{[^}]*image-rendering\s*:\s*pixelated/i.test(indexSource))fail('game canvas lost image-rendering:pixelated');

// Pin every character-cache destination, including the attack smear and incident
// prop/possum/pigeon overrides that do not travel through drawNpc/drawPlayer.
const drawSiteDefs=[
  ['src/render/actors_weather.js',/^(?:sp|cart|layer|patch|weapon),/,9],
  ['src/render/frame.js',/^smear,/,1],
  ['src/systems/incidents.js',/^(?:sp|ps),/,4],
];
const drawSources=Object.create(null);
const cacheDrawSites=drawSiteDefs.map(([relative,pattern,expectedCount])=>{
  const source=fs.readFileSync(path.join(ROOT,relative),'utf8');
  drawSources[relative]=source;
  const calls=[...source.matchAll(/ctx\.drawImage\(([\s\S]*?)\);/g)]
    .map(match=>match[1].replace(/\s+/g,' ').trim()).filter(call=>pattern.test(call));
  if(calls.length!==expectedCount)fail(`${relative}: found ${calls.length} character-cache draw sites, expected ${expectedCount}`);
  return [relative,calls];
});
function geometryMatch(relative,pattern,label){
  const matched=drawSources[relative]?.match(pattern)?.[0];
  if(!matched){fail(`${relative}: ${label} destination geometry is no longer explicit`);return ''}
  return matched.replace(/\s+/g,' ').trim();
}
const cacheDrawGeometry=[
  geometryMatch('src/render/actors_weather.js',/const\s+drawX\s*=\s*Math\.round\([^;]+;\s*const\s+drawY\s*=\s*Math\.round\([^;]+;/,'NPC anchor'),
  geometryMatch('src/render/actors_weather.js',/const\s+playerDrawX\s*=\s*P\.x-2\s*,\s*playerDrawY\s*=\s*P\.y-4\+\(P\.crashT>0\?1:0\)\s*;/,'player anchor'),
  geometryMatch('src/render/frame.js',/let\s+ax=P\.x-2\s*,\s*ay=P\.y-4\s*;[\s\S]*?if\(P\.facing==='right'\)ax\+=18\s*;/,'attack-smear anchor'),
];
if(RED_CASE==='draw-site')cacheDrawGeometry[0]+=' intentional-destination-drift';
const cacheDrawHash=createHash('sha256').update(JSON.stringify({cacheDrawSites,cacheDrawGeometry})).digest('hex');
const EXPECTED_CACHE_DRAW_HASH='fefd005d79ad33fd9f3919b7da44870405b862706adcfcde301e9dc1f7512585';
if(cacheDrawHash!==EXPECTED_CACHE_DRAW_HASH){
  fail(`character-cache destination rect/anchor corpus drifted (${cacheDrawHash})`);
}

if(failures.length){
  console.error('SPRITE GATE: FAIL');
  for(const failure of failures)console.error(`  - ${failure}`);
  process.exit(1);
}

console.log(`SPRITE GATE: PASS (${EXPECTED_KEYS.length} exact nonblank keys, ${EXPECTED_BASES.length} declared 32-logical character bases + ${EXPECTED_ENV_KEYS.length} explicit 16-logical environment sprites, 14 frozen draw sites, palette-use/no smoothing)`);
console.log('  structural gate only: sprite quality remains an operator visual decision');
