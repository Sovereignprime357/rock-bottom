import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {read,load,readInputs,validate,selectedPins,LIVE_MANIFEST} from './parity-metadata.mjs';
export function runGate(args=process.argv.slice(2),{reader=read,logger=console}={}) {
const selection=selectedPins(args,reader);const pins=selection.value;
const ledger=load(LIVE_MANIFEST,reader);
const result=validate(ledger,readInputs(reader),pins,{reader,complete:args.includes('--complete')});
if(!result.ok){logger.error(result.errors.join('\n'));logger.log(`ADDITIVE PARITY GATE: FAIL (${result.checks} checks;${result.errors.length} errors; complete=${result.completeRequested})`);return result;}
logger.log(`ADDITIVE PARITY GATE: PASS (${result.checks} checks; metadata only; FULL PORT INCOMPLETE; pins=${selection.name})`);
return result;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{const result=runGate();if(!result.ok)process.exitCode=1;}catch(error){console.error(error.message);process.exitCode=1;}
}

