extends SceneTree
const Memory = preload("res://scripts/memory_loop.gd")
const Rhythm = preload("res://scripts/rhythm_system.gd")
const Street = preload("res://scripts/street_dialogue.gd")
var checks: int = 0
var completed: int = 0
var groups: int = 0
var failures: Array[String] = []
class SequenceState:
	extends "res://scripts/game_state.gd"
	var sequence: Array[int] = [0,1,2,3,3,2,1,0]
	var cursor: int = 0
	func random_index(size: int) -> int:
		var result: int = sequence[cursor%sequence.size()]%size
		cursor += 1
		return result
class Spatial:
	extends RefCounted
	var visible: bool = true
	var calls: int = 0
	func can_reach_target(_id: String) -> bool: calls += 1; return visible
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_oracle(); _entry(); _session(); _real_street()
	_check(completed == 14,"all14 source fixtures completed without script abort")
	_check(groups == 4,"all4 rhythm groups completed without script abort")
	if failures.is_empty():
		print("3D RHYTHM GATE: PASS (%d checks;14 source fixtures;real untimed8-choice session;scene/native/Web pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D RHYTHM GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
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
func _rig() -> Dictionary:
	var game := SequenceState.new()
	var spatial := Spatial.new()
	var memory := Memory.new(game)
	var rhythm := Rhythm.new(game,spatial,memory)
	game.s.mode = "playing"; game.p.cash = 20; game.events.clear()
	var singer: Dictionary = {}
	for actor: Dictionary in game.npcs:
		if actor.id == "karaoke": singer = actor; break
	game.p.x = float(singer.x)+(float(singer.w)-float(game.p.w))*0.5
	game.p.y = float(singer.y)+(float(singer.h)-float(game.p.h))*0.5
	return {"game":game,"spatial":spatial,"memory":memory,"rhythm":rhythm,"singer":singer}
func _menu(actual: Dictionary,expected: Variant,label: String) -> void:
	if expected == null:
		_check(not actual.has("options"),label+" no modal"); return
	_check(actual.get("ok",false) and actual.has("token"),label+" live menu")
	_check(actual.get("title") == expected.title,label+" exact title")
	_check(actual.get("text") == expected.text,label+" exact next/history")
	var options: Array = actual.get("options",[])
	_check(options.size() == 5 and options.size() == expected.options.size(),label+" five choices")
	for index: int in range(mini(options.size(),expected.options.size())):
		_check(options[index].label == expected.options[index].label and options[index].enabled == expected.options[index].enabled,label+" exact choice%d" % index)
func _oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rhythm_reference.json"))
	_check(fixture.cases.size() == 14,"14 source fixtures present")
	for test: Dictionary in fixture.cases:
		var rig := _rig()
		for round: Dictionary in test.rounds:
			var current: Dictionary = rig.rhythm.start_paid_karaoke()
			_menu(current,round.started,test.id+".start")
			for step: Dictionary in round.steps:
				if step.choice is String:
					if step.choice == "escape": rig.rhythm.close(); current = {"ok":true,"closed":true}
					else: current = rig.rhythm.select(current.token,"forfeit")
				else: current = rig.rhythm.select(current.token,"note:%d" % int(step.choice))
				_menu(current,step.after,test.id+".after")
				_check(rig.game.p.cash == step.state.cash and rig.game.p.cred == step.state.cred,test.id+" exact resources")
				_check(rig.game.s.mode == step.state.mode,test.id+" exact mode")
				var achievements: Array = rig.game.s.achievements.duplicate(); achievements.sort()
				_check(_same(achievements,step.state.achievements),test.id+" achievements")
				_check(_same(rig.game.s.recognition,step.state.recognition),test.id+" recognition")
		completed += 1
	groups += 1
func _entry() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	rig.spatial.visible = false
	_check(not rig.rhythm.start_paid_karaoke().ok and game.p.cash == 20 and game.cursor == 0,"blocked LOS has no charge or RNG")
	rig.spatial.visible = true; game.p.x += 60
	_check(not rig.rhythm.start_paid_karaoke().ok and game.p.cash == 20,"strict60px entry")
	game.p.x -= 60; game.p.cash = 4
	_check(not rig.rhythm.start_paid_karaoke().ok and game.cursor == 0,"short cash no sequence")
	game.p.cash = 20; game.s.bossKind = "kingdom"
	_check(not rig.rhythm.start_paid_karaoke().ok and game.p.cash == 20,"kingdom entry lock")
	game.s.bossKind = "tony"; game.s.bossActive = true
	var menu: Dictionary = rig.rhythm.start_paid_karaoke()
	_check(menu.ok and game.p.cash == 15 and game.cursor == 8,"one real entry cost and8source draws")
	_check(not rig.rhythm.start_paid_karaoke().ok and game.p.cash == 15 and game.cursor == 8,"active rhythm cannot double-charge")
	rig.rhythm.close()
	rig.singer.dead = true
	_check(not rig.rhythm.start_paid_karaoke().ok and game.p.cash == 15,"dead singer cannot start")
	var missing := _rig()
	var plain := Rhythm.new(missing.game,missing.spatial,null)
	_check(not plain.start_paid_karaoke().ok and missing.game.p.cash == 20 and missing.game.cursor == 0,"missing recognition refuses atomically")
	groups += 1
func _session() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	var menu: Dictionary = rig.rhythm.start_paid_karaoke()
	var old: String = menu.token
	menu = rig.rhythm.select(menu.token,"note:1") # Deliberately miss first source arrow.
	_check(menu.text.ends_with("↑"),"history displays source arrow rather than attempted answer")
	_check(not rig.rhythm.select(old,"note:0").ok and rig.rhythm.is_active(),"old note cannot advance or terminate current page")
	var calls: int = rig.spatial.calls
	game.p.x += 1000; rig.spatial.visible = false; rig.singer.dead = true
	for index: int in range(1,8): menu = rig.rhythm.select(menu.token,"note:%d" % game.sequence[index])
	_check(menu.get("closed",false) and game.p.cash == 36 and game.p.cred == 3,"post-entry relocation/dead singer does not invent closure gate")
	_check(rig.spatial.calls == calls and game.cursor == 8,"no per-note rays, recharges or RNG")
	_check(not rig.rhythm.select(old,"note:0").ok and game.p.cash == 36,"completion cannot replay")
	var replacement := _rig()
	menu = replacement.rhythm.start_paid_karaoke(); replacement.game.fresh(); replacement.game.s.mode = "playing"
	_check(replacement.rhythm.select(menu.token,"note:0").reason == "replaced_state" and replacement.game.p.cash == 0,"fresh cannot pay stale rhythm")
	replacement = _rig(); menu = replacement.rhythm.start_paid_karaoke()
	replacement.game.restore(replacement.game.snapshot())
	_check(replacement.rhythm.select(menu.token,"note:0").reason == "replaced_state","restore invalidates rhythm")
	var malformed := _rig()
	menu = malformed.rhythm.start_paid_karaoke()
	_check(not malformed.rhythm.select(menu.token,"note:4").ok and malformed.game.p.cash == 15 and not malformed.rhythm.is_active(),"unoffered action cannot advance")
	var escaped := _rig()
	menu = escaped.rhythm.start_paid_karaoke(); escaped.game.events.clear(); escaped.rhythm.close()
	_check(escaped.game.p.cash == 15 and escaped.game.p.cred == 0 and escaped.game.events.is_empty(),"Escape silently discards fee without refund or reward")
	var isolated := SequenceState.new()
	var spatial := Spatial.new()
	var handler := Rhythm.new(isolated,spatial,null)
	var owner_ref: WeakRef = weakref(isolated)
	isolated = null
	_check(owner_ref.get_ref() == null and not handler.start_paid_karaoke().ok,"rhythm keeps owner weak")
	groups += 1
func _real_street() -> void:
	var rig := _rig()
	var street := Street.new(rig.game,rig.spatial,rig.memory,null,rig.rhythm)
	var menu: Dictionary = street.open("karaoke")
	menu = street.select(menu.token,"sing")
	_check(menu.get("domain") == "activities" and rig.game.p.cash == 15 and rig.rhythm.is_active(),"real Street handoff charges exactly once")
	for index: int in range(8): menu = rig.rhythm.select(menu.token,"note:%d" % rig.game.sequence[index])
	_check(rig.game.p.cash == 39 and rig.game.p.cred == 4 and rig.game.s.achievements.has("not_a_phase"),"real eight-note completion pays source19net/4cred")
	var news: int = 0
	for event: Dictionary in rig.game.events:
		if event.kind == "news" and event.payload.text == "KARAOKE PERFECTION REPORTED. WITNESSES UNAVAILABLE.": news += 1
	_check(news == 1,"perfect session emits one authored news receipt")
	var next: Dictionary = street.open("karaoke"); next = street.select(next.token,"sing")
	_check(next.has("token") and rig.game.p.cash == 34,"new paid session is source-repeatable")
	rig.rhythm.select(next.token,"forfeit")
	_check(rig.game.p.cash == 34 and rig.game.p.cred == 4,"forfeit grants no completion reward")
	groups += 1
