extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const Progression = preload("res://scripts/progression_routes.gd")
const Days = preload("res://scripts/day_system.gd")
const Travel = preload("res://scripts/travel_system.gd")
var checks: int = 0
var failures: Array[String] = []
var fixture: Dictionary = {}

class Spatial:
	extends RefCounted
	var blocked: bool = false
	func can_reach_target(_id: String) -> bool: return true
	func can_use_zone(_id: String) -> bool: return true
	func clear_placement(body: Dictionary) -> Variant: return null if blocked else Vector2(body.x,body.y)
	func stage_cash_pickup(at: Vector2,_maximum: float) -> Variant: return null if blocked else at
class Communications:
	extends RefCounted
	func unix_ms() -> float: return 1763424000000.0
	func day_capabilities_ready() -> bool: return true
	func post(_text: String,_author: String = "") -> bool: return true
	func broadcast(_text: String) -> bool: return true
	func dispatch_day_callback(_kind: String) -> bool: return true
	func flush_pending_events() -> bool: return true

func _initialize() -> void: call_deferred("_run")
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
func _save_count(state: RefCounted) -> int:
	var count: int = 0
	for event: Dictionary in state.events:
		if event.kind == "save_requested": count += 1
	return count
func _projection(state: RefCounted) -> Dictionary:
	var quests: Dictionary = {}
	for id: String in ["office_space","paper_empire","regional_office","all_business","hostile_correspondence","blue_weather","cart_appeal","copper_mass","royal_static","one_cracklord"]:
		quests[id] = {"done":state.s.quests[id].get("done",false),"available":state.s.quests[id].get("available")}
	var lifetime: Dictionary = {}
	for key: String in ["officeJobs","territoriesClaimed","pretendersDefeated","routesCompleted"]: lifetime[key] = state.p.lifetime.get(key,0)
	var flags: Dictionary = {}
	for key: String in Campaign.CLEAR_FLAGS: flags[key] = state.s.flags.get(key,false)
	var achievements: Array = state.s.achievements.duplicate(); achievements.sort()
	return {"office":state.s.office,"claims":state.s.districtClaims,"kingdom":state.s.kingdom,"quests":quests,"lifetime":lifetime,"flags":flags,"achievements":achievements,"cash":state.p.cash,"copper":state.p.copper,"cred":state.p.cred,"day":state.s.day,"bossActive":state.s.bossActive,"bossKind":state.s.bossKind}
func _apply_projection(state: RefCounted,data: Dictionary) -> void:
	state.s.office = data.office.duplicate(true); state.s.districtClaims = data.claims.duplicate(true); state.s.kingdom = data.kingdom.duplicate(true)
	for key: String in data.lifetime: state.p.lifetime[key] = data.lifetime[key]
	for id: String in data.quests:
		state.s.quests[id].done = data.quests[id].done; state.s.quests[id].available = data.quests[id].available
	for key: String in data.flags: state.s.flags[key] = data.flags[key]
	state.s.achievements = data.achievements.duplicate()
	for key: String in ["cash","copper","cred"]: state.p[key] = data[key]
	state.s.day = int(data.day)
func _compare_projection(state: RefCounted,expected: Dictionary,label: String) -> void:
	var actual: Dictionary = _projection(state)
	for key: String in actual: _check(_same(actual[key],expected[key]),label+" "+key+" got "+str(actual[key])+" expected "+str(expected[key]))

func _pure_source() -> void:
	_check(fixture.counts.nat+fixture.counts.offices+fixture.counts.kingdoms+fixture.counts.forces+fixture.counts.milestones+fixture.counts.restores == 215,"215 independent P13a source cases")
	for row: Dictionary in fixture.nat:
		_check(Campaign.office_nat(row.value) == row.expected,"source Number/floor/clamp "+str(row.value))
		_check(Campaign.office_nat(row.value,7) == row.bounded,"source bounded Number coercion "+str(row.value))
	for row: Dictionary in fixture.offices:
		var claims: Dictionary = Campaign.normalize_claims(row.claims)
		_check(_same(claims,row.normalizedClaims),"source strict true known district claims")
		_check(_same(Campaign.normalize_office(row.raw,claims),row.expected),"source office normalization "+JSON.stringify(row.raw))
	for row: Dictionary in fixture.kingdoms:
		_check(_same(Campaign.normalize_kingdom(row.raw,row.demote),row.expected),"source Kingdom normalize "+str(row.raw.get("stage"))+" demote "+str(row.demote)+" marks "+str(row.raw.get("marks")))
	_check(Campaign.office_nat(NAN) == 0 and Campaign.office_nat(INF) == 0,"nonfinite natural counters rejected")
	for row: Dictionary in fixture.forces:
		var state := State.new(); var campaign := Campaign.new(state)
		state.s.day = int(row.before.day); state.s.kingdom = row.before.kingdom.duplicate(true); state.p.lifetime.pretendersDefeated = row.before.pretenders
		var before: Dictionary = state.snapshot(); var npcs: Array = state.npcs.duplicate(true); var rng: int = state.rng_seed
		var plan: Dictionary = campaign.prepare_day(int(row.before.day))
		_check(plan.ok,"source force plan accepts known stage")
		_check(_same(state.snapshot(),before) and _same(state.npcs,npcs) and state.rng_seed == rng,"force preparation is pure no model/actor/RNG mutation")
		_check(row.randomCalls == 0,"source explicit force IDs require zero random calls")
		_check(_same(plan.kingdom,row.kingdom) and plan.pretenders_defeated == row.pretenders,"exact Kingdom/lifetime force reconciliation")
		_check(plan.actors.size() == row.actors.size(),"source exact guard/pretender count")
		for index: int in range(mini(plan.actors.size(),row.actors.size())):
			_check(_same(plan.actors[index],row.actors[index]),"source complete actor payload "+str(row.actors[index].id))
		_check(_same(campaign.prepare_day(int(row.before.day)),plan),"plan is deterministic and repeatable")
	var state := State.new(); var campaign := Campaign.new(state)
	_check(not campaign.prepare_day(0).ok and not campaign.prepare_day(1000000001).ok,"bounded day plan input")
	_check(not campaign.refresh_forces(),"unbound physical day owner cannot fake force refresh")

func _milestones_and_restore() -> void:
	for row: Dictionary in fixture.milestones:
		var state := State.new(); var campaign := Campaign.new(state)
		_apply_projection(state,row.before); state.events.clear()
		_check(campaign.update_office_milestones() == row.changed,"source office milestone changed result")
		_compare_projection(state,row.after,"milestone "+str(row.count))
		_check(_save_count(state) == row.firstWrites,"milestone commits one complete optional save")
		_check(campaign.update_office_milestones() == row.repeated and _save_count(state) == row.totalWrites,"repeated milestone repair cannot save/reward twice")
	for row: Dictionary in fixture.restores:
		var state := State.new(); var progression := Progression.new(state)
		var spatial := Spatial.new(); var travel := Travel.new(state,spatial); var comms := Communications.new()
		var campaign := Campaign.new(state,spatial,progression,travel,comms)
		var days := Days.new(state,spatial,progression,travel,campaign,comms,comms.unix_ms)
		campaign.bind_day_owner(days); travel._day_ref = weakref(days)
		var saved: Dictionary = state.snapshot(); saved.player = row.save.player.duplicate(true)
		for key: String in State.STATE_SAVE_KEYS:
			if row.save.has(key): saved.state[key] = row.save[key].duplicate(true) if row.save[key] is Array or row.save[key] is Dictionary else row.save[key]
		_check(state.restore(saved).ok,"core campaign fixture restores "+row.spec.id)
		var result: Dictionary = campaign.reconcile_loaded_state()
		_check(result.ok,"real campaign reconcile succeeds "+row.spec.id)
		_check(campaign.refresh_forces(),"source startGame force refresh commits staged pretender stamp "+row.spec.id)
		_compare_projection(state,row.expected,"restore "+row.spec.id)
		_check(_same(result.forces_plan.actors,row.expected.actors),"restore source force composition "+row.spec.id)
		var first: Dictionary = _projection(state).duplicate(true)
		var repeated: Dictionary = campaign.reconcile_loaded_state()
		_check(repeated.ok and _same(_projection(state),first),"repeat reconcile changes no durable progress "+row.spec.id)

func _real_day_seam() -> void:
	var state := State.new(); var spatial := Spatial.new(); var progression := Progression.new(state)
	var travel := Travel.new(state,spatial); var comms := Communications.new()
	var campaign := Campaign.new(state,spatial,progression,travel,comms)
	var days := Days.new(state,spatial,progression,travel,campaign,comms,comms.unix_ms)
	campaign.bind_day_owner(days); travel._day_ref = weakref(days)
	_check(days.install(),"Day installs real Campaign with contract spatial/comms owners")
	_check(days.has_method(&"replace_campaign_forces"),"approved single force replacement seam exists")
	if not days.has_method(&"replace_campaign_forces"): return
	state.s.mode = "playing"; state.s.day = 8; state.s.kingdom.stage = "complete"; state.s.kingdom.pretendersDefeated = 5; state.p.lifetime.pretendersDefeated = 2
	spatial.blocked = true
	var rng: int = state.rng_seed
	_check(campaign.refresh_forces(),"physical refusal commits source force generation to shared pending queue")
	_check(state.s.kingdom.pretendersDefeated == 5 and state.p.lifetime.pretendersDefeated == 5,"shared force commit reconciles lifetime max")
	_check(state.npcs.filter(func(actor: Dictionary) -> bool: return actor.get("kingdomGuard",false) or actor.get("kingdomPretender",false)).is_empty(),"deferred campaign creates no invisible live actors")
	_check(state.s.dayPendingPlacements.size() == 9 and state.rng_seed == rng,"nine exact complete-stage source records persisted without RNG")
	var plan: Dictionary = campaign.prepare_day(8)
	_check(campaign.refresh_forces() and state.s.dayPendingPlacements.size() == 9,"same source force refresh replaces rather than duplicates pending IDs")
	var saved: Dictionary = state.snapshot()
	_check(state.restore(saved).ok,"campaign deferred payloads survive schema2 restore")
	state.s.mode = "playing"; days.rehydrate()
	_check(campaign.reconcile_loaded_state().ok and campaign.refresh_forces(),"restore refresh replaces stale day1 generation before any active retry")
	spatial.blocked = false
	for index: int in range(30): days.tick_active(50)
	_check(state.s.dayPendingPlacements.is_empty(),"bounded retry finishes restored real force records")
	var current: Array = state.npcs.filter(func(actor: Dictionary) -> bool: return actor.get("kingdomGuard",false) or actor.get("kingdomPretender",false))
	_check(current.size() == plan.actors.size(),"restored source force count matches current day")
	var json_plan: Variant = JSON.parse_string(JSON.stringify(campaign.prepare_day(8)))
	_check(json_plan is Dictionary and days.replace_campaign_forces(json_plan),"canonical JSON float/integer representation preserves complete force plan")
	var before: Dictionary = state.snapshot(); var invalid: Dictionary = plan.duplicate(true); invalid.day = 9
	_check(not days.replace_campaign_forces(invalid) and _same(state.snapshot(),before),"force plan from different day rejected atomically")
	var before_npcs: Array = state.npcs.duplicate(true)
	for variant: String in ["duplicate","unknown","wrong_known_sprite","wrong_known_clan","wrong_stats","wrong_post","missing_actor","empty_actors","extra_field","stale_stage","missing_position","fractional_count","negative_count","nonfinite_count","noncanonical_kingdom"]:
		invalid = plan.duplicate(true)
		match variant:
			"duplicate": invalid.actors.append(invalid.actors[0].duplicate(true))
			"unknown": invalid.actors[0].name = "invented"
			"wrong_known_sprite": invalid.actors[0].sprite = "wire_guard"
			"wrong_known_clan": invalid.actors[0].kingdomClan = "copper_choir"
			"wrong_stats": invalid.actors[0].hp = 999; invalid.actors[0].maxHp = 999
			"wrong_post": invalid.actors[0].x += 1
			"missing_actor": invalid.actors.pop_back()
			"empty_actors": invalid.actors.clear()
			"extra_field": invalid.actors[0].invented = true
			"stale_stage": invalid = Campaign.plan_for_state(8,Campaign.fresh_kingdom(),5)
			"missing_position": invalid.actors[0].erase("x")
			"fractional_count": invalid.pretenders_defeated = 1.5
			"negative_count": invalid.pretenders_defeated = -1
			"nonfinite_count": invalid.pretenders_defeated = NAN
			"noncanonical_kingdom": invalid.kingdom.stage = "invented"
		_check(not days.replace_campaign_forces(invalid) and _same(state.snapshot(),before) and _same(state.npcs,before_npcs),"invalid force replacement refuses before removal: "+variant)
	state.s.dayTime = 0.9; state.s.day = 8; spatial.blocked = true
	_check(state._advance_day("hideout_sleep") and state.s.day == 9,"real Campaign completes Day source sleep rollover")
	_check(state.p.lifetime.pretendersDefeated == 5 and state.s.kingdom.pretenderDay == 9,"day commit applies source max/pretender stamps")
	_check(state.s.dayPendingPlacements.size() == 9,"next day defers new canonical generation once")

func _run() -> void:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/campaign_reference.json"))
	_check(decoded is Dictionary,"campaign source fixture parses")
	if decoded is Dictionary:
		fixture = decoded; _pure_source(); _milestones_and_restore(); _real_day_seam()
	if failures.is_empty():
		print("3D CAMPAIGN FOUNDATION GATE: PASS (%d checks;215 source cases; P13b/c menus/battles remain pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D CAMPAIGN FOUNDATION GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)
