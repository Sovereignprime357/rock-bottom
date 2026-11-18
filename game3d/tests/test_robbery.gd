extends SceneTree
const Robbery = preload("res://scripts/robbery_system.gd")
var checks: int = 0
var completed: int = 0
var failures: Array[String] = []
class FixedState:
	extends "res://scripts/game_state.gd"
	var values: Array = [0.25]
	var draws: int = 0
	func random_float() -> float:
		var value: float = values[mini(draws,values.size()-1)]; draws += 1; return value
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.00001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in a.size():
			if not same(a[i],b[i]): return false
		return true
	return a == b
func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/robbery_reference.json"))
	for test: Dictionary in fixture.cases:
		var state := FixedState.new()
		state.p.merge(test.setup.player.duplicate(true),true)
		state.s.merge(test.setup.state,true); state.s.counters.merge(test.setup.counters,true)
		state.values = test.rolls; state.events.clear()
		var robbery := Robbery.new(state)
		check(robbery.attempt(test.actor) == test.result,test.id+" result")
		check(state.draws == test.draws,test.id+" exact RNG draws")
		for key: String in test.expected.player: check(same(state.p.get(key),test.expected.player[key]),test.id+" player "+key)
		for key: String in test.expected.counters: check(same(state.s.counters.get(key),test.expected.counters[key]),test.id+" counter "+key)
		var toast: String = ""; var saves: int = 0; var feeds: int = 0
		for event: Dictionary in state.events:
			if event.kind == "toast": toast = event.payload.text
			if event.kind == "save_requested": saves += 1
			if event.kind == "feed":
				feeds += 1
				check(event.payload.author == "@local_eyewitness" and event.payload.text.begins_with("lurch is holding somebody's "),test.id+" source equipment post")
		check(toast == test.toast,test.id+" literal toast")
		check(saves == (1 if test.result else 0),test.id+" one atomic save")
		check(feeds == (1 if test.id.begins_with("equip_") or test.id in ["order_0","order_1","order_2"] else 0),test.id+" equipment-only feed")
		completed += 1
	check(completed == 30,"all30 source cases completed")
	var state := FixedState.new(); var robbery := Robbery.new(state)
	state.events.clear(); check(not robbery.attempt({}) and state.events.is_empty() and state.draws == 0,"empty actor rejection is pure")
	state.p.cash = 100; state.s.day = 2; state.s.dayTime = 0.35
	var actor: Dictionary = {"id":"skid_lurch","name":"LURCH (SKID)","robs":true}
	check(robbery.attempt(actor),"first take")
	var saved: Dictionary = state.snapshot(); state.restore(saved)
	check(not robbery.attempt(actor),"save/restore keeps cooldown")
	state.s.dayTime += 0.25
	check(robbery.attempt(actor),"exact60-second world advance permits second take")
	state.s.dayTime += 0.25
	check(not robbery.attempt(actor),"third take is capped")
	if failures.is_empty(): print("3D ROBBERY GATE: PASS (%d checks;30 unchanged-source cases;governor/save/allowlists)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D ROBBERY GATE: FAIL (%d/%d)" % [failures.size(),checks]); quit(1)
