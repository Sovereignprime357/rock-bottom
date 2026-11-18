extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)

func _model() -> RefCounted:
	var game: RefCounted = State.new()
	game.s.flags.introDone = true
	game.s.quests.intro_smoke.done = true
	return game

func _run() -> void:
	_test_source_oracle()
	_test_loops()
	_test_conditions()
	_test_memory()
	_test_normalization()
	_test_presentation_and_finds()
	if failures.is_empty():
		print("3D MEMORY GATE: PASS (%d checks; source oracle, smoke/soap/hitter, exact boundaries, conditions, recognition/discovery and save clocks)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D MEMORY GATE: FAIL (%d failures / %d checks)" % [failures.size(), checks])
		quit(1)

func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 0.0001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not _same(a[i], b[i]): return false
		return true
	return a == b

func _test_source_oracle() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/memory_reference.json"))
	_check(fixture is Dictionary and fixture.get("cases", []).size() == 13, "independent v22 oracle fixture is available")
	if not fixture is Dictionary: return
	for test: Dictionary in fixture.cases:
		var game: RefCounted = _model()
		var memory: RefCounted = Memory.new(game)
		for key: String in test.setup.player:
			var value: Variant = test.setup.player[key]
			game.p[key] = value.duplicate(true) if value is Array or value is Dictionary else value
		game.s.recognition = test.setup.recognition.duplicate(true)
		game.s.discoveredVenues = test.setup.discovered.duplicate()
		game.s.concessionClocks = test.setup.clocks.duplicate(true)
		game.s.dayTime = test.setup.dayTime
		game.s.kingdom.stage = test.setup.kingdomStage
		game.s.kingdom.marks = test.setup.kingdomMarks
		game.s.achievements = test.setup.achievements.duplicate()
		for operation: Array in test.operations:
			match operation[0]:
				"smoke": memory.smoke(operation[1])
				"craft": memory.craft_hitter()
				"hitter": memory.use_hitter()
				"found": memory.grant_found_hitter()
				"record": memory.record(operation[1], operation[2], operation[3])
				"discover": memory.discover(operation[1])
				"clocks": memory.tick(float(operation[1]))
		for key: String in test.expected.player:
			_check(_same(game.p[key], test.expected.player[key]), "oracle %s player.%s" % [test.id, key])
		_check(_same(game.s.recognition, test.expected.recognition), "oracle %s recognition" % test.id)
		_check(_same(game.s.discoveredVenues, test.expected.discovered), "oracle %s discovery" % test.id)
		_check(_same(game.s.concessionClocks, test.expected.clocks), "oracle %s clocks" % test.id)
		_check(game.s.kingdom.stage == test.expected.kingdomStage and game.s.kingdom.marks == test.expected.kingdomMarks, "oracle %s kingdom" % test.id)
		var achievements: Array = game.s.achievements.duplicate()
		achievements.sort()
		_check(_same(achievements, test.expected.achievements), "oracle %s achievements" % test.id)

func _test_loops() -> void:
	var game: RefCounted = _model()
	var memory: RefCounted = Memory.new(game)
	_check(not memory.smoke("block").ok, "zero rock refuses ignition")
	game.p.rocks = 1
	game.p.shakes = 60.0
	_check(memory.smoke("block").ok and game.p.rocks == 0, "one real rock ignites once")
	_check(not memory.smoke("block").ok, "duplicate ignition refuses active high")
	game.tick(17.99, {"at_block":true})
	_check(absf(game.p.rockedT - 10.0) < 0.001 and game.p.crashT == 0.0, "normal high lasts the complete18s")
	game.tick(0.02, {"at_block":true})
	_check(game.p.rockedT == 0.0 and absf(game.p.crashT - 7990.0) < 0.001, "boundary spends only leftover10ms in crash")
	game.tick(7.99, {"at_block":true})
	_check(absf(game.p.crashT) < 0.001, "normal crash completes at26s")
	var rock: RefCounted = _model()
	var rock_memory: RefCounted = Memory.new(rock)
	var hitter: RefCounted = _model()
	var hitter_memory: RefCounted = Memory.new(hitter)
	rock.p.rocks = 1; rock.p.shakes = 60.0
	hitter.p.hitters = 1; hitter.p.shakes = 60.0
	rock_memory.smoke("block"); hitter_memory.use_hitter()
	rock.tick(40.0, {"at_block":true}); hitter.tick(40.0, {"at_block":true})
	_check(absf(rock.p.shakes - 72.0) < 0.001 and hitter.p.shakes == 100.0, "whole-cycle hitter trade remains strictly worse at40s")
	_check(rock.p.brain > hitter.p.brain and rock.p.cred > hitter.p.cred, "hitter has larger brain cost and no cred")
	_check(hitter.p.lifetime.rocksSmoked == 0 and not hitter.p.hitterHigh, "hitter never enters rock count and clears high provenance")
	game = _model(); memory = Memory.new(game)
	game.p.x = 2500.0; game.p.y = 1000.0
	game.p.rocks = 1
	game.s.recognition.park.buy = 15
	game.s.dayTime = 0.10
	_check(memory.smoke("park").ok, "conceded legal venue uses the same ignition")
	game.tick(18.0, {"at_block":true})
	_check(game.s.recognition.park.full_high == 1, "full high credits current venue once")
	game.p.hitters = 1
	memory.use_hitter(); game.tick(6.0, {"at_block":true})
	_check(game.s.recognition.park.full_high == 1 and game.p.crashT == 14000.0, "hitter gets rough crash without full-high credit")
	game.p.rockedT = 0.0; game.p.crashT = 0.0; game.p.rocks = 1
	game.s.dayTime = 0.10
	memory.smoke("park")
	game.p.x = 1050; game.p.y = 840
	game.tick(18.0, {"at_block":true})
	_check(game.s.recognition.park.full_high == 1, "leaving venue before expiry earns no remote recognition")

func _test_conditions() -> void:
	var game: RefCounted = _model()
	var memory: RefCounted = Memory.new(game)
	for id: String in Memory.VENUES: game.s.recognition[id].buy = 15
	for mask: int in range(16):
		game.s.dayTime = 0.1 if mask & 1 else 0.5
		game.s.concessionClocks.choir = {"phase":"open" if mask & 2 else "closed", "t":30000}
		game.s.freedDogFollowT = 1000.0 if mask & 4 else 0.0
		game.npcs.clear()
		game.npcs.append({"id":"freed_dog_follower", "dead":false})
		game.s.concessionClocks.dryer = {"phase":"running", "t":30000 if mask & 8 else 65000}
		var legal: Array = []
		for index: int in range(4):
			var id: String = ["park", "choir_office", "underpass", "laundromat"][index]
			var expected: bool = (mask & (1 << index)) != 0
			_check(memory.available(id) == expected, "condition combination %d %s" % [mask,id])
			if expected: legal.append(id)
		var spot: Dictionary = memory.bad_idea_spot(Vector2(5000, 2000))
		_check(spot.id == "block" or spot.id in legal, "BAD IDEA advertises only currently legal spot")
	for value: float in [14999.0, 15000.0, 55000.0, 55001.0]:
		game.s.concessionClocks.dryer.t = value
		_check(memory.condition("laundromat") == (value >= 15000.0 and value <= 55000.0), "dryer exact inclusive margins %.0f" % value)
	game.npcs.clear()
	game.s.freedDogFollowT = 1000.0
	_check(not memory.condition("underpass"), "follow timer alone is not dog presence")
	var point: Vector2 = (Vector2(1064,882) + Vector2(2540,1046)) * 0.5
	_check(memory.nearest_legal(point,["park"]).id == "block", "equal nearest distance returns Block")
	game.p.x = 2500; game.p.y = 1000; game.p.rocks = 1; game.s.dayTime = 0.5
	_check(not memory.smoke("park").ok and game.p.rocks == 1, "action rechecks expired concession without spending")

func _test_memory() -> void:
	var game: RefCounted = _model()
	var memory: RefCounted = Memory.new(game)
	game.p.x = 2500; game.p.y = 1000
	_check(memory.record("park","bother","pigeon").credited, "first witnessed visit credits")
	_check(not memory.record("park","bother","pigeon").credited, "same witness cannot farm within visit")
	game.p.x = 1050; game.p.y = 840; memory.sync_visit()
	game.p.x = 2500; game.p.y = 1000
	_check(memory.record("park","bother","pigeon").credited, "return visit can credit again")
	var player_before: Dictionary = game.p.duplicate(true)
	var recognition_before: Dictionary = game.s.recognition.duplicate(true)
	_check(memory.discover("park") == "revealed" and memory.discover("park") == "known", "discovery is idempotent")
	_check(memory.discover("block").is_empty() and memory.discover("invented").is_empty(), "only four venue IDs can be discovered")
	_check(_same(game.p,player_before) and _same(game.s.recognition,recognition_before), "discovery changes no resource or recognition")
	_check(memory.ledger_line("park").begins_with("known:") and not memory.available("park"), "known room remains unearned")
	game.s.recognition.park.buy = Memory.COUNTER_CAP
	_check(not memory.record("park","buy").credited and game.s.recognition.park.buy == Memory.COUNTER_CAP, "recognition lane caps without new credit")
	_check(_same(game.p,player_before), "recognition grants no player resources")

func _test_normalization() -> void:
	var normalized: Dictionary = Memory.normalize_recognition({"park":{"buy":INF,"sit":-4,"sell":3.9,"bother":true},"block":{"buy":999}})
	_check(normalized.size() == 4 and normalized.park.buy == 0 and normalized.park.sit == 0 and normalized.park.sell == 3 and normalized.park.bother == 0, "malformed recognition is safely normalized")
	_check(_same(Memory.normalize_discovered(["park","park","block",1,"underpass"]),["park","underpass"]), "discovery normalization rejects unknown and duplicate IDs")
	var clocks: Dictionary = Memory.normalize_clocks({"seed":NAN,"choir":{"phase":"open","t":INF},"dryer":{"phase":"running","t":900000}})
	_check(clocks.choir.phase == "closed" and clocks.dryer.t == 70000, "clocks reject nonfinite and cap valid phases")
	var game: RefCounted = _model()
	var memory: RefCounted = Memory.new(game)
	memory.tick(123456.0)
	game.s.recognition.park.sell = 8
	memory.discover("laundromat")
	var saved: Dictionary = game.snapshot()
	var saved_clocks: Dictionary = game.s.concessionClocks.duplicate(true)
	game.restore(saved)
	_check(_same(game.s.concessionClocks,saved_clocks) and game.s.recognition.park.sell == 8 and memory.discovered("laundromat"), "real save roundtrip retains clocks and social memory: clocks=%s expected=%s sell=%s discovered=%s" % [game.s.concessionClocks, saved_clocks, game.s.recognition.park.sell, game.s.discoveredVenues])
	var before: Dictionary = game.s.concessionClocks.duplicate(true)
	memory.tick(NAN); memory.tick(-1); memory.tick(1e12)
	_check(_same(before,game.s.concessionClocks), "invalid clock delta cannot mutate state")

func _test_presentation_and_finds() -> void:
	var game: RefCounted = _model()
	var memory: RefCounted = Memory.new(game)
	game.p.x = 2500; game.p.y = 1000; game.s.dayTime = 0.1
	game.s.recognition.park.sell = 2
	game.p.rockedT = 1
	game.drain_events()
	game.tick(0.002)
	var events: Array = game.drain_events()
	var crash_index: int = -1
	var regular_index: int = -1
	var flash: bool = false
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		if event.kind == "flash": flash = true
		if event.kind == "toast" and event.payload.text.begins_with("the crash"):
			crash_index = index
		if event.kind == "toast" and event.payload.text.begins_with("· THE REGULAR"):
			regular_index = index
			_check(event.payload.defer_ms == 2300 and event.payload.duration_ms == 3600,"tier crossing defers only its presentation receipt")
	_check(crash_index >= 0 and regular_index > crash_index and flash,"crash feedback precedes deferred recognition")
	_check(game.s.recognition.park.full_high == 1 and game.p.crashT == 7999,"recognition credit and crash are immediate despite deferred toast")
	var seed: int = game.rng_seed
	_check(not memory.dumpster_hitter_roll(0.25) and not memory.dumpster_hitter_roll(NAN) and game.rng_seed == seed,"near or invalid dumpster cannot roll or spend RNG")
	# Independently calculated first LCG draws: seed0=.2360679728 (miss), seed1972=.0003213591 (hit).
	game.rng_seed = 0
	_check(not memory.dumpster_hitter_roll(1.0),"far dumpster roll rejects draw above4percent")
	game.rng_seed = 1972
	_check(memory.dumpster_hitter_roll(1.0),"far dumpster roll accepts draw below4percent")
	game.p.x = 1050; game.p.y = 840; game.p.rockedT = 0; game.p.soapRocks = 1
	game.drain_events(); memory.smoke("block")
	var sounds: Array = []
	for event: Dictionary in game.drain_events():
		if event.kind == "sound": sounds.append(event.payload.id)
	_check(sounds.has("hurt") and sounds.has("glassBreak"),"soap retains both original sound cues")
