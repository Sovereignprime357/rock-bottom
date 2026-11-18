extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Office = preload("res://scripts/office_campaign.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const Progression = preload("res://scripts/progression_routes.gd")
const Travel = preload("res://scripts/travel_system.gd")
var checks: int = 0
var failures: Array[String] = []
var fixture: Dictionary = {}

class FixedState:
	extends "res://scripts/game_state.gd"
	var roll: float = 0.4
	var draws: int = 0
	func random_float() -> float: draws += 1; return roll
	func random_index(size: int) -> int: return mini(size-1,int(floor(random_float()*size))) if size > 0 else 0
class Spatial:
	extends RefCounted
	var visible: bool = true
	var calls: int = 0
	func can_reach_target(_id: String) -> bool: calls += 1; return visible
	func can_use_zone(_id: String) -> bool: return visible

func _initialize() -> void: call_deferred("_run")
func _check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.000001
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
func _copy(value: Variant) -> Variant: return value.duplicate(true) if value is Dictionary or value is Array else value
func _bundle() -> Dictionary:
	var state := FixedState.new(); var spatial := Spatial.new(); var progression := Progression.new(state)
	var campaign := Campaign.new(state,spatial,progression); var travel := Travel.new(state,spatial)
	var office := Office.new(state,spatial,campaign,progression,travel)
	_check(office.ready(),"real office composition ready")
	return {"state":state,"spatial":spatial,"progression":progression,"campaign":campaign,"travel":travel,"office":office,"menu":{},"domain":"office"}
func _setup(bundle: Dictionary,data: Dictionary) -> void:
	var state: RefCounted = bundle.state
	for key: String in data.player: state.p[key] = _copy(data.player[key])
	for key: String in data.lifetime: state.p.lifetime[key] = data.lifetime[key]
	for pair: Array in [["office","office"],["claims","districtClaims"],["kingdom","kingdom"],["quests","quests"],["blockRoute","blockRoute"],["stash","hideoutStash"]]: state.s[pair[1]] = _copy(data[pair[0]])
	state.s.achievements = data.achievements.duplicate()
	state.s.counters.gutterInventoryDay = data.gutterInventoryDay; state.s.flags.introDone = data.introDone
	for key: String in ["day","dayTime","mode","bossActive","bossKind","brutusOlderActive"]: state.s[key] = data[key]
	state.events.clear(); state.draws = 0
func _at(state: RefCounted,point: Dictionary,offset: float = 0) -> void:
	state.p.x = point.x+float(point.get("w",0))*0.5-state.p.w*0.5+offset
	state.p.y = point.y+float(point.get("h",0))*0.5-state.p.h*0.5
func _location(bundle: Dictionary,target: String) -> Dictionary:
	if target == "office": return bundle.state.definition("src/systems/campaigns.js","OFFICE_DOOR",{})
	for actor: Dictionary in bundle.state.npcs:
		if actor.id == target: return actor
	return {}
func _mutate(bundle: Dictionary,values: Dictionary) -> void:
	var state: RefCounted = bundle.state
	for key: String in values.get("player",{}): state.p[key] = _copy(values.player[key])
	for key: String in values.get("lifetime",{}): state.p.lifetime[key] = values.lifetime[key]
	for key: String in values.get("state",{}): state.s[key] = _copy(values.state[key])
	for key: String in values.get("flags",{}): state.s.flags[key] = _copy(values.flags[key])
	for key: String in values.get("counters",{}): state.s.counters[key] = values.counters[key]
	if values.has("office"):
		state.s.office.merge(values.office.duplicate(true),true)
		if values.office.has("upgrades"):
			var clean: Dictionary = Campaign.fresh_office().upgrades
			clean.merge(values.office.upgrades,true); state.s.office.upgrades = clean
	if values.has("claims"): state.s.districtClaims = values.claims.duplicate(true)
	for id: String in values.get("quests",{}): state.s.quests[id].merge(values.quests[id],true)
func _menu_projection(menu: Dictionary) -> Variant:
	if menu.is_empty(): return null
	var options: Array = []
	for option: Dictionary in menu.options: options.append({"label":option.label,"enabled":option.enabled})
	return {"title":menu.title,"text":menu.text,"options":options}
func _run_operation(bundle: Dictionary,step: Dictionary,label: String) -> Dictionary:
	var operation: Dictionary = step.operation
	var state: RefCounted = bundle.state; var office: RefCounted = bundle.office
	match operation.kind:
		"open":
			office.close(); bundle.travel.close(); bundle.menu = {}; bundle.domain = "office"
			_at(state,_location(bundle,operation.target),operation.get("offset",0))
			var result: Dictionary = office.open(operation.target)
			if result.ok: bundle.menu = result
			return result
		"select":
			if bundle.menu.is_empty(): _check(false,label+" missing live model menu"); return {"ok":false}
			var index: int = -1
			for at: int in range(bundle.menu.options.size()):
				if bundle.menu.options[at].id == operation.action: index = at; break
			_check(index >= 0,label+" offered action "+operation.action)
			if index < 0: return {"ok":false}
			_check(index == int(step.result.index),label+" source option position "+operation.action)
			var choice: Dictionary = bundle.menu.options[index]
			if not choice.enabled: return {"ok":false}
			var result: Dictionary = bundle.travel.select(bundle.menu.token,operation.action) if bundle.domain == "travel" else office.select(bundle.menu.token,operation.action)
			bundle.menu = result if result.get("ok",false) and result.has("options") else {}
			if result.get("domain") == "travel": bundle.domain = "travel"
			return result
		"field":
			office.close(); bundle.travel.close(); state.s.mode = "playing"; bundle.menu = {}
			var target: Dictionary = office.active_field_target()
			_check(not target.is_empty(),label+" active physical field target")
			if target.is_empty(): return {"ok":false}
			_at(state,target,operation.get("offset",0))
			var old: Dictionary = {"mode":state.s.mode,"stunT":state.p.stunT,"bossActive":state.s.bossActive,"brutusOlderActive":state.s.brutusOlderActive}
			var context: Dictionary = operation.context
			if context.has("mode"): state.s.mode = context.mode
			if context.get("stun",false): state.p.stunT = 1
			if context.get("boss",false): state.s.bossActive = true
			if context.get("older",false): state.s.brutusOlderActive = true
			var result: Dictionary = office.use_field_target(context)
			state.s.mode = old.mode; state.p.stunT = old.stunT; state.s.bossActive = old.bossActive; state.s.brutusOlderActive = old.brutusOlderActive
			return result
		"change": _mutate(bundle,operation.values); return {"ok":true}
	return {"ok":false}
func _compare(bundle: Dictionary,expected: Dictionary,event_start: int,label: String) -> void:
	var state: RefCounted = bundle.state
	for key: String in expected.player: _check(_same(state.p[key],expected.player[key]),label+" player."+key+" got "+str(state.p[key])+" expected "+str(expected.player[key]))
	for key: String in expected.lifetime: _check(_same(state.p.lifetime[key],expected.lifetime[key]),label+" lifetime."+key)
	for pair: Array in [["office","office"],["claims","districtClaims"],["kingdom","kingdom"],["quests","quests"],["blockRoute","blockRoute"],["stash","hideoutStash"]]:
		_check(_same(state.s[pair[1]],expected[pair[0]]),label+" "+str(pair[0])+" got "+str(state.s[pair[1]]).left(450)+" expected "+str(expected[pair[0]]).left(450))
	var achievements: Array = state.s.achievements.duplicate(); achievements.sort()
	_check(_same(achievements,expected.achievements),label+" exact achievements")
	_check(state.s.counters.get("gutterInventoryDay",0) == expected.gutterInventoryDay,label+" inventory day stamp")
	for key: String in ["day","dayTime","mode","bossActive","bossKind","brutusOlderActive"]: _check(_same(state.s.get(key,false),expected[key]),label+" "+key)
	_check(state.draws == expected.draws,label+" exact authoritative random draw count got %d expected %d" % [state.draws,expected.draws])
	var writes: int = 0; var toast: String = ""
	for index: int in range(state.events.size()):
		var event: Dictionary = state.events[index]
		if event.kind == "save_requested": writes += 1
		if index >= event_start and event.kind == "toast": toast = event.payload.text
	_check(writes == expected.writes,label+" exact save count got %d expected %d" % [writes,expected.writes])
	if bundle.domain != "travel": _check(toast == expected.toast,label+" exact final source receipt got "+toast+" expected "+str(expected.toast))
	var objective: Dictionary = bundle.office.office_objective()
	_check(_same(objective,expected.objective if expected.objective != null else {}),label+" source objective projection")
func _source_paths() -> void:
	_check(fixture.counts.cases == 136 and fixture.counts.steps == 592,"136 unchanged source paths and592 steps")
	for path: Dictionary in fixture.cases:
		var bundle: Dictionary = _bundle(); _setup(bundle,path.setup); bundle.state.roll = path.roll
		var number: int = 0
		for step: Dictionary in path.steps:
			number += 1
			var label: String = path.id+" step%d %s" % [number,step.operation.kind]
			var event_start: int = bundle.state.events.size()
			var result: Dictionary = _run_operation(bundle,step,label)
			_check(result.get("ok",false) == step.result.ok,label+" source command result "+str(result.get("reason","")))
			# Travel's separately gated menu wording remains its owner's responsibility.
			if bundle.domain != "travel": _check(_same(_menu_projection(bundle.menu),step.menu),label+" exact menu text/options got "+str(_menu_projection(bundle.menu)).left(700)+" expected "+str(step.menu).left(700))
			else: _check((step.menu == null) == bundle.menu.is_empty(),label+" real Travel menu lifecycle")
			_compare(bundle,step.expected,event_start,label)
func _prepare_property_bundle() -> Dictionary:
	var bundle: Dictionary = _bundle(); var state: RefCounted = bundle.state
	state.s.mode = "playing"; state.s.flags.introDone = true; state.s.day = 4; state.s.dayTime = 0.3
	state.p.cash = 100; state.p.copper = 10; state.p.lifetime.routesCompleted = 3; state.p.hp = -2; state.p.stunT = 500
	state.s.office = Campaign.fresh_office()
	_at(state,_location(bundle,"lease_guy")); state.events.clear(); return bundle
func _counterexamples() -> void:
	var b: Dictionary = _prepare_property_bundle(); var state: RefCounted = b.state
	var menu: Dictionary = b.office.open("lease_guy")
	_check(menu.ok,"raw negativeHP/stun can open literal resident menu")
	var before: Dictionary = state.snapshot(); b.spatial.visible = false
	_check(not b.office.select(menu.token,"purchase").ok and _same(before,state.snapshot()),"fresh occlusion rejects purchase without mutation")
	b.spatial.visible = true; menu = b.office.open("lease_guy"); state.p.x += 60; before = state.snapshot()
	_check(not b.office.select(menu.token,"purchase").ok and _same(before,state.snapshot()),"moved resident capability rechecks strict60px")
	_check(state.s.mode == "playing","consumed moved-resident selection closes its dialogue")
	_at(state,_location(b,"lease_guy")); menu = b.office.open("lease_guy"); state.p.cash = 39; before = state.snapshot()
	_check(not b.office.select(menu.token,"purchase").ok and _same(before,state.snapshot()),"resources removed after menu cannot be spent")
	_check(state.s.mode == "playing","consumed changed-resource selection closes its dialogue")
	state.p.cash = 100; menu = b.office.open("lease_guy")
	_check(b.office.select(menu.token,"purchase").ok,"valid purchase commits once")
	before = state.snapshot()
	_check(not b.office.select(menu.token,"purchase").ok and _same(before,state.snapshot()),"consumed purchase token cannot replay")
	_at(state,_location(b,"office")); menu = b.office.open("office")
	var nested: Dictionary = b.office.select(menu.token,"upgrades")
	_check(nested.ok and nested.token != menu.token,"nested office page gets new capability")
	before = state.snapshot()
	_check(not b.office.select(menu.token,"upgrades").ok and _same(before,state.snapshot()),"old page cannot consume new page")
	_check(state.s.mode == "dialogue","stale token preserves current valid nested menu")
	_check(b.office.select(nested.token,"upgrade:desk").ok,"current nested page remains usable after stale token")
	state.s.office.claimJob = {"id":"canal","stage":"survey"}; b.office.close(); state.p.stunT = 0
	var field: Dictionary = b.office.active_field_target(); _at(state,field)
	before = state.snapshot(); b.spatial.visible = false
	_check(not b.office.use_field_target().ok and _same(before,state.snapshot()),"field requires fresh actual LOS")
	b.spatial.visible = true
	_check(not b.office.use_field_target({"target_id":"claim:alley:survey"}).ok,"wrong marker cannot progress active contract")
	_check(b.office.use_field_target().ok and state.s.office.claimJob.stage == "file","source field transition commits once")
	before = state.snapshot()
	_check(not b.office.use_field_target().ok and _same(before,state.snapshot()),"field transition cannot replay at same source anchor")
	b.office.close(); _at(state,_location(b,"office")); menu = b.office.open("office"); state.fresh()
	before = state.snapshot()
	_check(not b.office.select(menu.token,"upgrades").ok and _same(before,state.snapshot()),"fresh epoch rejects prior office token")
	var missing := Office.new(state,b.spatial,null,b.progression,b.travel)
	_check(not missing.ready() and not missing.open("office").ok,"missing real foundation cannot pretend office readiness")
	state.s.mode = "playing"; state.s.office.owned = true; state.s.office.upgrades.desk = true; state.s.kingdom.stage = "summons"
	_at(state,_location(b,"office")); menu = b.office.open("office")
	var pending: Dictionary = b.office.select(menu.token,"kingdom")
	_check(not pending.ok and pending.reason == "kingdom_actions_pending","unimplemented Kingdom action is explicit pending dependency")
	state.s.bossKind = "kingdom"; before = state.snapshot()
	_check(not b.office.open("office").ok and _same(before,state.snapshot()),"Kingdom battle rejects office opening")
	_check(b.office.supports("office") and b.office.supports("lease_guy") and b.office.supports("gutter_greg") and not b.office.supports("invented"),"exact service/resident coverage")
func _run() -> void:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/office_reference.json"))
	_check(decoded is Dictionary,"office source fixture parses")
	if decoded is Dictionary: fixture = decoded; _source_paths(); _counterexamples()
	if failures.is_empty(): print("3D OFFICE CAMPAIGN GATE: PASS (%d checks;136 source paths/592 steps; Kingdom actions remain P13c)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D OFFICE CAMPAIGN GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)
