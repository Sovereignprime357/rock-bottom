extends SceneTree
const Utilities = preload("res://scripts/neighborhood_utilities.gd")
const State = preload("res://scripts/game_state.gd")
const Travel = preload("res://scripts/travel_system.gd")
var checks: int = 0
var completed: int = 0
var groups: int = 0
var failures: Array[String] = []
class SequenceState:
	extends "res://scripts/game_state.gd"
	var rolls: Array[float] = []
	var cursor: int = 0
	func random_float() -> float:
		var value: float = rolls[cursor] if cursor < rolls.size() else 0.75
		cursor += 1; return value
class Spatial:
	extends RefCounted
	var reachable: bool = true
	var calls: int = 0
	func can_use_zone(_id: String) -> bool: calls += 1; return reachable
	func can_reach_target(_id: String) -> bool: return reachable
class ReplacingSpatial:
	extends RefCounted
	var owner_ref: WeakRef
	var replace_player: bool = false
	func can_use_zone(_id: String) -> bool:
		var owner: RefCounted = owner_ref.get_ref()
		if replace_player: owner.p = owner.p.duplicate(true)
		else: owner.s = owner.s.duplicate(true)
		return true
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/neighborhood_utilities_reference.json"))
	_menus(fixture); _actions(fixture); _timelines(fixture); _entries(fixture); _continuity(fixture)
	_capabilities(); _visibility(); _clock_properties()
	_check(completed == 133,"all133 source fixtures completed without abort")
	_check(groups == 8,"all8 utility groups completed without abort")
	if failures.is_empty():
		print("3D NEIGHBORHOOD UTILITIES GATE: PASS (%d checks;133 source cases;Block/market/squint/12zone entries/autosave/session continuity;Runtime/Scene pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D NEIGHBORHOOD UTILITIES GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
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
	for key: String in expected:
		_check(actual.has(key) and _same(actual.get(key),expected[key]),"%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])
func _at_zone(game: RefCounted,id: String) -> void:
	for zone: Dictionary in game.content.world.zones:
		if zone.id == id:
			game.p.x = zone.x+zone.w*0.5-game.p.w*0.5; game.p.y = zone.y+zone.h*0.5-game.p.h*0.5; return
func _rig(setup: Dictionary = {}) -> Dictionary:
	var game := SequenceState.new()
	# Some fixtures author overlapping zones; never mutate Content's shared immutable cache.
	game.content = game.content.duplicate(true)
	var spatial := Spatial.new()
	var utilities := Utilities.new(game,spatial)
	game.p.merge({"x":4000.0,"y":4000.0,"cash":20,"cred":0,"brain":70.0,"shakes":0.0,"hp":100.0,"maxHp":100.0,"wanted":0,"stunT":0.0,"rockedT":0.0,"crashT":0.0,"inventory":[]},true)
	game.p.merge(setup.get("player",{}).duplicate(true),true)
	game.s.merge({"mode":"playing","day":1,"dayTime":0.35,"tweakerT":0.0,"tweakerCdT":0.0,"autoSaveT":0.0},true)
	game.s.merge(setup.get("state",{}).duplicate(true),true)
	game.s.flags.merge(setup.get("flags",{}).duplicate(true),true)
	game.s.counters.bigPan = setup.get("bigPan",0)
	for row: Array in Utilities.ENTRIES: game.s.flags[row[1]] = not setup.get("entries",false)
	if setup.has("overlap"):
		for zone: Dictionary in game.content.world.zones:
			if setup.overlap.has(zone.id): zone.merge({"x":100,"y":100,"w":200,"h":200},true)
	if setup.has("zone"): _at_zone(game,setup.zone)
	if setup.has("center"):
		game.p.x = setup.center[0]-game.p.w*0.5; game.p.y = setup.center[1]-game.p.h*0.5
	game.rolls.assign(setup.get("rolls",[])); game.events.clear()
	return {"game":game,"spatial":spatial,"utilities":utilities}
func _event_count(game: RefCounted,kind: String) -> int:
	var count: int = 0
	for event: Dictionary in game.events:
		if event.kind == kind: count += 1
	return count
func _toasts(game: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in game.events:
		if event.kind == "toast": result.append(event.payload.duplicate(true))
	return result
func _sounds(game: RefCounted) -> Array[String]:
	var result: Array[String] = []
	for event: Dictionary in game.events:
		if event.kind == "sound": result.append(event.payload.id)
	return result
func _posts(game: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in game.events:
		if event.kind == "feed":
			result.push_front({"h":event.payload.author,"t":event.payload.text,"day":game.s.day})
			if result.size() > 8: result.pop_back()
	return result
func _news(game: RefCounted) -> String:
	var result: String = ""
	for event: Dictionary in game.events:
		if event.kind == "news": result = "· BREAKING · "+str(event.payload.text)+"   ◆   "+result
	return result
func _menu_view(menu: Dictionary) -> Variant:
	if not menu.get("ok",false) or not menu.has("options"): return null
	var options: Array[Dictionary] = []
	for option: Dictionary in menu.options: options.append({"label":option.label,"enabled":option.enabled})
	return {"title":menu.title,"text":menu.text,"options":options}
func _menus(fixture: Dictionary) -> void:
	_check(fixture.menus.size() == 23,"23 source menus present")
	for test: Dictionary in fixture.menus:
		var rig: Dictionary = _rig(test.setup)
		var menu: Dictionary = rig.utilities.open_zone(test.setup.zone)
		_check(menu.get("ok",false) and menu.has("token"),test.id+" real capability")
		_check(_same(_menu_view(menu),test.expected),test.id+" exact source menu")
		_check(rig.game.cursor == 0 and rig.game.events.is_empty(),test.id+" opening draws/grants nothing")
		completed += 1
	groups += 1
func _actions(fixture: Dictionary) -> void:
	_check(fixture.cases.size() == 75,"75 unchanged source actions present")
	for test: Dictionary in fixture.cases:
		var rig: Dictionary = _rig(test.setup)
		var menu: Dictionary = rig.utilities.open_zone(test.setup.zone)
		_check(_same(_menu_view(menu),test.menu),test.id+" captured source menu")
		rig.game.p.merge(test.setup.get("afterOpen",{}).duplicate(true),true)
		rig.game.s.merge(test.setup.get("afterOpenState",{}).duplicate(true),true)
		if test.setup.action == "escape": rig.utilities.close()
		else:
			var result: Dictionary = rig.utilities.select(menu.get("token",""),test.setup.action)
			_check(result.get("ok",false) and result.get("closed",false),test.id+" accepted one-use action")
		var actual: Dictionary = {"player":{},"bigPan":rig.game.s.counters.bigPan,"mode":rig.game.s.mode,"toasts":_toasts(rig.game),"sounds":_sounds(rig.game),"posts":_posts(rig.game),"news":_news(rig.game),"saves":_event_count(rig.game,"save_requested"),"draws":rig.game.cursor}
		for key: String in test.expected.player: actual.player[key] = rig.game.p[key]
		_fields(actual,test.expected,test.id)
		var gestures: int = 0 if test.setup.action in ["leave","escape"] else 1
		_check(_event_count(rig.game,"gesture") == gestures,test.id+" accepted gesture only")
		completed += 1
	groups += 1
func _timelines(fixture: Dictionary) -> void:
	_check(fixture.timelines.size() == 20,"20 source clock/input timelines present")
	for test: Dictionary in fixture.timelines:
		var rig: Dictionary = _rig(test.setup)
		for step: Dictionary in test.steps:
			var op: Dictionary = step.op
			if op.get("key") == "down": rig.utilities.press_squint()
			elif op.get("key") == "up": rig.utilities.release_squint()
			elif op.has("open"):
				# Source blockMenu is callable directly; real Scene entry adds zone/physics.
				_at_zone(rig.game,op.open); rig.utilities.open_zone(op.open)
			elif op.get("close",false): rig.utilities.close()
			else:
				if op.held:
					if not rig.game.s.keys.has("f"): rig.game.s.keys.append("f")
				else: rig.utilities.release_squint()
				if rig.game.s.mode == "playing":
					rig.utilities.tick_squint(op.dt,op.held); rig.utilities.finish_world_step(op.dt)
			var actual: Dictionary = {"brain":rig.game.p.brain,"mode":rig.game.s.mode,"held":rig.game.s.keys.has("f"),"toasts":_toasts(rig.game),"saves":_event_count(rig.game,"save_requested")}
			for key: String in Utilities.CLOCKS: actual[key] = rig.game.s.get(key,0)
			_fields(actual,step.expected,test.id)
		completed += 1
	groups += 1
func _entry_snapshot(game: RefCounted) -> Dictionary:
	var flags: Dictionary = {}
	for row: Array in Utilities.ENTRIES: flags[row[1]] = game.s.flags.get(row[1],false)
	return {"flags":flags,"toasts":_toasts(game),"posts":_posts(game),"saves":_event_count(game,"save_requested")}
func _entries(fixture: Dictionary) -> void:
	_check(fixture.entries.size() == 13,"13 source entry cases present")
	for test: Dictionary in fixture.entries:
		var rig: Dictionary = _rig(test.setup)
		if test.has("steps"):
			for expected: Dictionary in test.steps:
				rig.utilities.tick_zone_entries(); _fields(_entry_snapshot(rig.game),expected,test.id)
		else:
			rig.utilities.tick_zone_entries(); _fields(_entry_snapshot(rig.game),test.first,test.id+" first")
			rig.utilities.tick_zone_entries(); _fields(_entry_snapshot(rig.game),test.repeat,test.id+" repeat")
		_check(rig.game.cursor == 0,test.id+" traversal does not add RNG")
		completed += 1
	# Real Travel must expose the twelve destinations through the exact written flags.
	var visited: Dictionary = _rig({"entries":true})
	var travel := Travel.new(visited.game,visited.spatial)
	_check(travel.destinations().size() == 6,"only6 ungated bus targets before traversal")
	for row: Array in Utilities.ENTRIES:
		_at_zone(visited.game,row[0]); visited.utilities.tick_zone_entries()
	_check(travel.destinations().size() == 18,"all18 real bus targets after12 source entries")
	var saved: Dictionary = visited.game.snapshot()
	visited.game.restore(saved); visited.utilities.reset_session("restore")
	visited.game.events.clear()
	_check(visited.utilities.tick_zone_entries().is_empty() and visited.game.events.is_empty(),"restored entry flags suppress duplicate receipts")
	groups += 1
func _continuity(fixture: Dictionary) -> void:
	_check(fixture.continuity.size() == 2,"two actual source fresh/load continuity cases")
	for test: Dictionary in fixture.continuity:
		var rig: Dictionary = _rig()
		for key: String in Utilities.CLOCKS: rig.game.s[key] = test.before[key]
		rig.game.s.keys.append("f")
		var saved: Dictionary = rig.game.snapshot()
		for key: String in Utilities.CLOCKS: _check(not saved.state.has(key),test.kind+" does not persist "+key)
		if test.kind == "fresh": rig.game.fresh()
		else: rig.game.restore(saved)
		_check(not rig.utilities.ready(),test.kind+" owner waits for explicit epoch reset")
		_check(rig.utilities.reset_session(test.kind),test.kind+" explicit lifecycle accepted")
		var after: Dictionary = {"held":rig.game.s.keys.has("f")}
		for key: String in Utilities.CLOCKS: after[key] = rig.game.s.get(key,0)
		_fields(after,test.after,test.kind)
		rig.game.s.mode = "playing"; rig.utilities.tick_squint(16,false)
		_check(rig.game.s.tweakerT == 0 and rig.game.s.tweakerCdT == 1218,test.kind+" first active step ends old vision and advances carried cooldown")
		completed += 1
	groups += 1
func _capabilities() -> void:
	for replace_player: bool in [false,true]:
		var replaced_game := SequenceState.new()
		_at_zone(replaced_game,"block"); replaced_game.s.mode = "playing"; replaced_game.events.clear()
		var replacing := ReplacingSpatial.new()
		replacing.owner_ref = weakref(replaced_game); replacing.replace_player = replace_player
		var reentrant := Utilities.new(replaced_game,replacing)
		var prior: Dictionary = replaced_game.snapshot()
		_check(reentrant.open_zone("block").get("reason") == "replaced_state","spatial callback p/s replacement refuses immediately")
		_check(replaced_game.s.mode == "playing" and _same(prior,replaced_game.snapshot()) and replaced_game.events.is_empty() and replaced_game.cursor == 0,"spatial replacement cannot mutate new mode/resources/RNG")
	var rig: Dictionary = _rig({"zone":"block","player":{"rocks":1,"supplies":3,"inventory":[{"id":"lottery","n":"ticket","q":1}]},"flags":{"hasStripePackage":true}})
	var before: Dictionary = rig.game.snapshot()
	rig.spatial.reachable = false
	_check(not rig.utilities.open_zone("block").ok and _same(before,rig.game.snapshot()) and rig.game.cursor == 0,"physical refusal before mode/resources/RNG")
	rig.spatial.reachable = true; rig.game.p.x = 0; rig.game.p.y = 0
	_check(not rig.utilities.open_zone("block").ok,"zone membership cannot be replaced by spatial true")
	_at_zone(rig.game,"block"); rig.game.s.bossKind = "kingdom"
	_check(not rig.utilities.open_zone("block").ok,"kingdom blocks zone verb")
	rig.game.s.bossKind = "tony"; rig.game.p.hp = -10; rig.game.p.stunT = 500
	var menu: Dictionary = rig.utilities.open_zone("block")
	_check(menu.ok,"ordinary boss/raw HP/stun do not invent callback guards; Scene gates E")
	var old: String = menu.token
	menu = rig.utilities.open_zone("block")
	_check(rig.utilities.select(old,"lottery").reason == "stale_session" and rig.game.s.mode == "dialogue","old token leaves current menu intact")
	var calls: int = rig.spatial.calls
	rig.spatial.reachable = false; rig.game.p.x = 0; rig.game.p.y = 0; rig.game.p.inventory.clear()
	var selected: Dictionary = rig.utilities.select(menu.token,"lottery")
	_check(selected.ok and rig.game.cursor == 1 and _event_count(rig.game,"save_requested") == 1,"captured lottery callback survives ticket removal/relocation")
	_check(rig.spatial.calls == calls,"modal selection does not add a new ray")
	_check(not rig.utilities.select(menu.token,"lottery").ok and rig.game.cursor == 1,"scratch token cannot replay")
	for handoff: String in ["smoke","sleep","cooking","package"]:
		var delegated: Dictionary = _rig({"zone":"block","player":{"rocks":1,"supplies":3},"flags":{"hasStripePackage":true}})
		var opened: Dictionary = delegated.utilities.open_zone("block")
		var original: Dictionary = delegated.game.p.duplicate(true)
		var result: Dictionary = delegated.utilities.select(opened.token,handoff)
		_check(result.get("handoff") == handoff and result.get("zone") == "block" and delegated.game.s.mode == "playing","consumed real-owner handoff "+handoff)
		_check(_same(original,delegated.game.p) and delegated.game.cursor == 0 and delegated.game.events.is_empty(),"handoff does not duplicate transaction/gesture "+handoff)
	for action: String in ["lottery","smoke","cooking","bogus"]:
		var denied: Dictionary = _rig({"zone":"block","player":{"rocks":0,"supplies":0}})
		var opened: Dictionary = denied.utilities.open_zone("block")
		_check(not denied.utilities.select(opened.token,action).ok and denied.game.cursor == 0 and denied.game.events.is_empty(),"disabled/unoffered action cannot grant "+action)
	for kind: String in ["fresh","restore"]:
		var replaced: Dictionary = _rig({"zone":"market"})
		var opened: Dictionary = replaced.utilities.open_zone("market")
		if kind == "fresh": replaced.game.fresh()
		else: replaced.game.restore(replaced.game.snapshot())
		replaced.game.s.mode = "dialogue"
		var snapshot: Dictionary = replaced.game.snapshot()
		_check(replaced.utilities.select(opened.token,"change").reason == "replaced_state",kind+" rejects prior menu epoch")
		_check(_same(snapshot,replaced.game.snapshot()) and replaced.game.s.mode == "dialogue",kind+" does not close replacement mode")
		_check(not replaced.utilities.press_squint().ok and not replaced.utilities.tick_squint(16,true) and replaced.utilities.tick_zone_entries().is_empty() and not replaced.utilities.finish_world_step(16),kind+" all mutable seams refuse unannounced replacement")
	var lonely := SequenceState.new()
	var spatial := Spatial.new()
	var utility := Utilities.new(lonely,spatial)
	var owner_ref: WeakRef = weakref(lonely)
	lonely = null
	_check(owner_ref.get_ref() == null and not utility.ready(),"owner is weak, no model/capability cycle")
	groups += 1
func _visibility() -> void:
	var rig: Dictionary = _rig()
	var center: Vector2 = rig.game.player_center()
	for distance: float in [0.0,59.99,60.0,60.01,1000.0]:
		var pile: Dictionary = {"x":center.x+distance,"y":center.y}
		_check(rig.utilities.cash_visible(pile) == (distance < 60.0),"strict60px source visibility %.2f" % distance)
		for flag: String in ["intro","tool","equip"]:
			pile[flag] = true if flag == "intro" else "source_pickup"
			_check(rig.utilities.cash_visible(pile),flag+" always visible")
			pile.erase(flag)
		rig.game.s.tweakerT = 1
		_check(rig.utilities.cash_visible(pile),"positive vision reveals ordinary cash")
		rig.game.s.tweakerT = -1
		_check(rig.utilities.cash_visible(pile) == (distance < 60.0),"negative remainder is not visible vision")
		pile.collected = true; rig.game.s.tweakerT = 1
		_check(not rig.utilities.cash_visible(pile),"collected pile never appears")
		rig.game.s.tweakerT = 0
	var snapshot: Dictionary = rig.game.snapshot()
	for index: int in range(20): rig.utilities.cash_visible({"x":center.x+30,"y":center.y})
	_check(_same(snapshot,rig.game.snapshot()) and rig.game.cursor == 0 and rig.game.events.is_empty(),"visibility never collects or consumes state/RNG")
	_check(not rig.utilities.cash_visible({}) and not rig.utilities.cash_visible({"x":NAN,"y":0}),"malformed ordinary points fail closed")
	groups += 1
func _clock_properties() -> void:
	var rig: Dictionary = _rig({"zone":"block"})
	for invalid: float in [NAN,INF,-1.0,0.0,50.001,1000000.0]:
		var before: Dictionary = rig.game.s.duplicate(true)
		_check(not rig.utilities.tick_squint(invalid,true) and not rig.utilities.finish_world_step(invalid) and _same(before,rig.game.s),"invalid dt rejects without partial mutation")
	rig.game.s.tweakerT = 100; rig.game.s.tweakerCdT = 200
	for mode: String in ["paused","dialogue","cookmini","title","ending"]:
		rig.game.s.mode = mode
		_check(not rig.utilities.tick_squint(16,true) and rig.game.s.tweakerT == 100 and rig.game.s.tweakerCdT == 200,"paused vision clocks "+mode)
		_check(not rig.utilities.press_squint().ok,"paused keydown rejected "+mode)
		rig.game.s.flags.underpassEntered = false
		_check(rig.utilities.tick_zone_entries().is_empty(),"paused traversal "+mode)
	# Root calls this tail only for an already admitted active step, even if delivery opened a modal.
	rig.game.s.mode = "dialogue"; rig.game.s.autoSaveT = 45000
	_check(rig.utilities.finish_world_step(16) and rig.game.s.autoSaveT == 0 and _event_count(rig.game,"save_requested") == 1,"same-step modal continuation still autosaves")
	rig.game.s.mode = "playing"; rig.game.events.clear()
	var zone: Dictionary = {}
	for candidate: Dictionary in rig.game.content.world.zones:
		if candidate.id == "underpass": zone = candidate; break
	for edge: Vector2 in [Vector2(zone.x,zone.y),Vector2(zone.x+zone.w,zone.y+zone.h)]:
		rig.game.p.x = edge.x-rig.game.p.w*0.5; rig.game.p.y = edge.y-rig.game.p.h*0.5
		rig.game.s.flags.underpassEntered = false
		_check(rig.utilities.tick_zone_entries().has("underpassEntered"),"source inclusive zone boundary")
	var first: Dictionary = _rig()
	var second: Dictionary = _rig()
	first.utilities.press_squint(); second.utilities.press_squint()
	first.utilities.tick_squint(32,true)
	second.utilities.tick_squint(16,true); second.utilities.tick_squint(16,true)
	_check(first.game.s.tweakerT == second.game.s.tweakerT and first.game.s.tweakerCdT == second.game.s.tweakerCdT and is_equal_approx(first.game.p.brain,second.game.p.brain),"split/unsplit ordinary vision interval preserves timers and drain")
	groups += 1
