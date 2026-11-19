extends "res://tests/boss_acceptance_probe.gd"
## Acceptance-validator counterexamples. These dictionaries are not fight evidence.
const Probe = preload("res://tests/boss_acceptance_probe.gd")
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
	func _contact_peers(_body: Dictionary) -> Array[Dictionary]: return []
class RecoveryWorld:
	extends Node3D
	func is_clear_position(_point: Vector3) -> bool: return true

var recovery_driver_checks := false
var recovery_routes_available := false
var recovery_endpoints_clear := true
var recovery_segments_clear := false
var recovery_route_calls := 0

func _combat_endpoint(_point: Vector3,_target_record: Dictionary,_peers: Array[Dictionary]) -> bool:
	return recovery_endpoints_clear
func _resident_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	recovery_route_calls += 1
	return PackedVector3Array([from,to]) if recovery_routes_available else PackedVector3Array()
func _combat_segment(from: Vector3,to: Vector3) -> Dictionary:
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

func _valid() -> Dictionary:
	return {"driver":{"version":2,"qa_full":true,"combat_replans":0,"endpoint_route_attempts":0},"fixture":{"kind":"fresh_cash_only","cash_grant":25,"weapon":"fists","hp":100},"initial":{"cash":25,"hp":100,"max_hp":100,"weapon":"fists","rocks":0,"cred":0,"brain":70,"offenses":0,"rocks_smoked":0,"speed":2.2,"cart_mounted":false,"equip":{"coat":null,"hat":null,"shoes":null,"tool":null},"inventory":[]},"costs":[10,5,5,5],"fight":{"started":true,"won":true,"tony_dead":true,"globals_clear":true,"quest_done":true,"shoe_reward":true,"fists_only":true,"cooldowns_valid":true,"wall_ms":8000.0,"active_ms":7500.0,"phases":[1,2,3],"adds":["sherri_boss_a","sherri_boss_b"],"damage":205,"high_hits":8,"accepted_attacks":8},"loop":{"purchased":true,"spent":true,"smokes":1,"initial_high":18000.0,"high_ms":18020.0,"crash_ms":8005.0,"ending_seen":true,"continued":true},"deaths":0,"arrests":0,"epoch_replacements":0,"dependencies":[],"canonical_roster_retained":true,"inputs":{"motion_frames":2,"mouse_motion":2,"keys":2,"clicks":2,"capture_clicks":2}}
func _attack_row(before: String,after: String,id: String,ordinary: bool,victory: bool,active: float) -> Dictionary:
	# Synthetic evidence-validator fixtures only; no model damage or fight claim.
	var events: Array[Dictionary] = [
		{"kind":"actor_hit","payload":{"actor_id":id,"damage":20,"weapon":after}},
		{"kind":"actor_died","payload":{"actor_id":id}}]
	if before != after:
		var name_value: String = Content.load_content().catalogs.weapons[after].n
		events.append({"kind":"toast","payload":{"text":"+ "+name_value+"\n(equipped.)"}})
		events.append({"kind":"feed","payload":{"text":"picked up "+name_value+". things are escalating."}})
	events.append({"kind":"player_attack","payload":{"used_weapon":before,"hits":[id],"connected":true}})
	var pre: Dictionary = {}; var post: Dictionary = {}
	pre[id] = {"hp":15.0,"dead":false,"ordinary_reward":ordinary}; post[id] = {"hp":-5.0,"dead":true}
	return {"geometry":{"target_id":id,"distance":44.0,"alignment":1.0,"cooldown":0.0,"stun":0.0,"can_hit":true},"before_weapon":before,"after_weapon":after,"before_cd":0.0,"after_cd":Content.load_content().catalogs.weapons[before].cd,"active_ms":active,"wall_ms":active+100.0,"boss_before":true,"quest_before":false,"victory_after":victory,"events":events,"actors_before":pre,"actors_after":post}
func _earned_rows() -> Array[Dictionary]:
	return [_attack_row("fists","pipe","sherri_boss_a",true,false,1000.0),_attack_row("pipe","shoe","tony",false,true,1400.0)]
func _weapon_checks() -> void:
	var rows: Array[Dictionary] = _earned_rows()
	var result: Dictionary = Probe.weapon_chain(rows)
	_check(result.ok and not result.fists_only and result.weapons_used == ["fists","pipe"],"actual source reward evidence permits earned pipe and explicitly denies fists-only")
	_check(result.transitions.size() == 2 and result.transitions[0].actor_id == "sherri_boss_a" and result.transitions[1].actor_id == "tony","pipe and special Tony shoe have separate source death provenance")
	var report: Dictionary = _valid(); report.contract_mode = "source_earned"; report.attack_receipts = rows; report.fight.fists_only = false
	_check(Probe.assess(report).is_empty(),"source-earned acceptance is a separate explicit contract")
	_check(not Probe.assess(report,"fists_only").is_empty(),"same earned-pipe receipt still fails optional strict fists-only")
	rows = [_attack_row("fists","shoe","tony",false,true,1000.0)]
	result = Probe.weapon_chain(rows)
	_check(result.ok and result.fists_only,"post-fatal shoe snapshot does not rewrite pre-attack fists/used_weapon")
	# Source special death may emit actor_died before actor_hit in the fatal call.
	var swap: Dictionary = rows[0].events[0]; rows[0].events[0] = rows[0].events[1]; rows[0].events[1] = swap
	_check(Probe.weapon_chain(rows).ok,"source Tony fatal event order remains valid")
	for change: String in ["starting_pipe","used_weapon","missing_death","dead_before","hp_after","nonordinary","missing_toast","missing_feed","unbacked_switch","early_shoe","wrong_kill","missing_victory","cooldown","premature_quest","nan_health","nan_cooldown","feed_order","reward_order"]:
		rows = _earned_rows()
		match change:
			"starting_pipe": rows[0].before_weapon = "pipe"
			"used_weapon": rows[0].events[-1].payload.used_weapon = "pipe"
			"missing_death": rows[0].events.remove_at(1)
			"dead_before": rows[0].actors_before.sherri_boss_a.dead = true
			"hp_after": rows[0].actors_after.sherri_boss_a.hp = 1.0
			"nonordinary": rows[0].actors_before.sherri_boss_a.ordinary_reward = false
			"missing_toast": rows[0].events.remove_at(2)
			"missing_feed": rows[0].events.remove_at(3)
			"unbacked_switch": rows[1].before_weapon = "brick"; rows[1].events[-1].payload.used_weapon = "brick"
			"early_shoe": rows[0] = _attack_row("fists","shoe","sherri_boss_a",true,false,1000.0)
			"wrong_kill": rows[0] = _attack_row("fists","brick","sherri_boss_a",true,false,1000.0)
			"missing_victory": rows[1].victory_after = false
			"cooldown": rows[1].after_cd = 1.0
			"premature_quest": rows[1].quest_before = true
			"nan_health": rows[0].actors_after.sherri_boss_a.hp = NAN
			"nan_cooldown": rows[0].before_cd = NAN
			"feed_order": rows[0].events.insert(0,rows[0].events.pop_at(3))
			"reward_order": rows[0].events.insert(0,rows[0].events.pop_at(2))
		_check(not Probe.weapon_chain(rows).ok,"source reward chain rejects "+change)
	rows = _earned_rows(); rows.insert(1,_attack_row("pipe","pipe","skid_sherri",true,false,1300.0)); rows[2].active_ms = 1600.0
	_check(not Probe.weapon_chain(rows).ok,"previous pipe cooldown320ms cannot be replaced by fists280ms")
	report = _valid(); report.contract_mode = "source_earned"; report.attack_receipts = _earned_rows(); report.initial.weapon = "pipe"
	_check(not Probe.assess(report).is_empty(),"source-earned contract still forbids starting-pipe fixture")
	report = _valid(); report.contract_mode = "source_earned"
	_check(not Probe.assess(report).is_empty(),"source-earned mode cannot pass without actual attack receipts")
func _steering_checks() -> void:
	_check(Probe.launch_error(PackedStringArray(["--qa-full"])).is_empty(),"exact QA flag permits scene construction")
	for arguments: PackedStringArray in [PackedStringArray(),PackedStringArray(["--qa-tour"]),PackedStringArray(["--qa-full=false"]),PackedStringArray(["--output=--qa-full"])]:
		_check(not Probe.launch_error(arguments).is_empty(),"missing exact QA launch refuses before scene/save creation")
	# Observed frozen332 late-swing position is north of CORNER's y820 back wall.
	# Its capsule touches y807.95; Tony center is inside at y842.050, not his top-left.
	var player := Vector2(1573.812,807.95); var target := Vector2(1608.44043,842.05005)
	var distance: float = player.distance_to(target)
	_check(distance < 57.0 and not Probe.combat_attack_ready(distance,1.0,0.0,0.0,false),"observed near-range brick-wall swing refuses despite aim/range/cooldown")
	_check(Probe.combat_attack_ready(distance,1.0,0.0,0.0,true),"same normal melee facts require actual clear LOS")
	for values: Array in [[57.0,1.0,0.0,0.0],[44.0,0.985,0.0,0.0],[44.0,1.0,0.001,0.0],[44.0,1.0,0.0,0.001],[NAN,1.0,0.0,0.0],[44.0,INF,0.0,0.0],[44.0,1.0,NAN,0.0],[44.0,1.0,0.0,-INF]]:
		_check(not Probe.combat_attack_ready(values[0],values[1],values[2],values[3],true),"strict finite melee input guards refuse "+str(values))
	for origin: Vector2 in [player,target,target+Vector2(0,100),target+Vector2(-100,0)]:
		var points: Array[Vector2] = Probe.melee_ring(origin,target)
		_check(points.size() == 24,"finite24-point candidate set")
		var seen: Array[Vector2] = []; var prior := -1.0
		for point: Vector2 in points:
			var radius: float = point.distance_to(target); var score: float = point.distance_squared_to(origin)
			_check(point.is_finite() and (absf(radius-44.0) < 0.001 or absf(radius-30.0) < 0.001) and point not in seen and score >= prior-0.001,"melee candidates remain unique/range-bounded/nearest-first")
			seen.append(point); prior = score
	_check(Probe.melee_ring(Vector2.INF,target).is_empty() and Probe.melee_ring(player,Vector2(NAN,0)).is_empty(),"non-finite targets cannot create route candidates")
	var plan := {"target_id":"tony","target_center":target,"phase":2,"revision":7}
	_check(Probe.combat_route_reason(plan,"tony",target+Vector2(24,0),2,7,true,true).is_empty(),"24px target drift retains an otherwise valid route")
	_check(Probe.combat_route_reason(plan,"tony",target+Vector2(24.01,0),2,7,true,true) == "target_drift","larger target drift invalidates cached path")
	_check(Probe.combat_route_reason({},"tony",target,2,7,true,true) == "no_cached_route","empty route cannot masquerade as successful steering")
	_check(Probe.combat_route_reason(plan,"sherri_boss_a",target,2,7,true,true) == "target_changed","new target cannot inherit Tony's approach")
	_check(Probe.combat_route_reason(plan,"tony",target,3,7,true,true) == "phase_changed","new phase refreshes candidate route")
	_check(Probe.combat_route_reason(plan,"tony",target,2,8,true,true) == "collision_revision_changed","changed actual geometry invalidates route")
	_check(Probe.combat_route_reason(plan,"tony",target,2,7,false,true) == "endpoint_no_longer_melee_clear","lost endpoint LOS/range rejects old goal")
	_check(Probe.combat_route_reason(plan,"tony",target,2,7,true,false) == "next_segment_blocked","new live/static obstruction rejects cached segment")
	_check(Probe.combat_route_reason(plan,"tony",Vector2.INF,2,7,true,true) == "target_drift","non-finite drift invalidates route")
	_check(not Probe.combat_replan_ready(1499,1000,0) and Probe.combat_replan_ready(1500,1000,0),"500ms planner budget boundary")
	_check(Probe.combat_replan_ready(1500,1000,31) and not Probe.combat_replan_ready(1500,1000,32) and not Probe.combat_replan_ready(1500,1000,-1),"32-replan hard cap cannot reset or go negative")
	for change: String in ["missing_driver","old_driver","missing_flag","replan_cap","attempt_cap","negative_work","nan_work","fractional_work"]:
		var report: Dictionary = _valid()
		match change:
			"missing_driver": report.erase("driver")
			"old_driver": report.driver.version = 1
			"missing_flag": report.driver.qa_full = false
			"replan_cap": report.driver.combat_replans = 33
			"attempt_cap": report.driver.combat_replans = 1; report.driver.endpoint_route_attempts = 5
			"negative_work": report.driver.combat_replans = -1
			"nan_work": report.driver.endpoint_route_attempts = NAN
			"fractional_work": report.driver.combat_replans = 0.5
		_check(not Probe.assess(report).is_empty(),"driver receipt rejects "+change)
	for change: String in ["missing","wall","range","aim","cooldown","stun"]:
		var report: Dictionary = _valid(); report.contract_mode = "source_earned"; report.attack_receipts = _earned_rows()
		match change:
			"missing": report.attack_receipts[0].erase("geometry")
			"wall": report.attack_receipts[0].geometry.can_hit = false
			"range": report.attack_receipts[0].geometry.distance = 57.0
			"aim": report.attack_receipts[0].geometry.alignment = 0.985
			"cooldown": report.attack_receipts[0].geometry.cooldown = 1.0
			"stun": report.attack_receipts[0].geometry.stun = 1.0
		_check(not Probe.assess(report).is_empty(),"accepted attack must have actual current geometry: "+change)
func _run() -> void:
	_route_recovery_checks()
	_weapon_checks()
	_steering_checks()
	# Exercise the actual circular deadzone, not a mirrored hand-written decoder.
	var actions: Array[StringName] = [&"boss_qa_left",&"boss_qa_right",&"boss_qa_forward",&"boss_qa_back"]
	for action: StringName in actions: InputMap.add_action(action,0.5)
	for angle: float in [0.0,0.003,0.1,0.5,PI*0.25,PI*0.49,PI*0.5,PI*0.75,PI,PI*1.3,PI*1.75]:
		for strength: float in [0.0,0.005,0.1,0.4,1.0,2.0]:
			for action: StringName in actions: Input.action_release(action)
			var desired := Vector2(cos(angle),sin(angle))*strength
			var raw: Vector2 = Probe.encode_motion(desired)
			if absf(raw.x) > 0.000001: Input.action_press(actions[1] if raw.x > 0 else actions[0],absf(raw.x))
			if absf(raw.y) > 0.000001: Input.action_press(actions[3] if raw.y > 0 else actions[2],absf(raw.y))
			var observed: Vector2 = Input.get_vector(actions[0],actions[1],actions[2],actions[3])
			_check(observed.distance_to(desired.limit_length(1.0)) < 0.00001,"actual radial input preserves direction and speed %s/%s" % [angle,strength])
	for action: StringName in actions: Input.action_release(action); InputMap.erase_action(action)
	_check(Probe.interaction_matches({"kind":"vendor","id":"tony"},"tony"),"actual intended vendor receipt ends approach")
	_check(Probe.interaction_matches({"kind":"smoke","id":"block"},"smoke:block"),"actual intended Block receipt ends approach")
	for action: Dictionary in [{},{"kind":"resident","id":"tony"},{"kind":"vendor","id":"pete"},{"kind":"cash","id":"block"},{"kind":"smoke","id":"market"}]:
		_check(not Probe.interaction_matches(action,"tony") and not Probe.interaction_matches(action,"smoke:block"),"unrelated nearby interaction cannot satisfy destination")
	_check(Probe.assess(_valid()).is_empty(),"all declared receipts can satisfy acceptance schema")
	for key: String in ["started","won","tony_dead","globals_clear","quest_done","shoe_reward","fists_only","cooldowns_valid"]:
		var row: Dictionary = _valid(); row.fight[key] = false
		_check(not Probe.assess(row).is_empty(),"missing actual fight receipt refuses "+key)
	for key: String in ["wall_ms","active_ms"]:
		for value: float in [0.0,-1.0,90000.0,90000.01,INF,NAN]:
			var row: Dictionary = _valid(); row.fight[key] = value
			_check(not Probe.assess(row).is_empty(),"strict finite below90s boundary "+key+" "+str(value))
	for key: String in ["damage","high_hits","accepted_attacks"]:
		var row: Dictionary = _valid(); row.fight[key] = 199 if key == "damage" else 0
		_check(not Probe.assess(row).is_empty(),"injected or unobserved damage cannot pass "+key)
	for key: String in ["phases","adds"]:
		var row: Dictionary = _valid(); row.fight[key] = [1,3] if key == "phases" else ["one_add"]
		_check(not Probe.assess(row).is_empty(),"omitted source encounter behavior refuses "+key)
	for ids: Array in [["sherri_boss_a","sherri_boss_a"],["sherri_boss_a","unknown_add"]]:
		var row: Dictionary = _valid(); row.fight.adds = ids
		_check(not Probe.assess(row).is_empty(),"duplicate or substituted add cannot pass")
	for key: String in ["purchased","spent","ending_seen","continued"]:
		var row: Dictionary = _valid(); row.loop[key] = false
		_check(not Probe.assess(row).is_empty(),"missing actual loop/ending receipt refuses "+key)
	for key: String in ["smokes","initial_high","high_ms","crash_ms"]:
		var row: Dictionary = _valid(); row.loop[key] = 2 if key == "smokes" else 6000.0
		_check(not Probe.assess(row).is_empty(),"alternate/refilled/incomplete loop refuses "+key)
	for key: String in ["high_ms","crash_ms"]:
		for value: float in [INF,NAN]:
			var row: Dictionary = _valid(); row.loop[key] = value
			_check(not Probe.assess(row).is_empty(),"non-finite loop cannot pass "+key)
	for key: String in ["cash","hp","max_hp","weapon","rocks","cred","brain","offenses","rocks_smoked","speed","cart_mounted"]:
		var row: Dictionary = _valid()
		row.initial[key] = "shoe" if key == "weapon" else (true if key == "cart_mounted" else 999)
		_check(not Probe.assess(row).is_empty(),"honest fixture label cannot hide changed actual start "+key)
	for slot: String in ["coat","hat","shoes","tool"]:
		var row: Dictionary = _valid(); row.initial.equip[slot] = "prearmed_bonus"
		_check(not Probe.assess(row).is_empty(),"unearned equipment refuses "+slot)
	for key: String in ["deaths","arrests","epoch_replacements"]:
		var row: Dictionary = _valid(); row[key] = 1
		_check(not Probe.assess(row).is_empty(),"failure lifecycle cannot be hidden "+key)
	for key: String in ["motion_frames","mouse_motion","keys","clicks","capture_clicks"]:
		var row: Dictionary = _valid(); row.inputs[key] = 0
		_check(not Probe.assess(row).is_empty(),"direct-call substitute lacks controller evidence "+key)
	var row: Dictionary = _valid(); row.costs = [0,5,5,5]
	_check(not Probe.assess(row).is_empty(),"free pre-fight rock cannot pass")
	row = _valid(); row.fixture.hp = 999
	_check(not Probe.assess(row).is_empty(),"boosted HP fixture cannot pass")
	row = _valid(); row.fixture.weapon = "shoe"
	_check(not Probe.assess(row).is_empty(),"post-victory weapon cannot pre-arm fixture")
	row = _valid(); row.dependencies = ["tony_add_placement"]
	_check(not Probe.assess(row).is_empty(),"missing physical adds cannot pass")
	row = _valid(); row.canonical_roster_retained = false
	_check(not Probe.assess(row).is_empty(),"filtered source roster cannot pass")
	row = _valid(); row.initial.inventory = [{"id":"extra_resource"}]
	_check(not Probe.assess(row).is_empty(),"unearned starting inventory cannot pass")
	if failures.is_empty(): print("3D BOSS ACCEPTANCE CONTRACT: PASS (%d counterexample checks; no simulated fight claim)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D BOSS ACCEPTANCE CONTRACT: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
