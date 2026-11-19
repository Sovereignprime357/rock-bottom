"""Fresh pinned staging only. Never invokes engine, export, browser or Git."""
from pathlib import Path,PurePosixPath
import argparse,hashlib,json,re,stat,zipfile

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
SOURCES={
 '.build/3d/resident-index-composition-draft/source.zip':'ede8f5bf42ed80f4227d3d1d17b69f89c30eab65722932557ed3334c26a46ee2',
 '.build/3d/resident-index-composition-draft/manifest.json':'2075ab863cbca0e2a072f39c77b0e961f51ebbe7047a6a7e922351bf3dbdf315',
 '.build/3d/dave-sleep-art-draft/MANIFEST.json':'6bd74a9df548ded1633cf83f122f4aaafc344b743042bf42f058c80ecb04224d',
 '.build/3d/dave-ground-native-v2/game3d/tests/dave_walkthrough_probe.gd':'66eb032356c1fe8a34607a537ca9645164d7cab88fe5d934e8de7a597b3dd242',
 '.build/3d/dave-ground-support-draft/tests/posed_ground_diagnostic.gd':'64cfe67a4f118f7349c4d134a3f44d393114a243659f1d217cde4f714b4ffac4',
 '.build/3d/dave-wake-acceptance-draft/dave-walkthrough-shell.html':'117d0dadead1bdc3f8b5b674386c9682235e5a50cb822d7f8144445801cadfc2',
 '.build/3d/dave-wake-acceptance-draft/dave-walkthrough-bridge.js':'2405ccd6db2ee411062d7f759d1a2efaa878a31539e113a72265f3e863665ab7',
}
TESTS=[('test_dave_sleep_support.gd','DAVE SLEEP SUPPORT: PASS'),('test_character_roster.gd','3D CHARACTER ROSTER GATE: PASS'),('test_pose_input_memo.gd','3D POSE INPUT MEMO GATE: PASS'),('test_presentation_visibility.gd','3D PRESENTATION VISIBILITY GATE: PASS'),('test_dave_walkthrough_contract.gd','DAVE WALKTHROUGH CONTRACT: PASS')]
def read(ref):
 data=(ROOT/ref).read_bytes()
 if ref in SOURCES and sha(data)!=SOURCES[ref]:raise ValueError('Pinned input changed: '+ref)
 return data
def put(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
def js(path,value):put(path,(json.dumps(value,indent=2)+'\n').encode())
def safe(ref):
 p=PurePosixPath(ref)
 if p.is_absolute() or not p.parts or '..' in p.parts or '\\' in ref or ':' in ref:raise ValueError('Unsafe path '+ref)
 return p
def verify(run):
 run=Path(run).resolve();parent=(ROOT/'.build/full-port/dave-sleep-validation').resolve()
 if not run.is_relative_to(parent):raise ValueError('Outside validation root')
 report=json.loads((run/'staging.json').read_bytes());project=run/'game3d'
 for ref,digest in report['prepared_source'].items():
  if sha((project/safe(ref)).read_bytes())!=digest:raise ValueError('Prepared source changed '+ref)
 for p in project.rglob('*'):
  if not p.is_file():continue
  ref=p.relative_to(project).as_posix()
  if ref.startswith('.godot/') or ref in report['prepared_source']:continue
  if ref not in report['allow_generated_uids'] or not re.fullmatch(rb'uid://[a-z0-9]+\s*',p.read_bytes()):raise ValueError('Unexpected file '+ref)
 return report
def stage(run_name,mode):
 if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}',run_name):raise ValueError('Invalid run name')
 for ref in SOURCES:read(ref)
 base=json.loads(read('.build/3d/resident-index-composition-draft/manifest.json'))
 art=json.loads(read('.build/3d/dave-sleep-art-draft/MANIFEST.json'))
 artroot=ROOT/'.build/3d/dave-sleep-art-draft'
 overlays={}
 for row in art['overlays']:
  data=(artroot/row['candidate']).read_bytes()
  if sha(data)!=row['sha256']:raise ValueError('Held overlay changed')
  target=str(safe(row['target']));rel=target.removeprefix('game3d/')
  if rel==target:raise ValueError('Overlay must target game3d')
  if row['baseSha256']!=base['source'].get(rel):raise ValueError('Overlay base mismatch '+rel)
  if mode=='Focused' or row['kind']=='production_owner':overlays[rel]=data
 if len(overlays)!=(3 if mode=='Focused' else 1):raise ValueError('Unexpected art overlay count')
 archive=ROOT/'.build/3d/resident-index-composition-draft/source.zip'
 content={}
 with zipfile.ZipFile(archive) as z:
  for entry in z.infolist():
   ref=str(safe(entry.filename))
   if entry.is_dir() or stat.S_ISLNK(entry.external_attr>>16):raise ValueError('Unexpected archive entry')
   if not ref.startswith('game3d/'):raise ValueError('Archive root')
   rel=ref[7:]
   if rel in content:raise ValueError('Duplicate archive entry')
   content[rel]=z.read(entry)
 if len(content)!=495 or {k:sha(v) for k,v in content.items()}!=base['source']:raise ValueError('Archive exact inventory mismatch')
 engine=ROOT/'.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'
 runtime=engine.with_name('Godot_v4.5.1-stable_win64.exe');template=ROOT/'.tools/templates/web_nothreads_release.zip'
 for path,key in [(engine,'engine_launcher_sha256'),(runtime,'engine_runtime_sha256'),(template,'web_template_sha256')]:
  if sha(path.read_bytes())!=base[key]:raise ValueError('Engine/template mismatch')
 allow=['tests/test_dave_sleep_support.gd.uid','tests/reference_actor_animation_sleep_original.gd.uid'] if mode=='Focused' else ['tests/posed_ground_diagnostic.gd.uid']
 sidecars={}
 if mode!='Focused':
  wrapper=read('.build/3d/dave-ground-native-v2/game3d/tests/dave_walkthrough_probe.gd')
  line=b'\trow["posed_ground"] = preload("res://tests/posed_ground_diagnostic.gd").measure(game.actors.dave.get_node("Art"))\n'
  # Retained original wrapper is LF, and the archive uses the same LF source.
  if wrapper.count(line)!=1 or wrapper.replace(line,b'',1)!=content['tests/dave_walkthrough_probe.gd']:raise ValueError('Ground wrapper is not exact passive-only adjunct')
  overlays['tests/dave_walkthrough_probe.gd']=wrapper
  overlays['tests/posed_ground_diagnostic.gd']=read('.build/3d/dave-ground-support-draft/tests/posed_ground_diagnostic.gd')
 if mode=='Web':
  for name in ['dave-walkthrough-shell.html','dave-walkthrough-bridge.js']:
   overlays[name]=read('.build/3d/dave-wake-acceptance-draft/'+name)
  preset='''[preset.0]
name="Web Dave Sleep"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="data/*.json,tests/*.gd"
exclude_filter="tests/fixtures/*,tools/*"
[preset.0.options]
custom_template/release="%s"
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
html/canvas_resize_policy=0
html/custom_html_shell="res://dave-walkthrough-shell.html"
progressive_web_app/enabled=false
'''%template.as_posix()
  overlays['export_presets.cfg']=preset.encode()
  sidecars={'dave-walkthrough-bridge.js':overlays['dave-walkthrough-bridge.js'],'storage.js':content['web/storage.js']}
 parent=ROOT/'.build/full-port/dave-sleep-validation';run=parent/run_name
 if run.exists():raise FileExistsError('Fresh run directory required')
 run.mkdir(parents=True);project=run/'game3d'
 before={k:sha(v) for k,v in content.items()};content.update(overlays)
 for ref,data in content.items():put(project/safe(ref),data)
 for ref,data in sidecars.items():put(run/'web'/safe(ref),data)
 commands=[{'name':'import','executable':str(engine),'arguments':['--headless','--path',str(project),'--editor','--import','--quit'],'pass_marker':None}]
 if mode=='Focused':
  for name,marker in TESTS:commands.append({'name':name[:-3],'executable':str(engine),'arguments':['--headless','--path',str(project),'--script',str(project/'tests'/name)],'pass_marker':marker})
 elif mode=='Native':commands.append({'name':'native','executable':str(engine),'arguments':['--path',str(project),'--script',str(project/'tests/dave_walkthrough_probe.gd'),'--','--qa-full','--output='+str(run/'evidence')],'pass_marker':'DAVE WALKTHROUGH: PASS'})
 else:commands.append({'name':'web_export','executable':str(engine),'arguments':['--headless','--path',str(project),'--export-release','Web Dave Sleep',str(run/'web/index.html')],'pass_marker':None})
 report={'schema':1,'format':'dave-sleep-validation-stage','mode':mode,'status':'staged_only','source_kind':'exact 495-file resident archive, not inferred latest Git HEAD','source_archive_sha256':SOURCES['.build/3d/resident-index-composition-draft/source.zip'],'inputs':SOURCES,'engine_sha256':base['engine_launcher_sha256'],'runtime_sha256':base['engine_runtime_sha256'],'template_sha256':base['web_template_sha256'],'project':str(project),'prepared_source':{k:sha(v) for k,v in content.items()},'overlays':{k:{'old':before.get(k),'new':sha(v)} for k,v in overlays.items()},'allow_generated_uids':allow,'web_sidecars':{k:sha(v) for k,v in sidecars.items()},'commands':commands,'engine_run':False,'native_acceptance':False,'web_acceptance':False,'performance_acceptance':False}
 js(run/'staging.json',report);verify(run)
 print(str(run/'staging.json'));return run
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--run');p.add_argument('--mode',choices=['Focused','Native','Web'],default='Focused');p.add_argument('--verify')
 a=p.parse_args()
 if a.verify:verify(a.verify);print('DAVE STAGED SOURCE: PASS')
 elif a.run:stage(a.run,a.mode)
 else:p.error('--run or --verify required')
