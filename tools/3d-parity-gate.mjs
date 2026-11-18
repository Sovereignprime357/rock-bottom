import fs from 'node:fs';
import path from 'node:path';

const root=path.resolve(import.meta.dirname,'..');
const content=JSON.parse(fs.readFileSync(path.join(root,'game3d/data/source_content.json'),'utf8'));
const audit=fs.readFileSync(path.join(root,'reports/3d-full-port-system-inventory.md'),'utf8');
const matrix=audit.split('## Functional parity matrix')[1].split('## ')[0];
const rows=matrix.split(/\r?\n/).filter(line=>line.startsWith('| ')&&!line.startsWith('| System ')&&!line.startsWith('| ---'));
const features=rows.map(line=>{const cells=line.split('|').slice(1,-1).map(s=>s.trim());return {id:cells[0].toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/_$/,''),name:cells[0],source:cells[1],acceptance:cells[3]};});
const functions=content.omissions.filter(entry=>entry.reason==='function').map(entry=>({id:entry.path,name:entry.name||'(anonymous)'}));
const file=path.join(root,'game3d/data/parity_manifest.json');
let ledger=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{schema:1,baseline:'c9d61d2ce25d60737af2140206999d1242b260fa',features:[],handlers:[]};
if(process.argv.includes('--refresh')){
  const merge=(source,prior)=>source.map(item=>({...item,status:'planned',implementation:[],tests:[],integration:[],nativeEvidence:[],webEvidence:[],...prior.find(x=>x.id===item.id)}));
  ledger.features=merge(features,ledger.features);ledger.handlers=merge(functions,ledger.handlers);
  ledger.corpusSha256=content.source.corpusSha256;
  fs.writeFileSync(file,JSON.stringify(ledger,null,2)+'\n');
}
const errors=[];let checks=0;
function check(ok,message){checks++;if(!ok)errors.push(message);}
check(ledger.schema===1,'Unknown parity schema');
check(ledger.corpusSha256===content.source.corpusSha256,'Parity content hash drift');
const statuses=new Set(['planned','partial','model_checked','integrated','verified']);
for(const [kind,expected]of [['features',features],['handlers',functions]]){
  const actual=ledger[kind];const ids=new Set();
  check(Array.isArray(actual)&&actual.length===expected.length,`${kind} count drift`);
  for(const row of actual||[]){
    check(!ids.has(row.id),`Duplicate ${kind} ${row.id}`);ids.add(row.id);
    check(expected.some(x=>x.id===row.id),`Unknown ${kind} ${row.id}`);
    check(statuses.has(row.status),`Invalid status ${row.id}`);
    for(const key of ['implementation','tests','integration','nativeEvidence','webEvidence']){
      check(Array.isArray(row[key]),`Missing reference list ${row.id}/${key}`);
      for(const ref of row[key]||[]){
        const filename=ref.split('#')[0];
        const resolved=path.resolve(root,filename);
        check(resolved.startsWith(root+path.sep)&&fs.existsSync(resolved),`Missing/escaping reference ${row.id}/${ref}`);
      }
    }
    if(['model_checked','integrated','verified'].includes(row.status))check(row.implementation.length>0&&row.tests.length>0,`Unsupported checked status ${row.id}`);
    if(['integrated','verified'].includes(row.status))check(row.integration.length>0,`Missing live integration ${row.id}`);
    if(row.status==='verified')check(row.nativeEvidence.length>0&&row.webEvidence.length>0,`Missing platform evidence ${row.id}`);
    if(process.argv.includes('--complete'))check(row.status==='verified',`Incomplete ${row.id}`);
  }
  for(const item of expected)check(ids.has(item.id),`Missing ${kind} ${item.id}`);
}
if(errors.length){console.error(errors.join('\n'));process.exit(1);}
const completed=ledger.features.filter(x=>x.status==='verified').length;
console.log(`3D PARITY COVERAGE: PASS (${checks} checks; ${features.length} features, ${functions.length} explicit function obligations; ${completed}/${features.length} verified, full port ${completed===features.length?'ready for final audit':'INCOMPLETE'})`);
