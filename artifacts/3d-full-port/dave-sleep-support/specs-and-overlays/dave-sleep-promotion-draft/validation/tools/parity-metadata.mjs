import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {isDeepStrictEqual as equal} from 'node:util';
import {fileURLToPath} from 'node:url';
import {proveAlias,proveEmptyInitializer} from './parity-source-proof.mjs';

export const DIR = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(DIR,'..');
export const INPUT = {
  ledger:'reports/3d-parity-metadata/baseline-manifest.json', content:'game3d/data/source_content.json',
  inventory:'reports/3d-full-port-system-inventory.md',
  dispositions:'reports/3d-parity-metadata/handler-dispositions.json',
  evidence:'reports/3d-parity-metadata/evidence-index.json',
  proposal:'reports/3d-parity-metadata/PROPOSAL.md',
  decision:'SPEC-3D-PARITY-METADATA.md',
};
export const TARGETS = ['windows_first_person','web_keyboard_mouse'];
export const LIVE_MANIFEST='game3d/data/parity_manifest.json';
export const CONTRACT_REPORT='.build/3d/gates/parity-metadata-contract.json';
export const PIN_REVISIONS=Object.freeze({'metadata-v1':'reports/3d-parity-metadata/input-pins-metadata-v1.json','metadata-v2':'reports/3d-parity-metadata/input-pins-metadata-v2.json','metadata-v3':'reports/3d-parity-metadata/input-pins-metadata-v3.json'});
export function selectedPins(args=process.argv.slice(2),reader=read) {
  const flags=args.filter(arg=>arg.startsWith('--pins='));
  if(flags.length!==1)throw Error('Exactly one explicit --pins=<named revision> selection is required.');
  const name=flags[0].slice(7);
  if(!Object.hasOwn(PIN_REVISIONS,name))throw Error('Unknown input-pin revision; no default or automatic refresh.');
  return {name,path:PIN_REVISIONS[name],value:JSON.parse(reader(PIN_REVISIONS[name]).toString('utf8'))};
}
export const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
export const jsonBytes = value => Buffer.from(JSON.stringify(value));
export function workspacePath(ref) {
  if (typeof ref !== 'string' || !ref || ref.includes('\\') || path.isAbsolute(ref) || ref.split('/').some(p=>p==='..'||p==='.'||!p)) throw Error(`Unsafe workspace reference: ${ref}`);
  const resolved=path.resolve(ROOT,ref);
  if (!resolved.startsWith(ROOT+path.sep)) throw Error(`Escaping workspace reference: ${ref}`);
  const real=fs.realpathSync(resolved);
  if (!real.startsWith(fs.realpathSync(ROOT)+path.sep) || !fs.statSync(real).isFile()) throw Error(`Nonfile or escaping real path: ${ref}`);
  return real;
}
export const read = ref => fs.readFileSync(workspacePath(ref));
export const load = (ref,reader=read) => JSON.parse(reader(ref).toString('utf8').replace(/^\uFEFF/,''));
export function readInputs(reader=read) {
  return Object.fromEntries(Object.entries(INPUT).map(([k,p])=>[k,['inventory','proposal','decision'].includes(k)?reader(p).toString('utf8'):load(p,reader)]));
}
export function sourceIdentity(id) {
  const match=/^definitions\[("(?:[^"\\]|\\.)*")\]\[("(?:[^"\\]|\\.)*")\]$/.exec(id);
  if (!match) throw Error(`Not a module export ID: ${id}`);
  return {module:JSON.parse(match[1]),symbol:JSON.parse(match[2])};
}
export const aliasProof=proveAlias;
export const emptyInitializer=proveEmptyInitializer;
export function aliasCycles(edges) {
  const errors=[];
  for (const start of edges.keys()) { const seen=new Set(); let current=start;
    while(edges.has(current)) { if(seen.has(current)){errors.push(start);break;} seen.add(current);current=edges.get(current); }
  }
  return errors;
}
export function selectJson(object,selector) {
  const parts=selector.split('.'); let values=[object];
  for(const part of parts) {
    const m=/^([A-Za-z_]\w*)(?:\[(\*|\d+|id=[\w-]+)\])?$/.exec(part);
    if(!m) throw Error(`Unsupported selector: ${selector}`);
    const next=[];
    for(const value of values) {
      if(value===null || typeof value!=='object' || !Object.hasOwn(value,m[1])) throw Error(`Missing selector: ${selector}`);
      const field=value[m[1]];
      if(!m[2]) next.push(field);
      else {
        if(!Array.isArray(field)) throw Error(`Selector requires array: ${selector}`);
        if(m[2]==='*') { if(!field.length) throw Error(`Vacuous wildcard: ${selector}`); next.push(...field); }
        else if(m[2].startsWith('id=')) { const found=field.filter(x=>x?.id===m[2].slice(3));if(found.length!==1)throw Error(`Nonunique selector: ${selector}`);next.push(found[0]); }
        else { const index=Number(m[2]);if(index>=field.length)throw Error(`Missing index: ${selector}`);next.push(field[index]); }
      }
    }
    values=next;
  }
  return values;
}
export function sectionText(text,heading) {
  if(heading==='@opening') return text.split(/^## /m)[0];
  const lines=text.split(/\r?\n/); const at=lines.findIndex(line=>line===`## ${heading}`);
  if(at<0) throw Error(`Missing exact report section: ${heading}`);
  let end=at+1;while(end<lines.length&&!/^#{1,2} /.test(lines[end]))end++;
  return lines.slice(at,end).join('\n');
}
function sectionNames(ref) {
  if(ref.sections) return ref.sections;
  if(!ref.section) throw Error(`Unqualified report: ${ref.path}`);
  return ref.section.split(';').map(s=>s.trim().split(':')[0]).map(s=>s==='Opening checkpoint scope'?'@opening':s);
}
function markerNames(ref) {
  if(ref.path.endsWith('test_cart_view.log')) return ['3D CART VIEW GATE: PASS'];
  if(ref.path.endsWith('/build.log')) return ['3D BUILD: PASS (Full / All;'];
  if(!ref.section) throw Error(`Unqualified log: ${ref.path}`);
  return ref.section.split(';').map(s=>s.trim());
}
function summary(value) {
  if(value===null||typeof value!=='object') return value;
  return Array.isArray(value)?{arrayLength:value.length}:{keys:Object.keys(value)};
}
const OUTCOME_KEYS=['acceptance','pass','input_frame_checks_pass','model_and_framebuffer_pass','sync_target_pass','visual_acceptance','failures','engine_errors','browser_errors','web','format','scope','count','fixed_measured_frames','fixed_warmup_frames','maximum_byte_error','pngs_verified'];
export function artifactWitness(ref,reader=read) {
  const bytes=reader(ref.path);if(sha(bytes)!==ref.sha256)throw Error(`Evidence bytes changed: ${ref.path}`);
  if(ref.path.endsWith('.json')) {
    const data=JSON.parse(bytes.toString('utf8'));
    const selectors=[...new Set([...(ref.fields??[]),...OUTCOME_KEYS.filter(k=>Object.hasOwn(data,k))])];
    if(!selectors.length) throw Error(`No JSON outcome witness: ${ref.path}`);
    const observations=selectors.map(selector=>{const value=selectJson(data,selector);return {selector,sha256:sha(jsonBytes(value)),values:value.map(summary)};});
    const failures=Object.fromEntries(['acceptance','pass','sync_target_pass','visual_acceptance'].filter(k=>data[k]===false).map(k=>[k,false]));
    return {kind:'json_observations',observations,explicitFalseOutcomes:failures,automaticVisualApproval:false};
  }
  if(ref.path.endsWith('.md')) return {kind:'reported_sections',observations:sectionNames(ref).map(section=>({section,sha256:sha(Buffer.from(sectionText(bytes.toString('utf8'),section)))})),automaticVisualApproval:false};
  if(ref.path.endsWith('.log')) {
    const lines=bytes.toString('utf8').split(/\r?\n/);
    const observations=markerNames(ref).map(marker=>{const hits=lines.filter(s=>s.startsWith(marker)&&s.includes('PASS'));if(!hits.length)throw Error(`Missing passing log marker: ${marker}`);return {marker,lines:hits,sha256:sha(jsonBytes(hits))};});
    return {kind:'regression_or_packaging_log',observations,automaticVisualApproval:false};
  }
  if(ref.path.endsWith('.png')) {
    if(bytes.length<24 || bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')throw Error(`Invalid PNG: ${ref.path}`);
    return {kind:'image_only_no_outcome',width:bytes.readUInt32BE(16),height:bytes.readUInt32BE(20),automaticVisualApproval:false};
  }
  throw Error(`Unsupported evidence type: ${ref.path}`);
}
function obligations(kind) {
  const mapping={
    raster_authoring_adaptation:[['identity','palette','finite_geometry','grounding','cached_geometry'],[]],
    exact_reexport_alias:[['canonical_named_obligation'],[]],
    off_camera_embodiment:[['source_progression_if_applicable','first_person_embodiment_evidence'],['unseen_chest_or_top_down_foot_art']],
    legacy_raster_helper:[['active_makeRoutePatch32_callsite','route_progression','filed_journal'],['unseen_legacy_chest_grid']],
    outside_selected_input_target:[['desktop_equivalent_commands'],['coarse_touch_joystick_buttons_gestures']],
    mixed_scope_boot_adapter:[['title_load','async_save_present_missing_refused','desktop_startup','scene_clock','isolated_qa'],['coarse_touch_setup']],
    desktop_behavior_adaptation:[['single_remember_transaction','missing_refused_save','callback_isolation'],[]],
    mixed_responsive_projection_adaptation:[['perspective_viewport','desktop_hud_1280x720','desktop_hud_960x540'],['touch_topbar_allowance']],
    proven_empty_initializer:[['source_empty_body_proof'],[]],
    aggregate_renderer:[['observable_child_union','inline_renderer_obligations','native_web_render_evidence','feedback_shake_integration','dust_mote_integration','remaining_embodiment_decisions'],[]],
  };
  if(!mapping[kind])throw Error(`Unapproved disposition class: ${kind}`);
  return {retained: mapping[kind][0], excludedSubbehavior:mapping[kind][1]};
}
export function build(inputs,reader=read) {
  const ledger=structuredClone(inputs.ledger);
  ledger.scopeMetadata={schema:1,decisionRef:INPUT.decision,targets:TARGETS,sourceManifestSha256:sha(reader(INPUT.ledger)),proposalSha256:sha(reader(INPUT.dispositions)),evidenceIndexSha256:sha(reader(INPUT.evidence)),completionPolicy:'existing_verified_status_and_platform_lists_unchanged',purpose:'orthogonal_scope_and_narrow_evidence_index_only'};
  const byId=new Map(ledger.handlers.map(row=>[row.id,row]));
  for(const row of inputs.dispositions.handlers) {
    const {module,symbol}=sourceIdentity(row.id);
    const proof={module,symbol,sha256:row.source.sha256,kind:row.classification==='exact_reexport_alias'?'exact_import_export_binding':row.classification==='proven_empty_initializer'?'empty_exported_body':'pinned_source_obligation'};
    byId.get(row.id).disposition={schema:1,kind:row.classification,decisionRef:INPUT.decision,decision:'ratified_selected_target_adaptation',targets:TARGETS,source:proof,canonicalId:row.canonical_id??null,...obligations(row.classification),sourceObligation:row.source_obligation,equivalent:row.first_person_equivalent,acceptanceBoundary:row.acceptance,completionCredit:false};
  }
  const features=new Map(ledger.features.map(row=>[row.id,row]));
  for(const feature of inputs.evidence.features) {
    const refs=[];
    for(const [list,target] of [['native_refs',TARGETS[0]],['web_refs',TARGETS[1]]]) for(const [i,ref] of feature[list].entries()) {
      refs.push({id:`${feature.id}/${target}/${i}`,target,usage:'index_only',qualification:ref.qualification,covers:ref.covers??ref.supports,artifact:structuredClone(ref),outcome:artifactWitness(ref,reader),fixtureDisclosure:{qualification:ref.qualification,authority:'pinned artifact scope/fixture fields and retained index; no earned-progression inference'},provenance:{kind:'inspected_artifact_bytes',sha256:ref.sha256,reportedRefs:inputs.evidence.reported_provenance.map(p=>({path:p.path,sha256:p.sha256})),boundary:'Reported revision/delivery claims are attributed, not independently certified by this validator.'},humanVisualReview:{asserted:false,boundary:'No automatic visual acceptance; raw false flags and separately reported review remain distinct.'},fullFeatureAcceptance:false});
    }
    features.get(feature.id).evidenceRefs=refs;
    features.get(feature.id).coverageBoundary={remainingNative:feature.remaining_native,remainingWeb:feature.remaining_web,notes:feature.notes,fullFeatureAcceptance:false};
  }
  return ledger;
}
export function inputPaths(inputs) {
  const paths=new Set(Object.values(INPUT));
  for(const p of Object.keys(inputs.content.source.hashes))paths.add(p);
  for(const group of ['features','handlers'])for(const row of inputs.ledger[group])for(const field of ['implementation','tests','integration','nativeEvidence','webEvidence'])for(const ref of row[field])paths.add(ref.split('#')[0]);
  for(const row of inputs.dispositions.handlers){paths.add(row.source.path);for(const key of ['implementation_refs','regression_refs','spec_refs','extra_source_refs'])for(const ref of row[key]??[])paths.add(ref.split('#')[0]);}
  for(const feature of inputs.evidence.features){for(const key of ['native_refs','web_refs'])for(const ref of feature[key])paths.add(ref.path);for(const ref of feature.supporting_tests??[])paths.add(ref.split('#')[0]);}
  for(const ref of inputs.evidence.reported_provenance)paths.add(ref.path);
  return [...paths].sort();
}
export function validate(ledger,inputs,pins,{reader=read,complete=false}={}) {
  let checks=0; const errors=[];const check=(ok,message)=>{checks++;if(!ok)errors.push(message);};
  for(const [file,expected] of Object.entries(pins.hashes)) {try{check(sha(reader(file))===expected,`Referenced input/source drift: ${file}`);}catch(e){check(false,String(e));}}
  check(equal(Object.keys(pins.hashes).sort(),inputPaths(inputs)),'Pin census does not cover every referenced input/source');
  for(const [file,expected] of Object.entries(inputs.content.source.hashes))check(sha(reader(file))===expected,`Exported source hash drift: ${file}`);
  const baseline=structuredClone(ledger);delete baseline.scopeMetadata;
  for(const row of baseline.handlers??[])delete row.disposition;
  for(const row of baseline.features??[]){delete row.evidenceRefs;delete row.coverageBoundary;}
  check(equal(baseline,inputs.ledger),'Existing manifest fields/statuses/reference lists changed');
  const expectedHandlers=inputs.content.omissions.filter(row=>row.reason==='function').map(row=>row.path);
  const matrix=inputs.inventory.split('## Functional parity matrix')[1]?.split('## ')[0]??'';
  const expectedFeatures=matrix.split(/\r?\n/).filter(line=>line.startsWith('| ')&&!line.startsWith('| System ')&&!line.startsWith('| ---')).map(line=>line.split('|')[1].trim().toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/_$/,''));
  for(const [kind,ids,count] of [['handlers',expectedHandlers,585],['features',expectedFeatures,32]]) {
    const rows=ledger[kind]??[];check(rows.length===count&&new Set(rows.map(r=>r.id)).size===count,`Exact unique ${count} ${kind}`);
    check(equal(rows.map(r=>r.id).sort(),[...ids].sort()),`${kind} actual source census drift`);
    for(const row of rows){check(['planned','partial','model_checked','integrated','verified'].includes(row.status),`Unknown terminal status: ${row.id}`);if(complete)check(row.status==='verified'&&row.nativeEvidence.length>0&&row.webEvidence.length>0,`Incomplete ${row.id}`);}
  }
  const scoped=(ledger.handlers??[]).filter(r=>r.disposition);check(scoped.length===30,'Exactly30 approved dispositions');
  const edges=new Map(); let aliasCount=0;
  for(const row of scoped) {
    const d=row.disposition;
    try {
      const canonical=d.canonicalId?sourceIdentity(d.canonicalId):null;
      const own=sourceIdentity(row.id);const source=reader(own.module).toString('utf8');
      check(d.source.module===own.module&&d.source.symbol===own.symbol&&sha(reader(own.module))===d.source.sha256,`Disposition source identity/hash: ${row.id}`);
      check(equal(d.targets,TARGETS)&&d.decisionRef===INPUT.decision&&!d.completionCredit,`Scoped decision cannot discharge status: ${row.id}`);
      check(equal({retained:d.retained,excludedSubbehavior:d.excludedSubbehavior},obligations(d.kind)),`Retained/excluded subbehaviors changed: ${row.id}`);
      if(d.kind==='exact_reexport_alias') {
        aliasCount++;edges.set(row.id,d.canonicalId);
        check(own.module==='src/render/sprites.js'&&canonical?.module==='src/render/sprite_toolkit.js'&&canonical.symbol===own.symbol&&aliasProof(source,reader(canonical.module).toString('utf8'),own.symbol),`Exact source reexport proof: ${row.id}`);
      } else check(d.canonicalId===null,`Nonalias has canonical edge: ${row.id}`);
      if(d.kind==='proven_empty_initializer')check(own.module==='src/render/frame.js'&&own.symbol==='init_frame'&&emptyInitializer(source,own.symbol),`Source initializer is not empty: ${row.id}`);
    }catch(e){check(false,`Disposition proof failed ${row.id}: ${e.message}`);}
  }
  check(aliasCount===9&&aliasCycles(edges).length===0,'Exactly9 cycle-free canonical aliases');
  let expected;
  try {expected=build(inputs,reader);}catch(e){check(false,`Evidence/source materialization: ${e.message}`);}
  if(expected) {
    check(equal(ledger.scopeMetadata,expected.scopeMetadata),'Scope metadata drift');
    for(const row of scoped)check(equal(row.disposition,expected.handlers.find(r=>r.id===row.id)?.disposition),`Disposition differs from exact ratification: ${row.id}`);
    let refs=0;
    for(const row of ledger.features??[]) {
      const wanted=expected.features.find(r=>r.id===row.id);refs+=(row.evidenceRefs??[]).length;
      check(equal(row.coverageBoundary,wanted?.coverageBoundary),`Remaining coverage erased: ${row.id}`);
      check(equal(row.evidenceRefs,wanted?.evidenceRefs),`Evidence target/qualification/outcome/coverage mismatch: ${row.id}`);
      for(const ref of row.evidenceRefs??[]) {
        check(ref.usage==='index_only'&&ref.fullFeatureAcceptance===false&&ref.humanVisualReview?.asserted===false,`Index cannot fabricate full-feature or human acceptance: ${ref.id}`);
        if(ref.artifact?.path?.endsWith('.json'))try {
          const raw=load(ref.artifact.path,reader);
          check(ref.target===TARGETS[1]?raw.web===true:raw.web!==true,`Actual JSON platform differs from evidence slot: ${ref.id}`);
          for(const key of ['acceptance','pass','sync_target_pass','visual_acceptance'])if(raw[key]===false)check(ref.outcome?.explicitFalseOutcomes?.[key]===false,`Failed outcome concealed: ${ref.id}/${key}`);
        }catch(e){check(false,`Evidence platform/outcome proof: ${e.message}`);}
      }
    }
    check(refs===96,'Exactly96 narrow original references, not96 full-feature passes');
  }
  return {ok:errors.length===0,checks,errors,completeRequested:complete,completion:false};
}
