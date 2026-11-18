extends SceneTree
const Cooking = preload("res://scripts/cooking_system.gd")
var checks: int = 0
var completed: int = 0
var groups: int = 0
var failures: Array[String] = []
class FixedState:
	extends "res://scripts/game_state.gd"
	var rolls: Array[float] = []
	var fallback: float = 0.5
	var cursor: int = 0
	func random_float() -> float:
		var value: float = rolls[cursor] if cursor < rolls.size() else fallback
		cursor += 1; return value
class Spatial:
	extends RefCounted
	var reachable: bool = true
	var probes: int = 0
	func can_use_zone(id: String) -> bool:
		probes += 1; return id == "block" and reachable
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cooking_reference.json"))
	_menus(fixture); _starts(fixture); _outcomes(fixture); _boundaries(fixture); _timelines(fixture)
	_capabilities(); _chunks(); _clocks()
	_check(completed == 206,"all206 source fixtures completed without abort")
	_check(groups == 8,"all8 cooking groups completed without abort")
	if failures.is_empty():
		print("3D COOKING GATE: PASS (%d checks;206 source fixtures;five modes/six outcomes/phase clocks/atomic chunks;Runtime/UI integration pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D COOKING GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.00001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not _same(a[index],b[index]): return false
		return true
	return a == b
func _fields(actual: Dictionary,expected: Dictionary,label: String) -> void:
	for key: String in expected: _check(actual.has(key) and _same(actual.get(key),expected[key]),"%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])
func _rig(player: Dictionary = {}) -> Dictionary:
	var game := FixedState.new()
	var spatial := Spatial.new()
	var cooking := Cooking.new(game,spatial)
	game.s.mode = "playing"; game.p.supplies = 5; game.p.dirtySupplies = 2; game.p.shakes = 60
	game.p.equip.tool = "propane_torch"; game.p.merge(player.duplicate(true),true)
	game.events.clear()
	return {"game":game,"spatial":spatial,"cooking":cooking}
func _begin(rig: Dictionary,mode: String) -> Dictionary:
	var menu: Dictionary = rig.cooking.open_menu()
	_check(menu.get("ok",false),"fixture opens actual Block cooking menu")
	return rig.cooking.select(menu.get("token",""),mode)
func _menu_view(menu: Dictionary) -> Variant:
	if not menu.get("ok",false) or not menu.has("options"): return null
	var options: Array[Dictionary] = []
	for option: Dictionary in menu.options: options.append({"label":option.label,"enabled":option.enabled})
	return {"title":menu.title,"text":menu.text,"options":options}
func _posts(game: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in game.events:
		if event.kind == "feed": result.push_front({"h":event.payload.author,"t":event.payload.text,"day":game.s.day})
	return result
func _last_toast(game: RefCounted) -> String:
	var result: String = ""
	for event: Dictionary in game.events:
		if event.kind == "toast": result = event.payload.text
		elif event.kind == "achievement": result = "· ACHIEVEMENT ·\n"+str(event.payload.definition.name)
	return result
func _state(rig: Dictionary,expected: Dictionary,label: String) -> void:
	_fields(rig.game.p,expected.player,label+".player")
	_check(_same(rig.game.s.quests.finisher,expected.quest),label+" finisher quest")
	var achievements: Array = rig.game.s.achievements.duplicate(); achievements.sort()
	_check(_same(achievements,expected.achievements),label+" achievements")
	_check(rig.game.s.mode == expected.mode,label+" mode")
	_check(_same(rig.game.s.get("heat"),expected.heat),label+" heat record")
	_check(_same(rig.game.s.get("smokeT",0),expected.smokeT),label+" smokeT")
	_check(_same(_posts(rig.game),expected.posts),label+" exact authored feed")
	_check(_last_toast(rig.game) == expected.toast,label+" final source toast")
func _menus(fixture: Dictionary) -> void:
	_check(fixture.menus.size() == 38,"38 source menus present")
	for test: Dictionary in fixture.menus:
		var rig := _rig(test.player)
		var menu: Dictionary = rig.cooking.open_menu()
		_check(_same(_menu_view(menu),test.expected),test.id+" exact source menu/predictor")
		_check(rig.game.cursor == 0,"opening mode menu does not roll heat")
		completed += 1
	groups += 1
func _starts(fixture: Dictionary) -> void:
	_check(fixture.starts.size() == 40,"40 mode/brain/high start fixtures present")
	for test: Dictionary in fixture.starts:
		var rig := _rig(test.setup); rig.game.fallback = 0.75
		_check(_begin(rig,test.mode).get("started",false),test.id+" starts real heat")
		_state(rig,test.expected,test.id)
		_check(rig.game.cursor == test.draws,test.id+" one center draw")
		completed += 1
	groups += 1
func _outcomes(fixture: Dictionary) -> void:
	_check(fixture.outcomes.size() == 93,"93 source outcome fixtures present")
	for test: Dictionary in fixture.outcomes:
		var rig := _rig(test.setup)
		_begin(rig,test.mode)
		rig.game.cursor = 0; rig.game.fallback = test.get("roll",0.5)
		for value: float in test.get("rolls",[]): rig.game.rolls.append(value)
		rig.game.events.clear()
		# Source oracle calls applyCookOutcome directly; place its known outcome
		# at the real hold boundary so production finalization still owns payment.
		rig.game.s.heat.phase = "hold"; rig.game.s.heat.holdT = 1.0; rig.game.s.heat.outcome = test.outcome
		var original: Dictionary = rig.game.p.duplicate(true)
		rig.cooking.tick(1.0)
		if test.n > Cooking.PACKETS_PER_TICK:
			_check(rig.cooking.is_resolving() and rig.game.p == original,test.id+" first chunk cannot partially pay")
			if test.has("interleave_after"):
				_check(rig.game.cursor == test.interleave_after,test.id+" precise authoritative RNG boundary")
				rig.game.random_float()
			_check(not rig.cooking.bail().ok and not rig.cooking.cancel("restore"),test.id+" accepted resolution refuses cancellation")
			var safety: int = 0
			while rig.cooking.is_resolving() and safety < 4: rig.cooking.tick(1.0); safety += 1
		_state(rig,test.expected,test.id)
		_check(rig.game.cursor == test.draws,test.id+" exact source RNG count including approved interleave")
		completed += 1
	groups += 1
func _boundaries(fixture: Dictionary) -> void:
	_check(fixture.bounds.size() == 30,"30 exact outcome boundaries present")
	for test: Dictionary in fixture.bounds:
		var rig := _rig({"supplies":1})
		_begin(rig,"slow"); rig.game.cursor = 0; rig.game.fallback = test.roll
		rig.game.s.heat.progress = test.h.lockedAt; rig.game.s.heat.sweetCenter = test.h.sweetCenter
		rig.game.s.heat.sweetHalf = test.h.sweetHalf; rig.game.s.heat.burnZone = test.h.burnZone
		var result: Dictionary = rig.cooking.lock()
		_check(result.ok and result.outcome == test.outcome,"source threshold x=%s roll=%s" % [test.h.lockedAt,test.roll])
		_check(rig.game.cursor == test.draws,"threshold RNG is conditional")
		completed += 1
	groups += 1
func _timelines(fixture: Dictionary) -> void:
	_check(fixture.timelines.size() == 5,"five real phase timelines present")
	for test: Dictionary in fixture.timelines:
		var rig := _rig(test.setup)
		_begin(rig,test.mode); _state(rig,test.initial,test.id+" initial")
		for step: Dictionary in test.steps:
			if step.op.get("lock",false): rig.cooking.lock()
			elif step.op.get("bail",false): rig.cooking.bail()
			else:
				for index: int in range(int(step.op.count)): rig.cooking.tick(step.op.dt)
			_state(rig,step.expected,test.id+" phase")
			_check(rig.game.cursor == step.draws,test.id+" phase draws")
		completed += 1
	groups += 1
func _capabilities() -> void:
	var rig := _rig()
	rig.spatial.reachable = false
	var before: Dictionary = rig.game.snapshot()
	_check(not rig.cooking.open_menu().ok and rig.game.snapshot() == before and rig.game.cursor == 0,"missing Block geometry cannot mutate resources/RNG")
	rig.spatial.reachable = true; rig.game.p.x = 8000
	_check(not rig.cooking.open_menu().ok,"source Block zone is mandatory")
	rig.game.p.x = 1050; rig.game.s.bossKind = "kingdom"
	_check(not rig.cooking.open_menu().ok,"kingdom source interaction lock remains")
	rig.game.s.bossKind = "tony"; rig.game.p.hp = -1; rig.game.p.stunT = 1234
	var menu: Dictionary = rig.cooking.open_menu()
	_check(menu.ok,"no invented ordinary-boss/HP/stun restriction")
	rig.spatial.reachable = false; rig.game.p.x = 8000
	_check(rig.cooking.select(menu.token,"slow").get("started",false) and rig.spatial.probes == 2,"modal start does not add a second spatial check")
	_check(not rig.cooking.select(menu.token,"slow").ok and rig.game.cursor == 1,"mode token cannot start twice")
	rig.cooking.cancel("test")
	var torch := _rig(); torch.game.p.equip.tool = "crowbar"; torch.game.s.flags.peteToolLocker = "propane_torch"
	menu = torch.cooking.open_menu()
	_check(menu.options.size() == 5 and not torch.cooking.select(menu.token,"propane").ok,"locker ownership cannot authorize torch use")
	var stale := _rig(); menu = stale.cooking.open_menu(); stale.game.fresh(); stale.game.s.mode = "playing"
	_check(not stale.cooking.select(menu.token,"all").ok and stale.game.p.supplies == 0,"fresh rejects old captured all-packet closure")
	var isolated := FixedState.new(); var spatial := Spatial.new(); var cooking := Cooking.new(isolated,spatial)
	var owner_ref: WeakRef = weakref(isolated); isolated = null
	_check(owner_ref.get_ref() == null and not cooking.ready(),"Cooking/session/inventory hold weak player references")
	groups += 1
func _chunks() -> void:
	var rig := _rig({"supplies":4097,"dirtySupplies":1000,"brain":80})
	_begin(rig,"all")
	rig.game.s.heat.phase = "hold"; rig.game.s.heat.holdT = 1.0; rig.game.s.heat.outcome = "ok"
	rig.game.cursor = 0; var before: Dictionary = rig.game.p.duplicate(true)
	rig.cooking.tick(1)
	_check(rig.game.cursor == 2048 and rig.game.p == before,"huge batch has bounded first work and no partial mutation")
	_check(not rig.cooking.cancel("shutdown") and not rig.cooking.bail().ok,"caller must defer shutdown/Escape after accepted finalization")
	rig.cooking.tick(1)
	_check(rig.game.cursor == 4096 and rig.game.p == before,"second bounded chunk still grants nothing")
	rig.cooking.tick(1)
	_check(not rig.cooking.is_active() and rig.game.p.supplies == 0 and rig.game.p.rocks > 0,"last chunk commits one complete result")
	var after: Dictionary = rig.game.snapshot(); var cursor: int = rig.game.cursor
	_check(not rig.cooking.tick(1) and not rig.cooking.bail().ok and rig.game.snapshot() == after and rig.game.cursor == cursor,"completed work cannot reroll or pay twice")
	var forced := _rig({"supplies":2051})
	_begin(forced,"all"); forced.game.s.heat.phase = "hold"; forced.game.s.heat.holdT = 1.0; forced.game.s.heat.outcome = "ok"
	forced.cooking.tick(1); forced.game.fresh(); forced.game.s.mode = "playing"
	before = forced.game.snapshot()
	_check(not forced.cooking.tick(1) and forced.game.snapshot() == before,"unexpected epoch replacement cannot receive previous accepted payout")
	var ordinary := _rig({"supplies":2048})
	_begin(ordinary,"all"); ordinary.game.s.heat.phase = "hold"; ordinary.game.s.heat.holdT = 1.0; ordinary.game.s.heat.outcome = "ok"
	ordinary.cooking.tick(1)
	_check(not ordinary.cooking.is_resolving() and ordinary.game.p.supplies == 0,"2048 packet boundary still completes same frame")
	groups += 1
func _clocks() -> void:
	var rig := _rig({"supplies":1,"rockedT":17000,"crashT":7000})
	_begin(rig,"slow")
	var before: Dictionary = rig.cooking.snapshot()
	_check(not rig.cooking.tick(51) and not rig.cooking.tick(NAN) and not rig.cooking.tick(-1) and rig.cooking.snapshot() == before,"invalid dt cannot partially mutate heat")
	rig.game.s.hitPause = 1
	_check(not rig.cooking.tick(50) and rig.cooking.snapshot() == before,"hit pause takes precedence over heat tick")
	rig.game.s.hitPause = 0; rig.cooking.tick(50)
	_check(rig.game.p.rockedT == 17000 and rig.game.p.crashT == 7000,"heat owner never advances authoritative high/crash timers")
	rig.cooking.lock(); var cursor: int = rig.game.cursor
	_check(not rig.cooking.lock().ok and rig.game.cursor == cursor and rig.game.s.heat.holdT == 600,"repeat lock cannot reroll or shorten reveal")
	var snapshot: Dictionary = rig.cooking.snapshot(); snapshot.n = 999
	_check(rig.game.s.heat.n == 1,"heat rendering snapshot is detached")
	rig.game.s.smokeT = 2000; rig.game.s.mode = "paused"
	before = rig.cooking.snapshot(); rig.cooking.tick_presentation(50)
	_check(rig.game.s.smokeT == 1950 and rig.cooking.snapshot() == before,"global smoke presentation tick does not advance heat")
	_check(not rig.cooking.tick_presentation(INF) and rig.game.s.smokeT == 1950,"invalid presentation dt refused")
	rig.game.s.mode = "cookmini"; rig.cooking.cancel("restore")
	_check(rig.game.p.supplies == 1 and rig.game.s.heat == null,"unpaid lifecycle cancel is distinct from costly Escape")
	groups += 1
