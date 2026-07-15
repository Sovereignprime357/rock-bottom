import { loadModularGame } from './runtime-harness.mjs';

const {context,module}=await loadModularGame();
context.window._rb.startGame(false);

const data=module('src/data/props.js');
const world=module('src/data/world.js');
const structures=module('src/render/structures.js');
const actors=module('src/render/actors_weather.js');
const tiles=module('src/render/tiles.js');
const runtime=module('src/core/runtime_ui.js');
const ctx=context.__qa.context2d;
const failures=[];
const strictOverlap=(a,b)=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;

// Gate 1: every named building entry receives an authored, non-empty plated sign.
const namedBuildings=data.BUILDINGS.filter(building=>String(building.name||'').trim());
const uncovered=namedBuildings.filter(building=>{
  const style=structures.BUILDING_STYLE[building.name];
  return !style||!String(style.sign||'').trim();
});
if(uncovered.length)failures.push(`building sign coverage: ${uncovered.length}/${namedBuildings.length} uncovered`);

// Gate 2: zone-label ink boxes must clear building bodies and authored awnings.
ctx.font='11px Courier New';
const labelArtCollisions=[];
for(const zone of world.ZONES){
  const baseline=zone.y+(zone.labelDy??18);
  const label={x:zone.x+8,y:baseline-8.2,w:ctx.measureText(zone.name).width,h:10.4,zone:zone.name};
  for(const building of data.BUILDINGS){
    const body={x:building.x,y:building.y,w:building.w,h:building.h};
    let hitsArt=strictOverlap(label,body);
    const style=structures.BUILDING_STYLE[building.name];
    if(style?.awning){
      const awning={x:building.x+6,y:building.y-12,w:building.w-12,h:14};
      hitsArt=hitsArt||strictOverlap(label,awning);
    }
    if(hitsArt)labelArtCollisions.push(`${zone.name} × ${building.name||'(locked)'}`);
  }
}
if(labelArtCollisions.length)failures.push(`zone label vs art: ${labelArtCollisions.length} collision(s): ${labelArtCollisions.join(', ')}`);

function labelSpec(npc){
  const words=String(npc.name||'').split(' '),lines=[''];
  for(const word of words){
    const last=lines.length-1,joined=(lines[last]+' '+word).trim();
    if(joined.length>17&&lines[last]&&lines.length<2)lines.push(word);else lines[last]=joined;
  }
  ctx.font='9px Courier New';
  const widths=lines.map(line=>Math.ceil(ctx.measureText(line).width));
  const maxWidth=Math.max(...widths),cx=npc.x+npc.w/2,top=npc.y-8-lines.length*10;
  return {lines,widths,box:{x:Math.round(cx-maxWidth/2-3),y:top-8,w:maxWidth+6,h:lines.length*10}};
}

// Gate 3: use the production placer in the same feet-sorted order as drawAll.
const visibleNames=context.window._rb.npcs.filter(npc=>!npc.dead&&String(npc.name||'').trim()).sort((a,b)=>(a.y+a.h)-(b.y+b.h));
const rawBoxes=visibleNames.map(npc=>({npc,box:labelSpec(npc).box}));
const rawPairs=[];
for(let i=0;i<rawBoxes.length;i++)for(let j=i+1;j<rawBoxes.length;j++)if(strictOverlap(rawBoxes[i].box,rawBoxes[j].box))rawPairs.push(`${rawBoxes[i].npc.name} × ${rawBoxes[j].npc.name}`);

let placedBoxes=[];
if(typeof actors.placeNameplateBox==='function'&&actors.NAMEPLATE_BOX_BUFFER){
  actors.NAMEPLATE_BOX_BUFFER.length=0;
  for(const npc of visibleNames){const spec=labelSpec(npc);placedBoxes.push({npc,box:actors.placeNameplateBox(npc,spec.lines,spec.widths)});}
}else{
  placedBoxes=rawBoxes;
}
const placedPairs=[];
for(let i=0;i<placedBoxes.length;i++)for(let j=i+1;j<placedBoxes.length;j++)if(strictOverlap(placedBoxes[i].box,placedBoxes[j].box))placedPairs.push(`${placedBoxes[i].npc.name} × ${placedBoxes[j].npc.name}`);
if(placedPairs.length||typeof actors.placeNameplateBox!=='function')failures.push(`nameplate de-confliction: ${placedPairs.length||rawPairs.length} pair(s); audited raw pairs: ${rawPairs.join(', ')}`);

if(typeof actors.placeNameplateBox==='function'&&actors.NAMEPLATE_BOX_BUFFER){
  actors.NAMEPLATE_BOX_BUFFER.length=0;
  const dense=[];
  for(let i=0;i<60;i++){
    const npc={id:`dense_${i}`,name:`DENSE CLERK ${i}`,x:100+(i%10)*2,y:200+Math.floor(i/10)*2,w:24,h:28};
    const spec=labelSpec(npc);dense.push(actors.placeNameplateBox(npc,spec.lines,spec.widths));
  }
  for(let i=0;i<dense.length;i++)for(let j=i+1;j<dense.length;j++)if(strictOverlap(dense[i],dense[j]))failures.push(`nameplate dense fixture overlaps at ${i}/${j}`);
}

// Gate 4: every generated record carries measured wall bounds and stays inside them.
const badGraffiti=(runtime.state.graffiti||[]).filter(tag=>
  tag.layoutV!==2||!Number.isFinite(tag.textW)||!Number.isFinite(tag.wallX)||!Number.isFinite(tag.wallW)||
  tag.x<tag.wallX-0.001||tag.x+tag.textW>tag.wallX+tag.wallW+0.001
);
if(badGraffiti.length)failures.push(`graffiti wall fit: ${badGraffiti.length}/${runtime.state.graffiti.length} generated records invalid`);

if(typeof structures.graffitiPoolFor==='function'&&typeof structures.measureGraffitiText==='function'){
  for(const building of data.BUILDINGS.filter(building=>!building.locked)){
    const zoneId=tiles.zoneAt(building.x+building.w/2,building.y+building.h/2);
    const faction=world.ZONES.find(zone=>zone.id===zoneId)?.faction||'street';
    for(let size=8;size<=10;size++){
      const eligible=structures.graffitiPoolFor(faction).filter(line=>structures.measureGraffitiText(line,size)<=building.w-12);
      if(!eligible.length)failures.push(`graffiti eligible set empty: ${building.name} ${faction} ${size}px`);
    }
  }
  runtime.state.graffiti=[{x:0,y:0,text:'legacy',sz:9}];
  structures.buildGraffiti();
  if(runtime.state.graffiti.some(tag=>tag.layoutV!==2))failures.push('graffiti legacy layout did not rebuild once');
}else failures.push('graffiti production measurement helpers are missing');

if(failures.length){
  console.error(`LEGIBILITY GATE: ${failures.length} failure group(s)`);
  failures.slice(0,20).forEach(failure=>console.error(`- ${failure}`));
  process.exit(1);
}
console.log(`LEGIBILITY GATE: PASS (${namedBuildings.length} signs, ${world.ZONES.length} zone labels, ${placedBoxes.length} active nameplates, ${runtime.state.graffiti.length} fitted tags)`);
