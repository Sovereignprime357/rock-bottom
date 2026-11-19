import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=fs.readFileSync(path.join(root,'game3d/tests/fixtures/district_grade_reference.json'),'utf8');
const fixture=JSON.parse(source),unique=[...new Map(fixture.grades.map(g=>[JSON.stringify(g.expected),g])).values()];
const patches=fixture.blends.filter(b=>b.id.startsWith(fixture.grades[0].id+'/')).map(b=>b.background.map(v=>Math.round(v*255)));
const data={fixtureSha256:crypto.createHash('sha256').update(source).digest('hex'),grades:unique,patches};
const html=`<!doctype html><meta charset="utf-8"><title>District grade Canvas raster reference</title>
<style>body{background:#222;color:#eee;font:15px monospace}canvas{image-rendering:pixelated}pre{white-space:pre-wrap;word-break:break-all}</style>
<h1>Original Canvas blend operations</h1><p>Six recipes × fifteen opaque byte-color patches. Actual Canvas pixels appear below.</p><canvas id="patches" width="600" height="240"></canvas><pre id="result">Rendering…</pre>
<script>
const fixture=${JSON.stringify(data)};
const canvas=document.getElementById('patches'),ctx=canvas.getContext('2d',{alpha:false,colorSpace:'srgb'}),rows=[];
fixture.grades.forEach((grade,row)=>{
 const pixels=[];
 fixture.patches.forEach((rgb,col)=>{
  const x=col*40,y=row*40;
  ctx.globalCompositeOperation='source-over';ctx.globalAlpha=1;ctx.fillStyle='rgb('+rgb.join(',')+')';ctx.fillRect(x,y,40,40);
  for(const op of grade.operations){ctx.globalCompositeOperation=op.operation;ctx.globalAlpha=op.alpha;ctx.fillStyle='rgb('+op.rgb.map(v=>Math.round(v*255)).join(',')+')';ctx.fillRect(x,y,40,40);}
  pixels.push(Array.from(ctx.getImageData(x+20,y+20,1,1).data).slice(0,3));
 });
 rows.push({id:grade.id,pixels});
});
document.getElementById('result').textContent=JSON.stringify({schema:1,authority:'Actual opaque sRGB Canvas2D raster of unchanged source drawAmbientGrade operations',fixtureSha256:fixture.fixtureSha256,userAgent:navigator.userAgent,attributes:ctx.getContextAttributes(),patches:fixture.patches,rows});
</script>`;
const output=path.join(root,'.build/3d/full/web/district-grade-raster.html');
fs.writeFileSync(output,html);
console.log('DISTRICT GRADE RASTER PAGE: '+output);
