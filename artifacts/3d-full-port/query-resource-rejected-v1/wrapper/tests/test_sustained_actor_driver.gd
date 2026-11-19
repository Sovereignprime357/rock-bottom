extends SceneTree
const Driver = preload("sustained_actor_driver.gd")
var checks := 0
var failures: Array[String] = []
var completed_groups := 0

class Owner:
	extends RefCounted
	var p := {"x":0.0,"y":0.0,"w":24.0,"h":28.0,"hp":100.0,"wanted":4.0,"shakes":20.0,"stunT":0.0,"speed":2.2}
	var s := {"mode":"playing"}
	var npcs: Array[Dictionary] = []
	var rng_seed := 432484078
	func player_center() -> Vector2: return Vector2(p.x+p.w*0.5,p.y+p.h*0.5)
class Space:
	extends RefCounted
	var host: RefCounted
	var _collision_revision := 49
	var calls := 0
	var mode := "clear"
	var peers: Array[Dictionary] = []
	var replace_on_query := ""
	var replace_on_peers := ""
	var queries: Array[Dictionary] = []
	func _contact_peers(_body: Dictionary) -> Array[Dictionary]:
		if replace_on_peers == "p": host.p = host.p.duplicate(true); replace_on_peers = ""
		elif replace_on_peers == "s": host.s = host.s.duplicate(true); replace_on_peers = ""
		return peers.duplicate(true)
	func move_body(body: Dictionary,goal: Vector2) -> Dictionary:
		calls += 1
		var from := Vector2(body.x,body.y)
		queries.append({"body":body.duplicate(true),"goal":goal})
		if replace_on_query == "p": host.p = host.p.duplicate(true); replace_on_query = ""
		elif replace_on_query == "s": host.s = host.s.duplicate(true); replace_on_query = ""
		var blocked: bool = mode == "wall" or (mode == "short_only" and goal.distance_to(from) <= 1.001 and goal.x > from.x+0.9)
		if mode == "malformed": return {"blocked":false,"position":Vector2.INF}
		return {"blocked":blocked,"body_contact":mode == "peer","position":from if blocked else (goal+Vector2(0,0.01) if mode == "slide" else goal)}

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _fixture() -> Dictionary:
	var host := Owner.new(); var space := Space.new(); space.host = host
	var point: Vector2 = host.player_center()
	var policy: RefCounted = Driver.new(space,host,PackedVector2Array([point,point+Vector2(200,0),point]))
	return {"host":host,"space":space,"driver":policy}
func _source(f: Dictionary) -> Array:
	return [f.host.p.duplicate(true),f.host.s.duplicate(true),f.host.npcs.duplicate(true),f.host.rng_seed]
func _peer(id: String,center: Vector2) -> Dictionary:
	return {"id":id,"x":center.x-14,"y":center.y-16,"w":28.0,"h":32.0}

func _bounds_and_cadence() -> void:
	var f: Dictionary = _fixture(); var before: Array = _source(f)
	var result: Dictionary = f.driver.step(0)
	_check(result.ok and result.direction.length() > 0 and not result.sprint,"ordinary clear route uses normal walking")
	_check(f.space.calls == 34 and f.driver.decisions == 1 and f.driver.last_decision.candidates.size() == 16,"one decision has exactly16 long plus16 short plus two retained sweeps")
	var calls: int = f.space.calls
	f.driver.step(199)
	_check(f.space.calls-calls == 2 and f.driver.decisions == 1,"199ms rechecks only retained long and short segments")
	calls = f.space.calls; f.driver.step(200)
	_check(f.space.calls-calls == 34 and f.driver.decisions == 2,"200ms permits exactly one new finite decision")
	f.space._collision_revision += 1; calls = f.space.calls
	result = f.driver.step(201)
	_check(result.direction == Vector2.ZERO and f.space.calls == calls and f.driver.decisions == 2,"new collision revision clears endpoint without restarting decision allowance")
	f.driver.step(400)
	_check(f.driver.decisions == 3,"same200ms cadence resumes after revision")
	_check(_source(f) == before,"planning never changes source records, resources or RNG")
	var endpoints: PackedVector2Array = Driver.heading_endpoints(Vector2.ZERO,Vector2(12,0))
	_check(endpoints.size() == 16 and endpoints[0] == Vector2(12,0),"direct endpoint does not overshoot its route waypoint")
	for index: int in range(1,endpoints.size()): _check(absf(endpoints[index].length()-70) < 0.001,"other finite headings retain70px local lookahead")
	_check(Driver.heading_endpoints(Vector2.INF,Vector2.ZERO).is_empty(),"nonfinite route cannot create candidates")
	completed_groups += 1

func _blocked_and_lifecycle() -> void:
	for mode: String in ["wall","peer","slide","malformed"]:
		var f: Dictionary = _fixture(); f.space.mode = mode
		var before: Array = _source(f)
		var result: Dictionary = f.driver.step(0)
		_check(result.ok and result.direction == Vector2.ZERO and f.space.calls == 16,"all "+mode+" endpoints hold within finite16 long checks")
		_check(_source(f) == before,"rejected "+mode+" requests do not repair source state")
		result = f.driver.step(20001)
		_check(not result.ok and result.reason == "no_actual_progress20s","permanent "+mode+" fails unchanged20s progress limit")
	var f: Dictionary = _fixture(); f.space.mode = "short_only"
	var result: Dictionary = f.driver.step(0)
	_check(result.direction.x < 0.91 and result.direction.length() > 0,"long endpoint success cannot override blocked short endpoint")
	_check(f.space.calls <= 34,"short-refusal alternatives retain decision work cap")
	f = _fixture(); f.driver.step(0); f.space.mode = "peer"
	result = f.driver.step(1)
	_check(result.direction == Vector2.ZERO and result.reason == "cached_edge_blocked" and f.driver.decisions == 1,"moving live peer blocks retained motion without immediate replanning")
	f.space.mode = "clear"; result = f.driver.step(200)
	_check(result.ok and result.direction.length() > 0,"transient live crossing resumes at the same bounded cadence")
	for kind: String in ["arrest","death","placement_reset","source_epoch"]:
		f = _fixture(); f.driver.step(0); var before: Array = _source(f)
		f.driver.invalidate_lifecycle(kind); var calls: int = f.space.calls
		result = f.driver.step(500)
		_check(not result.ok and result.direction == Vector2.ZERO and f.space.calls == calls,"observed "+kind+" permanently invalidates workload without further motion")
		_check(_source(f) == before,"lifecycle "+kind+" is never repaired by driver")
	for epoch: String in ["p","s"]:
		for seam: String in ["query","peers"]:
			f = _fixture()
			if seam == "query": f.space.replace_on_query = epoch
			else: f.space.replace_on_peers = epoch
			result = f.driver.step(0)
			_check(not result.ok and result.direction == Vector2.ZERO and result.reason == "unexpected_source_epoch","synchronous "+epoch+" replacement in "+seam+" cannot leak stale motion")
	f = _fixture(); f.driver.step(10)
	_check(not f.driver.step(9).ok,"backwards supplied clock fails closed")
	f = _fixture(); f.host.p.stunT = 3000.0
	result = f.driver.step(0)
	_check(result.ok and result.reason == "source_stun" and f.space.calls == 0,"stun holds actual input without source timer repair")
	f.host.s.mode = "paused"; f.host.p.stunT = 0
	_check(f.driver.step(200).direction == Vector2.ZERO and f.space.calls == 0,"modal mode cannot emit movement")
	f = _fixture(); f.driver.step(0); f.driver.step(400)
	result = f.driver.step(500)
	_check(result.direction == Vector2.ZERO,"500ms actual stagnation invalidates a long-cast-clear heading")
	result = f.driver.step(600)
	_check(result.direction.length() > 0 and result.direction.normalized().x <= 0.9,"next finite decision excludes the observed stuck heading temporarily")
	_check(not f.driver.step(20001).ok,"escape attempts cannot renew progress without actual movement")
	completed_groups += 1

func _threats_and_distance() -> void:
	var f: Dictionary = _fixture(); var origin: Vector2 = f.host.player_center()
	f.host.npcs.assign([{"id":"cop","isCop":true,"dead":false},{"id":"dead","isCop":true,"dead":true},{"id":"hidden","isCop":true,"dead":false},{"id":"neutral","dead":false}])
	f.space.peers.assign([_peer("cop",origin+Vector2(60,0)),_peer("dead",origin-Vector2(10,0)),_peer("neutral",origin-Vector2(20,0))])
	var before: Array = _source(f)
	var result: Dictionary = f.driver.step(0)
	_check(f.driver.last_threats.size() == 1 and f.driver.last_threats[0].id == "cop","only actual live physical threatening peers enter evasion scores")
	_check(result.sprint and result.direction.x < 0,"nearby real cop favors normal-input escape and sprint")
	_check(_source(f) == before,"threat reading cannot alter cops, HP, wanted or source stats")
	f.host.p.shakes = 99.0
	result = f.driver.step(200)
	_check(f.host.p.shakes == 99.0 and result.sprint,"high shakes remain source-owned; driver adds no invented stamina rule or relief")
	var walk: Dictionary = Driver.sample_displacement(Vector2.ZERO,Vector2(2500,0),[])
	_check(walk.ok and walk.walked_m == 100.0 and walk.excluded_m == 0,"large lawful movement is not silently filtered by an arbitrary distance threshold")
	var arrest: Dictionary = Driver.sample_displacement(Vector2.ZERO,Vector2(2500,0),["arrest"])
	_check(arrest.ok and arrest.walked_m == 0 and arrest.excluded_m == 100.0,"observed arrest relocation is recorded and excluded from walked metres")
	_check(not Driver.sample_displacement(Vector2.ZERO,Vector2.ONE,["unexplained_jump"]).ok,"unknown exclusion labels cannot conceal movement")
	_check(not Driver.sample_displacement(Vector2.INF,Vector2.ZERO,[]).ok,"nonfinite displacement cannot become evidence")
	completed_groups += 1

func _input_and_source_guards() -> void:
	for action: String in ["left","right","forward","back"]:
		if not InputMap.has_action(action): InputMap.add_action(action,0.5)
	for desired: Vector2 in [Vector2(0.1,0),Vector2(0.05,-0.08),Vector2(0.7,0.7),Vector2.ZERO]:
		for action: String in ["left","right","forward","back"]: Input.action_release(action)
		var raw: Vector2 = Driver.encode_motion(desired)
		if raw.x != 0: Input.action_press("right" if raw.x > 0 else "left",absf(raw.x))
		if raw.y != 0: Input.action_press("back" if raw.y > 0 else "forward",absf(raw.y))
		_check(Input.get_vector("left","right","forward","back").distance_to(desired) < 0.00001,"actual circular input deadzone preserves desired normal motion "+str(desired))
	for action: String in ["left","right","forward","back"]: Input.action_release(action)
	var probe: String = FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("full_actor_performance_probe.gd"))
	_check("var sample_frames: int = 1080" in probe and "var warmup_frames: int = 120" in probe and "no override" in probe,"both full fixed sampling windows remain mandatory")
	_check("if min_alive < 60 or min_supported < 60 or min_rigs < 60" in probe and "cpu_stats.get(\"p95\",INF) >= 16.0" in probe and "process_stats.get(\"p95\",INF) >= 16.0" in probe,"population and both16ms thresholds are retained")
	_check("game.player.rotation" not in probe and "mouse.relative" in probe,"view turns use actual mouse input, never direct root yaw writes")
	var writes: Array[String] = []
	for line: String in probe.split("\n"):
		if line.strip_edges().begins_with("game.runtime.") and " = " in line: writes.append(line.strip_edges())
	_check(writes == ["game.runtime.state.rng_seed = int(spec.seed)","game.runtime.s.dayTime = float(spec.day_time)","game.runtime.profile_enabled = true","game.runtime.p.wanted = 4","game.runtime.p.wantedT = 0.0","game.runtime.p.x = placement.x; game.runtime.p.y = placement.y"],"sole authoritative writes are the original declared premeasurement setup")
	for forbidden: String in ["damage_actor(","runtime.attack(","p.hp =","p.rocks =","p.shakes =","p.iframes =","npcs.append(","npcs.erase("]:
		_check(forbidden not in probe,"probe cannot change workload via "+forbidden)
	completed_groups += 1

func _run() -> void:
	_bounds_and_cadence(); _blocked_and_lifecycle(); _threats_and_distance(); _input_and_source_guards()
	_check(completed_groups == 4,"all four contract groups completed without an aborted script call")
	for failure: String in failures: push_error(failure)
	print("SUSTAINED60 DRIVER CONTRACT: ","PASS" if failures.is_empty() else "FAIL"," (",checks," checks; detached driver only, no native performance claim)")
	quit(0 if failures.is_empty() else 1)
