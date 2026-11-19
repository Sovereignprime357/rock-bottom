extends SceneTree
## Calls the actual report-boundary helper; never constructs/runs FullScene.
const Probe = preload("res://tests/full_actor_performance_probe.gd")
const FIELDS := ["id", "seed", "start_day_time", "end_day_time", "warmup_frames", "frames", "elapsed_ms", "initial_player_top_left_px", "source_route_centers_px", "route_setup_us", "player_walked_m", "player_displacement_including_relocations_m", "excluded_lifecycle_displacement_m", "completed_laps", "actor_manifest", "final_actor_manifest", "driver_cpu_ms", "driver_cpu_total_ms", "driver_physics_queries", "physics_queries_excluding_driver", "driver_input_counts", "driver_decisions", "workload_frames", "lifecycle_timeline", "population_timeline", "driver_work", "min_live_actors", "min_supported_live_actors", "min_live_rigs", "moving_actor_ids", "charging_actor_ids", "born_ids", "dead_ids", "removed_ids", "projectile_peak", "events", "dependencies", "scene_cpu_ms", "engine_process_monitor_window_max_ms", "frame_interval_ms", "viewport_render_cpu_ms", "viewport_render_gpu_ms", "render_setup_cpu_ms", "gpu_timing_available", "scene_scopes_ms", "scene_scope_totals_ms", "supplied_delta_ms", "active_ms", "stage_calls", "physics_queries_per_active_second", "diagnostic_switches", "draw_calls", "rendered_objects", "rendered_primitives", "max_video_memory_bytes", "max_nodes", "physics_queries", "navigation_before", "navigation_after", "navigation_phase_max_tests", "navigation_phase_max_starts", "navigation_phase_max_queue", "sampled_oldest_pending_ms"]
var checks := 0
var groups := 0
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _fixture() -> Dictionary:
	var phase: Dictionary = {}
	for name: String in FIELDS: phase[name] = 1.0
	phase.id = "core_day"; phase.warmup_frames = 120; phase.frames = 1080
	phase.elapsed_ms = 44863; phase.min_live_actors = 60
	phase.driver_decisions = [{"part":"warmup","decision":{"selected":Vector2(12,14),"candidates":[{"edge":{"ok":true,"to":Vector2(70,0)},"score":4.0}]}}]
	var rows: Array[Dictionary] = []
	for index: int in range(1200):
		rows.append({"part":"warmup" if index<120 else "measured","frame":index if index<120 else index-120,"source_position":[672.0+index,1310.0],"active_ms":40.0,"alive":60,"input":{"direction":Vector2.RIGHT,"sprint":false}})
	phase.workload_frames = rows
	phase.lifecycle_timeline = [{"frame":0,"discontinuities":[],"events":{"arrest":0}}]
	phase.population_timeline = [{"frame":0,"added":["cop_1"],"removed":[],"live":60}]
	phase.driver_input_counts = {"motion_frames":1200,"sprint_frames":10}
	phase.source_route_centers_px = [[672.0,1310.0],[1432.0,1310.0]]
	phase.initial_player_top_left_px = [660.0,1296.0]
	phase.actor_manifest = {"tony":{"hp":100,"source_position_px":[100.0,200.0]}}
	phase.final_actor_manifest = {"tony":{"hp":100,"source_position_px":[101.0,200.0]}}
	phase.driver_cpu_ms = {"p95":14.189,"samples":1080}
	phase.scene_cpu_ms = {"p95":30.467,"samples":1080,"above16ms":1080}
	phase.active_ms = {"frames":{"p95":54.5,"samples":1080},"total":44887.5883968254}
	phase.stage_calls = {"actors":{"total":3266.0,"frames":{"max":5.0},"cpu_ms_per_call":3.76128046540111}}
	phase.scene_scopes_ms = {"models":{"p95":6.0}}
	phase.scene_scope_totals_ms = {"models":5000.0}
	phase.driver_work = {"decisions":228,"candidate_sweeps":3648}
	phase.navigation_before = {"queued":0,"status":{"source":"before"}}
	phase.navigation_after = {"queued":1,"status":{"source":"after"}}
	phase.events = {"player_attack":0}
	phase.dependencies = []; phase.moving_actor_ids = ["tony"]; phase.removed_ids = []
	phase.diagnostic_switches = {"without_grade":false,"without_pose_input_memo":false}
	return phase

func _reused_phase_arrays() -> void:
	var current := _fixture()
	var original: Dictionary = current # Original return boundary: shared references.
	var corrected: Dictionary = Probe.snapshot_phase(current)
	var expected := JSON.stringify(current)
	for key: String in ["driver_decisions","workload_frames","lifecycle_timeline","population_timeline"]:
		current[key].clear()
		current[key].append({"part":"measured","phase":"trainyard_night","alive":59})
		_check(original[key] == current[key],"original independently exhibits next-phase overwrite: "+key)
		_check(corrected[key] != current[key],"corrected preserves first phase array: "+key)
	_check(JSON.stringify(original) != expected,"original fails full-record identity after next-phase clear/refill")
	_check(JSON.stringify(corrected) == expected,"actual corrected return boundary retains all day values")
	_check(corrected.workload_frames.size()==1200 and corrected.workload_frames[119].part=="warmup" and corrected.workload_frames[120].part=="measured","complete120+1080 snapshot remains separate")
	groups += 1

func _nested_values() -> void:
	var current := _fixture(); var copied: Dictionary = Probe.snapshot_phase(current)
	var expected := JSON.stringify(copied)
	current.workload_frames[123].source_position[0] = -123.0
	current.workload_frames[123].input.sprint = true
	current.driver_decisions[0].decision.candidates[0].edge.ok = false
	current.actor_manifest.tony.source_position_px[0] = -1.0
	current.stage_calls.actors.frames.max = 99.0
	current.navigation_after.status.source = "next"
	current.driver_input_counts.motion_frames = 0
	_check(JSON.stringify(copied) == expected,"nested row/decision/actor/stats/navigation/counts have no shared mutable descendants")
	_check(copied.workload_frames[123].input.sprint == false and copied.driver_decisions[0].decision.candidates[0].edge.ok,"actual nested values preserved")
	groups += 1

func _all_fields_and_reverse() -> void:
	var current := _fixture(); var copied: Dictionary = Probe.snapshot_phase(current)
	_check(copied.keys() == current.keys() and copied.size()==FIELDS.size(),"all actual return field names/order retained")
	var expected := JSON.stringify(copied); var mutable_count := 0
	for name: String in current:
		if current[name] is Dictionary or current[name] is Array:
			mutable_count += 1; current[name].clear()
	_check(mutable_count >= 20,"census exercises more than four selected arrays")
	_check(JSON.stringify(copied) == expected,"clearing every mutable top-level source field cannot alter snapshot")
	var inverse := _fixture(); var original_text := JSON.stringify(inverse)
	var edited: Dictionary = Probe.snapshot_phase(inverse)
	for name: String in edited:
		if edited[name] is Dictionary or edited[name] is Array: edited[name].clear()
	_check(JSON.stringify(inverse) == original_text,"snapshot mutations cannot affect owner buffers in reverse")
	groups += 1

func _second_snapshot() -> void:
	var buffers := _fixture(); var day: Dictionary = Probe.snapshot_phase(buffers)
	buffers.id = "trainyard_night"
	buffers.workload_frames[0].source_position = [756.0,2648.0]
	buffers.scene_cpu_ms.p95 = 26.950
	var night: Dictionary = Probe.snapshot_phase(buffers)
	buffers.workload_frames.clear(); buffers.driver_decisions.clear()
	_check(day.id=="core_day" and night.id=="trainyard_night","source phase identities stay separate")
	_check(day.workload_frames[0].source_position==[672.0,1310.0] and night.workload_frames[0].source_position==[756.0,2648.0],"distinct source positions survive reused buffer cleanup")
	_check(day.scene_cpu_ms.p95==30.467 and night.scene_cpu_ms.p95==26.950,"strict16ms scalar failures are preserved rather than relabeled")
	_check(day.workload_frames.size()==1200 and night.workload_frames.size()==1200,"both full frame receipts survive")
	groups += 1

func _value_domain(value: Variant) -> bool:
	if value is Object: return false
	if value is Dictionary:
		for key: Variant in value:
			if not _value_domain(key) or not _value_domain(value[key]): return false
	elif value is Array:
		for item: Variant in value:
			if not _value_domain(item): return false
	return true
func _pure_boundary() -> void:
	var current := _fixture(); var before := JSON.stringify(current)
	var first: Dictionary = Probe.snapshot_phase(current)
	var second: Dictionary = Probe.snapshot_phase(current)
	_check(JSON.stringify(current)==before and JSON.stringify(first)==before and JSON.stringify(second)==before,"snapshot creation is a value-identical read")
	_check(not is_same(first,current) and not is_same(first,second),"distinct top-level snapshot ownership")
	_check(_value_domain(first),"fixture follows inspected value-only report domain, no shared Object leaves")
	first.workload_frames.clear()
	_check(second.workload_frames.size()==1200,"same input can produce independent completed snapshots")
	_check(Probe.snapshot_phase({}).is_empty(),"empty record remains empty")
	groups += 1

func _run() -> void:
	_reused_phase_arrays()
	_nested_values()
	_all_fields_and_reverse()
	_second_snapshot()
	_pure_boundary()
	_check(groups==5,"all five groups completed, including original failing witness")
	print("PERFORMANCE PHASE SNAPSHOT: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",groups,"/5 groups; original_alias_reproduced=true; no performance claim")
	quit(0 if failures.is_empty() else 1)
