extends SceneTree
const Heists = preload("res://scripts/heist_system.gd")
var checks: int = 0
var completed: int = 0
var sort_completed: int = 0
var groups: int = 0
var failures: Array[String] = []
class FixedState:
	extends "res://scripts/game_state.gd"
	var rolls: Array[float] = []
	var fallback: float = 0.75
	var cursor: int = 0
	func random_float() -> float:
		var value: float = rolls[cursor] if cursor < rolls.size() else fallback
		cursor += 1; return value
	func random_index(size: int) -> int: return mini(size-1,int(floor(random_float()*size))) if size > 0 else -1
class Spatial:
	extends RefCounted
	var reachable: bool = true
	var probes: int = 0
	var last_target: String = ""
	func can_use_site(target: String) -> bool:
		probes += 1; last_target = target; return reachable
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_oracle(); _sort_oracle(); _entry_and_caps(); _tokens_and_modal(); _geometry_and_latch(); _durability()
	_check(completed == 162,"all162 source paths completed without abort")
	_check(sort_completed == 98,"all98 comparator streams completed without abort")
	_check(groups == 6,"all6 heist groups completed without abort")
	if failures.is_empty():
		print("3D HEIST GATE: PASS (%d checks;162 source paths/98 comparator streams;9 sites/4 pins;physical Runtime integration pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D HEIST GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
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
func _rig() -> Dictionary:
	var game := FixedState.new()
	var spatial := Spatial.new()
	var heists := Heists.new(game,spatial)
	game.s.mode = "playing"; game.p.cash = 100; game.p.cred = 60; game.p.equip.tool = "crowbar"
	game.events.clear()
	return {"game":game,"spatial":spatial,"heists":heists}
func _site(game: RefCounted,id: String) -> Dictionary:
	for key: String in ["COPPER_SITES","BREAKIN_SITES"]:
		for site: Dictionary in game.definition("src/data/props.js",key,[]):
			if site.id == id: return site
	return {}
func _anchor(game: RefCounted,id: String) -> Dictionary:
	if id == "abandoned":
		for building: Dictionary in game.content.buildings:
			if building.get("locked",false): return building
	return _site(game,id).anchor
func _place(game: RefCounted,id: String) -> void:
	var anchor: Dictionary = _anchor(game,id)
	game.p.x = anchor.x+anchor.w*0.5-game.p.w*0.5; game.p.y = anchor.y+anchor.h+10-game.p.h*0.5
func _open(rig: Dictionary,id: String) -> Dictionary:
	_place(rig.game,id); return rig.heists.open(id)
func _menu_view(menu: Dictionary) -> Variant:
	if not menu.get("ok",false) or not menu.has("options"): return null
	var options: Array[Dictionary] = []
	for option: Dictionary in menu.options: options.append({"label":option.label,"enabled":option.enabled})
	return {"title":menu.title,"text":menu.text,"options":options}
func _state(game: RefCounted,expected: Dictionary,label: String) -> void:
	_fields(game.p,expected.player,label+".player")
	_fields(game.s.counters,expected.counters,label+".counters")
	_check(_same(game.s.quests.copper_sings,expected.quest),label+" quest")
	var achievements: Array = game.s.achievements.duplicate(); achievements.sort()
	_check(_same(achievements,expected.achievements),label+" achievements")
	_check(game.s.mode == expected.mode,label+" mode")
func _oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/heist_reference.json"))
	_check(fixture.cases.size() == 162,"162 source paths present")
	for test: Dictionary in fixture.cases:
		var rig := _rig()
		var game: RefCounted = rig.game
		game.p.merge(test.setup.player.duplicate(true),true); game.s.counters.merge(test.setup.counters.duplicate(true),true)
		game.s.flags.merge(test.setup.flags.duplicate(true),true); game.s.quests.copper_sings.done = test.setup.questDone
		var menu: Dictionary = rig.heists.open(test.site)
		_check(_same(_menu_view(menu),test.initial.menu),test.id+" initial menu")
		_state(game,test.initial.expected,test.id+" initial")
		_check(game.cursor == test.initial.draws,test.id+" initial RNG")
		for step: Dictionary in test.steps:
			game.cursor = 0; game.fallback = step.operation.get("roll",0.75)
			if step.operation.index is String:
				rig.heists.close(); menu = {}
			else:
				var index: int = int(step.operation.index)
				if menu.get("ok",false) and index < menu.get("options",[]).size():
					if menu.options[index].enabled: menu = rig.heists.select(menu.token,menu.options[index].id)
				else: _check(false,test.id+" missing option")
			_check(_same(_menu_view(menu),step.menu),test.id+" selected menu")
			_state(game,step.expected,test.id+" step")
			_check(game.cursor == step.draws,test.id+" exact RNG draws")
		completed += 1
	_check(fixture.availability.initial == "abandoned" and fixture.availability.afterRank4 == null,"actual source rank unlock removes heist trigger")
	_check(fixture.availability.afterFresh.rank == 4 and not fixture.availability.afterFresh.locked,"actual source start retains rank and unlocked global building")
	_check(fixture.availability.lowerRankLoad.ok and fixture.availability.lowerRankLoad.rank == 0 and fixture.availability.lowerRankLoad.site == null,"actual source lower-rank restore does not relock")
	groups += 1
func _sort_oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/heist_reference.json"))
	_check(fixture.sortCases.size() == 98,"64 signs/equality/32 seeded sort fixtures present")
	for test: Dictionary in fixture.sortCases:
		var rig := _rig()
		for value: float in test.rolls: rig.game.rolls.append(value)
		var menu := _open(rig,"abandoned")
		menu = rig.heists.select(menu.token,"entry:1")
		_check(menu.ok and menu.title == "LOCKPICK",test.id+" starts actual four-pin modal")
		_check(rig.game.cursor == test.draws and rig.game.cursor <= 6,test.id+" exact bounded source comparator count")
		var draws: int = rig.game.cursor
		for pin: int in test.expected:
			menu = rig.heists.select(menu.token,"pin:%d" % pin)
		_check(menu.ok and menu.title == "THE COPPER PIPES" and rig.game.p.brain == 70,test.id+" exact source target succeeds without brain loss")
		_check(rig.game.cursor == draws,test.id+" guesses never reroll target")
		sort_completed += 1
	groups += 1
func _entry_and_caps() -> void:
	var rig := _rig()
	_check(rig.heists.ready(),"canonical nine-site content ready")
	for id: String in ["abandoned","cold_not","water_dept"]:
		var menu := _open(rig,id)
		_check(menu.ok and menu.options.size() > 1,"accepted copper site spends shared attempt")
		rig.heists.select(menu.token,"leave")
	var refused := _open(rig,"rust_car")
	_check(refused.ok and refused.options.size() == 1 and rig.game.s.counters.heistsToday == 3,"fourth distinct copper site refuses same cap")
	rig.heists.close()
	for id: String in ["model_home","spoil_bank"]:
		var menu := _open(rig,id); rig.heists.select(menu.token,"leave")
	refused = _open(rig,"sod_office")
	_check(refused.ok and refused.options.size() == 1 and rig.game.s.counters.breakinsToday == 2 and rig.game.s.counters.heistsToday == 3,"break-in cap separate and shared")
	rig.heists.close(); rig.game.p.equip.tool = "propane_torch"; rig.game.p.cred = 0
	refused = _open(rig,"sod_office")
	_check(refused.text == _site(rig.game,"sod_office").gates[0].refuse,"equipped-tool gate precedes cred and exhausted governor")
	rig.heists.close(); rig.game.p.equip.tool = "crowbar"
	refused = _open(rig,"sod_office")
	_check(refused.text == _site(rig.game,"sod_office").gates[1].refuse,"second gate speaks once first passes")
	var blocked := _rig(); blocked.spatial.reachable = false
	_place(blocked.game,"cold_not")
	var before: Dictionary = blocked.game.snapshot()
	_check(not blocked.heists.open("cold_not").ok and blocked.game.snapshot() == before and blocked.game.cursor == 0,"physical refusal costs no cap/RNG/resources")
	var absent := FixedState.new(); var no_adapter := Heists.new(absent,null)
	absent.s.mode = "playing"; _place(absent,"cold_not")
	_check(no_adapter.open("cold_not").get("reason") == "missing_spatial_adapter" and absent.s.counters.heistsToday == 0,"missing real geometry fails before cap")
	groups += 1
func _tokens_and_modal() -> void:
	var rig := _rig()
	var menu := _open(rig,"cold_not")
	var first_token: String = menu.token
	_check(not rig.heists.open("cold_not").ok and rig.game.s.counters.heistsToday == 1,"active modal cannot reserve second attempt")
	rig.spatial.reachable = false; rig.game.p.x = 10; rig.game.p.y = 10
	menu = rig.heists.select(menu.token,"entry:1")
	_check(menu.ok and rig.game.p.cash == 98 and rig.spatial.probes == 1,"captured modal continues after relocation without per-stage ray")
	_check(not rig.heists.select(first_token,"entry:1").ok and rig.game.p.cash == 98,"entry payment token cannot replay")
	menu = rig.heists.select(menu.token,"take")
	var copper: int = rig.game.p.copper
	var exit_token: String = menu.token
	rig.heists.close()
	_check(not rig.heists.select(exit_token,"exit:0").ok and rig.game.p.copper == copper and rig.game.s.mode == "playing","Escape revokes getaway but retains take")
	var replaced := _rig(); menu = _open(replaced,"rust_car")
	replaced.game.fresh(); replaced.game.s.mode = "playing"
	_check(not replaced.heists.select(menu.token,"entry:2").ok and replaced.game.s.counters.heistsToday == 0,"fresh state rejects old paid closure")
	var tamper := _rig(); menu = _open(tamper,"abandoned")
	_check(not tamper.heists.select(menu.token,"entry:999").ok and tamper.game.cursor == 0 and tamper.game.s.mode == "playing","unknown action consumes capability without mutation or dead modal")
	var low := _rig(); low.game.p.hp = -1; low.game.p.stunT = 999; low.game.s.bossActive = true; low.game.s.bossKind = "tony"
	menu = _open(low,"cold_not")
	_check(menu.ok,"no invented raw HP/stun/ordinary-boss entry guard")
	menu = low.heists.select(menu.token,"entry:1")
	_check(menu.get("died",false) and low.game.p.hp == 60 and low.game.p.cash == 98,"entry applies full cost then authoritative death")
	groups += 1
func _geometry_and_latch() -> void:
	var rig := _rig()
	for id: String in Heists.COPPER_IDS+Heists.BREAKIN_IDS:
		var anchor := _anchor(rig.game,id)
		var center := Vector2(anchor.x+anchor.w*0.5,anchor.y+anchor.h+10)
		_check(rig.heists.site_at(center) == id,"source rectangle selects "+id)
		_check(rig.heists.site_at(Vector2(anchor.x-20,center.y)) != id and rig.heists.site_at(Vector2(anchor.x+anchor.w+20,center.y)) != id,"strict x boundaries "+id)
		_check(rig.heists.site_at(Vector2(center.x,anchor.y-20)) != id and rig.heists.site_at(Vector2(center.x,anchor.y+anchor.h+20)) != id,"strict y boundaries "+id)
	_check(rig.heists.site_at(Vector2(NAN,0)).is_empty() and not rig.heists.open("invented").ok,"invalid site geometry/identity refused")
	var menu := _open(rig,"abandoned")
	rig.game.p.rank = 4; rig.heists.sync_rank_unlock(); rig.heists.sync_rank_unlock()
	var changes: int = 0
	for event: Dictionary in rig.game.events:
		if event.kind == "site_availability_changed": changes += 1
	_check(not rig.heists.site_available("abandoned") and changes == 1,"rank4 unboards and removes availability once")
	menu = rig.heists.select(menu.token,"entry:3")
	_check(menu.ok and menu.title == "THE COPPER PIPES","existing closure survives later site availability change")
	rig.heists.close()
	var saved: Dictionary = rig.game.snapshot(); saved.player.rank = 0; saved.player.cred = 0
	rig.game.restore(saved); rig.game.s.mode = "playing"
	_check(not rig.heists.site_available("abandoned") and not _open(rig,"abandoned").ok,"same-session lower-rank restore retains source unboarded latch")
	rig.game.fresh(); rig.game.s.mode = "playing"
	_check(not rig.heists.site_available("abandoned"),"fresh does not rewrite session-global building")
	var cold := _rig()
	_check(cold.heists.site_available("abandoned"),"cold application starts from original locked content")
	groups += 1
func _durability() -> void:
	var rig := _rig()
	rig.game.p.inventory = [{"id":"food","n":"food","q":4,"migration_units":true}]
	var menu := _open(rig,"water_dept")
	menu = rig.heists.select(menu.token,"entry:1")
	_check(menu.ok and rig.game.p.inventory.size() == 1 and rig.game.p.inventory[0].q == 3,"source one-record entry consumes one migrated virtual food unit")
	menu = rig.heists.select(menu.token,"take")
	var save: Dictionary = rig.game.snapshot()
	var restored := FixedState.new()
	var result: Dictionary = restored.restore(save)
	_check(result.ok and restored.p.copper == rig.game.p.copper and restored.s.counters.heistsToday == 1 and restored.s.quests.copper_sings.done,"real save retains cap/copper/quest independently of modal")
	_check(restored.p.inventory[0].q == 3 and restored.p.inventory[0].migration_units,"migration remainder survives save roundtrip")
	_check(not save.state.has("heist") and not save.state.has("lockpick"),"no persisted duplicate activity owner")
	var events_before: int = rig.game.events.size()
	rig.heists.close()
	_check(rig.game.events.size() == events_before,"Escape has no fabricated refund/failure/save event")
	var isolated := FixedState.new()
	var spatial := Spatial.new()
	var heists := Heists.new(isolated,spatial)
	var owner_ref: WeakRef = weakref(isolated)
	isolated = null
	_check(owner_ref.get_ref() == null and not heists.ready(),"heist and nested ActionSession hold weak owner references")
	groups += 1
