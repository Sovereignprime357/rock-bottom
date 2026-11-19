"""Create distinct root-only runner; never launch it."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
PRIOR=ROOT/'.build/3d/profile-cost-breakdown-draft'
REVIEWED=ROOT/'.build/3d/sustained-population-draft'
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((HERE/'manifest.json').read_text())
pins=json.loads((REVIEWED/'profile-frozen.pins.json').read_text())
raw=(PRIOR/'profile-cost-breakdown.ps1').read_bytes()
assert sha(raw)==manifest['reviewed_cost_wrapper_sha256']
s=raw.decode().replace('\r\n','\n')
def replace(old,new):
    global s
    assert s.count(old)==1,(old[:90],s.count(old))
    s=s.replace(old,new)
replace("$Revision = '648dc7868a54e6da4d2acc9231d1ec83d209fbbf'","$Revision = '"+manifest['revision']+"'")
replace("'profile-cost-breakdown.pins.json'","'profile-pose-exclusive.pins.json'")
replace("$overlayNames = @('scripts/full_scene.gd','scripts/world_adapter.gd','tests/full_actor_performance_probe.gd','tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd')","$overlayNames = @('scripts/actor_animation.gd','scripts/character_roster.gd','scripts/pose_cost_metrics.gd','tests/test_pose_cost_metrics.gd','tests/full_actor_performance_probe.gd','tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd')")
replace("if ($pins.overlay.Count -ne 5 -or @($pins.overlay.Keys | Where-Object { $_ -notin $overlayNames }).Count -ne 0) { throw 'Diagnostic overlay must contain exactly the three reviewed tests and two instrumented production files.' }","if ($pins.overlay.Count -ne 7 -or @($pins.overlay.Keys | Where-Object { $_ -notin $overlayNames }).Count -ne 0) { throw 'Pose diagnostic requires the exact seven approved source/metric/test overlays.' }")
replace("@('tests/sustained_actor_driver.gd.uid','tests/test_sustained_actor_driver.gd.uid')","@('tests/sustained_actor_driver.gd.uid','tests/test_sustained_actor_driver.gd.uid','scripts/pose_cost_metrics.gd.uid','tests/test_pose_cost_metrics.gd.uid','tests/test_world_dust_visual_contract.gd.uid','tests/test_world_feedback_visual_contract.gd.uid','tests/web_dust_visual_probe.gd.uid','tests/web_feedback_visual_probe.gd.uid','tests/world_dust_visual_probe.gd.uid','tests/world_feedback_visual_probe.gd.uid')")
replace('# Import may assign identity files to the two new test scripts. They are','# Import may assign only the four diagnostic/workload and six existing promoted probe UIDs below. They are')
s=s.replace('Strip-CostInstrumentation','Strip-PoseInstrumentation')
replace('COST-BEGIN','POSE-COST-BEGIN');replace('COST-END','POSE-COST-END')
replace("return $stripped.Replace('_cost_needs_pose(art,pose_context)','PoseVisibility.needs_pose(art,pose_context)')","return $stripped")
replace("if ($pins.revision -ne $Revision) { throw 'Only the reviewed648 archive is authorized for this diagnostic.' }","if ($pins.revision -ne $Revision -or $pins.snapshot_kind -ne 'current working production with promoted effects, not a Git revision') { throw 'Only this reviewed working-source snapshot is authorized.' }")
replace("throw 'Exact retained648 source archive is missing or changed.'","throw 'Exact retained working-source archive is missing or changed.'")
replace("'.build/full-port/profile-cost-breakdown'","'.build/full-port/pose-exclusive-cost'")
replace("variant='instrumentation_only_cost_breakdown'; reviewed_wrapper_sha256=$pins.reviewed_wrapper_sha256; stripped_originals=$pins.stripped_originals","variant='instrumentation_only_exclusive_pose_costs'; reviewed_wrapper_sha256=$pins.reviewed_wrapper_sha256; stripped_originals=$pins.stripped_originals\n    snapshot_kind=$pins.snapshot_kind; snapshot_sha256=$pins.snapshot_sha256; reviewed_cost_wrapper_sha256=$pins.reviewed_cost_wrapper_sha256")
s=s.replace('Windows Cost Breakdown Frozen','Windows Pose Exclusive Frozen').replace('RockBottomCostBreakdown.exe','RockBottomPoseExclusive.exe')
replace('tests/sustained_actor_driver.gd,tests/test_sustained_actor_driver.gd"','tests/sustained_actor_driver.gd,tests/test_sustained_actor_driver.gd,tests/test_pose_cost_metrics.gd"')
replace("    if ($contract -notmatch 'SUSTAINED60 DRIVER CONTRACT: PASS') { throw 'Detached contract did not complete all required groups.' }","    if ($contract -notmatch 'SUSTAINED60 DRIVER CONTRACT: PASS') { throw 'Detached contract did not complete all required groups.' }\n    $poseContract = Invoke-IsolatedChild 'pose-contract' $engine @('--headless','--path',$project,'--log-file',(Join-Path $runRoot 'pose-contract.godot.log'),'--script','res://tests/test_pose_cost_metrics.gd')\n    if ($poseContract -notmatch 'POSE EXCLUSIVE COST CONTRACT: PASS') { throw 'Nested timing contract did not complete.' }")
replace('$report.cost_breakdown_diagnostic','$report.pose_cost_diagnostic')
replace("if ($phase.cost_breakdown -isnot [hashtable] -or $phase.cost_breakdown.Count -ne 8) { throw 'Cost breakdown is missing its four Scene and four driver counter groups.' }","if ($phase.pose_cost_breakdown -isnot [hashtable] -or $phase.pose_cost_breakdown.Count -ne 4) { throw 'Pose breakdown is missing its two Scene and two driver groups.' }\n        foreach ($groupName in @('scene_ms','driver_ms')) { if ($phase.pose_cost_breakdown[$groupName].Count -ne 12) { throw 'Incomplete fixed timing keys.' } }\n        foreach ($groupName in @('scene_counts','driver_counts')) { if ($phase.pose_cost_breakdown[$groupName].Count -ne 42) { throw 'Incomplete fixed count keys.' } }\n        foreach ($key in @('root_ticks','reset_in_tick_calls','apply_in_tick_calls','attachments_in_tick_calls')) { if ($phase.pose_cost_breakdown.scene_counts[$key].total -le 0) { throw \"Missing actual measured work: $key\" } }\n        foreach ($groupName in @('scene_counts','driver_counts')) { foreach ($key in @('overflow','imbalance','negative_span','unknown_key')) { if ($phase.pose_cost_breakdown[$groupName][$key].total -ne 0) { throw \"Invalid diagnostic accounting: $groupName/$key\" } } }")
replace('foreach ($group in $phase.cost_breakdown.Values)','foreach ($group in $phase.pose_cost_breakdown.Values)')
s=s.replace('instrumented cost breakdown only; overhead included; acceptance ineligible','instrumented exclusive pose costs only; overhead included; acceptance ineligible')
assert '& git' not in s and '--frames' not in s
out=HERE/'profile-pose-exclusive.ps1';out.write_text(s,encoding='utf8',newline='\n')
new=dict(pins)
for key in ['revision','game3d_tree','archive','archive_sha256','overlay','stripped_originals','reviewed_wrapper_sha256','reviewed_pins_sha256','reviewed_cost_wrapper_sha256','snapshot_kind','snapshot_sha256']:new[key]=manifest[key]
new['wrapper_sha256']=sha(out.read_bytes());new['variant']='instrumentation_only_exclusive_pose_costs'
new['note']='Current working-source snapshot, not a committed archive. Exact seven overlays, fixed sustained60; acceptance always false.'
(HERE/'profile-pose-exclusive.pins.json').write_text(json.dumps(new,indent=2)+'\n')
print('POSE COST WRAPPER: PASS; exact working snapshot +7 explicit overlays; no engine/Git execution.')
