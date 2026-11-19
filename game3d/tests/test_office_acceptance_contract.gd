extends "res://tests/office_acceptance_probe.gd"
## Synthetic validator counterexamples, never native gameplay evidence.
const Probe = preload("res://tests/office_acceptance_probe.gd")
const Driver = preload("res://tests/boss_acceptance_probe.gd")
var checks := 0

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> bool:
	if recovery_driver_checks:
		if not ok and label not in failures: failures.append(label)
		return ok
	checks += 1
	if not ok: failures.append(label)
	return ok

# Controlled geometry dependencies for real inherited driver orchestration only.
# They are never attached to this SceneTree and never simulate a fight or rewards.
class RecoveryState:
	extends RefCounted
	var center := Vector2(1599.266,983.0338)
	var rng_seed := 716205
	func player_center() -> Vector2: return center
class RecoveryRuntime:
	extends RefCounted
	var p := {"w":24.0,"h":24.0,"hp":85.0}
	var s := {"bossPhase":3,"mode":"playing","bossActive":false}
	var state := RecoveryState.new()
class RecoveryPhysics:
	extends RefCounted
	var _collision_revision := 49
	var service_reachable := true
	var service_queries := 0
	func can_reach_target(_id: String) -> bool:
		service_queries += 1; return service_reachable
	func _contact_peers(_body: Dictionary) -> Array[Dictionary]: return []
class RecoveryWorld:
	extends Node3D
	func is_clear_position(_point: Vector3) -> bool: return true

class CornerPhysics:
	extends RefCounted
	var anchor := Vector2.ZERO
	var refuse_all := false
	var peer_contact := false
	var queries := 0
	var records: Array[Dictionary] = []
	func move_body(body: Dictionary,goal: Vector2) -> Dictionary:
		queries += 1
		var origin := Vector2(body.x,body.y)
		records.append({"origin":origin,"goal":goal,"length":origin.distance_to(goal)})
		# A long endpoint clears a narrow synthetic margin band; short ones do not.
		var blocked: bool = refuse_all or (goal.x > anchor.x+0.5 and goal.x < anchor.x+3.5 and absf(goal.y-anchor.y) < 0.125)
		return {"position":origin if blocked or peer_contact else goal,"blocked":blocked,"body_contact":peer_contact}

var recovery_driver_checks := false
var recovery_routes_available := false
var recovery_endpoints_clear := true
var recovery_segments_clear := false
var recovery_route_calls := 0
var walking_driver_checks := false
var walking_case := ""
var walking_clock_ms := 1000
var walking_frames := 0
var walking_motion := Vector2.ZERO
var walking_move_samples: Array[Dictionary] = []
var walking_plan_origins: Array[Vector3] = []
var walking_defended := false
var walking_completed := false
var walking_local_calls := 0
var corner_completed := false
var service_driver_checks := false
var service_frames := 0
var service_aims := 0
var service_actor: Dictionary = {}
var service_completed := false

class ServiceScene:
	extends Probe.ObservedScene
	var service_result := {"kind":"route","id":"route:higher_priority"}
	func resolve_interaction() -> Dictionary: return service_result.duplicate()

func _combat_endpoint(_point: Vector3,_target_record: Dictionary,_peers: Array[Dictionary]) -> bool:
	return recovery_endpoints_clear
func _resident_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	recovery_route_calls += 1
	if walking_driver_checks:
		walking_plan_origins.append(from)
		resident_route_context = {"reason":"controlled_resident_crossing","from":from,"to":to}
		var ready: bool = walking_case in ["segment","leg_limit","short_step","stagnation"] or (walking_case == "transient" and walking_clock_ms >= 4000) or (walking_case == "defense" and walking_defended) or (walking_case == "last_plan" and recovery_route_calls == 33)
		return PackedVector3Array([from,to]) if ready else PackedVector3Array()
	return PackedVector3Array([from,to]) if recovery_routes_available else PackedVector3Array()
func _walking_step(point: Vector3) -> Dictionary:
	if not walking_driver_checks: return super._walking_step(point)
	var clear: bool = walking_case != "short_step" or walking_local_calls > 0
	return {"ok":clear,"reason":"" if clear else "controlled_short_endpoint_overlap"}
func _walking_detour(from: Vector3,to: Vector3) -> PackedVector3Array:
	if not walking_driver_checks: return super._walking_detour(from,to)
	walking_local_calls += 1
	walking_plan_origins.append(from)
	return PackedVector3Array([from,from+Vector3(0,0,0.25),to])
func _combat_segment(from: Vector3,to: Vector3) -> Dictionary:
	if walking_driver_checks:
		var clear: bool = walking_case != "segment" or walking_clock_ms < 1250 or walking_clock_ms >= 3250
		return {"ok":clear,"reason":"" if clear else "controlled_new_peer_crossing","from":Content.to_source(from),"to":Content.to_source(to)}
	return {"ok":recovery_segments_clear,"reason":"" if recovery_segments_clear else "controlled_live_peer_block","from":Content.to_source(from),"to":Content.to_source(to)}
func _combat_blocker(_target_record: Dictionary) -> Dictionary:
	return {"owner":"controlled_static_boundary"}
func _recovery_steer(target_record: Dictionary,now: int,line_clear: bool = false) -> Vector2:
	recovery_driver_checks = true
	var result: Vector2 = _combat_steering(target_record,now,line_clear)
	recovery_driver_checks = false
	return result
func _recovery_reset() -> void:
	combat_plan.clear(); combat_context.clear(); combat_navigation.clear()
	combat_replans = 0; combat_last_plan = -1000; combat_endpoint_attempts = 0
	recovery_route_calls = 0; recovery_routes_available = false
	recovery_endpoints_clear = true; recovery_segments_clear = false
func _recovery_expect_fatal(before: Array[String],label: String) -> void:
	var actual: Array = failures.slice(before.size())
	var stopped: bool = not _alive()
	failures.assign(before)
	_check(actual == ["bounded combat replans remain below32"] and stopped,label)

func _route_recovery_checks() -> void:
	game = Probe.ObservedScene.new()
	game.runtime = RecoveryRuntime.new(); game.physics = RecoveryPhysics.new()
	game.world = RecoveryWorld.new(); game.player = Node3D.new()
	game.add_child(game.world); game.add_child(game.player) # OFF tree: no production _ready.
	game.player.position = Content.to_world(game.runtime.state.player_center(),0.06)
	began_wall = Time.get_ticks_msec()
	var target_record := {"id":"tony","x":1615.781,"y":890.9409,"w":28.0,"h":32.0}
	var original := [game.runtime.p.duplicate(true),game.runtime.s.duplicate(true),game.runtime.state.center,game.runtime.state.rng_seed,game.player.position]
	_recovery_reset()
	var held: Vector2 = _recovery_steer(target_record,Time.get_ticks_msec())
	_check(held == Vector2.ZERO and combat_plan.is_empty() and failures.is_empty() and _alive(),"four transient blocked routes hold input without aborting the real driver")
	_check(combat_replans == 1 and recovery_route_calls == 4 and combat_endpoint_attempts == 4,"failed plan consumes one cumulative plan and exactly four eligible route attempts")
	_check(combat_context.reason == "route_unavailable" and combat_navigation[-1].retryable and combat_navigation[-1].next_plan_ms == combat_last_plan+500,"unavailable observation records bounded next opportunity")
	held = _recovery_steer(target_record,combat_last_plan+499)
	_check(held == Vector2.ZERO and combat_plan.is_empty() and combat_replans == 1 and recovery_route_calls == 4,"499ms cannot retry or follow a stale path")
	_check(combat_context.reason == "waiting_for_replan_budget","hold is reported as waiting rather than a fabricated route")
	recovery_routes_available = true; recovery_segments_clear = true
	var resumed: Vector2 = _recovery_steer(target_record,combat_last_plan+500)
	_check(resumed.length_squared() > 0.0 and combat_replans == 2 and recovery_route_calls == 5 and failures.is_empty(),"at500ms the next actual plan can recover without a scenario restart")
	_check(combat_plan.target_id == target_record.id and combat_plan.phase == game.runtime.s.bossPhase and combat_plan.revision == game.physics._collision_revision,"recovery captures current target/phase/geometry facts")
	recovery_segments_clear = false
	held = _recovery_steer(target_record,combat_last_plan+100)
	_check(held == Vector2.ZERO and combat_plan.is_empty() and combat_replans == 2 and recovery_route_calls == 5,"a newly blocked cached segment clears the stale route while the budget is waiting")
	# Normal nearby defense/direct approach is still available during that wait.
	var nearby: Dictionary = target_record.duplicate(true)
	nearby.id = "sherri_boss_fixture"; nearby.x = game.runtime.state.center.x+35.0-nearby.w*0.5
	nearby.y = game.runtime.state.center.y-nearby.h*0.5
	recovery_segments_clear = true
	resumed = _recovery_steer(nearby,combat_last_plan+101,true)
	_check(resumed.length_squared() > 0.0 and combat_context.reason == "direct_melee" and combat_plan.is_empty() and combat_replans == 2 and recovery_route_calls == 5,"fresh certified nearby defense bypasses planner wait without resetting its cumulative count")
	_check([game.runtime.p,game.runtime.s,game.runtime.state.center,game.runtime.state.rng_seed,game.player.position] == original,"route retries/hold/defense steer only: no HP, RNG, clock or source-position repair")

	_recovery_reset(); recovery_routes_available = true; recovery_segments_clear = false
	held = _recovery_steer(target_record,Time.get_ticks_msec())
	_check(held == Vector2.ZERO and combat_context.reason == "new_route_segment_blocked" and recovery_route_calls == 1,"even a newly returned route cannot move through its failed final segment certificate")
	_recovery_reset(); recovery_routes_available = true; recovery_segments_clear = true
	combat_replans = 31
	resumed = _recovery_steer(target_record,Time.get_ticks_msec())
	_check(resumed.length_squared() > 0 and combat_replans == 32 and failures.is_empty(),"32nd plan may succeed; the cap does not reject a valid final route")
	var last_calls: int = recovery_route_calls
	resumed = _recovery_steer(target_record,combat_last_plan+500)
	_check(resumed.length_squared() > 0 and combat_replans == 32 and recovery_route_calls == last_calls,"valid32nd route remains usable without a33rd plan")
	var prior_failures: Array[String] = failures.duplicate()
	game.physics._collision_revision += 1
	held = _recovery_steer(nearby,combat_last_plan+500)
	_recovery_expect_fatal(prior_failures,"changed target/revision cannot erase the exhausted cumulative32-plan budget")
	_check(held == Vector2.ZERO and combat_plan.is_empty() and recovery_route_calls == last_calls,"exhausted invalid route produces no movement and no33rd route call")

	_recovery_reset(); recovery_endpoints_clear = false
	held = _recovery_steer(target_record,Time.get_ticks_msec())
	_check(held == Vector2.ZERO and failures.is_empty() and combat_replans == 1 and recovery_route_calls == 0 and combat_endpoint_attempts == 0,"zero eligible endpoints still consume a bounded plan without expensive route calls or immediate abort")
	for attempt: int in range(1,31):
		held = _recovery_steer(target_record,combat_last_plan+500)
	_check(failures.is_empty() and combat_replans == 31,"persistent blockage may retry only within its remaining finite budget")
	prior_failures = failures.duplicate()
	held = _recovery_steer(target_record,combat_last_plan+500)
	_recovery_expect_fatal(prior_failures,"permanent obstruction hard-stops on failed plan32 instead of waiting indefinitely")
	_check(held == Vector2.ZERO and combat_replans == 32 and recovery_route_calls == 0,"exhausted empty endpoint sets never manufacture a path or extra planner work")
	game.free(); game = null
	_recovery_reset()


func _walk_clock() -> int:
	return walking_clock_ms if walking_driver_checks else super._walk_clock()
func _walk_frame() -> void:
	if not walking_driver_checks:
		await super._walk_frame(); return
	walking_move_samples.append({"at":walking_clock_ms,"position":game.player.position,"input":walking_motion})
	walking_frames += 1
	if walking_case in ["leg_limit","cap"] or (walking_case == "last_plan" and recovery_route_calls < 33):
		# Detached controller observations keep the physical-progress clock alive
		# without changing source player/state. This is not movement evidence.
		game.player.position.x = 0.04 if walking_frames%2 == 1 else 0.0
	elif walking_case == "stagnation" and walking_local_calls == 0:
		pass # Input was requested but actual observed controller motion is zero.
	elif walking_motion.length_squared() > 0.0:
		game.player.position += Vector3(walking_motion.x,0,walking_motion.y)*0.2
	walking_clock_ms += 1000 if walking_case in ["leg_limit","cap","last_plan"] else 250
	await process_frame
func _reach_service(id: String) -> bool:
	if walking_driver_checks: return false
	return await super._reach_service(id)
func _defend_exit() -> bool:
	if not walking_driver_checks: return await super._defend_exit()
	if walking_case != "defense" or walking_defended: return false
	walking_defended = true; game.player.position = Vector3(1,0,0)
	return true
func _aim(target: Vector3,delta: float) -> float:
	if service_driver_checks: service_aims += 1; return 1.0
	return 1.0 if walking_driver_checks else super._aim(target,delta)
func _motion(direction: Vector2) -> void:
	if walking_driver_checks: walking_motion = direction
	else: super._motion(direction)
func _release() -> void:
	if service_driver_checks: return
	if walking_driver_checks: walking_motion = Vector2.ZERO
	else: super._release()

func _walking_recovery_checks() -> void:
	game = Probe.ObservedScene.new()
	game.runtime = RecoveryRuntime.new(); game.physics = RecoveryPhysics.new()
	game.world = RecoveryWorld.new(); game.player = Node3D.new()
	game.add_child(game.world); game.add_child(game.player)
	game.camera = Camera3D.new(); root.add_child(game.camera)
	began_wall = Time.get_ticks_msec()
	var source_before := [game.runtime.p.duplicate(true),game.runtime.s.duplicate(true),game.runtime.state.center,game.runtime.state.rng_seed]
	for scenario: String in ["transient","segment","defense","permanent","leg_limit","cap","last_plan","short_step","stagnation"]:
		walking_case = scenario; walking_clock_ms = 1000; walking_frames = 0
		walking_motion = Vector2.ZERO; walking_move_samples.clear(); walking_plan_origins.clear()
		walking_defended = false; recovery_route_calls = 0; walking_local_calls = 0
		game.player.position = Vector3.ZERO; resident_route_context.clear(); walking_context.clear()
		var before: Array[String] = failures.duplicate()
		walking_driver_checks = true; recovery_driver_checks = true
		var arrived: bool = await _walk_to(Vector3(2,0,0))
		walking_driver_checks = false; recovery_driver_checks = false
		var actual_failures: Array = failures.slice(before.size()); failures.assign(before)
		_check(walking_motion == Vector2.ZERO,"walking always releases input after "+scenario)
		_check([game.runtime.p,game.runtime.s,game.runtime.state.center,game.runtime.state.rng_seed] == source_before,"walk orchestration cannot rewrite source resources/epoch/RNG: "+scenario)
		match scenario:
			"transient":
				_check(arrived and actual_failures.is_empty() and recovery_route_calls == 5,"four empty resident plans wait then fifth current plan arrives normally")
				for sample: Dictionary in walking_move_samples:
					if int(sample.at) < 4000: _check(sample.input == Vector2.ZERO and sample.position == Vector3.ZERO,"uncertified transient route holds actual requested input")
				_check(walking_clock_ms < 21000 and walking_plan_origins.all(func(point: Vector3) -> bool: return point == Vector3.ZERO),"retry origins remain current and do not consume a fictitious waypoint")
			"segment":
				_check(arrived and actual_failures.is_empty() and recovery_route_calls > 1,"newly blocked live segment can recover within unchanged walk")
				for sample: Dictionary in walking_move_samples:
					if int(sample.at) >= 1250 and int(sample.at) < 3250: _check(sample.input == Vector2.ZERO and sample.position.is_equal_approx(Vector3(0.2,0,0)),"blocked cached/new segment never keeps stale motion")
			"defense":
				_check(arrived and actual_failures.is_empty() and walking_defended and walking_plan_origins.size() == 2,"ordinary defense preserves bounded walking recovery")
				_check(walking_plan_origins[0] == Vector3.ZERO and walking_plan_origins[1] == Vector3(1,0,0),"post-defense route starts from actual displaced controller endpoint")
			"permanent":
				_check(not arrived and actual_failures.size() == 1 and str(actual_failures[0]).begins_with("actual controller walking stalled"),"permanent crossing fails the real20s no-progress watchdog")
				_check(walking_context.no_progress_ms > 20000 and walking_context.elapsed_ms < 120000 and recovery_route_calls <= 28,"plans/waypoint bookkeeping never renew20s progress time")
			"leg_limit":
				_check(not arrived and actual_failures.size() == 1 and walking_context.elapsed_ms == 120000 and walking_context.no_progress_ms == 0,"physical motion does not renew the120s leg watchdog")
			"cap":
				_check(not arrived and actual_failures == ["bounded live-resident approach replans"] and recovery_route_calls == 33 and walking_context.replans == 32,"initial plan plus32 replans cannot issue a34th request")
			"last_plan":
				_check(arrived and actual_failures.is_empty() and recovery_route_calls == 33 and walking_context.replans == 32,"valid32nd replan remains usable without a33rd replan")
			"short_step":
				_check(arrived and actual_failures.is_empty() and walking_local_calls == 1 and walking_context.replans == 1,"long route success with short-step refusal requests one bounded outward detour")
				for sample: Dictionary in walking_move_samples:
					if int(sample.at) < 1750: _check(sample.input == Vector2.ZERO,"short-step refusal releases stale motion until750ms replan opportunity")
			"stagnation":
				_check(arrived and actual_failures.is_empty() and walking_local_calls == 1 and walking_context.replans == 1,"500ms actual stagnation replans despite a successful long segment certificate")
				_check(walking_plan_origins[1] == Vector3.ZERO,"stagnation detour begins at actual unchanged controller origin")
	game.camera.free(); game.free(); game = null
	walking_completed = true

func _corner_checks() -> void:
	game = Probe.ObservedScene.new(); game.runtime = RecoveryRuntime.new()
	var physics := CornerPhysics.new(); game.physics = physics
	game.world = RecoveryWorld.new(); game.player = Node3D.new()
	game.add_child(game.world); game.add_child(game.player)
	game.runtime.p = {"x":1588.16821289063,"y":929.989440917969,"w":24.0,"h":28.0,"hp":100.0}
	var exact := Vector2(game.runtime.p.x,game.runtime.p.y)
	physics.anchor = exact
	game.player.position = Content.to_world(exact+Vector2(12,14),0.06)
	var from: Vector3 = game.player.position
	var target: Vector3 = from+Vector3(0.64,0,0)
	var before: Dictionary = game.runtime.p.duplicate(true)
	var body: Dictionary = _walking_body(from)
	_check(body.x == game.runtime.p.x and body.y == game.runtime.p.y,"short-step origin preserves exact source scalars")
	_check(_walking_query(body,exact+Vector2(16,0)).ok,"controlled long endpoint clears the narrow margin band")
	_check(not _walking_step(target).ok,"same route's actual short endpoint is refused")
	var blocked: Dictionary = _walking_local_link(from,target)
	_check(not blocked.ok and blocked.steps == 1,"local proof cannot reuse a successful long endpoint cast")
	var candidates: Array[Vector3] = Probe.walking_corner_candidates(from,target)
	_check(candidates.size() == 24 and Probe.walking_corner_candidates(Vector3.INF,target).is_empty(),"local candidate set is exactly24 finite headings/radii or empty invalid input")
	var last_distance := -1.0
	for candidate: Vector3 in candidates:
		_check(candidate.is_finite() and candidate.distance_to(from) <= 1.00001 and candidate.distance_to(from) >= 0.24999,"outward endpoint stays within finite local bounds")
		_check(candidate.distance_squared_to(target) >= last_distance,"closest remaining target distance is considered first")
		last_distance = candidate.distance_squared_to(target)
	recovery_routes_available = true; recovery_route_calls = 0
	physics.queries = 0; physics.records.clear()
	var detour: PackedVector3Array = _walking_detour(from,target)
	_check(detour.size() == 3 and detour[0] == from and detour[-1] == target and absf(detour[1].z-from.z) > 0.01,"real driver orchestration retains explicit outward point and original target")
	_check(walking_local_context.reason == "certified_outward_join" and int(walking_local_context.tail_attempts) == 1,"closest locally clear candidate joins the existing route")
	for row: Dictionary in physics.records: _check(float(row.length) <= 1.001,"each detached local query is at most one source pixel")
	_check(game.runtime.p == before and game.player.position == from,"local proof never commits source or controller positions")
	physics.refuse_all = true; physics.queries = 0; physics.records.clear()
	detour = _walking_detour(from,target)
	_check(detour.is_empty() and physics.queries == 24 and walking_local_context.tail_attempts == 0,"all blocked candidates remain failure with exactly24 first-step refusals")
	physics.refuse_all = false; physics.peer_contact = true; physics.queries = 0
	_check(not _walking_local_link(from,from+Vector3(0,0,0.25)).ok,"source peer contact invalidates otherwise static-clear outward motion")
	physics.peer_contact = false; physics.queries = 0
	_check(not _walking_local_link(from,from+Vector3(1.01,0,0)).ok and physics.queries == 0,"local proof never expands into unbounded district-path subdivision")
	recovery_routes_available = false; recovery_route_calls = 0; physics.queries = 0
	detour = _walking_detour(from,target)
	_check(detour.is_empty() and recovery_route_calls == 4 and walking_local_context.tail_attempts == 4 and physics.queries <= 24*Probe.WALK_LOCAL_MAX_STEPS,"failed tail joins retain hard four-route and624-step bounds")
	game.free(); game = null; corner_completed = true


func _actor(id: String) -> Dictionary:
	if service_driver_checks: return service_actor if id == "tony" else {}
	return super._actor(id)
func _service_frame() -> void:
	if not service_driver_checks: await super._service_frame(); return
	service_frames += 1
	await process_frame

func _service_range_checks() -> void:
	game = ServiceScene.new(); game.runtime = RecoveryRuntime.new()
	game.physics = RecoveryPhysics.new(); game.player = Node3D.new(); game.add_child(game.player)
	began_wall = Time.get_ticks_msec()
	service_actor = {"id":"tony","x":-14.0,"y":-16.0,"w":28.0,"h":32.0,"dead":false}
	service_driver_checks = true; service_frames = 0; service_aims = 0
	for distance: float in [59.999,60.0,60.001,67.2]:
		game.runtime.state.center = Vector2(-distance,0)
		var queries: int = game.physics.service_queries
		var candidate: bool = _service_candidate("tony")
		_check(candidate == (distance < 60.0),"NPC candidate uses resolver strict60px at "+str(distance))
		_check(game.physics.service_queries-queries == (1 if distance < 60.0 else 0),"outer physical reach cannot override60px resolver filter")
		if distance >= 60.0:
			_check(not await _reach_service("tony") and service_frames == 0 and service_aims == 0,"out-of-resolver-range cannot stop movement for aim frames")
	game.runtime.state.center = Vector2(-50,0)
	service_actor.dead = true
	_check(not _service_candidate("tony"),"dead actor cannot become an aim candidate")
	service_actor.dead = false; service_actor.x = NAN
	_check(not _service_candidate("tony"),"nonfinite actor cannot become an aim candidate")
	service_actor.x = -14.0; game.runtime.state.center = Vector2.INF
	_check(not _service_candidate("tony"),"nonfinite player cannot become an aim candidate")
	game.runtime.state.center = Vector2(-50,0); game.physics.service_reachable = false
	_check(not _service_candidate("tony"),"strict range never bypasses actual physical refusal")
	game.physics.service_reachable = true
	game.player.position = Content.to_world(game.runtime.state.player_center(),0.06)
	service_aim_wait.clear()
	_check(not await _reach_service("tony") and service_frames == 120 and service_aims == 120,"higher-priority actual resolver consumes only one120-frame attempt")
	for attempt: int in range(3):
		_check(not await _reach_service("tony") and service_frames == 120,"unchanged failed aim returns immediately so certified walking can resume")
	var previous_frames: int = service_frames
	game.player.position.x += 0.3; game.runtime.state.center.x += 7.5
	_check(not await _reach_service("tony") and service_frames == previous_frames+120,"actual player displacement permits a new bounded aim")
	previous_frames = service_frames; service_actor.x += 7.5
	_check(not await _reach_service("tony") and service_frames == previous_frames+120,"actual target displacement permits a new bounded aim")
	previous_frames = service_frames; game.physics._collision_revision += 1
	_check(not await _reach_service("tony") and service_frames == previous_frames+120,"geometry revision invalidates only the probe aim suppression")
	previous_frames = service_frames; game.runtime.p = game.runtime.p.duplicate(true)
	_check(not await _reach_service("tony") and service_frames == previous_frames+120,"player-only epoch cannot inherit stale aim suppression")
	previous_frames = service_frames; game.runtime.s = game.runtime.s.duplicate(true)
	_check(not await _reach_service("tony") and service_frames == previous_frames+120,"state-only epoch cannot inherit stale aim suppression")
	previous_frames = service_frames
	var service_scene: ServiceScene = game as ServiceScene
	service_scene.service_result = {"kind":"vendor","id":"tony"}
	_check(await _reach_service("tony") and service_frames == previous_frames and service_aim_wait.is_empty(),"actual intended resolver immediately succeeds without waiting or weakening reach")
	service_driver_checks = false; game.free(); game = null; service_completed = true


func _base() -> Dictionary:
	return {"cash":300,"copper":6,"hp":100,"max_hp":100,"brain":70,"shakes":20,"wanted":0,"cred":0,"weapon":"fists","equip":{"coat":null,"hat":null,"shoes":null,"tool":null},"inventory":[],"speed":2.2,"cart_mounted":false,"rocks":0,"offenses":0,"rocks_smoked":0,"routes":0,"office_jobs":0,"intro":false,"office_available":false,"paper_done":false,"office":{"owned":false,"upgrades":{"desk":false,"radio":false,"cot":false,"locker":false,"generator":false,"route_board":false},"claimJob":null,"workJob":null,"workDay":1,"workToday":0,"jobsCompleted":0,"orderSerial":0,"lastWorkId":"","rerollDay":0},"claims":{},"route":{},"day":1,"day_time":0.35,"high":0.0,"crash":0.0}

func _row(kind: String,before: Dictionary,after: Dictionary,extra: Dictionary = {}) -> Dictionary:
	var text: String = Probe.expected_toast(kind)
	var result := {"kind":kind,"before":before.duplicate(true),"after":after.duplicate(true),"events":[] if text.is_empty() else [{"kind":"toast","payload":{"text":text}}]}
	result.merge(extra,true); return result

func _brief(state: Dictionary) -> Dictionary:
	var o: Dictionary = state.office
	return {"cash":state.cash,"copper":state.copper,"routes":state.routes,"officeJobs":state.office_jobs,"claims":state.claims.duplicate(true),"route":state.route.duplicate(true),"owned":o.owned,"upgrades":o.upgrades.duplicate(true),"claimJob":o.claimJob,"workJob":o.workJob.duplicate(true) if o.workJob is Dictionary else null,"orderSerial":o.orderSerial,"jobsCompleted":o.jobsCompleted,"workToday":o.workToday,"day":state.day,"weapon":state.weapon,"paper_done":state.paper_done}

func _valid() -> Dictionary:
	var state: Dictionary = _base()
	var report := {"fixture":{"kind":"fresh_resources_only","cash":300,"copper":6,"writes":2},"initial":state.duplicate(true),"receipts":[],"route_receipts":[],"saves":[],"phases":[],"legs":[{"arrived":true,"inter_stop":true,"wall_ms":30000.0,"active_ms":29000.0}],"inputs":{"motion_frames":120,"mouse_motion":100,"keys":35,"menu_clicks":5,"capture_clicks":4},"loop":{"purchased":true,"spent":true,"initial_high":18000,"initial_smokes":1,"high_ms":18020.0,"crash_ms":8005.0},"epoch_replacements":2,"overflow":false,"canonical_roster_retained":true,"dependencies":[],"deaths":0,"arrests":0,"boss_starts":0,"attack_receipts":[],"wall_ms":500000.0}
	report.defense_driver = {"version":2,"combat_replans":0,"endpoint_route_attempts":0,"occluded_decisions":0}
	report.legs.clear()
	var intro_before: Dictionary = state.duplicate(true); state.cash = 290; state.rocks = 1
	report.receipts.append(_row("buy_rock",intro_before,state,{"events":[{"kind":"toast","payload":{"text":"- $10\n+ 1 rock"}}]}))
	intro_before = state.duplicate(true); state.rocks = 0; state.high = 18000; state.cred = 1; state.intro = true; state.rocks_smoked = 1
	report.receipts.append(_row("smoke",intro_before,state,{"events":[{"kind":"toast","payload":{"text":"· smoke a rock ·\nthe sun moves.\nbrain -4. shakes -50."}}]}))
	state.high = 0
	var sheets: Array = [["block_news","scrap_gate","pawn_sill"],["under_sign","corner_curb","bus_glass"],["laundry_sock","market_line","alley_can"],["church_step","project_meter","train_signal"]]
	var stop_by_id: Dictionary = {}
	for stop: Dictionary in Content.definition("src/systems/progression_routes.js","ROUTE_STOPS",[]): stop_by_id[stop.id] = stop
	state.route = {"stops":sheets[0].duplicate(),"cursor":0,"serial":1,"lastStopId":""}
	for sheet: int in range(3):
		for cursor: int in range(3):
			var before: Dictionary = state.duplicate(true); var id: String = sheets[sheet][cursor]
			var toast: String = stop_by_id[id].stamp
			if cursor < 2:
				state.route.cursor += 1; toast += "\n[%d/3 stamped]" % (cursor+1)
			else:
				state.routes += 1; state.cash += 6; state.cred += 1
				state.route = {"stops":sheets[sheet+1].duplicate(),"cursor":0,"serial":sheet+2,"lastStopId":id}
				if sheet == 2: state.office_available = true
				toast += "\n· ROUTE FILED %d ·  + $6 · + 1 cred\na new sheet is under the brick.%s" % [sheet+1,"\nthe leasing guy has a key in the lot." if sheet == 2 else ""]
			var row: Dictionary = _row("stamp",before,state,{"service":"route:"+id,"resolved":{"kind":"route","id":"route:"+id},"source_distance":20.0,"reachable":true,"events":[{"kind":"toast","payload":{"text":toast}}]})
			report.route_receipts.append(row); report.receipts.append(row.duplicate(true))
			report.legs.append({"service":"route:"+id,"arrived":true,"inter_stop":cursor > 0,"wall_ms":30000.0,"active_ms":29000.0})
	var before: Dictionary = state.duplicate(true)
	state.cash -= 40; state.copper -= 1; state.office.owned = true
	report.receipts.append(_row("lease",before,state))
	for id: String in ["desk","radio","cot"]:
		before = state.duplicate(true)
		state.cash -= {"desk":60,"radio":90,"cot":30}[id]
		state.copper -= 0 if id == "cot" else 2; state.office.upgrades[id] = true
		report.receipts.append(_row(id,before,state))
	before = state.duplicate(true); state.office.claimJob = {"id":"canal","stage":"survey"}
	report.receipts.append(_row("select_claim",before,state))
	before = state.duplicate(true); state.office.claimJob.stage = "file"
	report.receipts.append(_row("survey",before,state,{"service":"claim:canal:survey","resolved":{"kind":"office_field","id":"claim:canal:survey"},"source_distance":30.0,"reachable":true}))
	before = state.duplicate(true); state.office.claimJob.stage = "install"; state.cash -= 20; state.copper -= 1
	report.receipts.append(_row("file_claim",before,state))
	before = state.duplicate(true); state.office.claimJob = null; state.claims = {"canal":true}; state.cred += 2; state.paper_done = true
	report.receipts.append(_row("install",before,state,{"service":"claim:canal:sign","resolved":{"kind":"office_field","id":"claim:canal:sign"},"source_distance":30.0,"reachable":true}))
	before = state.duplicate(true); state.office.orderSerial = 1; state.office.lastWorkId = "canal"; state.office.workJob = {"id":"canal","stage":"inspect","serial":1}
	report.receipts.append(_row("work",before,state))
	before = state.duplicate(true); state.office.workJob.stage = "file"
	report.receipts.append(_row("inspect",before,state,{"service":"claim:canal:sign","resolved":{"kind":"office_field","id":"claim:canal:sign"},"source_distance":30.0,"reachable":true}))
	var pending: Dictionary = _brief(state)
	report.saves.append({"durable":true,"menu_loaded":true,"before":pending.duplicate(true),"stored":pending.duplicate(true),"after":pending.duplicate(true)})
	before = state.duplicate(true); state.cash += 6; state.office.workJob = null; state.office.jobsCompleted = 1; state.office.workToday = 1; state.office_jobs = 1
	report.receipts.append(_row("file_work",before,state))
	report.receipts.append(_row("disabled_cap",state,state,{"disabled":true}))
	var paid: Dictionary = _brief(state)
	report.saves.append({"durable":true,"menu_loaded":true,"before":paid.duplicate(true),"stored":paid.duplicate(true),"after":paid.duplicate(true)})
	state.day_time = 0.6; state.hp = 50; state.brain = 60; state.shakes = 90; state.wanted = 2
	before = state.duplicate(true); state.day += 1; state.day_time = 0.3; state.hp = 100; state.brain = 85; state.shakes = 100; state.wanted = 0; state.office.workToday = 0; state.office.workDay = state.day
	report.receipts.append(_row("sleep",before,state))
	before = state.duplicate(true); state.office.orderSerial = 2; state.office.workJob = {"id":"canal","stage":"inspect","serial":2}
	report.receipts.append(_row("work_next",before,state)); report.final = state.duplicate(true)
	for id: String in ["intro","routes","office_claim","work_restore","cot_day"]: report.phases.append({"id":id,"wall_ms":10000.0})
	for id: String in ["tony","smoke:block","lease_guy","office","office","office","office","claim:canal:survey","claim:canal:sign","claim:canal:sign"]: report.legs.append({"service":id,"arrived":true,"inter_stop":false,"wall_ms":10000.0,"active_ms":9000.0})
	return report

func _find(report: Dictionary,kind: String) -> Dictionary:
	for row: Dictionary in report.receipts:
		if row.kind == kind: return row
	return {}

func _attack() -> Dictionary:
	return {"geometry":{"target_id":"skid_sherri","distance":45.0,"alignment":1.0,"cooldown":0.0,"stun":0.0,"can_hit":true},"before_weapon":"fists","after_weapon":"pipe","before_cd":0.0,"after_cd":280.0,"active_ms":1000.0,"wall_ms":1200,"actors_before":{"skid_sherri":{"hp":12.0,"dead":false,"ordinary_reward":true}},"actors_after":{"skid_sherri":{"hp":-4.0,"dead":true}},"events":[{"kind":"actor_hit","payload":{"actor_id":"skid_sherri","damage":16}},{"kind":"actor_died","payload":{"actor_id":"skid_sherri"}},{"kind":"toast","payload":{"text":"+ a length of copper pipe\n(equipped.)"}},{"kind":"feed","payload":{"text":"picked up a length of copper pipe. things are escalating."}},{"kind":"player_attack","payload":{"used_weapon":"fists","hits":["skid_sherri"]}}]}

func _counterexamples() -> void:
	_check(Probe.assess(_valid()).is_empty(),"complete synthetic receipt chain satisfies validator (not gameplay proof)")
	for change: String in ["fixture_cash","fixture_copper","starting_hp","starting_weapon","starting_route","starting_office","starting_desk","starting_claim","starting_equipment","missing_stamp","duplicate_stamp","route_replaced","wrong_target","wrong_kind","radius_edge","occluded","route_cash","route_cred","route_lifetime","early_office","unknown_stop","early_far_stop","wrong_stamp_text","missing_lease","lease_price","desk_copper","radio_price","cot_price","duplicate_lease","wrong_order","skip_survey","free_filing","wrong_sign","missing_claim_cred","missing_paper","wrong_order_id","wrong_serial","uninspected_order","duplicate_payment","missing_cap","cap_enabled","wrong_saved_job","wrong_stored_cash","lost_paid_job","failed_save","failed_load","extra_epoch","missing_epoch","wrong_sleep_day","sleep_boundary","sleep_heal","sleep_shakes","sleep_reset","missing_next_work","wrong_final_routes","unbacked_final_weapon","missing_loop","short_high","short_crash","missing_phase","phase_timeout","tour_timeout","walk_timeout","walk_failure","route_budget","no_input","removed_actor","death","arrest","boss","dependency","overflow"]:
		var report: Dictionary = _valid()
		match change:
			"fixture_cash": report.fixture.cash = 301
			"fixture_copper": report.fixture.copper = 7
			"starting_hp": report.initial.hp = 101
			"starting_weapon": report.initial.weapon = "pipe"
			"starting_route": report.initial.route = report.route_receipts[0].before.route.duplicate(true)
			"starting_office": report.initial.office.owned = true
			"starting_desk": report.initial.office.upgrades.desk = true
			"starting_claim": report.initial.claims = {"canal":true}
			"starting_equipment": report.initial.equip.coat = "trench"
			"missing_stamp": report.route_receipts.pop_back()
			"duplicate_stamp": report.route_receipts[1] = report.route_receipts[0].duplicate(true)
			"route_replaced": report.route_receipts[1].before.route.serial += 1
			"wrong_target": report.route_receipts[0].service = "route:under_sign"
			"wrong_kind": report.route_receipts[0].resolved.kind = "office_field"
			"radius_edge": report.route_receipts[0].source_distance = 58.0
			"occluded": _find(report,"survey").reachable = false
			"route_cash": report.route_receipts[2].after.cash += 1
			"route_cred": report.route_receipts[5].after.cred += 1
			"route_lifetime": report.route_receipts[8].after.routes += 1
			"early_office": report.route_receipts[8].after.office_available = false
			"unknown_stop": report.route_receipts[0].before.route.stops[0] = "invented"
			"early_far_stop": report.route_receipts[0].before.route.stops[0] = "ditch_gauge"
			"wrong_stamp_text": report.route_receipts[0].events[0].payload.text = "done"
			"missing_lease": report.receipts.erase(_find(report,"lease"))
			"lease_price": _find(report,"lease").after.cash += 1
			"desk_copper": _find(report,"desk").after.copper += 1
			"radio_price": _find(report,"radio").after.cash += 1
			"cot_price": _find(report,"cot").after.cash += 1
			"duplicate_lease": report.receipts.append(_find(report,"lease").duplicate(true))
			"wrong_order": var last: Dictionary = report.receipts.pop_back(); report.receipts.insert(0,last)
			"skip_survey": _find(report,"survey").after.office.claimJob.stage = "install"
			"free_filing": _find(report,"file_claim").after.cash += 20
			"wrong_sign": _find(report,"install").resolved.id = "claim:alley:sign"
			"missing_claim_cred": _find(report,"install").after.cred -= 1
			"missing_paper": _find(report,"install").after.paper_done = false
			"wrong_order_id": _find(report,"work").after.office.workJob.id = "alley"
			"wrong_serial": _find(report,"work").after.office.workJob.serial = 2
			"uninspected_order": _find(report,"file_work").before.office.workJob.stage = "inspect"
			"duplicate_payment": _find(report,"file_work").after.cash += 6
			"missing_cap": report.receipts.erase(_find(report,"disabled_cap"))
			"cap_enabled": _find(report,"disabled_cap").disabled = false
			"wrong_saved_job": report.saves[0].after.workJob.serial = 2
			"wrong_stored_cash": report.saves[0].stored.cash += 6
			"lost_paid_job": report.saves[1].after.workJob = {"id":"canal","stage":"file","serial":1}
			"failed_save": report.saves[0].durable = false
			"failed_load": report.saves[1].menu_loaded = false
			"extra_epoch": report.epoch_replacements = 3
			"missing_epoch": report.epoch_replacements = 1
			"wrong_sleep_day": _find(report,"sleep").after.day -= 1
			"sleep_boundary": _find(report,"sleep").before.day_time = 0.3
			"sleep_heal": _find(report,"sleep").after.hp -= 1
			"sleep_shakes": _find(report,"sleep").after.shakes = 0
			"sleep_reset": _find(report,"sleep").after.office.workToday = 1
			"missing_next_work": _find(report,"work_next").after.office.workJob = null
			"wrong_final_routes": report.final.routes = 4
			"unbacked_final_weapon": report.final.weapon = "pipe"
			"missing_loop": report.loop.spent = false
			"short_high": report.loop.high_ms = 17000
			"short_crash": report.loop.crash_ms = 7000
			"missing_phase": report.phases.pop_back()
			"phase_timeout": report.phases[0].wall_ms = 120000
			"tour_timeout": report.wall_ms = Probe.TOTAL_LIMIT
			"walk_timeout": report.legs[0].wall_ms = 120000
			"walk_failure": report.legs[0].arrived = false
			"route_budget": report.legs[1].active_ms = 60000
			"no_input": report.inputs.motion_frames = 0
			"removed_actor": report.canonical_roster_retained = false
			"death": report.deaths = 1
			"arrest": report.arrests = 1
			"boss": report.boss_starts = 1
			"dependency": report.dependencies = ["not implemented"]
			"overflow": report.overflow = true
		_check(not Probe.assess(report).is_empty(),"validator rejects "+change)
	_check(Probe.expected_toast("lease") == "- $40 · - 1 copper\n+ one key\nthe office is yours in the sense that no one stopped you.","source lease receipt retained literally")
	_check(Probe.expected_toast("file_work") == "· ORDER 1 FILED ·\ngross $23. chair rental $17.\nnet + $6","source gross/chair/net receipt retained literally")
	_check(Probe.expected_toast("sleep") == "you slept at the office.\nthe office opened before you did.\nthe day is the next day.","source cot receipt retained literally")
	for change: String in ["nan_route_distance","nan_field_distance","nan_phase","nan_total","nan_walk","missing_legs","missing_buy","free_rock","fake_smoke","unbacked_live_weapon"]:
		var report: Dictionary = _valid()
		match change:
			"nan_route_distance": report.route_receipts[0].source_distance = NAN
			"nan_field_distance": _find(report,"survey").source_distance = NAN
			"nan_phase": report.phases[0].wall_ms = NAN
			"nan_total": report.wall_ms = NAN
			"nan_walk": report.legs[0].active_ms = NAN
			"missing_legs": report.legs.clear()
			"missing_buy": report.receipts.erase(_find(report,"buy_rock"))
			"free_rock": _find(report,"buy_rock").after.cash += 10
			"fake_smoke": _find(report,"smoke").after.rocks = 1
			"unbacked_live_weapon": report.weapon_changes = [{"from":"fists","to":"pipe"},{"from":"pipe","to":"fists"}]
		_check(not Probe.assess(report).is_empty(),"finite physical/source provenance rejects "+change)
	_check(Probe.weapon_chain([]).ok and Probe.weapon_chain([]).final_weapon == "fists","tour without combat does not fabricate required attacks")
	_check(Probe.weapon_chain([_attack()]).ok and Probe.weapon_chain([_attack()]).final_weapon == "pipe","actual ordinary defense reward chain may earn pipe")
	for change: String in ["starting_pipe","early_shoe","missing_death","already_dead","wrong_hit","missing_toast","missing_feed","feed_order","wrong_used_weapon","cooldown","living_after"]:
		var row: Dictionary = _attack()
		match change:
			"starting_pipe": row.before_weapon = "pipe"
			"early_shoe": row.after_weapon = "shoe"
			"missing_death": row.events.remove_at(1)
			"already_dead": row.actors_before.skid_sherri.dead = true
			"wrong_hit": row.events[-1].payload.hits = []
			"missing_toast": row.events.remove_at(2)
			"missing_feed": row.events.remove_at(3)
			"feed_order": row.events.insert(0,row.events.pop_at(3))
			"wrong_used_weapon": row.events[-1].payload.used_weapon = "pipe"
			"cooldown": row.before_cd = 1.0
			"living_after": row.actors_after.skid_sherri.hp = 1.0
		_check(not Probe.weapon_chain([row]).ok,"defense provenance rejects "+change)

func _input_checks() -> void:
	var actions: Array[StringName] = [&"office_qa_left",&"office_qa_right",&"office_qa_forward",&"office_qa_back"]
	for action: StringName in actions: InputMap.add_action(action,0.5)
	for angle: float in [0.0,0.003,0.1,0.5,PI*0.25,PI*0.49,PI*0.5,PI*0.75,PI,PI*1.3,PI*1.75]:
		for strength: float in [0.0,0.005,0.1,0.4,1.0,2.0]:
			for action: StringName in actions: Input.action_release(action)
			var desired := Vector2(cos(angle),sin(angle))*strength; var raw: Vector2 = Probe.encode_motion(desired)
			if absf(raw.x) > 0.000001: Input.action_press(actions[1] if raw.x > 0 else actions[0],absf(raw.x))
			if absf(raw.y) > 0.000001: Input.action_press(actions[3] if raw.y > 0 else actions[2],absf(raw.y))
			_check(Input.get_vector(actions[0],actions[1],actions[2],actions[3]).distance_to(desired.limit_length(1.0)) < 0.00001,"real input radial deadzone preserves intended vector")
	for action: StringName in actions: Input.action_release(action); InputMap.erase_action(action)
	for pair: Array in [["office","office"],["office","lease_guy"],["vendor","tony"],["route","route:canal_gauge"],["office_field","claim:canal:survey"]]:
		_check(Probe.interaction_matches({"kind":pair[0],"id":pair[1]},pair[1]),"actual intended resolver matches "+str(pair[1]))
		_check(not Probe.interaction_matches({"kind":"wrong","id":pair[1]},pair[1]),"same ID with wrong resolver kind refuses")
	_check(Probe.interaction_matches({"kind":"smoke","id":"block"},"smoke:block"),"Block world-service ID maps to canonical source action")

func _defense_checks() -> void:
	_check(Probe.CombatDriver == Driver,"Office and Tony share the same test-only geometry/work policy")
	_check(not Driver.combat_attack_ready(45.0,1.0,0.0,0.0,false),"wall-occluded45px target never produces an accepted driver click")
	_check(Driver.combat_attack_ready(45.0,1.0,0.0,0.0,true),"same target is actionable once actual LOS is clear")
	var origin := Vector2(1000,840); var target := Vector2(1045,840)
	var ring: Array[Vector2] = Driver.melee_ring(origin,target)
	_check(ring.size() == 24,"wall-aware candidate set remains finite24")
	for point: Vector2 in ring:
		var distance: float = point.distance_to(target)
		_check(point.is_finite() and (absf(distance-44.0) < 0.001 or absf(distance-30.0) < 0.001),"all candidate endpoints retain authored melee radii")
	_check(Driver.melee_ring(Vector2.INF,target).is_empty(),"invalid origin cannot manufacture a certified approach")
	_check(Driver.combat_route_reason({},"skid_sherri",target,1,7,false,false) == "no_cached_route","occlusion without a path requires planning rather than stationary swings")
	var plan := {"target_id":"skid_sherri","target_center":target,"phase":1,"revision":7}
	_check(Driver.combat_route_reason(plan,"skid_sherri",target,1,7,true,true).is_empty(),"certified unchanged path can be retained")
	_check(Driver.combat_route_reason(plan,"lurch",target,1,7,true,true) == "target_changed","a different defender cannot inherit the prior actor's path")
	_check(Driver.combat_route_reason(plan,"skid_sherri",target+Vector2(24.1,0),1,7,true,true) == "target_drift","moving defender invalidates stale endpoint")
	_check(Driver.combat_route_reason(plan,"skid_sherri",target,2,7,true,true) == "phase_changed","phase change invalidates the captured route")
	_check(Driver.combat_route_reason(plan,"skid_sherri",target,1,8,true,true) == "collision_revision_changed","moving geometry invalidates route")
	_check(Driver.combat_route_reason(plan,"skid_sherri",target,1,7,false,true) == "endpoint_no_longer_melee_clear","lost range/LOS cannot retain destination permission")
	_check(Driver.combat_route_reason(plan,"skid_sherri",target,1,7,true,false) == "next_segment_blocked","new live peer obstruction stops cached approach")
	_check(not Driver.combat_replan_ready(1499,1000,0) and Driver.combat_replan_ready(1500,1000,31) and not Driver.combat_replan_ready(1500,1000,32),"planner preserves500ms minimum and whole-tour32-plan ceiling")
	var valid := {"defense_driver":{"version":2,"combat_replans":1,"endpoint_route_attempts":4,"occluded_decisions":2},"attack_receipts":[_attack()]}
	_check(Probe.defense_errors(valid).is_empty(),"bounded driver with fresh certified click evidence passes")
	for change: String in ["missing_driver","replans","attempts","negative","fraction","nonfinite","missing_geometry","occluded","range","aim","cooldown","stun","nonfinite_range","empty_target"]:
		var report: Dictionary = valid.duplicate(true)
		var geometry: Dictionary = report.attack_receipts[0].geometry
		match change:
			"missing_driver": report.erase("defense_driver")
			"replans": report.defense_driver.combat_replans = 33
			"attempts": report.defense_driver.endpoint_route_attempts = 5
			"negative": report.defense_driver.occluded_decisions = -1
			"fraction": report.defense_driver.combat_replans = 0.5
			"nonfinite": report.defense_driver.endpoint_route_attempts = INF
			"missing_geometry": report.attack_receipts[0].erase("geometry")
			"occluded": geometry.can_hit = false
			"range": geometry.distance = 57.0
			"aim": geometry.alignment = 0.985
			"cooldown": geometry.cooldown = 1.0
			"stun": geometry.stun = 1.0
			"nonfinite_range": geometry.distance = NAN
			"empty_target": geometry.target_id = ""
		_check(not Probe.defense_errors(report).is_empty(),"defense acceptance rejects "+change)

func _run() -> void:
	_route_recovery_checks()
	await _walking_recovery_checks()
	_check(walking_completed,"inherited async walk counterexamples completed before acceptance")
	_corner_checks()
	_check(corner_completed,"short-step and bounded outward-join witnesses completed")
	await _service_range_checks()
	_check(service_completed,"strict resolver and bounded aim coroutine witnesses complete")
	_counterexamples(); _input_checks(); _defense_checks()
	var source: String = FileAccess.get_file_as_string("res://tests/office_acceptance_probe.gd")
	var assignments: Array[String] = []
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("game.runtime.") and " = " in line: assignments.append(line.strip_edges())
	_check(assignments == ["game.runtime.p.cash = 300","game.runtime.p.copper = 6"],"driver's sole authored resource writes are approved initial fixture")
	for forbidden: String in ["game.runtime.fresh(","game.runtime.restore(","game.runtime.attack(","game.runtime.state.random_float(","game._new_game(","game._load(","game._manual_save(","game._resume(",".pressed.emit(","damage_actor("]:
		_check(forbidden not in source,"driver cannot bypass normal input via "+forbidden)
	for failure: String in failures: push_error(failure)
	print("3D OFFICE ACCEPTANCE CONTRACT: ","PASS" if failures.is_empty() else "FAIL"," (",checks," checks; synthetic assessor counterexamples, not native progression)")
	quit(0 if failures.is_empty() else 1)
