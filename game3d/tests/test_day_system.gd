extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Days = preload("res://scripts/day_system.gd")
const Travel = preload("res://scripts/travel_system.gd")
const Progression = preload("res://scripts/progression_routes.gd")
var checks: int = 0
var failures: Array[String] = []
var fixture: Dictionary = {}

class FixedState:
	extends "res://scripts/game_state.gd"
	var roll: float = 0.5
	var rolls: int = 0
	func random_float() -> float: rolls += 1; return roll
	func random_index(size: int) -> int: return mini(size-1,int(floor(random_float()*size))) if size > 0 else 0

# These are contract test doubles, never installed into the production scene.
class Spatial:
	extends RefCounted
	var visible: bool = true
	var placement: String = "clear"
	var calls: int = 0
	func can_reach_target(_id: String) -> bool: return visible
	func can_use_zone(_id: String) -> bool: return visible
	func clear_placement(body: Dictionary) -> Variant: return _point(Vector2(body.x,body.y))
	func stage_cash_pickup(point: Vector2,_maximum: float) -> Variant: return _point(point)
	func _point(point: Vector2) -> Variant:
		calls += 1
		match placement:
			"blocked": return null
			"far": return point+Vector2(101,0)
			"nan": return Vector2(NAN,0)
			"outside": return Vector2(-1,0)
			"near": return point+Vector2(10,0)
			_: return point
class Campaign:
	extends RefCounted
	var owner: WeakRef
	var accepts: bool = true
	var actors: Array = []
	var calls: int = 0
	func _init(host: RefCounted) -> void: owner = weakref(host)
	func prepare_day(_day: int) -> Dictionary:
		calls += 1
		return {"ok":accepts,"kingdom":owner.get_ref().s.kingdom.duplicate(true),"actors":actors.duplicate(true)}
class Communications:
	extends RefCounted
	var owner: WeakRef
	var accepts: bool = true
	var now_ms: float = 1763424000000.0
	var calls: Array[String] = []
	var deliveries: Array[Dictionary] = []
	var flushes: int = 0
	func _init(host: RefCounted) -> void: owner = weakref(host)
	func unix_ms() -> float: return now_ms
	func day_capabilities_ready() -> bool: return accepts
	func dispatch_day_callback(kind: String) -> bool: calls.append(kind); return accepts
	func post(text: String,author: String = "") -> bool:
		if float(owner.get_ref().s.flags.get("silenceUntilT",0)) <= now_ms: deliveries.append({"kind":"feed","text":text,"author":author})
		return accepts
	func broadcast(text: String) -> bool:
		if float(owner.get_ref().s.flags.get("silenceUntilT",0)) <= now_ms: deliveries.append({"kind":"news","text":text})
		return accepts
	func flush_pending_events() -> void:
		flushes += 1
		var kept: Array[Dictionary] = []
		for event: Dictionary in owner.get_ref().events:
			if event.kind == "feed": post(event.payload.get("text",""),event.payload.get("author",""))
			elif event.kind == "news": broadcast(event.payload.get("text",""))
			else: kept.append(event)
		owner.get_ref().events = kept

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
func _copy(value: Variant) -> Variant: return value.duplicate(true) if value is Array or value is Dictionary else value
func _bundle() -> Dictionary:
	var state := FixedState.new()
	var spatial := Spatial.new()
	var progression := Progression.new(state)
	var travel := Travel.new(state,spatial)
	var campaign := Campaign.new(state)
	var comms := Communications.new(state)
	var days := Days.new(state,spatial,progression,travel,campaign,comms,comms.unix_ms)
	travel._day_ref = weakref(days)
	_check(days.install(),"test contract owners install complete day callback pair")
	state.s.mode = "playing"
	return {"state":state,"spatial":spatial,"progression":progression,"travel":travel,"campaign":campaign,"comms":comms,"days":days}
func _setup(bundle: Dictionary,entry: Dictionary) -> void:
	var state: RefCounted = bundle.state
	var data: Dictionary = entry.before
	for key: String in data.player: state.p[key] = _copy(data.player[key])
	for key: String in data.flags: state.s.flags[key] = _copy(data.flags[key])
	for key: String in data.counters: state.s.counters[key] = _copy(data.counters[key])
	state.s.office = data.office.duplicate(true); state.s.kingdom = data.kingdom.duplicate(true)
	state.s.flags.peteToolLocker = data.locker
	state.s.day = int(data.day); state.s.dayTime = data.time; state.s.weather = data.weather
	state.p.lifetime.dayCount = int(data.lifetimeDay); state.s.achievements = data.achievements.duplicate()
	state.p.inventory = data.inventory.duplicate(true); state.s.territoryCashMult = data.territoryCashMult
	state.npcs.clear(); state.cash_piles.clear(); state.roll = float(entry.spec.get("roll",0.5)); state.rolls = 0
	state.s.mode = "playing"; state.events.clear(); bundle.comms.deliveries.clear()
func _at_actor(state: RefCounted,actor: Dictionary) -> void:
	state.p.x = actor.x+actor.w*0.5-state.p.w*0.5; state.p.y = actor.y+actor.h*0.5-state.p.h*0.5
func _source_compare(bundle: Dictionary,entry: Dictionary) -> void:
	var state: RefCounted = bundle.state
	var expected: Dictionary = entry.after
	var label: String = entry.spec.id
	for key: String in expected.player: _check(_same(state.p[key],expected.player[key]),"%s player.%s got %s expected %s" % [label,key,state.p[key],expected.player[key]])
	for key: String in expected.flags: _check(_same(state.s.flags.get(key),expected.flags[key]),label+" flags."+key)
	for key: String in expected.counters: _check(_same(state.s.counters.get(key),expected.counters[key]),label+" counters."+key)
	_check(_same(state.s.day,expected.day) and _same(state.s.dayTime,expected.time),label+" day/time")
	_check(_same(state.p.lifetime.dayCount,expected.lifetimeDay),label+" lifetime day")
	_check(_same(state.s.office,expected.office),label+" office")
	_check(_same(state.s.flags.get("peteToolLocker"),expected.locker),label+" tool locker")
	var achievements: Array = state.s.achievements.duplicate(); achievements.sort()
	_check(_same(achievements,expected.achievements),label+" achievements")
	_check(_same(state.p.inventory,expected.inventory),label+" inventory")
	_check(state.s.mode == ("ending" if expected.mode == "title" else expected.mode),label+" mode/ending presentation adaptation")
	_check(state.s.get("endingContinue",false) == expected.endingContinue,label+" source ending continuation")
	var actors: Array = []
	for actor: Dictionary in state.npcs:
		if actor.get("isDay3Visitor",false) or actor.get("isPriceGuy",false) or actor.get("isBusDriver",false): actors.append(actor)
	_check(actors.size() == expected.actors.size(),label+" actual conditional actor count")
	for wanted: Dictionary in expected.actors:
		var actual: Dictionary = bundle.days._actor(wanted.id)
		for key: String in wanted: _check(_same(actual.get(key),wanted[key]),"%s actor %s.%s" % [label,wanted.id,key])
	_check(_same(state.cash_piles,expected.cash),label+" actual cash records")
	if entry.spec.kind in ["event","event_repeat","interaction","rehydrate","price","price_poll"]:
		_check(state.rolls == expected.randomCalls,label+" exact source random draw count")
		var saves: int = 0
		for event: Dictionary in state.events:
			if event.kind == "save_requested": saves += 1
		# Achievements add their own source save; its implementation is separately gated.
		_check(saves == expected.saves,label+" exact save requests")
func _source_cases() -> void:
	_check(fixture.cases.size() == 68 and fixture.counts.cases == 68,"68 independent source cases")
	for entry: Dictionary in fixture.cases:
		var bundle: Dictionary = _bundle()
		_setup(bundle,entry)
		var state: RefCounted = bundle.state
		var days: RefCounted = bundle.days
		var kind: String = entry.spec.kind
		match kind:
			"weather":
				_check(state._advance_day("hideout_sleep") and state.s.weather == entry.after.weather,entry.spec.id+" source weather threshold")
				continue
			"reset":
				state.s.day -= 1
				_check(state._advance_day("hideout_sleep"),entry.spec.id+" reset invocation")
				for key: String in entry.after.counters: _check(_same(state.s.counters.get(key),entry.after.counters[key]),entry.spec.id+" retained/reset counter "+key)
				_check(_same(state.s.office,entry.after.office),entry.spec.id+" same-day office stamp")
				continue
			"night":
				_check(days.is_night() == entry.expectedNight,entry.spec.id+" strict night boundary")
				for id: String in ["mom","pete","cubscout","train_hopper"]:
					_check(days.actor_visible({"id":id,"daytimeOnly":id in ["cubscout","train_hopper"]}) != entry.expectedNight,entry.spec.id+" visibility "+id)
				_check(days.actor_visible({"id":"tony"}),"ordinary actor stays visible")
				continue
			"event","event_repeat":
				days._fire_day_events()
				if kind == "event_repeat": days._fire_day_events()
			"rehydrate": days.rehydrate(); days.rehydrate()
			"interaction":
				days._fire_day_events()
				var actor: Dictionary = state.npcs[0]
				_at_actor(state,actor)
				var menu: Dictionary = days.open(actor.id)
				_check(menu.ok and days.select(menu.token,entry.spec.action).ok,entry.spec.id+" source dialogue action")
			"price","price_poll":
				days.tick_active(1.0)
				if kind == "price_poll": days.tick_active(1.0)
				else:
					_at_actor(state,days._actor("price_guy"))
					var menu: Dictionary = days.open("price_guy")
					var result: Dictionary = days.select(menu.token,"pay")
					_check(result.ok == (entry.before.player.cash > 0),entry.spec.id+" current cash gate")
					if not result.ok: days.close()
			"park":
				# Territory is a separate owner; consume its source-calculated multiplier.
				state.s.territoryCashMult = entry.after.territoryCashMult
				days.tick_active(1.0)
			"cause":
				var cause: String = entry.spec.cause
				if cause == "natural":
					state.s.dayTime = 0.0; _check(state._advance_day(cause),"source natural cause")
					days.tick_active(1.0)
				elif cause == "block_sleep": _check(days.sleep_at_block().ok,"source Block sleep")
				else:
					var service: String = "office:cot" if cause == "office_sleep" else "hideout:scrap"
					var door: Dictionary = state.definition("src/systems/campaigns.js","OFFICE_DOOR",{}) if cause == "office_sleep" else state.definition("src/systems/daily_hideouts.js","HIDEOUT_DOORS",{}).scrap
					_at_actor(state,door)
					var menu: Dictionary = bundle.travel.open(service)
					_check(menu.ok and bundle.travel.select(menu.token,"sleep").ok,"source Travel -> Day sleep "+cause)
		_source_compare(bundle,entry)

func _pending_and_restore() -> void:
	for mode: String in ["blocked","far","nan","outside"]:
		var bundle: Dictionary = _bundle(); var state: RefCounted = bundle.state
		state.s.day = 14; state.cash_piles.clear(); bundle.spatial.placement = mode
		var rolls: int = state.rolls
		bundle.days._fire_day_events()
		_check(state.s.flags.day14Fired and state.cash_piles.is_empty() and state.s.dayPendingPlacements.size() == 1,"physical refusal retains inheritance without phantom pickup "+mode)
		_check(state.rolls == rolls+2,"deferred source event rolls exactly twice "+mode)
		var saved: Dictionary = state.snapshot()
		_check(state.restore(saved).ok,"pending save restores "+mode)
		bundle.days.rehydrate(); state.s.mode = "playing"
		_check(state.s.dayPendingPlacements.size() == 1,"pending queue survives normalized restore "+mode)
		rolls = state.rolls; bundle.spatial.placement = "near"
		bundle.days.tick_active(1.0)
		_check(state.s.dayPendingPlacements.is_empty(),"successful bounded recovery retires pending "+mode)
		var inherited: Array = state.cash_piles.filter(func(pile: Dictionary) -> bool: return pile.get("isInheritance",false))
		_check(inherited.size() == 1 and state.rolls == rolls,"recovery creates one source pickup without reroll "+mode)
		bundle.days.tick_active(50.0)
		_check(state.cash_piles.filter(func(pile: Dictionary) -> bool: return pile.get("isInheritance",false)).size() == 1,"recovery cannot duplicate pickup "+mode)
	var b: Dictionary = _bundle(); var g: RefCounted = b.state
	g.s.day = 2; g.s.dayTime = 0.3; b.spatial.placement = "blocked"
	_check(g._advance_day("natural") and g.s.day == 3,"blocked physical placement cannot stall natural dawn")
	_check(b.days._actor("day3_visitor_%d" % int(fixture.unixMs)).is_empty() and g.s.dayPendingPlacements.size() == 1,"blocked visitor has no invisible model body")
	var count: int = g.rolls; b.days.tick_active(1)
	_check(g.rolls == count and g.s.dayPendingPlacements.size() == 2,"price day defers separately without rerolling visitor")
	b.spatial.placement = "clear"; b.days.tick_active(50); b.days.tick_active(50); b.days.tick_active(50); b.days.tick_active(50); b.days.tick_active(50)
	_check(g.s.dayPendingPlacements.is_empty() and b.days.supports("price_guy"),"bounded retry drains visitor and Price Guy")

func _normalization() -> void:
	var bundle: Dictionary = _bundle(); var days: RefCounted = bundle.days
	for actor: Dictionary in fixture.campaignActors:
		var record: Dictionary = days._pending("campaign",actor,9)
		var accepted: Array = Days.normalize_pending([record])
		_check(accepted.size() == 1,"exact source campaign actor retained "+actor.id)
		if not accepted.is_empty():
			for key: String in ["targetX","targetY","wanderT","noComboReward","zoneOnly"]: _check(_same(accepted[0].payload[key],actor[key]),"campaign pending preserves physical/combat field "+key)
		for field: String in ["name","sprite","id","zoneOnly"]:
			var invalid: Dictionary = record.duplicate(true)
			if field == "zoneOnly": invalid.payload.zoneOnly = {"x":0,"y":0,"w":NAN,"h":1}
			else: invalid.payload[field] = "invented"
			_check(Days.normalize_pending([invalid]).is_empty(),"reject mutated campaign identity "+field)
	var good: Dictionary = days._pending("inheritance",{"id":"cp_inheritance_42","x":500.0,"y":500.0,"amt":500,"isInheritance":true,"collected":false},14)
	for key: String in ["source_x","source_y","source_day"]:
		for value: Variant in [NAN,INF,-1,"14",null]:
			var invalid: Dictionary = good.duplicate(true); invalid[key] = value
			_check(Days.normalize_pending([invalid]).is_empty(),"reject malformed pending scalar "+key)
	_check(Days.normalize_pending([good,good]).size() == 1,"pending IDs unique")
	var forged: Dictionary = good.duplicate(true); forged.payload.amt = 501
	_check(Days.normalize_pending([forged]).is_empty(),"inheritance cannot mint forged amount")
	for bad_id: String in ["cp_inheritance_foo","cp_inheritance_-1","cp_inheritance_01"]:
		forged = good.duplicate(true); forged.id = bad_id; forged.payload.id = bad_id
		_check(Days.normalize_pending([forged]).is_empty(),"reject noncanonical generated ID "+bad_id)
	var many: Array = []
	for index: int in range(100):
		var record: Dictionary = good.duplicate(true); record.id = "cp_inheritance_%d" % index; record.payload.id = record.id; many.append(record)
	_check(Days.normalize_pending(many).size() == Days.MAX_PENDING,"pending normalization allocation bounded64")

func _dependency_and_clock() -> void:
	var bundle: Dictionary = _bundle(); var state: RefCounted = bundle.state
	state.s.day = 6; state.s.dayTime = 1.0-1.0/State.DAY_MS; state.p.hp = 50
	bundle.comms.accepts = false
	var before: Dictionary = state.snapshot(); var rolls: int = state.rolls
	_check(not state.tick(0.016) and _same(before,state.snapshot()) and state.rolls == rolls,"missing required owner rejects dawn interval before all resource/time/RNG mutation")
	state.s.dayTime = 0.8
	before = state.snapshot()
	_check(not bundle.days.sleep_at_block().ok and _same(before,state.snapshot()),"missing owner rejects Block sleep before slept/stat/time changes")
	bundle.comms.accepts = true; bundle.campaign.accepts = false
	_check(not bundle.days.advance_sleep_day("hideout_sleep") and _same(before,state.snapshot()),"real campaign preparation failure rejects paid sleep")
	bundle.campaign.accepts = true
	state.s.day = 6; state.s.dayTime = 0.0; state.roll = 0.1
	state.p.rockedT = 1234; state.p.crashT = 456
	_check(state._advance_day("natural"),"source day7 natural commit")
	_check(state.s.flags.silenceUntilT == fixture.unixMs+240000,"silence uses shared Unix clock")
	_check(bundle.comms.deliveries.size() >= 2,"pre-silence day7 news/feed delivered synchronously")
	_check(bundle.comms.flushes == 1,"pre-day-event flush runs once after progression")
	_check(state.p.rockedT == 1234 and state.p.crashT == 456,"day commit does not clear high/crash")
	bundle.days.tick_wall(7999)
	_check(bundle.comms.calls.is_empty(),"garbage not early")
	bundle.days.tick_wall(15000)
	_check(bundle.comms.calls == ["garbage_truck","mom_proud"],"due callbacks execute once in chronological source order")
	bundle.days.tick_wall(15000)
	_check(bundle.comms.calls.size() == 2 and not bundle.days.tick_wall(14999),"wall callback single execution and monotonic guard")
	state.s.day = 1; state.s.dayTime = 0; state._advance_day("natural")
	state.fresh(); bundle.days.rehydrate(); bundle.days.tick_wall(100000)
	_check(bundle.comms.calls.size() == 2,"state epoch cancels old scheduled callbacks")
	var missing := Days.new(state,bundle.spatial,bundle.progression,bundle.travel,null,bundle.comms,bundle.comms.unix_ms)
	_check(not missing.install(),"missing real Campaign cannot install a production callback")

func _session_guards() -> void:
	var bundle: Dictionary = _bundle(); var state: RefCounted = bundle.state
	state.s.day = 3; state.p.cash = 100; bundle.days._spawn_price_guy()
	_at_actor(state,bundle.days._actor("price_guy"))
	var menu: Dictionary = bundle.days.open("price_guy")
	bundle.spatial.visible = false
	_check(not bundle.days.select(menu.token,"pay").ok and state.p.cash == 100,"fresh LOS refusal before payment")
	bundle.spatial.visible = true; menu = bundle.days.open("price_guy"); state.p.cash = 0
	_check(not bundle.days.select(menu.token,"pay").ok,"cash removed after open cannot pay")
	state.p.cash = 100; menu = bundle.days.open("price_guy")
	_check(bundle.days.select(menu.token,"pay").ok,"Price Guy exact one payment")
	var paid: Dictionary = state.snapshot()
	_check(not bundle.days.select(menu.token,"pay").ok and _same(paid,state.snapshot()),"payment capability cannot replay")
	state.s.day = 30; bundle.days._fire_day_events(); _at_actor(state,bundle.days._actor("bus_driver"))
	menu = bundle.days.open("bus_driver"); state.p.x += 60
	_check(not bundle.days.select(menu.token,"take_bus").ok and not state.s.flags.busTaken,"driver revalidates strict60px boundary")
	_at_actor(state,bundle.days._actor("bus_driver")); menu = bundle.days.open("bus_driver"); state.fresh()
	_check(not bundle.days.select(menu.token,"take_bus").ok and not state.s.flags.busTaken,"new epoch rejects old bus ending token")

func _run() -> void:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/day_reference.json"))
	_check(decoded is Dictionary,"source Day fixture parses")
	if decoded is Dictionary:
		fixture = decoded
		_source_cases(); _pending_and_restore(); _normalization(); _dependency_and_clock(); _session_guards()
	if failures.is_empty():
		print("3D DAY GATE: PASS (%d checks;68 source cases,4 causes,4 scripted events; real Campaign/Runtime integration pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D DAY GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)
