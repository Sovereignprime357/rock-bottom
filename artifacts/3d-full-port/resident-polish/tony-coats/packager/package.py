"""Raw-byte Tony evidence delivery. No engine, browser, Git or promotion."""
from pathlib import Path,PurePosixPath
import argparse,base64,hashlib,importlib.util,json,re,stat
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
DEST='artifacts/3d-full-port/resident-polish/tony-coats'
CAP=22_000_000
PARENT='bdb6902a34830b79067e5e42dde21592ab596f3db5b46572be466f04710eb006'
WEB_IMAGES={'tony_front_peak_strike_2m.png','tony_coats_2.png','tony_coats_1.png','tony_quarter_late_walk_coats_2.png','tony_quarter_windup_2m.png'}
OLD_IMAGES={'tony_front_peak_strike_2m.png','tony_coats_1.png'}
OLD_ART='9cc532faae1bce276c0dd7843e98c65795b52f7e58c10a6976ca854c1afddd2c'
ART='b8b4b58bd9b5cb8493b0bf56683cb01271df7ed97691c0f70c855d27b0bef5a8'
TEST='481754d629d101df88d7861a3c0a095530c0001af8f680e315fd1ac198bfbb1a'
CORE=[('v1-failed','tony-coat-central-v1',''),('v2-diagnostic-failed','tony-coat-central-v2-diagnostic',''),
 ('v3-shell-pass','tony-coat-central-v3-fit',''),('v4-surfaces-failed','tony-coat-central-v4-surfaces','validation-v1'),
 ('v5-diagnostic-failed','tony-coat-central-v5-diagnostic','validation-v1'),('v6-surfaces-pass','tony-coat-central-v6-corrected','validation-v1')]
DRAFTS=['tony-coat-fit-draft','tony-coat-fit-diagnostic-draft','tony-coat-fit-refinement-draft',
 'tony-coat-surfaces-next-draft','tony-coat-surfaces-diagnostic-draft','tony-coat-surfaces-corrected-draft',
 'tony-coat-surfaces-central-draft','tony-coat-visual-draft','tony-coat-surfaces-visual-draft']
VISUAL=[('old-native','tony-coat-visual','native-v1',OLD_ART),('old-web','tony-coat-visual','web-v1',OLD_ART),
 ('new-native','tony-coat-surfaces-visual','native-v1',ART),('new-web','tony-coat-surfaces-visual','web-v1',ART)]
sha=lambda payload:hashlib.sha256(payload).hexdigest()
load=lambda path:json.loads(path.read_bytes())
def require(ok,message):
    if not ok:raise ValueError(message)
def safe(base,value):
    require(isinstance(value,str) and value and '\\' not in value and ':' not in value,'unsafe relative path')
    p=PurePosixPath(value);require(not p.is_absolute() and '..' not in p.parts,'unsafe relative path')
    target=base.joinpath(*p.parts);require(target.resolve().is_relative_to(base.resolve()),'escaped root')
    for cursor in [target,*target.parents]:
        if cursor.exists():
            require(not cursor.is_symlink() and not(getattr(cursor.lstat(),'st_file_attributes',0)&stat.FILE_ATTRIBUTE_REPARSE_POINT),'reparse path')
        if cursor==base:break
    return target
def module(path,label):
    spec=importlib.util.spec_from_file_location(label,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
def labels():
    return ['tony_'+a+'_'+s+'_2m' for s in ['rest','walk','peak_strike','windup'] for a in ['front','quarter']]+['tony_front_rest_20m']+['tony_coats_'+str(c) for c in [3,2,1,0]]+['tony_'+a+'_late_walk_coats_'+str(c) for c in [3,2] for a in ['front','quarter']]
def required():
    paths=[]
    for _,folder,sub in CORE:
        base=ROOT/'.build/3d'/folder
        paths.append(base/sub/('validation-result.json' if sub else 'fit.result.json'))
    for _,packet,run,_ in VISUAL:
        base=ROOT/'.build/full-port'/packet/run
        paths.extend([base/'staging.json',base/'validation-result.json'])
        evidence=base/('browser-evidence' if run.startswith('web') else 'evidence')
        paths.append(evidence/('original-bundle.json' if run.startswith('web') else 'tony-coat.json'))
        paths.extend(evidence/(name+'.png') for name in labels())
    return paths
def audit():
    require(sha((ROOT/'.build/3d/tony-coat-evidence-draft/package.py').read_bytes())==PARENT,'unexecuted predecessor helper pin')
    missing=[p.relative_to(ROOT).as_posix() for p in required() if not p.is_file()]
    require(not missing,'pending inputs: '+', '.join(missing))
    core=[]
    for label,folder,sub in CORE:
        base=ROOT/'.build/3d'/folder/sub
        result=load(base/('validation-result.json' if sub else 'fit.result.json'))
        expected='failed' if 'failed' in label else 'pass'
        require(result['status']==expected,label+' retained outcome')
        if sub:
            stages=result['stages'];focused=next(row for row in stages if row['name']=='surfaces')
            require(focused['exit_code']==(1 if expected=='failed' else 0),label+' actual exit')
            lines=(base/'surfaces.stdout.log').read_text(encoding='utf-8').splitlines()
            d=json.loads(next(line.split(': ',1)[1] for line in lines if line.startswith('TONY COAT SURFACES DIAGNOSTIC: ')))
            require([d[x] for x in ['inherited_groups','surface_groups','shell_pose_cases','surface_pose_cases','other_identities']]==[4,2,48,48,71],label+' complete tails')
            require(bool(d['failures'])==(expected=='failed'),label+' actual failed assertions')
            if expected=='pass':
                require(d['checks']==1368 and len(stages)==4 and all(row['status']=='pass' and row['exit_code']==0 for row in stages),'corrected full gate')
                require(all(d[key]>=.001 for key in ['shell_inner_minimum_m','shell_outer_minimum_m','skin_minimum_m','layer_minimum_m']) and d['missing_cloth']==0,'actual1mm gates')
                for name,marker in [('roster','PASS (2040 checks;'),('art','PASS (196 checks;')]:require(marker in (base/(name+'.stdout.log')).read_text(),name+' gate')
            core.append({'run':label,'status':expected,'checks':d['checks'],'failures':d['failures'],'diagnostic':d})
        else:
            require(result['exit_code']==(1 if expected=='failed' else 0),label+' actual exit')
            core.append({'run':label,'status':expected,'result':result})
    reports=[]
    for label,packet,run,art in VISUAL:
        base=ROOT/'.build/full-port'/packet/run;web=run.startswith('web')
        helperdir=ROOT/'.build/3d'/('tony-coat-visual-draft' if label.startswith('old') else 'tony-coat-surfaces-visual-draft')
        helper=module(helperdir/'prepare.py',label.replace('-','_'))
        helper.check(base)
        stage=load(base/'staging.json');result=load(base/'validation-result.json')
        require(stage['prepared_source']['game3d/scripts/character_art.gd']==art,label+' Art pin')
        require(result['status']=='pass' and all(row['exit_code']==0 for row in result['engine_stages']),label+' complete engine stages')
        evidence=base/('browser-evidence' if web else 'evidence')
        if web:
            source=evidence/'original-bundle.json';bundle=load(source);helper.bundle(source)
            report=bundle['report'];frames={row['record']['file']:base64.b64decode(row['base64'],validate=True) for row in bundle['frames']}
        else:
            source=evidence/'tony-coat.json';report=load(source)
            frames={row['file']:(evidence/row['file']).read_bytes() for row in report['records']}
            helper.validate_report(report,frames)
        for name,payload in frames.items():require((evidence/name).read_bytes()==payload,label+' individual original '+name)
        reports.append({'run':label,'source_report_sha256':sha(source.read_bytes()),'art_sha256':art,'frames':{name:sha(payload) for name,payload in frames.items()},'machine_capture_pass':True,'visual_acceptance_decided_by_copier':False})
    source=load(ROOT/'.build/3d/tony-coat-visual-draft/INPUTS.json')
    archive=safe(ROOT,source['archive']);require(sha(archive.read_bytes())==source['archive_sha256'],'source499 archive pin')
    final=ROOT/'.build/3d/tony-coat-central-v6-corrected/game3d/tests/test_tony_coat_surfaces.gd'
    require(sha(final.read_bytes())==TEST,'final focused test pin')
    return {'schema':1,'core':core,'visual':reports,'original_pngs':68,'source_archive_reference':{'path':source['archive'],'sha256':source['archive_sha256'],'inventory_path':source['archive_plan'],'copied':False,'observed_source_files':499,'git_equivalence_claimed':False},'visual_acceptance_decided_by_copier':False,'full_port_or_performance_acceptance':False}
def source_rows(disposition):
    rows=[]
    def add(path,target):
        rel=path.relative_to(ROOT).as_posix();safe(ROOT,rel)
        require(path.is_file(),'missing source '+rel)
        require(path.suffix.lower() in ['.gd','.uid','.md','.json','.log','.txt','.png','.jpg','.py','.mjs','.js','.html','.ps1','.diff'],'excluded extension '+rel)
        payload=path.read_bytes();rows.append({'source':rel,'destination':target,'bytes':len(payload),'sha256':sha(payload)})
    for label,folder,sub in CORE:
        base=ROOT/'.build/3d'/folder
        for path in sorted(base.iterdir()):
            if path.is_file() and path.suffix in ['.json','.log']:add(path,'central/'+label+'/'+path.name)
        if sub:
            for path in sorted((base/sub).iterdir()):
                if path.is_file() and path.suffix in ['.json','.log']:add(path,'central/'+label+'/'+sub+'/'+path.name)
    for name in DRAFTS:
        base=ROOT/'.build/3d'/name
        for path in sorted(base.iterdir()):
            if path.is_file() and path.suffix.lower() in ['.md','.json','.py','.ps1','.diff','.gd','.mjs','.js','.html']:add(path,'drafts/'+name+'/'+path.name)
        candidate=base/'candidate'
        if candidate.exists():
            for path in sorted(candidate.rglob('*')):
                if path.is_file() and path.suffix=='.gd':add(path,'drafts/'+name+'/'+path.relative_to(base).as_posix())
    for label,packet,run,_ in VISUAL:
        base=ROOT/'.build/full-port'/packet/run
        for path in sorted(base.iterdir()):
            if path.is_file() and path.suffix in ['.json','.log']:add(path,'visual/'+label+'/'+path.name)
        evidence=base/('browser-evidence' if run.startswith('web') else 'evidence')
        expected={name+'.png' for name in labels()}|{'tony-coat.json','original-bundle.json','original-verification.json','browser-console.json','browser.jpg','browser.png'}
        for path in sorted(evidence.iterdir()):
            require(path.is_file() and path.name in expected,'unexpected evidence input '+str(path))
            add(path,'visual/'+label+'/'+evidence.name+'/'+path.name)
    base=ROOT/'.build/3d/tony-coat-central-v6-corrected/game3d/tests'
    add(base/'test_tony_coat_surfaces.gd.uid','final/test_tony_coat_surfaces.gd.uid')
    add(ROOT/'.build/3d/web-progression-current-staging-draft/PLAN.json','source-reference/source499-inventory.json')
    add(disposition,'VISUAL-DISPOSITION.md')
    destinations=[row['destination'].casefold() for row in rows]
    require(len(destinations)==len(set(destinations)),'duplicate destination')
    return rows
def portable(row):
    path=PurePosixPath(row['destination']);parts=path.parts;name=path.name
    if parts[0]=='visual':
        if path.suffix=='.log':return False
        if path.suffix.lower() in ['.png','.jpg']:
            return path.suffix=='.png' and ((parts[1]=='new-native' and name in {x+'.png' for x in labels()}) or (parts[1]=='new-web' and name in WEB_IMAGES) or (parts[1]=='old-native' and name in OLD_IMAGES))
        return name!='original-bundle.json'
    if parts[0]=='drafts':
        if path.suffix in ['.md','.json']:return True
        if parts[1]=='tony-coat-surfaces-next-draft' and name=='character_art.gd':return True
        if parts[1]=='tony-coat-surfaces-corrected-draft' and name=='test_tony_coat_surfaces.gd':return True
        if parts[1]=='tony-coat-fit-refinement-draft' and name=='test_tony_coat_fit.gd':return True
        return False
    return True
def derived_statuses():
    rows=[]
    for label,packet,run,_ in VISUAL:
        if not run.startswith('web'):continue
        source=ROOT/'.build/full-port'/packet/run/'browser-evidence/original-bundle.json'
        payload=source.read_bytes();bundle=json.loads(payload)
        rows.append({'kind':'DERIVED status; not original browser bytes','source':source.relative_to(ROOT).as_posix(),'source_bytes':len(payload),'source_sha256':sha(payload),'omitted':'frames array containing base64 PNG payloads; all original record hashes remain in report.records','run':label,'status_without_frames':{key:value for key,value in bundle.items() if key!='frames'}})
    return {'schema':1,'derived':True,'original_bundles_copied':False,'records':rows}
def verify():
    manifest=load(HERE/'MANIFEST.json')
    for name,digest in manifest['files'].items():require(sha(safe(HERE,name).read_bytes())==digest,'packager changed '+name)
    allow=load(HERE/'allowlist.json');require(allow['destination']==DEST,'fixed destination')
    raw=load(HERE/'RAW-LOCATORS.json')['files'];require(len(raw)==299,'complete299 raw locators')
    for row in raw:
        payload=safe(ROOT,row['source']).read_bytes();require(len(payload)==row['bytes'] and sha(payload)==row['sha256'],'changed evidence '+row['source'])
    require(allow['files']==[row for row in raw if row['portable']],'exact compact selection')
    require(sum(row['destination'].endswith('.png') for row in allow['files'])==24,'exact24 portable original PNGs')
    actual=audit();require(actual==load(HERE/'AUDIT.json'),'audit changed after sealing')
    require(derived_statuses()==load(HERE/'DERIVED-WEB-STATUS.json'),'derived Web status changed')
    return allow,actual
def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['plan','seal','verify','copy']);p.add_argument('--write',action='store_true');p.add_argument('--disposition');a=p.parse_args()
    require(a.write==(a.command in ['seal','copy']),'explicit --write only for seal/copy')
    if a.command=='plan':
        missing=[p.relative_to(ROOT).as_posix() for p in required() if not p.is_file()]
        print(json.dumps({'status':'pending' if missing else 'inputs-present','missing':missing,'write':False,'destination':DEST},indent=2));return
    if a.command=='seal':
        require(not any((HERE/name).exists() for name in ['allowlist.json','AUDIT.json','MANIFEST.json','RAW-LOCATORS.json','DERIVED-WEB-STATUS.json']),'sealed packet retained')
        require(a.disposition is not None,'root-authored disposition required')
        disposition=Path(a.disposition).resolve();require(disposition.is_relative_to(ROOT) and disposition.suffix=='.md','root disposition path')
        report=audit();raw=source_rows(disposition);require(len(raw)==299,'complete299 raw locators')
        for row in raw:row['portable']=portable(row)
        rows=[row for row in raw if row['portable']]
        require(sum(row['destination'].endswith('.png') for row in rows)==24,'exact24 portable original PNGs')
        require(sum(row['bytes'] for row in rows)<CAP,'compact evidence exceeds cap')
        for name,data in [('allowlist.json',{'schema':1,'destination':DEST,'original_pngs_copied':24,'all68_original_pngs_portable':False,'files':rows}),('AUDIT.json',report),('RAW-LOCATORS.json',{'schema':1,'raw_input_count':299,'files':raw}),('DERIVED-WEB-STATUS.json',derived_statuses())]:
            with (HERE/name).open('x',encoding='utf-8',newline='\n') as file:file.write(json.dumps(data,indent=2)+'\n')
        manifest={'schema':1,'files':{path.name:sha(path.read_bytes()) for path in sorted(HERE.iterdir()) if path.is_file()},'scope':'raw-byte packaging only'}
        with (HERE/'MANIFEST.json').open('x',encoding='utf-8',newline='\n') as file:file.write(json.dumps(manifest,indent=2)+'\n')
        print(json.dumps({'sealed_files':len(rows),'bytes_before_packager':sum(row['bytes'] for row in rows),'original_pngs_copied':24,'all_local_original_pngs_verified':68,'raw_locators':299,'manifest_sha256':sha((HERE/'MANIFEST.json').read_bytes())},indent=2));return
    allow,report=verify();rows=list(allow['files'])
    for name in sorted([*load(HERE/'MANIFEST.json')['files'],'MANIFEST.json']):
        path=safe(HERE,name)
        rows.append({'source':path.relative_to(ROOT).as_posix(),'destination':'packager/'+name,'bytes':path.stat().st_size,'sha256':sha(path.read_bytes())})
    receipt={'schema':1,'status':'raw-bytes-copied','files':rows,'source_archive_reference':report['source_archive_reference'],'original_pngs_copied':24,'all68_original_pngs_portable':False,'visual_acceptance_decided_by_copier':False}
    receipt_bytes=(json.dumps(receipt,indent=2)+'\n').encode('utf-8')
    total=sum(row['bytes'] for row in rows)+len(receipt_bytes);require(total<=CAP,'final portable package exceeds22,000,000bytes')
    if a.command=='copy':
        destination=safe(ROOT,DEST);require(not destination.exists(),'destination already exists; no overwrite')
        destination.mkdir(parents=True)
        for row in rows:
            payload=safe(ROOT,row['source']).read_bytes();require(sha(payload)==row['sha256'],'input changed during copy')
            target=safe(destination,row['destination']);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open('xb') as file:file.write(payload)
            require(sha(target.read_bytes())==row['sha256'],'copy mismatch')
        with (destination/'PACKAGE-RECEIPT.json').open('xb') as file:file.write(receipt_bytes)
    print(json.dumps({'command':a.command,'files':len(rows)+1,'bytes':total,'portable_original_pngs':24,'all_local_original_pngs_verified':68,'raw_locators':299,'destination':DEST,'no_promotion':True},indent=2))
if __name__=='__main__':
    try:main()
    except (OSError,ValueError,KeyError,TypeError,AssertionError) as error:raise SystemExit('REFUSED: '+str(error)) from error
