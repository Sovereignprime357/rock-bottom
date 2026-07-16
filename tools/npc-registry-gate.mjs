import fs from 'node:fs';
import path from 'node:path';
import { loadModularGame } from './runtime-harness.mjs';

const ROOT=path.resolve(import.meta.dirname,'..');
const failures=[];
const fail=message=>failures.push(message);

const ALIASES=new Map([
  ['BRUTUS (SKID)','BRUTUS'],
  ['LURCH (SKID)','LURCH'],
  ['SHERRI (SKID)','SPIDER-BITE SHERRI'],
  ["FATHER O'MALLEY (FALLEN)","FATHER O'MALLEY"],
]);
const GENERATED_FAMILIES=[
  {canonical:'CURB PRETENDER No. N',runtime:/^CURB PRETENDER No\. [1-9]\d*$/},
];
const OPERATOR_RESERVED_NAME_REGISTER=[
  {
    slot:'blue_tarp_guard',initial:'TARP KNIGHT',runtimeId:/^kingdom_guard_blue_tarp_/,
    sourceSites:["guardSprite:'blue_tarp_guard',guardName:'<NAME>',bossId:'darryl_under_blue'"],
    decisions:[{authority:'operator-ratified',ratified:'2026-07-15',from:'TARP KNIGHT',to:'TARP KNIGHT'}],
  },
  {
    slot:'cart_cavalry_guard',initial:'CART LANCER',runtimeId:/^kingdom_guard_cart_cavalry_/,
    sourceSites:["guardSprite:'receipt_guard',guardName:'<NAME>',bossId:'general_receipt'"],
    decisions:[{authority:'operator-ratified',ratified:'2026-07-15',from:'CART LANCER',to:'CART LANCER'}],
  },
  {
    slot:'copper_choir_guard',initial:'WIRE DEACON',runtimeId:/^kingdom_guard_copper_choir_/,
    sourceSites:["guardSprite:'wire_guard',guardName:'<NAME>',bossId:'bishop_wire'"],
    decisions:[{authority:'operator-ratified',ratified:'2026-07-15',from:'WIRE DEACON',to:'WIRE DEACON'}],
  },
  {
    slot:'throne_guard',initial:['CURB','HOLDOUT'].join(' '),runtimeId:/^kingdom_guard_throne_/,
    sourceSites:[
      "name:emperor?'<NAME>':def.guardName",
      "{id:'throne',guardName:'<NAME>',guardSprite:",
      "id:'kingdom_guard_throne_'+state.day+'_'+i,name:'<NAME>',sprite:",
    ],
    decisions:[{authority:'operator-ratified',ratified:'2026-07-15',from:['CURB','HOLDOUT'].join(' '),to:'KNIGHT EMERITUS'}],
  },
];

function currentReservedName(record){
  let current=record.initial;
  for(const decision of record.decisions){
    if(decision.authority!=='operator-ratified')fail(`reserved-name decision lacks operator ratification: ${record.slot}`);
    if(!/^\d{4}-\d{2}-\d{2}$/.test(decision.ratified))fail(`reserved-name decision has invalid date: ${record.slot}`);
    if(decision.from!==current)fail(`reserved-name decision chain is broken: ${record.slot}`);
    if(!String(decision.to||'').trim())fail(`reserved-name decision has no approved display name: ${record.slot}`);
    current=decision.to;
  }
  return current;
}

const OPERATOR_RESERVED_NAMES=new Map();
for(const record of OPERATOR_RESERVED_NAME_REGISTER){
  const name=currentReservedName(record);
  if(OPERATOR_RESERVED_NAMES.has(record.slot))fail(`duplicate operator-reserved slot: ${record.slot}`);
  if([...OPERATOR_RESERVED_NAMES.values()].includes(name))fail(`duplicate operator-reserved display name: ${name}`);
  OPERATOR_RESERVED_NAMES.set(record.slot,name);
}

function parseRegistry(){
  const lines=fs.readFileSync(path.join(ROOT,'VIBE.md'),'utf8').split(/\r?\n/);
  const header='| Name | Tic | Relationship | Transaction/Threat |';
  const start=lines.findIndex(line=>line.trim()===header);
  if(start<0){fail('canonical VIBE registry header is missing');return new Map();}
  const rows=new Map();
  for(let i=start+2;i<lines.length;i++){
    const line=lines[i].trim();
    if(!line.startsWith('|'))break;
    const cells=line.split('|').slice(1,-1).map(cell=>cell.trim());
    if(cells.length!==4){fail(`VIBE registry line ${i+1} has ${cells.length} cells, expected 4`);continue;}
    const [name,...identity]=cells;
    if(cells.some(cell=>!cell))fail(`VIBE registry line ${i+1} has an empty identity cell`);
    if(cells.some(cell=>/^(?:tbd|todo|\?|n\/a)$/i.test(cell)))fail(`VIBE registry line ${i+1} contains a placeholder cell`);
    if(rows.has(name))fail(`duplicate VIBE registry name: ${name}`);
    rows.set(name,{line:i+1,identity});
  }
  return rows;
}

const registry=parseRegistry();
for(const [alias,target] of ALIASES){
  if(registry.has(alias))fail(`alias also has a canonical row: ${alias}`);
  if(!registry.has(target))fail(`alias target is not registered: ${alias} -> ${target}`);
  if(ALIASES.has(target))fail(`alias chain is forbidden: ${alias} -> ${target}`);
}
for(const family of GENERATED_FAMILIES)if(!registry.has(family.canonical))fail(`generated family is not registered: ${family.canonical}`);

function canonicalName(raw){
  const name=String(raw||'').trim();
  if(registry.has(name))return name;
  if(ALIASES.has(name))return ALIASES.get(name);
  const family=GENERATED_FAMILIES.find(candidate=>candidate.runtime.test(name));
  return family?.canonical||'';
}

function decodeLiteral(expression){
  const text=expression.trim(),quote=text[0];
  if((quote!=="'"&&quote!=='"')||text.at(-1)!==quote)return null;
  return text.slice(1,-1).replace(/\\(u[0-9a-fA-F]{4}|n|r|t|\\|'|")/g,(_,escape)=>{
    if(escape[0]==='u')return String.fromCharCode(parseInt(escape.slice(1),16));
    return {n:'\n',r:'\r',t:'\t','\\':'\\',"'":"'",'"':'"'}[escape]??escape;
  });
}

function sourceFiles(dir){
  const out=[];
  for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
    const full=path.join(dir,entry.name);
    if(entry.isDirectory())out.push(...sourceFiles(full));
    else if(entry.name.endsWith('.js'))out.push(full);
  }
  return out;
}

const quoted=String.raw`(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')`;
const actorPattern=new RegExp(String.raw`\bname\s*:\s*(${quoted}|[^,\r\n]+)\s*,\s*sprite\s*:`,`g`);
const namedFieldPattern=new RegExp(String.raw`\b(?:guardName|bossName)\s*:\s*(${quoted})`,'g');
const mutationPattern=new RegExp(String.raw`\b[A-Za-z_$][\w$]*\.name\s*=\s*(${quoted})\s*;`,'g');
const knownComputed=new Set([
  'extra.name||def.guardName',
  'def.bossName',
  "emperor?'KNIGHT EMERITUS':def.guardName",
  'clan.guardName',
].map(expression=>expression.replace(/\s+/g,'')));
const pretenderExpression="'CURB PRETENDER No. '+(k.pretendersDefeated+1)";
const sourceIdentities=new Map();
let actorAuthoringSites=0;
const campaignsSource=fs.readFileSync(path.join(ROOT,'src/systems/campaigns.js'),'utf8');

function recordSourceIdentity(name,file,index){
  if(!name)return;
  const rel=path.relative(ROOT,file).replaceAll('\\','/');
  const line=fs.readFileSync(file,'utf8').slice(0,index).split(/\r?\n/).length;
  if(!sourceIdentities.has(name))sourceIdentities.set(name,[]);
  sourceIdentities.get(name).push(`${rel}:${line}`);
}

for(const file of sourceFiles(path.join(ROOT,'src'))){
  const source=fs.readFileSync(file,'utf8');
  const spriteFields=source.match(/\bsprite\s*:/g)?.length||0;
  let actorMatches=0,match;
  actorPattern.lastIndex=0;
  while((match=actorPattern.exec(source))){
    actorMatches++;actorAuthoringSites++;
    const expression=match[1].trim(),literal=decodeLiteral(expression);
    if(literal!==null)recordSourceIdentity(literal,file,match.index);
    else{
      const compact=expression.replace(/\s+/g,'');
      if(compact===pretenderExpression.replace(/\s+/g,''))recordSourceIdentity('CURB PRETENDER No. N',file,match.index);
      else if(!knownComputed.has(compact))fail(`unrecognized computed NPC name in ${path.relative(ROOT,file)}: ${expression}`);
    }
  }
  if(actorMatches!==spriteFields)fail(`${path.relative(ROOT,file)} has ${spriteFields} sprite fields but ${actorMatches} registry-scannable actor names; author actors as adjacent name, sprite fields`);
  namedFieldPattern.lastIndex=0;
  while((match=namedFieldPattern.exec(source)))recordSourceIdentity(decodeLiteral(match[1]),file,match.index);
  mutationPattern.lastIndex=0;
  while((match=mutationPattern.exec(source)))recordSourceIdentity(decodeLiteral(match[1]),file,match.index);
}

for(const [name,sites] of sourceIdentities){
  if(!canonicalName(name))fail(`unregistered source NPC identity: ${name} (${sites.join(', ')})`);
}

const {context,module}=await loadModularGame();
context.window._rb.startGame(false);
const runtimeActors=context.window._rb.npcs.filter(actor=>!actor.dead&&String(actor.name||'').trim());
const runtimeIdentities=new Set();
for(const actor of runtimeActors){
  runtimeIdentities.add(actor.name.trim());
  if(!canonicalName(actor.name))fail(`unregistered runtime NPC identity: ${actor.id} / ${actor.name}`);
}

for(const [slot,name] of OPERATOR_RESERVED_NAMES){
  if(!registry.has(name))fail(`operator-reserved display name lacks a canonical row: ${slot} / ${name}`);
  if(!sourceIdentities.has(name))fail(`operator-reserved display name is no longer authored: ${slot} / ${name}`);
  if(!runtimeIdentities.has(name))fail(`operator-reserved display name is absent at runtime: ${slot} / ${name}`);
}
for(const record of OPERATOR_RESERVED_NAME_REGISTER){
  const name=OPERATOR_RESERVED_NAMES.get(record.slot);
  for(const template of record.sourceSites){
    const expected=template.replace('<NAME>',name);
    const occurrences=campaignsSource.split(expected).length-1;
    if(occurrences!==1)fail(`operator-reserved source site changed: ${record.slot} / ${name} (${occurrences} matches)`);
  }
  const actors=runtimeActors.filter(actor=>record.runtimeId.test(String(actor.id||'')));
  if(!actors.length)fail(`operator-reserved runtime slot is absent: ${record.slot}`);
  for(const actor of actors)if(String(actor.name||'').trim()!==name)fail(`operator-reserved runtime slot changed: ${record.slot} / ${actor.id} / ${actor.name}`);
}
const campaigns=module('src/systems/campaigns.js');
const kingdom=campaigns.ensureKingdomState();
kingdom.stage='emperor_gate';
if(!campaigns.startKingdomBoss('emperor'))fail('operator-reserved emperor-add fixture did not start');
const emperorAdds=context.window._rb.npcs.filter(actor=>/^kingdom_add_curb_emperor_/.test(String(actor.id||'')));
const throneGuardName=OPERATOR_RESERVED_NAMES.get('throne_guard');
if(emperorAdds.length!==campaigns.KINGDOM_EMPEROR.adds.length)fail(`operator-reserved emperor-add fixture has ${emperorAdds.length} adds, expected ${campaigns.KINGDOM_EMPEROR.adds.length}`);
for(const actor of emperorAdds)if(String(actor.name||'').trim()!==throneGuardName)fail(`operator-reserved emperor add changed: ${actor.id} / ${actor.name}`);

if(failures.length){
  console.error(`NPC REGISTRY GATE: ${failures.length} failure(s)`);
  failures.slice(0,40).forEach(message=>console.error(`- ${message}`));
  process.exit(1);
}
console.log(`NPC REGISTRY GATE: PASS (${registry.size} canonical rows, ${sourceIdentities.size} source identities, ${runtimeActors.length} runtime actors/${runtimeIdentities.size} identities, ${ALIASES.size} aliases, ${GENERATED_FAMILIES.length} generated family, ${actorAuthoringSites} actor sites)`);
