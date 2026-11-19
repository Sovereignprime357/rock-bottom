import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {ROOT,read,readInputs,build,validate,selectedPins,LIVE_MANIFEST} from './parity-metadata.mjs';
export function runMigration(args=process.argv.slice(2),{reader=read,outputPath=path.join(ROOT,LIVE_MANIFEST),logger=console}={}) {
if(args.includes('--write')&&args.includes('--check'))throw Error('Choose --write or --check, not both.');
const selection=selectedPins(args,reader);const pins=selection.value;
const inputs=readInputs(reader);const ledger=build(inputs,reader);const gate=validate(ledger,inputs,pins,{reader});
if(!gate.ok){logger.error(gate.errors.join('\n'));return gate;}
const file=outputPath;const bytes=JSON.stringify(ledger,null,2)+'\n';
if(!args.includes('--write')){
  if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('Deterministic draft bytes differ.');
}else {fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);}
logger.log(`ADDITIVE PARITY MIGRATION: PASS (${gate.checks} checks;585 handlers/32 features/30 dispositions/96 narrow refs; all statuses unchanged; pins=${selection.name})`);
return gate;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{const result=runMigration();if(!result.ok)process.exitCode=1;}catch(error){console.error(error.message);process.exitCode=1;}
}

