"""Prepare only pinned orchestration/artifacts. Never run engine, Git or live edits."""
from pathlib import Path
import hashlib,json,shutil,zipfile,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OLD=ROOT/'.build/3d/indexed-performance-draft'
STAGE=ROOT/'.build/3d/query-reuse-resident-v1'
ARCHIVE=ROOT/'.build/3d/resident-index-composition-draft/source.zip'
sha=lambda b:hashlib.sha256(b).hexdigest()
assert not (HERE/'pins.json').exists(),'Refuse repinning prepared packet'
oldpins=json.loads((OLD/'pins.json').read_text())
proof=json.loads((STAGE/'provenance.json').read_text())
assert sha(ARCHIVE.read_bytes())==proof['baseline_archive']=='ede8f5bf42ed80f4227d3d1d17b69f89c30eab65722932557ed3334c26a46ee2'
original=(OLD/'profile-one.ps1').read_text();assert sha((OLD/'profile-one.ps1').read_bytes())==oldpins['wrapper_sha256']
text=original;edits=[]
def replace(old,new):
 global text
 assert text.count(old)==1,(old[:100],text.count(old))
 text=text.replace(old,new);edits.append({'old':old,'new':new})
replace("[ValidateSet('baseline','indexed')]","[ValidateSet('baseline','query_resource')]")
replace("if ($relative -notin @('tests/sustained_actor_driver.gd.uid','tests/test_sustained_actor_driver.gd.uid','scripts/exact_vertex_indexer.gd.uid'))", "if ($relative -notin $allowedGeneratedUids)")
replace("$overlayNames = @('tests/full_actor_performance_probe.gd','tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd')", """$overlayNames = @('tests/full_actor_performance_probe.gd','tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd')
$allowedGeneratedUids = @('tests/sustained_actor_driver.gd.uid','tests/test_sustained_actor_driver.gd.uid')
if ($Variant -eq 'query_resource') { $allowedGeneratedUids += @('tests/fixtures/query_resource_candidate.gd.uid','tests/fixtures/query_resource_reference.gd.uid') }""")
replace("# Import may assign identity files to the two new test scripts. They are\n        # generated artifacts, recorded separately; no other source is allowed.", "# Import may assign only the named new workload/observer script UIDs.\n        # They are generated artifacts, recorded separately, never original source.")
replace("'Exact GPU source archive drift.'","'Exact resident source archive drift.'")
replace("'pinned-effects-working-source-'+$Variant","'pinned-resident-query-resource-'+$Variant")
replace("'.build/full-port/indexed-performance'","'.build/full-port/query-resource-performance'")
replace("index_overlay_sha256=$pins.index_overlay", "query_overlay_sha256=$pins.query_overlay; central_proof_sha256=$pins.central_proof; source_runtime_pins=$pins.runtime_sources")
block=original[original.index("    $indexNames = @("):original.index("    $archivedProbe =",original.index("    $indexNames = @("))]
replace(block,"""    $queryNames = @('scripts/world_adapter.gd','tests/test_world_adapter.gd','tests/test_actor_navigation.gd','tests/fixtures/query_resource_candidate.gd','tests/fixtures/query_resource_reference.gd')
    if ($pins.query_overlay.Count -ne 5 -or @($pins.query_overlay.Keys | Where-Object { $_ -notin $queryNames }).Count -ne 0) { throw 'Only five centrally tested query-resource files are allowed.' }
    foreach ($relative in $queryNames) {
        $candidatePath = Assert-Within $PSScriptRoot (Join-Path $PSScriptRoot ('query/'+$relative))
        $bytes = [IO.File]::ReadAllBytes($candidatePath)
        if ((Get-ByteSha $bytes) -ne $pins.query_overlay[$relative]) { throw "Query overlay changed: $relative" }
        if ($Variant -eq 'query_resource') {
            $destination = Assert-Within $project (Join-Path $project $relative)
            $null = New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force
            [IO.File]::WriteAllBytes($destination,$bytes)
        }
    }
""")
replace("($Variant -eq 'indexed' -and $relative -in $indexNames)","($Variant -eq 'query_resource' -and $relative -in $queryNames)")
replace("    $reportPath = Join-Path $evidence 'full-actor-performance.json'", """    $provenance.post_native_source_sha256 = Get-Inventory $project $true
    Assert-SourceUnchanged $provenance.exported_source_sha256 $provenance.post_native_source_sha256
    if ((Get-Sha $archive) -ne $pins.archive_sha256 -or (Get-Sha $archivePin) -ne $pins.archive_sha256) { throw 'Source archive changed during run.' }
    $reportPath = Join-Path $evidence 'full-actor-performance.json'""")
replace("$wrapperHash = Get-Sha $PSCommandPath", """foreach ($relative in $pins.central_proof.Keys) {
    $path = Assert-Within $repoRoot (Join-Path $repoRoot $relative)
    if ((Get-Sha $path) -ne $pins.central_proof[$relative]) { throw "Central proof input changed: $relative" }
}
$wrapperHash = Get-Sha $PSCommandPath""")
reverse=text
for edit in reversed(edits):assert reverse.count(edit['new'])==1;reverse=reverse.replace(edit['new'],edit['old'])
assert reverse==original
(HERE/'profile-one.ps1').write_text(text,newline='\n')
(HERE/'launcher-transform.json').write_text(json.dumps({'original_path':str((OLD/'profile-one.ps1').relative_to(ROOT)).replace('\\','/'),'original_sha256':oldpins['wrapper_sha256'],'normalized_original_sha256':sha(original.encode()),'edits':edits},indent=2)+'\n')

paired=(OLD/'run-paired.ps1').read_text();assert sha((OLD/'run-paired.ps1').read_bytes())==oldpins['paired_wrapper_sha256']
pair=paired;paired_edits=[]
def pair_replace(old,new):
 global pair
 assert pair.count(old)==1,(old[:80],pair.count(old))
 pair=pair.replace(old,new);paired_edits.append({'old':old,'new':new})
pair_replace("'.build/full-port/indexed-performance'","'.build/full-port/query-resource-performance'")
pair_replace("($RunName+'-indexed')","($RunName+'-query_resource')")
pair_replace("foreach($variant in @('baseline','indexed')){& (Join-Path $PSScriptRoot 'profile-one.ps1') -Variant $variant -RunName ($RunName+'-'+$variant)}", "foreach($variant in @('baseline','query_resource')){& (Join-Path $PSScriptRoot 'profile-one.ps1') -Variant $variant -RunName ($RunName+'-'+$variant)}")
block=paired[paired.index('$reports=@{};'):]
pair_replace(block,"""$helper=Join-Path $PSScriptRoot 'compare-pair.py'
if((Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pins.comparison_helper_sha256){throw 'Comparison helper changed.'}
& python $helper --run-name $RunName
if($LASTEXITCODE -ne 0){throw 'Strict diagnostic comparison refused the pair; raw run evidence retained.'}
Write-Output "QUERY RESOURCE PERFORMANCE PAIR: complete diagnostic; original failure lists retained; $summaryPath"
""")
rev=pair
for e in reversed(paired_edits):assert rev.count(e['new'])==1;rev=rev.replace(e['new'],e['old'])
assert rev==paired
(HERE/'run-paired.ps1').write_text(pair,newline='\n')
(HERE/'paired-transform.json').write_text(json.dumps({'original_path':str((OLD/'run-paired.ps1').relative_to(ROOT)).replace('\\','/'),'original_sha256':oldpins['paired_wrapper_sha256'],'normalized_original_sha256':sha(paired.encode()),'edits':paired_edits},indent=2)+'\n')

shutil.copyfile(ARCHIVE,HERE/'source.zip')
with zipfile.ZipFile(ARCHIVE) as archive:
 source={name.removeprefix('game3d/'):sha(archive.read(name)) for name in archive.namelist()}
 assert len(source)==495 and all(name.startswith('game3d/') for name in archive.namelist())
 assert 'scripts/exact_vertex_indexer.gd' not in source
 for path,expected in proof['baseline'].items():assert sha(archive.read(path))==expected
 for rel,expected in source.items():
  staged=STAGE/'game3d'/rel
  expected=proof['overlays'].get('game3d/'+rel,expected)
  assert sha(staged.read_bytes())==expected,rel
 baseline_probe=archive.read('game3d/tests/full_actor_performance_probe.gd').decode().replace('\r\n','\n')
for rel,expected in oldpins['overlay'].items():
 raw=(OLD/rel).read_bytes();assert sha(raw)==expected
 dest=HERE/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
query={}
for path,expected in proof['overlays'].items():
 raw=(STAGE/path).read_bytes();assert sha(raw)==expected
 rel=path.removeprefix('game3d/');query[rel]=expected
 dest=HERE/'query'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
probe=(HERE/'tests/full_actor_performance_probe.gd').read_text()
def measured(text):return text[text.index('class MeasuredScene:\n'):text.index('\nvar game: MeasuredScene')].rstrip()+'\n'
assert measured(probe)==measured(baseline_probe)
assert sha(measured(probe).encode())==oldpins['measured_scene_sha256']
central={}
for name,pattern in [('provenance.json',None),('import.log',None),('test_world_adapter.log','3D PHYSICS ADAPTER GATE: PASS (634 checks'),('test_actor_navigation.log','3D ACTOR NAVIGATION GATE: PASS (4759 checks')]:
 path=STAGE/name;raw=path.read_bytes()
 if pattern:assert pattern in raw.decode(errors='replace'),name
 assert not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|Parse Error):',raw.decode(errors='replace'),re.M)
 central[str(path.relative_to(ROOT)).replace('\\','/')]=sha(raw)
runtime_paths=['scripts/full_runtime.gd','scripts/full_scene.gd','scripts/actor_director.gd','scripts/combat_system.gd','scripts/actor_contact.gd','scripts/actor_navigation.gd','scripts/world_adapter.gd','scripts/character_roster.gd','scripts/cast_profiles.gd','data/source_content.json']
pins={**{k:v for k,v in oldpins.items() if k not in ['index_overlay','source','archive_sha256','snapshot_kind','gpu_manifest_sha256','note','reviewed_wrapper_sha256','wrapper_sha256','paired_wrapper_sha256']},
 'schema':1,'wrapper_sha256':sha((HERE/'profile-one.ps1').read_bytes()),'paired_wrapper_sha256':sha((HERE/'run-paired.ps1').read_bytes()),'comparison_helper_sha256':sha((HERE/'compare-pair.py').read_bytes()),
 'source':source,'archive_sha256':sha(ARCHIVE.read_bytes()),'query_overlay':query,'central_proof':central,'runtime_sources':{rel:source[rel] for rel in runtime_paths},
 'snapshot_kind':'exact current-resident495 working-source archive; no indexed composition','reviewed_wrapper_sha256':oldpins['wrapper_sha256'],'reviewed_paired_wrapper_sha256':oldpins['paired_wrapper_sha256'],
 'note':'Exactly same three reviewed workload files and MeasuredScene; query_resource adds only centrally tested five files. Diagnostic only. No engine run by author.'}
(HERE/'pins.json').write_text(json.dumps(pins,indent=2)+'\n')
print('QUERY RESOURCE PERFORMANCE PREPARE: PASS; resident495 source; unchanged3 workload; tested5 candidate overlays; reversible wrappers')
