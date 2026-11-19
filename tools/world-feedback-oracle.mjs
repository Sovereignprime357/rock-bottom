import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
const root=path.resolve(import.meta.dirname,'..');
const out=path.join(root,'game3d/tests/fixtures/world_feedback_reference.json');
const sources={};const pins={};
function text(file){if(!sources[file]){sources[file]=fs.readFileSync(path.join(root,file),'utf8');pins[file]=crypto.createHash('sha256').update(sources[file]).digest('hex');}return sources[file];}
function line(file,marker){const data=text(file);const lines=data.split(/\r?\n/);const hits=lines.flatMap((l,i)=>l.includes(marker)?[i]:[]);if(hits.length!==1)throw Error(`${file}:${marker}:${hits.length}`);return {file,line:hits[0]+1,statement:lines[hits[0]].trim()};}
function loop(file,marker){const data=text(file);const start=data.indexOf(marker);if(start<0||data.indexOf(marker,start+1)>=0)throw Error(marker);let depth=0,end=-1;for(let i=data.indexOf('{',start);i<data.length;i++){if(data[i]==='{')depth++;if(data[i]==='}'&&!--depth){end=i+1;break;}}if(end<0)throw Error('Unclosed loop');return {file,line:data.slice(0,start).split('\n').length,statement:data.slice(start,end)};}
const combat='src/systems/combat.js',update='src/core/update.js',interactions='src/systems/interactions.js',ai='src/systems/npc_ai.js';
const recipes=[
 ['essential',line(combat,"vy:-1.2,life:420")],
 ['melee_sparks',line(combat,"for (let i=0;i<8;i++) particles.push")],
 ['melee_rust',line(combat,"for (let i=0;i<3;i++) particles.push")],
 ['melee_flash',line(combat,"vx:0,vy:0,life:200,c:sparkC")],
 ['bottle_break',line(combat,"for (let i=0;i<12;i++) particles.push")],
 ['bottle_impact',line(update,"for (let j=0;j<10;j++) particles.push")],
 ['holy_impact',line(update,"for (let j=0;j<12;j++) particles.push")],
 ['tony_coat',loop(update,'for (let i=0;i<24;i++) {')],
 ['older_phase',line(update,"for (let i=0;i<20;i++) particles.push")],
 ['dumpster_rats',line(interactions,"for (let i=0;i<10;i++) particles.push")],
 ['trash_cash',line(interactions,"for (let i=0;i<6;i++) particles.push")],
 ['trash_rats',line(interactions,"for (let i=0;i<8;i++) particles.push")],
 ['possum_reveal',line(ai,"for (let i=0;i<6;i++) particles.push")],
 ['ally_hit',line(ai,"for (let i=0;i<4;i++) particles.push({x:target.x")],
 ['ranged_aim',line(ai,"particles.push({x:n.x+n.w/2+8")],
 ['fallen_aim',line(ai,"for (let i=0;i<4;i++) particles.push({x:n.x")],
 ['radio',line(combat,"particles.push({x: cop.x+cop.w/2")],
 ['taser',line(ai,"for (let i=0;i<10;i++) particles.push({x:P.x")],
];
function rgba(value){if(value.startsWith('#')){let raw=value.slice(1);if(raw.length===3)raw=raw.split('').map(x=>x+x).join('');return [0,2,4].map(i=>parseInt(raw.slice(i,i+2),16)/255).concat(1);}const nums=value.match(/[\d.]+/g).map(Number);return nums.slice(0,3).map(n=>n/255).concat(nums[3]??1);}
function origin(recipe,ctx){const center=b=>[b.x+b.w/2,b.y+b.h/2];switch(recipe){case'bottle_break':return[ctx.ip.x,ctx.ip.y-4];case'bottle_impact':case'holy_impact':return[ctx.pr.x,ctx.pr.y];case'tony_coat':return center(ctx.b);case'older_phase':return center(ctx.bo);case'dumpster_rats':return[ctx.dumpster.x,ctx.dumpster.y];case'trash_cash':case'trash_rats':return[ctx.can.x,ctx.can.y];case'possum_reveal':return[ctx.target.x,ctx.target.y];case'ally_hit':return center(ctx.target);case'ranged_aim':return[ctx.n.x+ctx.n.w/2+8,ctx.n.y+4];case'fallen_aim':return[ctx.n.x+ctx.n.w/2,ctx.n.y+8];case'radio':return[ctx.cop.x+ctx.cop.w/2,ctx.cop.y-6];case'taser':return center(ctx.P);default:return center(ctx.n);}}
const cases=[];
for(const[recipe,source]of recipes)for(const seed of [1,7,71231,2147483646])for(const variant of recipe==='tony_coat'?[2,3]:['melee_sparks','melee_flash'].includes(recipe)?[false,true]:[null]){
 let rng=((seed%2147483646)+2147483646)%2147483646+1,draws=0;const math=Object.create(Math);math.random=()=>{rng=rng*48271%2147483647;draws++;return rng/2147483647;};
 const ctx={Math:math,particles:[],n:{x:100,y:200,w:28,h:32},target:{x:230,y:140,w:28,h:32},b:{x:60,y:80,w:30,h:36},bo:{x:400,y:500,w:48,h:36},cop:{x:500,y:300,w:28,h:32},P:{x:1050,y:840,w:24,h:28},ip:{x:170,y:230},pr:{x:760.25,y:330.5},dumpster:{x:55,y:66,w:38},can:{x:900,y:950},sparkC:variant===true?'#ffaa60':'#fff080',cc:variant===3?'#2a1010':'#4a2018'};
 vm.runInNewContext(source.statement,ctx,{timeout:1000});
 const at=origin(recipe,ctx);const expected=ctx.particles.map(p=>({x:p.x,y:p.y,vx:p.vx,vy:p.vy,life:p.life,size:p.sz,gravity:p.gravity??0,glow:p.glow??false,color:rgba(p.c)}));
 cases.push({id:`${recipe}/${seed}/${String(variant)}`,recipe,seed,source_point:at,width:ctx.dumpster.w,phase:recipe==='tony_coat'?variant:2,sings:variant===true,expected,rng_state:rng,rng_draws:draws,source:{file:source.file,line:source.line}});
}
for(const file of ['src/render/frame.js','src/systems/incidents.js','src/minigames/activities.js','src/dialogue/neighborhood_b.js','src/systems/campaigns.js'])text(file);
const data={schema:1,oracle:'unchanged source particle-emission statements with controlled cosmetic stream; not production branch acceptance',sourceHashes:pins,recipes:recipes.map(([id,s])=>({id,...s})),cases};
const generated=JSON.stringify(data,null,2)+'\n';
if(process.argv.includes('--check')) {
  if(!fs.existsSync(out)||fs.readFileSync(out,'utf8')!==generated)throw Error('Source fixture drift: '+out);
} else { fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,generated); }
console.log(`WORLD FEEDBACK RECIPE ORACLE: PASS (${recipes.length} recipes; ${cases.length} cases; ${cases.reduce((n,c)=>n+c.expected.length,0)} source particles; original source unchanged)`);
