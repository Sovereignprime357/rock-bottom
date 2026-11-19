"""Stage a fresh successor through the held helper; never invokes an engine."""
from pathlib import Path
import argparse,hashlib,importlib.util,json
H=Path(__file__).resolve().parent;R=H.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--run',required=True);p.add_argument('--mode',choices=['Focused','Web'],required=True);a=p.parse_args()
 pins=json.loads((H/'MANIFEST.json').read_text())
 for ref,digest in pins['old'].items():assert sha((R/ref).read_bytes())==digest,ref
 for ref,digest in pins['candidate'].items():assert sha((H/'candidate'/ref).read_bytes())==digest,ref
 for ref,digest in pins['failedWebV1'].items():assert sha((R/ref).read_bytes())==digest,'Retained failure changed'
 wrapper=(H/'ground-wrapper/dave_walkthrough_probe.gd').read_bytes();assert sha(wrapper)==pins['groundWrapper']
 helper=R/'.build/3d/dave-sleep-validation-draft/stage.py'
 spec=importlib.util.spec_from_file_location('held_dave_stage',helper);base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
 run=base.stage(a.run,a.mode);path=run/'staging.json';report=json.loads(path.read_text());project=run/'game3d'
 original_stage_hash=sha(path.read_bytes());changes=[]
 for ref,digest in pins['candidate'].items():
  rel=ref.removeprefix('game3d/');data=wrapper if a.mode=='Web' and rel=='tests/dave_walkthrough_probe.gd' else (H/'candidate'/ref).read_bytes()
  destination=project/rel;old=destination.read_bytes();destination.write_bytes(data)
  report['prepared_source'][rel]=sha(data);report['overlays'][rel]={'old':pins['old'][ref],'new':sha(data)}
  changes.append({'path':rel,'previousStageSha256':sha(old),'newSha256':sha(data)})
 if a.mode=='Focused':report['commands']=[r for r in report['commands'] if r['name'] in ['import','test_dave_walkthrough_contract']]
 report['driver_successor']={'manifest_sha256':sha((H/'MANIFEST.json').read_bytes()),'base_staging_sha256':original_stage_hash,'changes':changes,'scope':'ordinary post-Leave local movement only; no prior art gates rerun'}
 path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n');base.verify(run)
 print('DAVE RESUME SUCCESSOR STAGED:',path,'; commands only, no engine run')
if __name__=='__main__':main()
