extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const Office = preload("res://scripts/office_campaign.gd")
const Kingdom = preload("res://scripts/kingdom_campaign.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Bosses = preload("res://scripts/boss_system.gd")
const Days = preload("res://scripts/day_system.gd")
const Progression = preload("res://scripts/progression_routes.gd")
const Travel = preload("res://scripts/travel_system.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Communications = preload("res://scripts/communications_system.gd")
const Props = preload("res://scripts/prop_state.gd")
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
	var blocked: bool = false
	var refused_id: String = ""
	var displaced: Vector2 = Vector2.ZERO
	var calls: int = 0
	func unix_ms() -> float: return 1763424000000.0
	func can_reach_target(_id: String) -> bool: return visible
	func can_use_zone(_id: String) -> bool: return visible
	func can_hit(_a: Vector2,_b: Vector2,_source: String,_target: String) -> bool: return visible
	func clear_placement(body: Dictionary) -> Variant:
		calls += 1
		return null if blocked or body.id == refused_id else Vector2(body.x,body.y)+displaced
	func stage_cash_pickup(point: Vector2,_bound: float) -> Variant: return point
	func move_body(_body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary: return {"position":intended,"blocked":false}
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
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
func _actor(state: RefCounted,id: String) -> Dictionary:
	for body: Dictionary in state.npcs:
		if body.id == id: return body
	return {}
func _kingdom_actor(body: Dictionary) -> bool: return body.get("kingdomGuard",false) or body.get("kingdomBoss",false) or body.get("kingdomAdd",false) or body.get("kingdomPretender",false)
func _bundle() -> Dictionary:
	var state := FixedState.new(); var spatial := Spatial.new(); var progression := Progression.new(state)
	var props := Props.new(state); var comms := Communications.new(state,props,spatial.unix_ms); var memory := Memory.new(state)
	var travel := Travel.new(state,spatial); var campaign := Campaign.new(state,spatial,progression,travel,comms,memory)
	var days := Days.new(state,spatial,progression,travel,campaign,comms,spatial.unix_ms)
	campaign.bind_day_owner(days); travel.bind_day_owner(days)
	var office := Office.new(state,spatial,campaign,progression,travel); var combat := Combat.new(state,spatial)
	var kingdom := Kingdom.new(state,spatial,campaign,office,combat,memory,comms,days)
	var bosses := Bosses.new(state,combat,kingdom); combat._domain_ref = weakref(bosses)
	_check(kingdom.ready(),"Kingdom real owner composition ready")
	return {"state":state,"spatial":spatial,"progression":progression,"props":props,"comms":comms,"memory":memory,"travel":travel,"campaign":campaign,"days":days,"office":office,"combat":combat,"kingdom":kingdom,"bosses":bosses,"menu":{},"ending_ms":0.0,"endingPresentation":null}
func _setup(bundle: Dictionary,data: Dictionary) -> void:
	var state: RefCounted = bundle.state
	for key: String in data.player: state.p[key] = data.player[key]
	for key: String in data.lifetime: state.p.lifetime[key] = data.lifetime[key]
	for pair: Array in [["office","office"],["claims","districtClaims"],["kingdom","kingdom"],["quests","quests"],["flags","flags"],["kingdomBattle","kingdomBattle"],["recognition","recognition"],["recognitionVisit","recognitionVisit"]]: state.s[pair[1]] = _copy(data[pair[0]])
	state.s.achievements = data.achievements.duplicate()
	for key: String in ["day","mode","endingContinue","bossActive","bossKind","bossPhase","brutusOlderActive"]: state.s[key] = data[key]
	for index: int in range(state.npcs.size()-1,-1,-1):
		if _kingdom_actor(state.npcs[index]): state.npcs.remove_at(index)
	for actor: Dictionary in data.actors: state.npcs.append(actor.duplicate(true))
	state.s.bossNPC = _actor(state,data.bossNPC) if not str(data.bossNPC).is_empty() else null
	_set_projectiles(bundle,data.projectiles)
	bundle.comms._posts.assign(data.communications.posts); bundle.comms._news_text = data.communications.news_text; bundle.comms._news_index = int(data.communications.news_index)
	state.events.clear(); state.draws = 0
func _set_projectiles(bundle: Dictionary,rows: Array) -> void:
	bundle.state.projectiles.clear()
	for raw: Dictionary in rows:
		var record: Dictionary = raw.duplicate(true); var id: Variant = raw.get("from")
		var body: Dictionary = _actor(bundle.state,str(id)) if id != null else {}
		record.from = body if not body.is_empty() else ({"id":id} if id != null else null)
		bundle.state.projectiles.append(record)
func _at(state: RefCounted,point: Dictionary,offset: float = 0) -> void:
	state.p.x = point.x+float(point.get("w",0))*0.5-state.p.w*0.5+offset; state.p.y = point.y+float(point.get("h",0))*0.5-state.p.h*0.5
func _point(bundle: Dictionary,id: String) -> Dictionary:
	var parts: PackedStringArray = id.split(":")
	if parts[0] == "kingdom":
		for door: Dictionary in bundle.kingdom.doors:
			if door.id == parts[1]: return door
	if parts[0] == "kingdom_mark": return bundle.kingdom._by_id[parts[1]].marks[int(parts[2])]
	if parts[0] == "kingdom_banner": return bundle.kingdom.emperor.banner if parts[1] == "throne" else bundle.kingdom._by_id[parts[1]].banner
	return {}
func _mutate(bundle: Dictionary,values: Dictionary) -> void:
	var state: RefCounted = bundle.state
	for key: String in values.get("player",{}): state.p[key] = _copy(values.player[key])
	for key: String in values.get("lifetime",{}): state.p.lifetime[key] = values.lifetime[key]
	for key: String in values.get("state",{}): state.s[key] = _copy(values.state[key])
	for key: String in values.get("flags",{}): state.s.flags[key] = _copy(values.flags[key])
	if values.has("office"):
		state.s.office.merge(values.office.duplicate(true),true)
		if values.office.has("upgrades"):
			var upgrades: Dictionary = Campaign.fresh_office().upgrades; upgrades.merge(values.office.upgrades,true); state.s.office.upgrades = upgrades
	if values.has("claims"): state.s.districtClaims = values.claims.duplicate(true)
	if values.has("kingdom"): state.s.kingdom.merge(values.kingdom.duplicate(true),true)
	if values.has("recognition"): state.s.recognition = values.recognition.duplicate(true)
	for id: String in values.get("quests",{}): state.s.quests[id].merge(values.quests[id],true)
	for id: String in values.get("actors",{}): _actor(state,id).merge(values.actors[id],true)
	if values.has("projectiles"): _set_projectiles(bundle,values.projectiles)
func _menu_projection(menu: Dictionary) -> Variant:
	if menu.is_empty(): return null
	var options: Array = []
	for option: Dictionary in menu.options: options.append({"label":option.label,"enabled":option.enabled})
	return {"title":menu.title,"text":menu.text,"options":options}
func _operation(bundle: Dictionary,step: Dictionary,label: String) -> bool:
	var state: RefCounted = bundle.state; var kingdom: RefCounted = bundle.kingdom; var op: Dictionary = step.operation
	match op.kind:
		"open_ledger":
			kingdom.close(); bundle.office.close(); _at(state,state.definition("src/systems/campaigns.js","OFFICE_DOOR",{}))
			var result: Dictionary = kingdom.open_ledger(); bundle.menu = result if result.ok else {}; return result.ok
		"select":
			if bundle.menu.is_empty(): _check(false,label+" live model menu absent"); return false
			var choice: Dictionary = {}; var selected_index: int = -1
			for index: int in range(bundle.menu.options.size()):
				if bundle.menu.options[index].id == op.action: choice = bundle.menu.options[index]; selected_index = index; break
			_check(selected_index == int(op.index),label+" source action/index mapping")
			if choice.is_empty() or not choice.enabled: return false
			var result: Dictionary = kingdom.select(bundle.menu.token,op.action)
			bundle.menu = result if result.get("ok",false) and result.has("options") else {}; return result.ok
		"door":
			kingdom.close(); bundle.office.close(); bundle.menu = {}; state.s.mode = "playing"; _at(state,_point(bundle,op.id),op.get("offset",0))
			return kingdom.use_door(op.id).ok
		"target":
			kingdom.close(); bundle.office.close(); bundle.menu = {}; state.s.mode = "playing"; _at(state,_point(bundle,op.id),op.offset)
			var previous: Dictionary = {"mode":state.s.mode,"stunT":state.p.stunT,"bossActive":state.s.bossActive,"brutusOlderActive":state.s.brutusOlderActive}
			if op.context.has("mode"): state.s.mode = op.context.mode
			if op.context.get("stun",false): state.p.stunT = 1
			if op.context.get("boss",false): state.s.bossActive = true
			if op.context.get("older",false): state.s.brutusOlderActive = true
			var result: Dictionary = kingdom.use_target(op.id,op.context)
			state.s.mode = previous.mode; state.p.stunT = previous.stunT
			if op.context.get("boss",false): state.s.bossActive = previous.bossActive
			if op.context.get("older",false): state.s.brutusOlderActive = previous.brutusOlderActive
			return result.ok
		"start": kingdom.close(); bundle.office.close(); bundle.menu = {}; return kingdom.start_boss(op.clan)
		"change": _mutate(bundle,op.values); return true
		"damage":
			var body: Dictionary = _actor(state,op.id)
			if body.is_empty(): _check(false,label+" actual actor missing"); return false
			body.hp = 0; return bundle.combat.kill_actor(op.id)
		"complete": return kingdom.finish_actor(op.id)
		"set_boss_health": state.s.bossNPC.hp = state.s.bossNPC.maxHp*op.ratio; return true
		"tick":
			var zone: Dictionary = {}
			for candidate: Dictionary in state.content.world.zones:
				if candidate.id == state.s.kingdomBattle.zoneId: zone = candidate; break
			var point := {"x":zone.x+zone.w*0.5,"y":zone.y+zone.h*0.5}
			if op.where == "outside": point.x = zone.x-1
			elif op.where == "edge": point.x = zone.x; point.y = zone.y+zone.h
			_at(state,point); var remaining: float = op.ms
			while remaining > 0:
				var dt: float = minf(50,remaining); kingdom.tick_active(dt); remaining -= dt
			return true
		"abort": return kingdom.abort(op.show,op.refresh)
		"refresh": return bundle.campaign.refresh_forces()
		"sync_recognition": bundle.memory.sync_visit(); return true
		"death": kingdom.abort(false,false); state.die(); return true
		"arrest": kingdom.abort(false,false); state.arrest(); return true
		"ending":
			bundle.ending_ms += float(op.elapsed_ms); kingdom.tick_wall(bundle.ending_ms)
			if not kingdom._ending_due: return false
			state.s.mode = "title" # Test-only Runtime lifecycle adapter accepts the queued request.
			var accepted: bool = kingdom.commit_ending()
			if accepted: bundle.endingPresentation = {"title":"ONE CRACKLORD","subtitle":"the kingdom is four curbs and a ditch · the throne is a folding chair","continueText":"[ SPACE / TAP ] return to the block"}
			return accepted
	return false
func _compare(bundle: Dictionary,step: Dictionary,event_start: int,label: String) -> void:
	var state: RefCounted = bundle.state; var expected: Dictionary = step.expected
	var adapted: bool = step.get("characterization") == "rejected_completion_normalizes"
	for key: String in expected.player: _check(_same(state.p[key],expected.player[key]),label+" player."+key+" got "+str(state.p[key])+" expected "+str(expected.player[key]))
	for key: String in expected.lifetime: _check(_same(state.p.lifetime.get(key,0),expected.lifetime[key]),label+" lifetime."+key)
	for pair: Array in [["office","office"],["claims","districtClaims"],["kingdom","kingdom"],["quests","quests"],["flags","flags"],["kingdomBattle","kingdomBattle"],["recognition","recognition"],["recognitionVisit","recognitionVisit"]]:
		if adapted and pair[0] == "kingdom": continue
		_check(_same(state.s[pair[1]],expected[pair[0]]),label+" "+str(pair[0])+" got "+str(state.s[pair[1]]).left(500)+" expected "+str(expected[pair[0]]).left(500))
	if adapted: _check(_same(state.s.kingdom,step.beforeKingdom),label+" approved pure rejection retains pre-callback Kingdom")
	var actors: Array = state.npcs.filter(_kingdom_actor)
	_check(actors.size() == expected.actors.size(),label+" exact actor count")
	for index: int in range(mini(actors.size(),expected.actors.size())): _check(_same(actors[index],expected.actors[index]),label+" complete actor payload "+str(expected.actors[index].id)+" got "+str(actors[index]).left(600))
	var projectiles: Array = []
	for shot: Dictionary in state.projectiles:
		var projected: Dictionary = shot.duplicate(true); projected.from = shot.from.get("id") if shot.get("from") is Dictionary else null; projectiles.append(projected)
	_check(_same(projectiles,expected.projectiles),label+" source projectile removal")
	var achievements: Array = state.s.achievements.duplicate(); achievements.sort()
	_check(_same(achievements,expected.achievements),label+" achievements")
	for key: String in ["day","mode","bossActive","bossKind","bossPhase","brutusOlderActive","endingContinue"]: _check(_same(state.s.get(key,false),expected[key]),label+" "+key)
	_check((str(state.s.bossNPC.get("id","")) if state.s.get("bossNPC") is Dictionary else "") == expected.bossNPC,label+" boss reference")
	_check(_same(_menu_projection(bundle.menu),expected.menu),label+" exact source menu")
	if not adapted:
		_check(_same(bundle.kingdom.objective(),expected.objective if expected.objective != null else {}),label+" objective")
		_check(bundle.kingdom.action_hint() == expected.hint,label+" action hint")
	_check(_same(bundle.endingPresentation,expected.endingPresentation),label+" source ending text")
	_check(state.draws == expected.draws,label+" source RNG count")
	var writes: int = 0; var toast: String = ""
	for index: int in range(state.events.size()):
		if state.events[index].kind == "save_requested": writes += 1
		if index >= event_start and state.events[index].kind == "toast": toast = state.events[index].payload.text
	_check(writes == expected.writes,label+" source saves got%d expected%d" % [writes,expected.writes])
	# Core die/arrest callbacks expose events; their presentation belongs to Combat/Runtime.
	if step.operation.kind not in ["death","arrest"]: _check(toast == expected.toast,label+" exact receipt got "+toast+" expected "+str(expected.toast))
	bundle.comms.flush_pending_events()
	var comms: Dictionary = bundle.comms.snapshot()
	if step.operation.kind not in ["death","arrest"]:
		for key: String in expected.communications: _check(_same(comms[key],expected.communications[key]),label+" communications."+key)
func _source_paths() -> void:
	_check(fixture.counts.cases == 159 and fixture.counts.steps == 369,"159 independent source paths/369 steps")
	var adaptations: int = 0
	for path: Dictionary in fixture.cases:
		var bundle: Dictionary = _bundle(); _setup(bundle,path.setup); bundle.state.roll = path.roll
		var number: int = 0
		for step: Dictionary in path.steps:
			number += 1; var label: String = path.id+" step%d %s" % [number,step.operation.kind]
			var start: int = bundle.state.events.size(); var before: Dictionary = bundle.state.snapshot()
			var actual: bool = _operation(bundle,step,label)
			_check(actual == step.result.ok,label+" source command outcome")
			if step.get("characterization") == "rejected_completion_normalizes":
				adaptations += 1; _check(_same(before,bundle.state.snapshot()),label+" failed completion makes no partial repair/reward")
			_compare(bundle,step,start,label)
	_check(adaptations == 4,"all four deliberate corrupt-stage refusal adaptations remain visible")

func _property_bundle() -> Dictionary:
	var bundle: Dictionary = _bundle(); var state: RefCounted = bundle.state
	state.s.mode = "playing"; state.s.day = 6; state.s.office.owned = true; state.s.office.upgrades.radio = true
	state.s.kingdom = Campaign.normalize_kingdom({"stage":"tarp_marks","marks":7})
	bundle.campaign.refresh_forces(); state.events.clear(); return bundle
func _physical_transactions() -> void:
	for id: String in ["darryl_under_blue","kingdom_add_darryl_under_blue_0","kingdom_add_darryl_under_blue_1"]:
		var b: Dictionary = _property_bundle(); b.spatial.refused_id = id
		var before: Dictionary = b.state.snapshot(); var actors: Array = b.state.npcs.duplicate(true); var events: Array = b.state.events.duplicate(true); var draws: int = b.state.draws
		_check(not b.kingdom.start_boss("blue_tarp"),"one refused staged body blocks all-three encounter "+id)
		_check(_same(before,b.state.snapshot()) and _same(actors,b.state.npcs) and _same(events,b.state.events) and b.state.draws == draws,"staging refusal pure across model/actors/RNG/events "+id)
	for displacement: Vector2 in [Vector2(101,0),Vector2(NAN,0),Vector2(INF,0)]:
		var b: Dictionary = _property_bundle(); b.spatial.displaced = displacement; var before: Dictionary = b.state.snapshot()
		_check(not b.kingdom.start_boss("blue_tarp") and _same(before,b.state.snapshot()),"invalid/unbounded staged position rejects whole battle")
	var b: Dictionary = _property_bundle(); var state: RefCounted = b.state
	b.spatial.blocked = true; b.campaign.refresh_forces()
	_check(state.s.dayPendingPlacements.size() == 15,"all source guards deferred by real shared Day owner")
	b.spatial.blocked = false
	_check(b.kingdom.start_boss("blue_tarp"),"exact three staged bodies commit source fight")
	_check(state.s.dayPendingPlacements.size() == 11,"start cancels only challenged clan's four pending guards")
	_check(state.s.dayPendingPlacements.filter(func(row: Dictionary) -> bool: return row.payload.get("kingdomClan") == "blue_tarp").is_empty(),"pending challenged guards cannot appear during battle")
	var next: Dictionary = b.kingdom._victory_state(_actor(state,"darryl_under_blue")); var before: Dictionary = state.snapshot(); var actors: Array = state.npcs.duplicate(true); var events: Array = state.events.duplicate(true); var draws: int = state.draws
	_check(b.days.can_replace_campaign_forces(next,next.pretendersDefeated),"canonical prospective victory passes capacity")
	_check(_same(before,state.snapshot()) and _same(actors,state.npcs) and _same(events,state.events) and state.draws == draws,"prospective Day validation is pure")
	var invalid: Dictionary = next.duplicate(true); invalid.marks = 9
	_check(not b.days.can_replace_campaign_forces(invalid,0) and not b.days.can_replace_campaign_forces(next,NAN),"noncanonical prospective state/counter rejected")
	var saved_pending: Array = state.s.dayPendingPlacements.duplicate(true)
	state.s.dayPendingPlacements.clear()
	for index: int in range(64): state.s.dayPendingPlacements.append(b.days._pending("inheritance",{"id":"cp_inheritance_%d" % index,"x":500.0,"y":500.0,"amt":500,"isInheritance":true,"collected":false},6))
	before = state.snapshot(); var hp: float = _actor(state,"darryl_under_blue").hp
	_check(not b.combat.damage_actor("darryl_under_blue",hp),"real Combat refuses fatal damage before saturated reward/refresh")
	_check(_actor(state,"darryl_under_blue").hp == hp and _same(before,state.snapshot()),"refused fatal damage leaves HP/resources/defeats unchanged")
	state.s.dayPendingPlacements.assign(saved_pending); b.spatial.blocked = true
	var cash: int = state.p.cash; var cred: int = state.p.cred
	_check(b.combat.damage_actor("darryl_under_blue",hp),"real Combat/Boss delegates accepted source victory")
	_check(state.p.cash == cash+24 and state.p.cred == cred+18 and state.s.kingdom.stage == "cart_marks","source reward and next stage commit once")
	_check(state.s.dayPendingPlacements.size() == 13 and state.npcs.filter(_kingdom_actor).is_empty(),"post-victory physical refusal retains13 canonical guards without invisible actors")
	before = state.snapshot()
	_check(not b.kingdom.finish_actor("darryl_under_blue") and _same(before,state.snapshot()),"replayed removed boss cannot pay again")
	b.spatial.blocked = false
	for index: int in range(35): b.days.tick_active(50)
	_check(state.s.dayPendingPlacements.is_empty() and state.npcs.filter(_kingdom_actor).size() == 13,"bounded Day retry physically restores exact victory guards")
func _lifecycle_and_capabilities() -> void:
	var b: Dictionary = _property_bundle(); var state: RefCounted = b.state
	state.s.kingdom = Campaign.normalize_kingdom({"stage":"summons"}); _at(state,state.definition("src/systems/campaigns.js","OFFICE_DOOR",{}))
	var menu: Dictionary = b.kingdom.open_ledger(); var before: Dictionary = state.snapshot()
	b.spatial.visible = false
	_check(not b.kingdom.select(menu.token,"accept").ok and _same(before,state.snapshot()),"summons selection requires fresh LOS")
	_check(state.s.mode == "playing" and not b.kingdom._ledger_open,"consumed geometry refusal closes only owned dialogue")
	b.spatial.visible = true; menu = b.kingdom.open_ledger(); var stale: String = menu.token; menu = b.kingdom.open_ledger()
	_check(not b.kingdom.select(stale,"accept").ok and state.s.mode == "dialogue" and b.kingdom._ledger_open,"stale token preserves current Kingdom dialogue")
	_check(not b.kingdom.select(menu.token,"invented_action").ok and state.s.mode == "playing" and not b.kingdom._ledger_open,"consumed unknown action closes owned dialogue")
	menu = b.kingdom.open_ledger(); state.s.mode = "paused"
	_check(not b.kingdom.select(menu.token,"invented_action").ok and state.s.mode == "paused","consumed rejection preserves an external lifecycle mode")
	state.s.mode = "playing"
	b.spatial.visible = true; menu = b.kingdom.open_ledger(); state.s.office.upgrades.radio = false; before = state.snapshot()
	_check(not b.kingdom.select(menu.token,"accept").ok and _same(before,state.snapshot()) and state.s.mode == "playing","removed radio rejects consumed menu and closes owned dialogue")
	state.s.office.upgrades.radio = true; menu = b.kingdom.open_ledger()
	_check(b.kingdom.select(menu.token,"accept").ok,"valid summons consumes one capability")
	before = state.snapshot(); _check(not b.kingdom.select(menu.token,"accept").ok and _same(before,state.snapshot()),"summons cannot replay")
	state.s.kingdom = Campaign.normalize_kingdom({"stage":"emperor_gate"}); b.campaign.refresh_forces(); state.s.mode = "playing"
	b.kingdom.tick_wall(1000)
	_check(b.kingdom.start_boss("emperor"),"actual emperor encounter staged")
	_check(b.combat.damage_actor("curb_emperor",280),"actual emperor completion uses Combat domain")
	b.kingdom.tick_wall(3599); _check(not b.kingdom._ending_due,"ending not before source2600ms")
	state.s.mode = "cookmini"; b.kingdom.tick_wall(3600)
	_check(b.kingdom._ending_due and state.s.mode == "cookmini" and not b.kingdom.commit_ending(),"wall request cannot bypass accepted external lifecycle")
	state.s.mode = "title"; _check(b.kingdom.commit_ending() and state.s.endingContinue,"accepted Runtime mode commits source ending once")
	before = state.snapshot(); _check(not b.kingdom.commit_ending() and _same(before,state.snapshot()),"ending receipt cannot replay")
	state.s.mode = "playing"; state.s.kingdom = Campaign.normalize_kingdom({"stage":"emperor_gate"}); b.campaign.refresh_forces()
	_check(b.kingdom.start_boss("emperor") and b.combat.damage_actor("curb_emperor",280),"second test epoch has a pending ending")
	state.fresh(); b.kingdom.tick_wall(10000)
	_check(not b.kingdom._ending_due and not state.s.get("endingContinue",false),"fresh state drops previous epoch ending")
	_check(not b.kingdom.tick_wall(9999) and not b.kingdom.tick_active(51) and not b.kingdom.tick_active(NAN),"clock inputs remain bounded monotonic")
	var replaced: Dictionary = _property_bundle(); replaced.state.s.kingdom = Campaign.normalize_kingdom({"stage":"summons"})
	_at(replaced.state,replaced.state.definition("src/systems/campaigns.js","OFFICE_DOOR",{})); menu = replaced.kingdom.open_ledger()
	replaced.state.fresh(); replaced.state.s.mode = "paused"
	_check(not replaced.kingdom.select(menu.token,"accept").ok and replaced.state.s.mode == "paused","replaced-state token cannot overwrite the new lifecycle")
func _royal_static_loop() -> void:
	var b: Dictionary = _property_bundle(); var state: RefCounted = b.state
	state.s.kingdom = Campaign.normalize_kingdom({"stage":"anoint"}); state.p.x = 1050; state.p.y = 840
	state.p.rocks = 1; state.p.soapRocks = 1
	_check(b.memory.smoke("block").ok and state.s.kingdom.stage == "anoint" and state.p.rocks == 1,"soap cannot anoint the crown or spend the real rock")
	state.p.hitters = 1
	_check(b.memory.use_hitter().ok and state.s.kingdom.stage == "anoint","hitter cannot replace the royal Block rock")
	state.p.rockedT = 0; state.p.crashT = 0; state.p.hitterHigh = false
	state.p.x = 2500; state.p.y = 1000; state.s.recognition.park.buy = 15; state.s.dayTime = 0.10
	_check(b.memory.smoke("park").ok and state.s.kingdom.stage == "anoint","real remote venue smoke cannot anoint the crown")
	state.p.rockedT = 0; state.p.crashT = 0; state.p.rocks = 1; state.p.x = 1050; state.p.y = 840
	_check(b.memory.smoke("block").ok and state.s.kingdom.stage == "emperor_gate" and state.p.rocks == 0,"sole Memory authority consumes the real Block rock and opens emperor gate")
	b.campaign.sync_quests()
	_check(b.kingdom.active_targets().size() == 1 and b.kingdom.active_targets()[0].id == "kingdom_banner:throne","royal static exposes only the throne challenge")
	_check(state.tick(17.99,{"at_block":true}) and absf(state.p.rockedT-10) < 0.001 and state.p.crashT == 0,"royal high retains complete18s duration")
	_check(state.tick(0.02,{"at_block":true}) and state.p.rockedT == 0 and absf(state.p.crashT-7990) < 0.001,"royal high crosses into the same8s crash")
	_check(state.tick(7.99,{"at_block":true}) and state.p.crashT == 0 and state.s.kingdom.stage == "emperor_gate","royal26s loop ends without repeating crown state")
func _run() -> void:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/kingdom_reference.json"))
	_check(decoded is Dictionary,"Kingdom oracle parses")
	if decoded is Dictionary: fixture = decoded; _source_paths(); _physical_transactions(); _lifecycle_and_capabilities(); _royal_static_loop()
	if failures.is_empty(): print("3D KINGDOM CAMPAIGN GATE: PASS (%d checks;159 source paths/369 steps; physical/native fight budgets remain root evidence)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D KINGDOM CAMPAIGN GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)
