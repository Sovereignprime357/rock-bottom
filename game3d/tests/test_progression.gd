extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Progression = preload("res://scripts/progression_routes.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.0001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not _same(a[i],b[i]): return false
		return true
	return a == b
func _model() -> RefCounted:
	var game: RefCounted = State.new()
	game.s.flags.introDone = true; game.s.quests.intro_smoke.done = true
	game.s.mode = "playing"
	return game

func _run() -> void:
	_test_oracle()
	_test_routes()
	_test_hustles()
	_test_territory()
	_test_normalizers()
	if failures.is_empty():
		print("3D PROGRESSION GATE: PASS (%d checks; 31 source fixtures, routes/hustles, territory, ranks and save guards; scene integration pending)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D PROGRESSION GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks])
		quit(1)

func _test_oracle() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/progression_reference.json"))
	_check(fixture is Dictionary and fixture.get("cases",[]).size() == 31,"independent source fixtures loaded")
	if not fixture is Dictionary: return
	for test: Dictionary in fixture.cases:
		var game: RefCounted = _model()
		var progress: RefCounted = Progression.new(game)
		game.p = test.setup.player.duplicate(true)
		game.s.flags = test.setup.flags.duplicate(true)
		game.s.hustles = test.setup.hustles.duplicate(true)
		game.s.hustleSnapshot = {}; game.s.blockRoute = null
		game.npcs.clear()
		for actor: Dictionary in test.setup.npcs: game.npcs.append(actor.duplicate(true))
		for operation: Array in test.operations:
			match operation[0]:
				"route": progress.roll_route(true,operation[1] if operation.size() > 1 else "")
				"hustles": progress.roll_hustles()
				"stamp_all":
					for i: int in range(3):
						var stop: Dictionary = progress.current_stop()
						game.p.x = stop.x-float(game.p.w)*0.5; game.p.y = stop.y-float(game.p.h)*0.5
						progress.stamp_route()
				"repeat_stamp": progress.stamp_route()
				"satisfy":
					var id: String = operation[1]
					var key: String = progress.hustle_by_id[id].key
					var target: Dictionary = game.p.lifetime if key in Progression.LIFETIME_KEYS else game.s.counters
					target[key] = int(game.s.hustleSnapshot.get(key,0))+int(Progression.TARGETS[id])
				"check": progress.check_hustles()
				"territory":
					for i: int in range(int(operation[1])): progress.tick_territory(2000,100000)
		var actual: Dictionary = {
			"cash":game.p.cash,"cred":game.p.cred,"brain":game.p.brain,"wanted":game.p.wanted,"wantedT":game.p.wantedT,
			"lifetime":game.p.lifetime,"hustles":game.s.hustles,"hustleSnapshot":game.s.hustleSnapshot,
			"route":game.s.blockRoute,"officeAvailable":game.s.quests.office_space.available,
			"achievements":game.s.achievements.duplicate(),"seed":game.rng_seed,
			"territory":{"heat":game.s.get("territoryHeat",0),"cashMult":game.s.get("territoryCashMult",1),"brainTicks":game.s.get("territoryBrainTicks",0),"zoneId":game.s.get("territoryZoneId"),"greeted":game.s.get("territoryGreeted",[]),"greetLast":game.s.get("territoryGreetLast",{})}}
		actual.achievements.sort()
		for key: String in test.expected:
			_check(_same(actual.get(key),test.expected[key]),"oracle %s %s actual=%s expected=%s" % [test.id,key,actual.get(key),test.expected[key]])

func _place_at(game: RefCounted, stop: Dictionary, distance: float = 0.0) -> void:
	game.p.x = float(stop.x)-float(game.p.w)*0.5+distance
	game.p.y = float(stop.y)-float(game.p.h)*0.5

func _test_routes() -> void:
	var game: RefCounted = _model()
	var progress: RefCounted = Progression.new(game)
	_check(is_equal_approx(progress.route_leg_budget(),8250.0),"source runway-derived leg budget")
	progress.ensure_route()
	var stop: Dictionary = progress.current_stop()
	_place_at(game,stop,58.0)
	_check(not progress.stamp_route(),"exact58px edge rejected")
	_place_at(game,stop,57.99)
	for mode: String in ["title","pause","dialogue","cooking","heist"]:
		game.s.mode = mode
		_check(not progress.stamp_route(),"stamp blocked in " + mode)
	game.s.mode = "playing"
	_check(not progress.stamp_route({"hidden":true}),"hidden scene cannot stamp")
	_check(not progress.stamp_route({"reachable":false}),"physical LOS rejection cannot stamp")
	game.p.stunT = 1
	_check(not progress.stamp_route(),"stun cannot stamp")
	game.p.stunT = 0
	for flag: String in ["bossActive","brutusOlderActive"]:
		game.s[flag] = true
		_check(not progress.stamp_route(),"boss blocks route " + flag)
		game.s[flag] = false
	for contract: String in ["claimJob","workJob"]:
		game.s.office[contract] = {"id":"active"}
		_check(not progress.stamp_route(),"office contract blocks route " + contract)
		game.s.office[contract] = null
	_check(progress.stamp_route() and game.s.blockRoute.cursor == 1,"within strict radius stamps once")
	_check(not progress.stamp_route() and game.s.blockRoute.cursor == 1,"repeat input at previous location cannot stamp next stop")
	for row: Dictionary in progress.stops:
		if row.has("unlockFlag"): game.s.flags[row.unlockFlag] = true
	game.p.lifetime.routesCompleted = 2
	for seed: int in range(128):
		game.rng_seed = seed
		var route: Dictionary = progress.roll_route(true,"ditch_gauge")
		_check(progress.valid_route(route) and not route.stops.has("ditch_gauge"),"unique unlocked total route %d" % seed)
		for index: int in range(1,3):
			var a: Dictionary = progress.stop_by_id[route.stops[index-1]]
			var b: Dictionary = progress.stop_by_id[route.stops[index]]
			_check(Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y)) <= progress.route_leg_budget(),"shuffled route leg budget %d/%d" % [seed,index])
	game.p.cred = 800
	_check(progress.update_ranks() == 7 and game.p.rank == 7 and game.s.achievements.has("glass_mayor"),"all rank thresholds crossed in order")
	game.p.cred = -50
	_check(progress.update_ranks() == 0 and game.p.rank == 7,"cred loss does not revoke rank")
	_check(progress.patch_tier() == 0,"patch starts before five routes")
	game.p.lifetime.routesCompleted = 999
	_check(progress.patch_tier() == 4,"patch tier caps at four")

func _test_hustles() -> void:
	var game: RefCounted = _model()
	var progress: RefCounted = Progression.new(game)
	for id: String in Progression.TARGETS:
		var definition: Dictionary = progress.hustle_by_id[id]
		game.s.hustles = [{"id":id,"done":false,"reward":{"cash":999999}}]
		game.s.hustleSnapshot = {}
		var key: String = definition.key
		var counters: Dictionary = game.p.lifetime if key in Progression.LIFETIME_KEYS else game.s.counters
		counters[key] = int(Progression.TARGETS[id])-1
		_check(progress.check_hustles() == 0,"hustle below threshold " + id)
		var before: float = game.p.cash
		counters[key] += 1
		_check(progress.check_hustles() == 1 and game.p.cash-before == float(definition.reward.get("cash",0)),"canonical reward ignores forged save " + id)
		_check(progress.check_hustles() == 0,"hustle duplicate refuses reward " + id)
		var target: int = 1 if id == "church_2" else int(Progression.TARGETS[id])
		_check(progress.hustle_progress({"id":id}) == "%d/%d" % [target,target],"hustle progress display " + id)
		counters[key] = -1
		_check(progress.hustle_progress({"id":id}) == "0/%d" % target,"negative delta displays zero " + id)

func _test_territory() -> void:
	var game: RefCounted = _model()
	var progress: RefCounted = Progression.new(game)
	game.p.x = 1620; game.p.y = 870; game.p.faction.street = -10
	for i: int in range(29): progress.tick_territory(2000,100000)
	_check(game.p.wanted == 0,"hated territory before30 ticks")
	progress.tick_territory(2000,100000)
	_check(game.p.wanted == 1 and game.s.territoryHeat == 0,"hated territory30 ticks then reset")
	game.s.mode = "dialogue"
	progress.tick_territory(60000,100000)
	_check(game.s.territoryHeat == 0,"modal freezes territory")
	game.s.mode = "playing"; game.p.faction.street = 25; game.p.brain = 99.5
	progress.tick_territory(100000,100000)
	_check(game.s.territoryBrainTicks == 1 and game.p.brain == 99.5,"source oversized territory call fires one tick")
	for i: int in range(4): progress.tick_territory(2000,100000)
	_check(game.p.brain == 100 and game.s.territoryCashMult == 1.4,"loved brain capped and cash multiplier")
	game.p.x = 8500; game.p.y = 5500
	progress.tick_territory(2000,100000)
	_check(game.s.territoryCashMult == 1.0 and game.s.territoryHeat == 0,"leaving territory clears effects")

func _test_normalizers() -> void:
	var game: RefCounted = _model()
	var progress: RefCounted = Progression.new(game)
	progress.ensure_route()
	var valid: Dictionary = game.s.blockRoute.duplicate(true)
	for field: String in ["stops","cursor","serial","lastStopId"]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed.erase(field)
		_check(not progress.valid_route(malformed),"route requires " + field)
	for bad: Variant in [NAN,INF,-1,0.5,4,true,"1"]:
		var malformed: Dictionary = valid.duplicate(true); malformed.cursor = bad
		_check(progress.normalize_route(malformed) == null,"invalid route cursor " + str(bad))
	var repeated: Dictionary = valid.duplicate(true); repeated.stops[1] = repeated.stops[0]
	_check(not progress.valid_route(repeated),"duplicate route IDs rejected")
	var forged: Array = progress.normalize_hustles([{"id":"rocks_3","reward":{"cash":9999},"done":false},{"id":"rocks_3"},{"id":"unknown"}])
	_check(forged.size() == 1 and forged[0].reward.cash == 15,"hustle save allowlist canonical reward and dedup")
	game.s.hustles = forged
	var saved: Dictionary = game.snapshot()
	_check(game.restore(saved) and _same(game.s.blockRoute,valid) and _same(game.s.hustles,forged),"route/hustles survive real schema2 roundtrip")
