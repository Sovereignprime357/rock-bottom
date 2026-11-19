extends SceneTree
const Runtime = preload("res://scripts/full_runtime.gd")
const State = preload("res://scripts/game_state.gd")
const INTRO_ID := "cp_intro_remember"
class Spatial extends RefCounted:
	func can_reach_target(_id: String) -> bool: return true
	func can_use_zone(_id: String) -> bool: return true
	func move_body(_body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary: return {"position":intended,"blocked":false}
	func clear_placement(body: Dictionary) -> Variant: return Vector2(body.x,body.y)
	func can_hit(_from: Vector2,_to: Vector2,_source: String,_target: String) -> bool: return true
	func sweep_projectile(_start: Vector2,end: Vector2,_radius: float) -> Dictionary: return {"blocked":false,"fraction":1.0,"position":end}
	func stage_interactive_prop(_id: String,_kind: String,point: Vector2,_maximum: float) -> Variant: return point
var checks: int = 0
var failures: Array[String] = []
var source_starts: int = 0
var source_hustle_starts: int = 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _pile(state: RefCounted,id: String) -> Dictionary:
	for row: Dictionary in state.cash_piles:
		if row.id == id: return row
	return {}
func _wake(events: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.kind == "toast" and str(event.payload.get("text","")).begins_with("you wake up on the sidewalk."): result.append(event.payload)
	return result
func _same(a: Variant,b: Variant,numeric_tolerance: float = 0.0) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) <= numeric_tolerance
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key],numeric_tolerance): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not _same(a[index],b[index],numeric_tolerance): return false
		return true
	return typeof(a) == typeof(b) and a == b
func _run() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/startup_reference.json"))
	_check(fixture is Dictionary and fixture.get("cases") is Array,"startup source fixture exists")
	if fixture is Dictionary:
		_test_source(fixture)
		_test_cash(fixture)
		_test_hustle_starts(fixture)
	_test_real_lifecycle()
	_check(source_starts == 20,"all20 unchanged-source starts completed")
	_check(source_hustle_starts == 12,"all12 seeded source hustle starts completed")
	if failures.is_empty():
		print("3D STARTUP PARITY GATE: PASS (%d checks;14 publication paths/20 starts/4 cash variants/12 seeded hustle starts, real lifecycle and stale pickup)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D STARTUP PARITY GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)
func _test_source(fixture: Dictionary) -> void:
	_check(fixture.cases.size() == 14,"all14 publication paths present")
	for test: Dictionary in fixture.cases:
		var spatial := Spatial.new()
		var runtime := Runtime.new(spatial,null,func(): return 1000000.0)
		_check(runtime.communications.snapshot().posts.is_empty() and _wake(runtime.drain_events()).is_empty(),test.id+" cold title does not publish")
		runtime.communications.post("retained before start","@qa")
		_check(runtime.communications.snapshot().news_text == test.baselineNews,test.id+" real source initial ticker")
		runtime.p.rank = int(test.rank); runtime.s.day = int(test.day)
		runtime.s.flags.introDone = test.intro; runtime.s.flags.silenceUntilT = test.silence
		runtime.s.mode = "playing"; runtime.drain_events()
		for step: Dictionary in test.steps:
			var before: Dictionary = runtime.snapshot()
			var seed: int = runtime.state.rng_seed
			runtime._publish_start(test.loaded)
			var view: Dictionary = runtime.communications.snapshot()
			_check(_same(view.posts,step.posts),test.id+" exact retained/newest-first feed")
			_check(view.news_text == step.news,test.id+" exact ranked/silenced ticker")
			var wake: Array[Dictionary] = _wake(runtime.drain_events())
			_check(wake.size() == 1 and wake[0].text == step.toast and wake[0].duration_ms == step.duration,test.id+" exact source wake copy/duration")
			_check(runtime.state.rng_seed == seed and step.publicationDraws == 0,test.id+" publication suffix draws no RNG")
			_check(runtime.snapshot() == before,test.id+" publications do not mutate saved authority")
			source_starts += 1
func _test_cash(fixture: Dictionary) -> void:
	_check(fixture.piles.size() == 4 and fixture.sameSession.introPresent,"source cash variants include same-session quirk")
	for test: Dictionary in fixture.piles:
		var state := State.new()
		var saved: Dictionary = state.snapshot()
		saved.state.flags.introDone = test.intro
		if test.collected: saved.state.cashPilesCollected.append(INTRO_ID)
		var cash: int = int(saved.player.cash)
		_check(state.restore(saved).get("ok",false),"conditional pile restore accepts source state")
		_check(state.cash_piles.size() == test.count and (not _pile(state,INTRO_ID).is_empty()) == test.introPresent,"conditional pile membership matches spawnCashPiles")
		_check(state.p.cash == cash and state.s.cashPilesCollected.has(INTRO_ID) == test.collected,"reconciliation pays nothing and preserves collected IDs")
		var again: Dictionary = state.snapshot()
		state.restore(again)
		_check(state.cash_piles.size() == test.count,"repeat restore cannot duplicate conditional pile")
	var migrated := State.new()
	_check(migrated.restore({"schema":1,"cash":17}).get("ok",false) and _pile(migrated,INTRO_ID).is_empty() and migrated.p.cash == 17,"schema1 completed intro cannot receive an unearned intro pickup")
	var ordinary := State.new(); var ordinary_save: Dictionary = ordinary.snapshot()
	ordinary_save.state.cashPilesCollected.append("cp_0")
	ordinary.restore(ordinary_save)
	_check(_pile(ordinary,"cp_0").get("collected",false) and ordinary.cash_piles.size() == 29,"ordinary collected source piles retain their records")
	var spatial := Spatial.new(); var runtime := Runtime.new(spatial,null,func(): return 1000000.0)
	runtime.fresh(); runtime.drain_events()
	var current: Dictionary = _pile(runtime.state,INTRO_ID)
	runtime.s.flags.introDone = true
	runtime.p.x = float(current.x)-float(runtime.p.w)*0.5; runtime.p.y = float(current.y)-float(runtime.p.h)*0.5
	var before_cash: int = int(runtime.p.cash)
	_check(runtime.collect_cash(INTRO_ID) and runtime.p.cash == before_cash+10,"source allows an already-present intro pile after same-session intro completion")
	_check(not runtime.collect_cash(INTRO_ID),"same-session intro pickup remains one-use")
	runtime.fresh(); runtime.s.flags.introDone = true
	var detached_old: Dictionary = _pile(runtime.state,INTRO_ID)
	var saved: Dictionary = runtime.snapshot()
	_check(runtime.restore(saved) and _pile(runtime.state,INTRO_ID).is_empty(),"real Runtime restore removes finished-intro uncollected pile")
	runtime.p.x = float(detached_old.x)-float(runtime.p.w)*0.5; runtime.p.y = float(detached_old.y)-float(runtime.p.h)*0.5
	runtime.drain_events()
	var before: Dictionary = runtime.snapshot()
	_check(not runtime.collect_cash(INTRO_ID) and runtime.snapshot() == before and runtime.drain_events().is_empty(),"stale removed pile ID cannot pay or emit pickup/save receipts")
	_check(not detached_old.collected,"stale detached pile object is not mutated")
	_check(runtime.fresh() and not _pile(runtime.state,INTRO_ID).is_empty(),"fresh new intro recreates one eligible source pile")
func _test_real_lifecycle() -> void:
	var spatial := Spatial.new(); var runtime := Runtime.new(spatial,null,func(): return 1000000.0)
	_check(runtime.fresh(),"real fresh succeeds")
	var wake: Array[Dictionary] = _wake(runtime.drain_events())
	_check(wake.size() == 1 and wake[0].duration_ms == 4200 and runtime.communications.snapshot().posts.size() == 2,"fresh binds original receipt and both posts before presentation drain")
	var saved: Dictionary = runtime.snapshot(); saved.player.rank = 3; saved.state.day = 4
	_check(runtime.restore(saved),"real restore succeeds")
	wake = _wake(runtime.drain_events())
	_check(wake.size() == 1 and wake[0].duration_ms == 3500 and runtime.communications.snapshot().posts.size() == 4,"load uses shorter source wake and retains previous posts")
	_check(runtime.communications.snapshot().posts[0].day == 4 and runtime.communications.snapshot().news_text.begins_with("· BREAKING · good evening. strip-mall fiend is once again at large."),"load publication reads normalized current day and rank")
	var view: Dictionary = runtime.communications.snapshot()
	_check(not runtime.restore({"schema":99}) and runtime.communications.snapshot() == view and runtime.drain_events().is_empty(),"rejected load cannot issue startup publications")
	saved.state.flags.silenceUntilT = 1000001
	_check(runtime.restore(saved),"silenced valid load succeeds")
	wake = _wake(runtime.drain_events())
	_check(wake.size() == 1 and runtime.communications.snapshot().posts == view.posts and runtime.communications.snapshot().news_text == view.news_text,"load silence applies at publication time while wake toast survives")
	# Earlier queued source news/posts must remain before the suffix; later caller silence
	# cannot retroactively suppress the accepted publications.
	runtime.s.flags.silenceUntilT = 0
	runtime.state.emit_event("feed",{"text":"earlier source work","author":"@earlier"})
	runtime.state.emit_event("news",{"text":"earlier source news"})
	var seed: int = runtime.state.rng_seed
	runtime._publish_start(true)
	var current: Dictionary = runtime.communications.snapshot()
	_check(current.posts[2].t == "earlier source work" and current.news_text.contains("   ◆   · BREAKING · earlier source news"),"startup flush preserves original prior-publication order")
	runtime.s.flags.silenceUntilT = 1000001; runtime.drain_events()
	_check(runtime.communications.snapshot().posts == current.posts and runtime.state.rng_seed == seed,"later silence/event drain cannot erase or replay accepted startup output")

func _test_hustle_starts(fixture: Dictionary) -> void:
	_check(fixture.get("hustleCases") is Array and fixture.hustleCases.size() == 12,"all12 captured source order cases present")
	for test: Dictionary in fixture.hustleCases:
		var spatial := Spatial.new(); var runtime := Runtime.new(spatial,null,func(): return 1000000.0)
		_check(runtime.enable_actor_simulation() and runtime.enable_interactive_props(),test.id+" real interactive bottle startup enabled")
		var saved: Dictionary = runtime.snapshot()
		for key: String in test.rawState: saved.state[key] = test.rawState[key].duplicate(true) if test.rawState[key] is Array or test.rawState[key] is Dictionary else test.rawState[key]
		for key: String in ["hustles","graffiti","posters"]:
			if not test.rawState.has(key): saved.state.erase(key)
		for key: String in test.player: saved.player[key] = test.player[key].duplicate(true) if test.player[key] is Array or test.player[key] is Dictionary else test.player[key]
		saved.rng_seed = test.seed; saved.npcs_killed = test.get("dead",[]).duplicate()
		_check(runtime.restore(saved),test.id+" actual Runtime restore accepts input")
		_check(runtime.state.rng_seed == test.expected.seed,test.id+" exact source final RNG seed")
		_check(_same(runtime.s.hustles,test.expected.hustles),test.id+" exact source chosen/preserved hustle rows")
		_check(_same(runtime.s.hustleSnapshot,test.expected.hustleSnapshot) and runtime.s.counters.bigPan == test.expected.bigPan,test.id+" exact source snapshot and panhandle reset")
		_check(_same(runtime.s.blockRoute,test.expected.route),test.id+" route consumes draws after missing hustles")
		# Same micro-pixel tolerance as the existing wall-layout source gate; seeds,
		# job rewards, route IDs and all nongeometry comparisons remain exact.
		_check(_same(runtime.s.graffiti,test.expected.graffiti,0.000001) and _same(runtime.s.posters,test.expected.posters,0.000001),test.id+" wall layouts consume draws before missing hustles")
		if test.expected.equipmentAtHustle is Dictionary:
			for key: String in test.expected.equipmentAtHustle:
				_check(is_equal_approx(float(runtime.p[key]),float(test.expected.equipmentAtHustle[key])),test.id+" applied equipment "+key)
		var stages: Array = test.expected.stages
		_check(not stages.is_empty() and stages[0].stage == "bottles" and stages[0].draws == 24,test.id+" full source ordering witness includes24 initial bottle draws")
		source_hustle_starts += 1
	# Explicit malformed array contents remain an array decision. Safety normalization
	# removes injected rewards/unknown jobs; it must not secretly roll replacements.
	var spatial := Spatial.new(); var runtime := Runtime.new(spatial,null,func(): return 1000000.0)
	runtime.fresh(); var saved: Dictionary = runtime.snapshot()
	saved.state.flags.introDone = true
	saved.state.blockRoute = {"stops":runtime.progression.stops.slice(0,3).map(func(stop: Dictionary): return stop.id),"cursor":0,"serial":1,"lastStopId":""}
	saved.state.hustles = [{"id":"invented","reward":{"cash":999999}},17]
	var seed: int = int(saved.rng_seed)
	_check(runtime.restore(saved) and runtime.s.hustles.is_empty() and runtime.state.rng_seed == seed,"explicit malformed array is sanitized without fallback or extra RNG")
	saved.state.hustles = [{"id":"rocks_3","desc":"injected","reward":{"cash":999999},"done":false}]
	_check(runtime.restore(saved) and runtime.s.hustles.size() == 1 and runtime.s.hustles[0].reward == runtime.progression.hustle_by_id.rocks_3.reward,"known saved jobs use canonical rewards rather than raw injection")
	var migration := Runtime.new(spatial,null,func(): return 1000000.0)
	_check(migration.restore({"schema":1,"cash":12}) and migration.s.hustles.size() == 3 and migration.p.cash == 12,"slice migration generates missing jobs after marking intro complete without payout")
