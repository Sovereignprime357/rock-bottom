extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Bosses = preload("res://scripts/boss_system.gd")
const Residents = preload("res://scripts/resident_dialogue.gd")
var checks: int = 0
var completed: int = 0
var groups: int = 0
var failures: Array[String] = []

class FixedState:
	extends "res://scripts/game_state.gd"
	var roll: float = 0.75
	var rolls: int = 0
	func random_float() -> float: rolls += 1; return roll
	func random_index(size: int) -> int: return mini(size-1,int(floor(random_float()*size))) if size > 0 else 0
class Spatial:
	extends RefCounted
	var visible: bool = true
	var placeable: bool = true
	var calls: int = 0
	func can_reach_target(_id: String) -> bool: calls += 1; return visible
	func clear_placement(body: Dictionary) -> Variant: return Vector2(body.x,body.y) if placeable else null
	func move_body(_body: Dictionary, intended: Vector2, _goal: Variant = null, _stop: bool = false) -> Dictionary: return {"position":intended,"blocked":false}
	func can_hit(_a: Vector2,_b: Vector2,_source: String,_target: String) -> bool: return visible

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_oracle()
	_live_guards()
	_daily_and_discovery()
	_priest_contract()
	_lifecycle()
	_check(completed == 38,"all38 source fixtures completed without script abort")
	_check(groups == 5,"all5 resident groups completed without script abort")
	if failures.is_empty():
		print("3D RESIDENT GATE: PASS (%d checks;38 source fixtures;exact menus,daily governors,discovery,atomic Fallen transition;runtime/scene pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D RESIDENT GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
func _check(ok: bool, label: String) -> void:
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
func _fields(actual: Dictionary, expected: Dictionary, label: String, skip: Array = []) -> void:
	for key: String in expected:
		if key in skip: continue
		_check(actual.has(key) and _same(actual.get(key),expected[key]),"%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])
func _rig() -> Dictionary:
	var game := FixedState.new()
	var spatial := Spatial.new()
	var memory := Memory.new(game)
	var combat := Combat.new(game,spatial)
	var bosses := Bosses.new(game,combat)
	var residents := Residents.new(game,spatial,memory,combat,bosses)
	game.s.mode = "playing"; game.events.clear()
	return {"game":game,"spatial":spatial,"memory":memory,"combat":combat,"bosses":bosses,"residents":residents}
func _at(rig: Dictionary,id: String) -> void:
	var body: Dictionary = rig.combat.actor(id)
	rig.game.p.x = float(body.x)+(float(body.w)-float(rig.game.p.w))*0.5
	rig.game.p.y = float(body.y)+(float(body.h)-float(rig.game.p.h))*0.5
func _open(rig: Dictionary,id: String) -> Dictionary:
	_at(rig,id); return rig.residents.open(id)
func _choice(menu: Dictionary,id: String) -> Dictionary:
	for option: Dictionary in menu.get("options",[]):
		if option.id == id: return option
	return {}
func _act(rig: Dictionary,id: String,action: String) -> Dictionary:
	var menu := _open(rig,id)
	return rig.residents.select(menu.token,action) if menu.get("token") is String else menu
func _events(game: RefCounted,kind: String) -> int:
	var count: int = 0
	for event: Dictionary in game.events:
		if event.kind == kind: count += 1
	return count
func _menu(actual: Dictionary,expected: Variant,label: String) -> void:
	if expected == null:
		_check(not actual.has("options"),label+" no modal"); return
	_check(actual.get("ok",false) and actual.has("token"),label+" live menu")
	_fields(actual,{"title":expected.title,"text":expected.text},label)
	var options: Array = actual.get("options",[])
	_check(options.size() == expected.options.size(),label+" choice count")
	for index: int in range(mini(options.size(),expected.options.size())):
		_fields(options[index],expected.options[index],label+".option%d" % index)

func _oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/resident_reference.json"))
	_check(fixture.cases.size() == 38,"38 source fixtures present")
	for test: Dictionary in fixture.cases:
		var rig := _rig()
		var game: RefCounted = rig.game
		game.roll = test.roll
		game.p.merge(test.setup.player.duplicate(true),true)
		game.s.merge(test.setup.state.duplicate(true),true)
		game.s.flags.merge(test.setup.flags.duplicate(true),true)
		game.s.counters.merge(test.setup.counters.duplicate(true),true)
		var current: Dictionary = {}
		for step: Dictionary in test.steps:
			var operation: Dictionary = step.operation
			if operation.has("day"): game.s.day = operation.day
			if not operation.get("reuse",false): current = _open(rig,operation.actor)
			_menu(current,step.before,test.id+".before")
			if operation.action != null:
				var option := _choice(current,operation.action)
				if not option.is_empty() and option.enabled: current = rig.residents.select(current.token,operation.action)
			_menu(current,step.after,test.id+".after")
			_fields(game.p,step.expected.player,test.id+".player")
			_fields(game.s.counters,step.expected.counters,test.id+".counter")
			_fields(game.s.flags,step.expected.flags,test.id+".flag")
			for id: String in step.expected.quests: _fields(game.s.quests[id],step.expected.quests[id],test.id+".quest."+id)
			var achievements: Array = game.s.achievements.duplicate(); achievements.sort()
			var discovered: Array = game.s.discoveredVenues.duplicate(); discovered.sort()
			_check(_same(achievements,step.expected.achievements),test.id+" achievements")
			_check(_same(discovered,step.expected.discovered),test.id+" discovery")
			var actors: Array[Dictionary] = []
			for body: Dictionary in game.npcs:
				if body.id in ["lurch","sherri","paulie","larry","priest","omalley_fallen"] or str(body.id).begins_with("sherri_"): actors.append(body)
			_check(actors.size() == step.expected.actors.size(),test.id+" actor count")
			for index: int in range(mini(actors.size(),step.expected.actors.size())):
				var skip: Array = ["id"] if str(step.expected.actors[index].id).begins_with("sherri_") else []
				_fields(actors[index],step.expected.actors[index],test.id+".actor",skip)
		completed += 1
	groups += 1

func _live_guards() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.p.cash = 1
	var menu := _open(rig,"lurch")
	game.p.cash = 0
	_check(not rig.residents.select(menu.token,"give").ok and game.p.cred == 0,"recheck cash before resident payment")
	game.p.cash = 4
	menu = _open(rig,"lurch"); rig.spatial.visible = false
	_check(not rig.residents.select(menu.token,"give").ok and game.p.cash == 4,"live LOS rechecked without payment")
	_check(not rig.residents.select(menu.token,"give").ok,"refused geometry token cannot replay")
	rig.spatial.visible = true
	menu = _open(rig,"priest")
	var visits: int = game.s.counters.priestVisits
	rig.residents.select(menu.token,"tic_tac")
	_check(game.s.counters.priestVisits == visits,"selection does not replay priest opening")
	menu = _open(rig,"math")
	var interactions: int = game.s.counters.mathInteractions
	var rolls: int = game.rolls
	rig.residents.select(menu.token,"calculates")
	_check(game.s.counters.mathInteractions == interactions and game.rolls == rolls,"validation does not replay math effects or RNG")
	menu = _open(rig,"mom"); game.s.dayTime = 0.8
	var cash: int = game.p.cash
	_check(not rig.residents.select(menu.token,"accept").ok and game.p.cash == cash,"night starts after Mom menu without stale grant")
	game.s.dayTime = 0.5; game.s.bossActive = true; game.s.bossKind = "tony"
	_check(_open(rig,"larry").ok,"Tony fight preserves resident interaction")
	rig.residents.close(); menu = _open(rig,"larry"); game.s.bossKind = "kingdom"
	_check(not rig.residents.select(menu.token,"shout").ok,"new kingdom lock blocks stale resident choice")
	game.s.bossActive = false
	_check(not rig.residents.open("larry").ok,"kingdom kind locks even with inactive boss")
	game.s.bossKind = ""; _at(rig,"larry")
	game.p.x += 60.0
	_check(not rig.residents.open("larry").ok,"strict source60px boundary")
	menu = _open(rig,"larry"); rig.combat.actor("larry").dead = true
	_check(not rig.residents.select(menu.token,"shout").ok,"dead resident cannot execute stale grant")
	_check(not rig.residents.open("tony").ok and not rig.residents.supports("invented"),"strict dispatch does not replace unsupported dialogue")
	groups += 1

func _daily_and_discovery() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.p.cash = 4
	_act(rig,"lurch","give"); _act(rig,"lurch","give")
	_check(game.p.cash == 3 and game.p.cred == 2,"one daily Lurch payment")
	game.s.day += 1; _act(rig,"lurch","give")
	_check(game.p.cash == 2 and game.p.cred == 4,"Lurch next day permits once")
	_act(rig,"mom","accept"); _act(rig,"mom","compliment")
	var cash: int = game.p.cash; var cred: int = game.p.cred
	_act(rig,"mom","ask_again"); _act(rig,"mom","compliment")
	_check(game.p.cash == cash and game.p.cred == cred,"Mom ask and compliment caps are separate")
	_act(rig,"sherri","saw")
	_check(game.s.discoveredVenues == ["park"] and not rig.memory.unlocked("park"),"first Sherri reveal is visibility only")
	_act(rig,"sherri","saw"); _act(rig,"paulie","hears"); _act(rig,"lurch","sleeps")
	_check(game.s.discoveredVenues.size() == 4,"all four source teller reveals supported")
	for venue: String in ["park","laundromat","underpass","choir_office"]:
		_check(not rig.memory.unlocked(venue) and game.s.recognition[venue].full_high == 0,"telling does not unlock smoke at "+venue)
	var menu := _open(rig,"math")
	var old_token: String = menu.token
	var next: Dictionary = rig.residents.select(old_token,"another")
	_check(next.has("token") and next.token != old_token,"nested math conversation receives a fresh capability")
	_check(not rig.residents.select(old_token,"another").ok,"nested menu invalidates parent token")
	rig.residents.close(); game.s.counters.mathInteractions = 14
	var scrap: int = game.p.faction.scrap
	_act(rig,"math","leave"); game.s.counters.mathInteractions = 17; _act(rig,"math","leave")
	_check(game.p.faction.scrap == scrap+1,"fifth authored math tip pays; sixth does not")
	_open(rig,"philosopher"); game.events.clear()
	rig.residents.close(); game.events.clear()
	_act(rig,"philosopher","think")
	_check(_events(game,"save_requested") == 0,"philosopher preserves no immediate save on thought")
	groups += 1

func _priest_contract() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.roll = 0.75; game.p.hp = 5.0; game.p.iframes = 777.0; game.p.hitFlash = 123.0; game.s.combo = 6
	_act(rig,"priest","steal")
	_check(game.p.hp == -7.0 and game.p.iframes == 777 and game.p.hitFlash == 123 and game.s.combo == 6,"source plate cost bypasses damage combat effects")
	_check(_events(game,"death") == 0 and _events(game,"arrest") == 0,"source negative HP does not invent immediate respawn")
	var unavailable := _rig()
	game = unavailable.game; game.s.counters.priestVisits = 3; unavailable.spatial.placeable = false
	var menu := _open(unavailable,"priest")
	var before: Dictionary = game.p.duplicate(true)
	var attempts: int = game.s.counters.get("plateStealAttempts",0)
	_check(not unavailable.residents.select(menu.token,"steal").ok and game.p == before and game.s.counters.get("plateStealAttempts",0) == attempts,"failed transform placement has no partial attempt or faction cost")
	unavailable.spatial.placeable = true
	_check(_act(unavailable,"priest","steal").ok and game.s.flags.omalleyFallen,"real boss transaction transforms once")
	_check(unavailable.combat.actor("priest").is_empty() and not unavailable.combat.actor("omalley_fallen").is_empty(),"single transformed identity")
	menu = _open(unavailable,"omalley_fallen")
	_check(menu.options.size() == 1 and menu.options[0].id == "leave" and menu.text.contains("medicine is no longer offered"),"Fallen retains source defensive callback")
	_check(not unavailable.residents.select(menu.token,"steal").ok,"Fallen cannot use removed source action")
	var no_boss := Residents.new(game,unavailable.spatial,unavailable.memory,unavailable.combat)
	game.fresh(); game.s.mode = "playing"; game.s.counters.priestVisits = 3; _at(unavailable,"priest")
	menu = no_boss.open("priest"); attempts = game.s.counters.get("plateStealAttempts",0)
	_check(not no_boss.select(menu.token,"steal").ok and game.s.counters.get("plateStealAttempts",0) == attempts,"missing boss dependency refuses atomically")
	groups += 1

func _lifecycle() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	var menu := _open(rig,"larry")
	game.fresh(); game.s.mode = "playing"
	_check(rig.residents.select(menu.token,"shout").reason == "replaced_state","fresh invalidates resident epoch")
	menu = _open(rig,"larry"); game.restore(game.snapshot()); game.s.mode = "playing"
	_check(rig.residents.select(menu.token,"shout").reason == "replaced_state","restore invalidates resident epoch")
	menu = _open(rig,"larry"); rig.residents.close()
	_check(not rig.residents.select(menu.token,"shout").ok,"explicit close revokes token")
	menu = _open(rig,"larry")
	var other := Residents.new(game,rig.spatial,rig.memory,rig.combat,rig.bosses)
	var foreign: Dictionary = other.open("larry")
	_check(not rig.residents.select(foreign.token,"shout").ok and rig.residents.select(menu.token,"shout").ok,"tokens cannot cross handler instances")
	var isolated := FixedState.new()
	var spatial := Spatial.new()
	var handler := Residents.new(isolated,spatial)
	var owner_ref: WeakRef = weakref(isolated)
	isolated = null
	_check(owner_ref.get_ref() == null and not handler.open("lurch").ok,"resident handler does not retain owner")
	var missing := _rig()
	var plain := Residents.new(missing.game,missing.spatial)
	_at(missing,"lurch"); menu = plain.open("lurch")
	_check(not plain.select(menu.token,"fight").ok and missing.game.p.wanted == 0,"missing combat cannot fake aggro")
	_at(missing,"lurch"); menu = plain.open("lurch")
	_check(not plain.select(menu.token,"sleeps").ok and missing.game.s.discoveredVenues.is_empty(),"missing memory cannot fake discovery")
	groups += 1
