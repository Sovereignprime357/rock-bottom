extends SceneTree
const Actions = preload("res://scripts/world_prop_actions.gd")
const Props = preload("res://scripts/prop_state.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Comms = preload("res://scripts/communications_system.gd")
const Companions = preload("res://scripts/companion_system.gd")
var checks: int = 0
var groups: int = 0
var completed: int = 0
var failures: Array[String] = []

class FixedState extends "res://scripts/game_state.gd":
	var rolls: Array[float] = []
	var cursor: int = 0
	var fallback: float = 0.75
	func random_float() -> float:
		var value: float = rolls[cursor] if cursor < rolls.size() else fallback
		cursor += 1; return value
class Spatial extends RefCounted:
	var reachable: bool = true
	var placement: Variant = Vector2(1800,1320)
	var calls: int = 0
	func can_reach_target(_id: String) -> bool: return reachable
	func stage_cash_pickup(_point: Vector2,_maximum: float) -> Variant:
		calls += 1; return placement
	func clear_placement(body: Dictionary) -> Vector2: return Vector2(body.x,body.y)

func _initialize() -> void: call_deferred("_run")
func _check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
func _run() -> void:
	_source_cases()
	_capabilities()
	_phone_physical()
	_continuity()
	_check(groups == 4,"all four prop groups complete without abort")
	if failures.is_empty():
		print("3D WORLD PROP ACTIONS GATE: PASS (%d checks; %d unchanged-source paths; shared props/capabilities/physical phone/continuity; root integration pending)" % [checks,completed]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D WORLD PROP ACTIONS GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
func _rig() -> Dictionary:
	var game := FixedState.new()
	var spatial := Spatial.new()
	var props := Props.new(game)
	var memory := Memory.new(game)
	var comms := Comms.new(game,props,func(): return 1000.0)
	var companions := Companions.new(game,spatial,comms)
	var actions := Actions.new(game,spatial,props,memory,companions)
	game.s.mode = "playing"; game.events.clear(); game.cursor = 0
	return {"game":game,"spatial":spatial,"props":props,"memory":memory,"comms":comms,"companions":companions,"actions":actions,"saves":0,"toast":"","events":[]}
func _id(rig: Dictionary,type: String) -> String:
	for index: int in range(rig.game.content.props.size()):
		if rig.game.content.props[index].type == type: return "prop:%d" % index
	return ""
func _near(rig: Dictionary,id: String,offset: Vector2 = Vector2.ZERO) -> void:
	var prop: Dictionary = rig.props.record(id)
	var center := Vector2(prop.x,prop.y)
	if prop.has("w") and prop.has("h"): center += Vector2(prop.w,prop.h)*0.5
	rig.game.p.x = center.x-rig.game.p.w*0.5+offset.x
	rig.game.p.y = center.y-rig.game.p.h*0.5+offset.y
func _flush(rig: Dictionary) -> void:
	while not rig.game.events.is_empty():
		var events: Array = rig.game.drain_events()
		for event: Dictionary in events:
			rig.events.append(event)
			if event.kind == "save_requested": rig.saves += 1
			elif event.kind == "toast": rig.toast = event.payload.text
			elif event.kind == "achievement": rig.toast = "· ACHIEVEMENT ·\n"+str(event.payload.definition.name)
			elif event.kind in ["feed","news"]: rig.comms.consume_event(event)
func _event_count(rig: Dictionary,kind: String) -> int:
	var count: int = 0
	for event: Dictionary in rig.events:
		if event.kind == kind: count += 1
	return count
func _same(actual: Variant,expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float): return absf(float(actual)-float(expected)) < 0.00001
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key: Variant in expected:
			if not actual.has(key) or not _same(actual[key],expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for index: int in range(expected.size()):
			if not _same(actual[index],expected[index]): return false
		return true
	return actual == expected
func _fields(actual: Dictionary,expected: Dictionary,label: String) -> void:
	for key: String in expected:
		# Physical centers use Vector2 float32; economic/state scalars keep double precision.
		if key in ["x","y"] and actual.has(key):
			_check(absf(float(actual[key])-float(expected[key])) <= 0.0003,label+"."+key+" float32 physical coordinate"); continue
		_check(actual.has(key) and _same(actual.get(key),expected[key]),"%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])

func _source_cases() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_props_reference.json"))
	_check(fixture is Dictionary and fixture.get("schema") == 1 and fixture.get("cases",[]).size() == 159,"unchanged-source world prop fixture is available")
	if not fixture is Dictionary: return
	var step_count: int = 0
	for test: Dictionary in fixture.cases:
		var rig := _rig()
		_oracle_setup(rig,test.setup)
		rig.game.rolls.assign(test.rolls); rig.game.fallback = test.roll; rig.game.cursor = 0
		var menu: Dictionary = {}
		for step: Dictionary in test.steps:
			rig.toast = ""
			var operation: Dictionary = step.operation
			var result: Dictionary = {"ok":true}
			match str(operation.kind):
				"open":
					rig.actions.close(); rig.companions.close(); menu = {}
					_near(rig,operation.id,Vector2(float(operation.get("offset",0)),0))
					result = rig.actions.open(operation.id)
					if result.has("options"): menu = result
				"choice":
					var index: int = operation.index
					_check(menu.has("options") and index >= 0 and index < menu.get("options",[]).size(),"%s choice has real captured option" % test.id)
					if not menu.has("options") or index < 0 or index >= menu.options.size(): break
					result = rig.actions.select(menu.token,menu.options[index].id)
					menu = result if result.has("options") else {}
				"escape": rig.actions.close(); rig.companions.close(); menu = {}
				"change": _oracle_change(rig,operation.values)
				"tick":
					var remaining: float = operation.ms
					while remaining > 0:
						var dt := minf(50.0,remaining)
						rig.actions.call("tick_"+str(operation.system),dt)
						remaining -= dt
				"save": rig.saved = rig.game.snapshot(); rig.saves += 1
				"restore":
					result = rig.game.restore(rig.saved)
					rig.props.reset_session("restore"); rig.actions.reset_session("restore"); menu = {}
				"fresh":
					result.ok = rig.game.fresh()
					rig.props.reset_session("fresh"); rig.actions.reset_session("fresh"); menu = {}
				_: _check(false,"unknown oracle operation "+str(operation.kind))
			_flush(rig)
			var label: String = "%s step%d %s" % [test.id,step_count,operation.kind]
			# tryInteract returns undefined; only source functions with bool returns are compared.
			if step.result.has("ok"): _check(result.get("ok") is bool and result.ok == step.result.ok,label+" accepted/refused")
			var shown: Variant = null
			if not menu.is_empty():
				var options: Array[Dictionary] = []
				for option: Dictionary in menu.options: options.append({"label":option.label,"enabled":option.enabled})
				shown = {"title":menu.title,"text":menu.text,"options":options}
			_check(_same(shown,step.menu),label+" exact captured dialogue")
			_oracle_expected(rig,step.expected,label,bool(step.compareSaves))
			if step.compareDraws: _check(rig.game.cursor == int(step.mechanicDraws),label+" exact gameplay RNG order/count")
			step_count += 1
		completed += 1
	_check(completed == 159 and step_count == 287,"all159 source paths and287 source steps completed without abort")
	groups += 1

func _oracle_setup(rig: Dictionary,setup: Dictionary) -> void:
	rig.game.p.merge(setup.player.duplicate(true),true)
	for key: String in setup.state:
		if key in ["flags","counters"]: rig.game.s[key].merge(setup.state[key].duplicate(true),true)
		else: rig.game.s[key] = setup.state[key]
	rig.game.s.achievements.assign(setup.achievements)
	rig.game.s.recognition = setup.recognition.duplicate(true)
	rig.game.s.recognitionVisit = setup.recognitionVisit.duplicate(true)
	rig.game.cash_piles.assign(setup.piles); rig.game.npcs.clear()
	for row: Dictionary in setup.props:
		var live: Dictionary = rig.props.record(row.id)
		for key: String in ["type","x","y","w","h","looted","tipsJar","diveCdT"]:
			if row.has(key): live[key] = row[key]
			else: live.erase(key)
		if row.type == "dumpster": rig.props.set_dumpster_looted(row.id,bool(row.get("looted",false)))
	rig.game.events.clear(); rig.events.clear(); rig.saves = setup.saves; rig.toast = setup.toast

func _oracle_change(rig: Dictionary,values: Dictionary) -> void:
	if values.has("player"):
		rig.game.p.merge(values.player.duplicate(true),true)
		if values.player.has("equip"):
			var equipment: Dictionary = {"shoes":null,"hat":null,"coat":null,"tool":null}
			equipment.merge(values.player.equip,true); rig.game.p.equip = equipment; rig.game.apply_equip_stats()
	if values.has("state"): rig.game.s.merge(values.state.duplicate(true),true)
	if values.has("flags"): rig.game.s.flags.merge(values.flags.duplicate(true),true)
	if values.has("counters"): rig.game.s.counters.merge(values.counters.duplicate(true),true)
	if values.has("props"):
		for id: String in values.props:
			var live: Dictionary = rig.props.record(id)
			live.merge(values.props[id].duplicate(true),true)
			if values.props[id].has("looted"): rig.props.set_dumpster_looted(id,values.props[id].looted)
	if values.has("achievements"): rig.game.s.achievements.assign(values.achievements)
	if values.has("recognition"): rig.game.s.recognition = values.recognition.duplicate(true)

func _oracle_expected(rig: Dictionary,expected: Dictionary,label: String,compare_saves: bool) -> void:
	if expected.has("player"): _fields(rig.game.p,expected.player,label+" player")
	if expected.has("state"):
		for key: String in expected.state:
			if key in ["flags","counters"]: _fields(rig.game.s[key],expected.state[key],label+" "+key)
			else:
				var field: Dictionary = {}
				field[key] = expected.state[key]; _fields(rig.game.s,field,label+" state")
	if expected.has("props"):
		for row: Dictionary in expected.props:
			var live: Dictionary = rig.props.record(row.id)
			var projected: Dictionary = {}
			for key: String in ["type","x","y","w","h","looted","tipsJar","diveCdT"]:
				if row.has(key): projected[key] = row[key]
			_fields(live,projected,label+" "+row.id)
	if expected.has("achievements"):
		var achievements: Array = rig.game.s.achievements.duplicate(); achievements.sort()
		_check(_same(achievements,expected.achievements),label+" achievements")
	for key: String in ["recognition","recognitionVisit"]:
		if expected.has(key): _check(_same(rig.game.s[key],expected[key]),label+" "+key)
	if expected.has("posts"): _check(_same(rig.comms.snapshot().posts,expected.posts),label+" authored posts")
	if expected.has("piles"):
		var piles: Array[Dictionary] = rig.game.cash_piles.duplicate(true)
		for index: int in range(piles.size()):
			if str(piles[index].get("id","")).begins_with("cp_phone_church_"): piles[index].id = "cp_phone_church_%d" % index
		_check(_same(piles,expected.piles),label+" physical piles")
	if expected.has("toast"): _check(rig.toast == expected.toast,"%s receipt actual=%s expected=%s" % [label,rig.toast,expected.toast])
	if compare_saves and expected.has("saves"): _check(rig.saves == int(expected.saves),"%s saves actual=%d expected=%d" % [label,rig.saves,expected.saves])

func _capabilities() -> void:
	var rig := _rig(); var game: RefCounted = rig.game
	var dumpster := _id(rig,"dumpster"); var bench := _id(rig,"park_bench"); var phone := _id(rig,"pay_phone")
	_check(rig.actions.ready() and not dumpster.is_empty() and not bench.is_empty() and not phone.is_empty(),"all dependencies and canonical prop families are available")
	for bad: String in ["", "prop:-1", "prop:00", "prop:999999", "interactive:0"]:
		_check(not rig.actions.open(bad).ok,"unknown/noncanonical prop identity is rejected")
	_near(rig,dumpster,Vector2(44,0))
	_check(not rig.actions.open(dumpster).ok and game.cursor == 0,"exact44px dumpster boundary refuses before RNG")
	_near(rig,bench,Vector2(50,0))
	_check(not rig.actions.open(bench).ok,"exact50px bench boundary refuses")
	_near(rig,phone,Vector2(38,0)); game.s.phonePropRingT = 30000
	_check(not rig.actions.open(phone).ok and game.s.phonePropRingT == 30000,"exact38px phone boundary retains answer opportunity")
	_near(rig,dumpster); rig.spatial.reachable = false
	_check(not rig.actions.open(dumpster).ok and game.cursor == 0,"blocked physical ray cannot roll or grant dumpster loot")
	rig.spatial.reachable = true; game.s.bossKind = "kingdom"
	_check(not rig.actions.open(dumpster).ok,"kingdom encounter keeps source interaction exclusion")
	game.s.bossKind = ""; game.p.hp = -1; game.p.stunT = 900
	game.rolls.assign([0.0,0.9,1.1/22.0,0.0]); game.cursor = 0
	var menu: Dictionary = rig.actions.open(dumpster)
	_check(menu.ok,"ordinary raw HP/stun do not invent a source prop gate")
	var captured: String = menu.options[0].label
	rig.props.garbage_reset()
	var draws: int = game.cursor
	var taken: Dictionary = rig.actions.select(menu.token,"take:0"); _flush(rig)
	_check(taken.ok and captured == "a wet sock (sell)" and game.cursor == draws,"garbage reset cannot replace or reroll captured dumpster choice")
	_check(rig.props.record(dumpster).looted and rig.props.record(dumpster).diveCdT == 90000 and game.s.counters.dumpDives == 1,"selected outcome writes shared looted projection/cooldown/count")
	var after: Dictionary = game.p.duplicate(true); var saves: int = rig.saves
	_check(not rig.actions.select(menu.token,"take:0").ok and game.p == after,"repeated capability cannot grant again")
	_flush(rig); _check(rig.saves == saves,"repeated capability does not save again")
	var untouched := _rig(); dumpster = _id(untouched,"dumpster"); _near(untouched,dumpster)
	menu = untouched.actions.open(dumpster); untouched.actions.close(); _flush(untouched)
	_check(not untouched.props.record(dumpster).get("looted",false) and untouched.saves == 0,"generic Escape is not the climb-out transaction")
	menu = untouched.actions.open(dumpster)
	untouched.actions.select(menu.token,"leave"); _flush(untouched)
	_check(untouched.props.record(dumpster).looted and not untouched.props.record(dumpster).has("diveCdT") and untouched.game.s.counters.dumpDives == 0 and untouched.saves == 0,"climb-out preserves source no-cooldown/no-count/no-save quirk")
	untouched.props.set_dumpster_looted(dumpster,false)
	menu = untouched.actions.open(dumpster)
	untouched.actions.select(menu.token,"not_an_option")
	_check(untouched.game.s.mode == "playing","consumed invalid action closes its owned modal")
	var pet := _rig(); dumpster = _id(pet,"dumpster"); _near(pet,dumpster)
	pet.game.npcs.clear(); pet.game.rolls.assign([0.0,0.9,20.1/22.0,0.0])
	_check(not pet.actions.consume_possum_handoff("forged"),"virtual possum requires a real one-use handoff")
	menu = pet.actions.open(dumpster)
	var handoff: Dictionary = pet.actions.select(menu.token,"take:0")
	_check(handoff.ok and handoff.domain == "companion" and pet.game.s.mode == "dialogue" and pet.props.record(dumpster).looted,"real Companion owner receives committed dumpster possum without outdoor actor")
	_check(not pet.actions.consume_possum_handoff("%d:dumpster:1" % pet.actions.get_instance_id()),"consumed real possum ticket cannot replay")
	var companion_after: Dictionary = pet.game.p.duplicate(true)
	_check(not pet.actions.select(menu.token,"take:0").ok and pet.game.s.mode == "dialogue" and pet.game.p == companion_after,"old dumpster token cannot close the new Companion modal")
	groups += 1

func _phone_physical() -> void:
	var rig := _rig(); var game: RefCounted = rig.game
	var phone := _id(rig,"pay_phone"); _near(rig,phone)
	game.s.phonePropRingT = 30000.0; game.rolls.assign([0.95]); game.cursor = 0
	rig.spatial.placement = null
	var before: Dictionary = game.p.duplicate(true)
	var initial_piles: int = game.cash_piles.size()
	var accepted: Dictionary = rig.actions.open(phone); _flush(rig)
	_check(accepted.ok and accepted.pending and not accepted.committed and game.s.phonePropRingT == 0,"blocked church answer reserves the ringing opportunity without claiming completion")
	_check(game.p == before and game.s.publicPhoneAnswered == 0 and game.cash_piles.size() == initial_piles and rig.saves == 0 and rig.toast.is_empty(),"blocked placement creates no payment/count/pile/receipt/save")
	_check(not rig.actions.open(phone).ok and game.cursor == 1,"pending answer cannot be rolled again")
	for invalid: Variant in [Vector2(NAN,1320),Vector2(1901,1320),Vector2(-1,1320),"point",false]:
		rig.spatial.placement = invalid
		var calls: int = rig.spatial.calls
		for step: int in range(5): rig.actions.tick_phone(50)
		_check(rig.spatial.calls == calls+1 and rig.actions.snapshot().phone_pending and game.cursor == 1,"invalid point retries at bounded cadence without RNG")
	rig.spatial.placement = Vector2(1808,1320)
	for step: int in range(5): rig.actions.tick_phone(50)
	_flush(rig)
	_check(not rig.actions.snapshot().phone_pending and game.s.publicPhoneAnswered == 1 and game.cursor == 1,"valid physical placement finishes the original answer exactly once")
	_check(game.cash_piles.size() == initial_piles+1 and game.cash_piles[-1].amt == 50 and game.cash_piles[-1].x == 1808 and game.p.cash == before.cash,"church reward is a real staged cash pile rather than direct cash")
	_check(game.s.flags.churchLoadedDumpsterX == 1800 and game.s.flags.churchLoadedDumpsterY == 1320 and rig.saves == 1 and _event_count(rig,"cash_spawned") == 1,"placement commits source flags and one save/spawn receipt")
	for step: int in range(10): rig.actions.tick_phone(50)
	_flush(rig)
	_check(game.cash_piles.size() == initial_piles+1 and rig.saves == 1,"later ticks cannot duplicate accepted phone transaction")
	var stale := _rig(); phone = _id(stale,"pay_phone"); _near(stale,phone)
	stale.game.s.phonePropRingT = 30000; stale.game.rolls.assign([0.95]); stale.spatial.placement = null
	stale.actions.open(phone); stale.game.fresh(); stale.spatial.placement = Vector2(1800,1320)
	var count: int = stale.game.cash_piles.size()
	_check(not stale.actions.tick_phone(50) and stale.game.cash_piles.size() == count,"unannounced epoch replacement cannot receive pending church money")
	stale.props.reset_session("restore"); stale.actions.reset_session("restore")
	_check(not stale.actions.snapshot().phone_pending,"explicit restore discards ephemeral pending answer")
	groups += 1

func _continuity() -> void:
	var rig := _rig(); var game: RefCounted = rig.game
	var dumpster := _id(rig,"dumpster"); var bench := _id(rig,"park_bench")
	rig.props.set_dumpster_looted(dumpster,true); rig.props.record(dumpster).diveCdT = 10.0; rig.props.record(dumpster).tipsJar = true
	game.s.mode = "paused"
	_check(not rig.actions.tick_props(50) and rig.props.record(dumpster).diveCdT == 10,"paused prop clocks remain unchanged")
	game.s.mode = "playing"; rig.actions.tick_props(50)
	_check(not rig.props.record(dumpster).looted and rig.props.record(dumpster).diveCdT == -40.0,"cooldown crossing keeps source negative remainder and clears shared looted")
	_flush(rig); _check(rig.saves == 0,"cooldown expiry does not invent a save")
	_near(rig,bench); rig.actions.open(bench)
	game.p.brain = 99; game.s.benchSitGainT = 1990; game.s.benchSitT = 59990
	game.s.benchSitPasserT = 30000
	rig.actions.tick_bench(10); _flush(rig)
	_check(game.p.brain == 100 and game.s.achievements.has("bench_press") and game.s.benchSitPasserT == 0,"bench exact60s/gain and strict passer boundaries retain source order")
	var timer: float = game.s.benchSitT
	game.p.x += 500; rig.actions.tick_bench(50)
	_check(game.s.sittingOnBench and game.s.benchSitT == timer+50,"bench state survives movement because source does not immobilize or auto-stand")
	game.s.publicPhoneT = 1234.0; game.s.phonePropRingT = 567.0
	var saved: Dictionary = game.snapshot()
	game.restore(saved); rig.props.reset_session("restore"); rig.actions.reset_session("restore")
	_check(game.s.sittingOnBench and game.s.benchSitT == timer+50 and game.s.publicPhoneT == 1234 and game.s.phonePropRingT == 567,"same-session restore carries unsaved source bench/phone clocks")
	_check(rig.props.record(dumpster).tipsJar and rig.props.record(dumpster).diveCdT == -40,"restore reuses source-global live prop transients")
	game.fresh(); rig.props.reset_session("fresh"); game.cursor = 0; game.rolls.clear(); game.fallback = 0.5
	rig.actions.reset_session("fresh")
	_check(game.s.sittingOnBench and game.s.benchSitT == timer+50 and game.s.publicPhoneT == 360000 and game.s.phonePropRingT == 0 and game.s.publicPhoneAnswered == 0 and game.cursor == 1,"fresh preserves bench continuity but explicitly rerolls phone/reset ring and answer count")
	var state: Dictionary = game.s.duplicate(true)
	_check(not rig.actions.tick_bench(INF) and not rig.actions.tick_props(-1) and not rig.actions.tick_phone(51) and game.s == state,"invalid prop ticks do not mutate clocks or resources")
	groups += 1
