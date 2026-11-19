"""Root's exact promotion, only after focused/native/Web approval."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[2]
packet=root/'.build/3d/dave-sleep-promotion-draft'
driver=root/'.build/3d/dave-resume-driver-draft'
sha=lambda b:hashlib.sha256(b).hexdigest()
delivery=json.loads((packet/'DELIVERY.json').read_bytes())
assert sha((packet/'DELIVERY.json').read_bytes())=='018482dd3b8086e90b42c5f609d0b6a537aae7e1cacc3865f9467731d8828d59'
web=json.loads((root/'.build/full-port/dave-sleep-validation/web-v2/browser-evidence/browser-report.json').read_bytes())
assert web['acceptance'] and web['finished'] and web['machine_checks_pass'] and web['pngs_verified'] and not web['failures'] and not web['browser_errors']
assert len(web['frames'])==3 and web['movement']['metres']>=.15
assert json.loads((root/'.build/full-port/dave-sleep-validation/focused-v1/focused-result.json').read_bytes())['engine_tests_pass']
assert json.loads((root/'.build/full-port/dave-sleep-validation/native-v1/root-run.json').read_bytes())['status']=='pass'
assert json.loads((root/'.build/full-port/dave-sleep-validation/focused-driver-v2/root-run.json').read_bytes())['status']=='pass'
rows=[]
for entry in delivery['files']:
    path=entry['path'];source=packet/'candidate'/path;raw=source.read_bytes()
    assert sha(raw)==entry['sha256']
    rows.append((path,entry['oldSha256'],raw))
dm=json.loads((driver/'MANIFEST.json').read_bytes())
for path,digest in dm['candidate'].items():
    source=driver/'candidate'/path
    if not source.exists():
        source=driver/path
    raw=source.read_bytes();assert sha(raw)==digest
    rows.append((path,dm['old'][path],raw))
for name in ('reference_actor_animation_sleep_original.gd','test_dave_sleep_support.gd'):
    source=root/'.build/full-port/dave-sleep-validation/focused-v1/game3d/tests'/(name+'.uid')
    rows.append(('game3d/tests/'+name+'.uid',None,source.read_bytes()))
assert len(rows)==13 and len({p for p,_,_ in rows})==13
for path,old,_ in rows:
    dest=root/path
    assert (sha(dest.read_bytes()) if dest.exists() else None)==old, 'Base changed: '+path
assert sha((root/'game3d/data/parity_manifest.json').read_bytes())==delivery['manifestUnchanged']
receipt=root/'.build/3d/dave-sleep-promotion.json'
assert not receipt.exists(), 'Promotion is not repeatable'
if '--check' in sys.argv:
    print('DAVE SLEEP PROMOTION PREFLIGHT: PASS 13 files; no writes')
    raise SystemExit(0)
# Publish the already-specified contracts before code.
rows.sort(key=lambda row:(not row[0].startswith('SPEC-'),row[0]))
for path,_,raw in rows:
    dest=root/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
receipt.write_text(json.dumps({'scope':'exact Dave sleep art plus bounded test-only tail and explicit metadata-v3; no parity status promotion','files':[{'path':p,'oldSha256':old,'sha256':sha(raw)} for p,old,raw in rows],'web_report_sha256':sha((root/'.build/full-port/dave-sleep-validation/web-v2/browser-evidence/browser-report.json').read_bytes())},indent=2)+'\n',encoding='utf-8')
print('DAVE SLEEP PROMOTED: 13 exact files; full gates/export/delivery pending')
