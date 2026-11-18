class_name RockBottomDaySystem
extends RefCounted
## Source days and conditional residents; GameState alone owns the model and day increment.
const Session = preload("res://scripts/action_session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const CAUSES := ["natural","hideout_sleep","office_sleep","block_sleep"]
const MAX_PENDING := 64
const OPTIONAL_PENDING_LIMIT := 40
const RECOVERY_PX := 100.0
const ACTOR_KEYS := ["id","name","sprite","x","y","w","h","color","hp","maxHp","speed","dmg","hostile","aggro","archetype","isDay3Visitor","isPriceGuy","isBusDriver","hasFloater","kingdomGuard","kingdomPretender","kingdomClan","zoneOnly","showHp","transient","noComboReward","attackCd","chargeState","chargeT","wanderT","targetX","targetY"]
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _progression_ref: WeakRef
var _travel_ref: WeakRef
var _campaign_ref: WeakRef
var _communications_ref: WeakRef
var _unix_ms: Callable
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var session: RefCounted
var inventory: RefCounted
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _prepared: Dictionary = {}
var _scheduled: Array[Dictionary] = []
var _wall_ms: float = 0.0
var _retry_ms: float = 0.0
var _missing: Dictionary = {}
var _opened_id: String = ""


func _init(owner: RefCounted,spatial: Object,progression: RefCounted,travel: RefCounted,campaign: Object,communications: Object,unix_ms: Callable) -> void:
	_host_ref = weakref(owner)
	_spatial_ref = weakref(spatial) if spatial != null else null
	_progression_ref = weakref(progression) if progression != null else null
	_travel_ref = weakref(travel) if travel != null else null
	_campaign_ref = weakref(campaign) if campaign != null else null
	_communications_ref = weakref(communications) if communications != null else null
	_unix_ms = unix_ms
	session = Session.new(owner,spatial); inventory = Inventory.new(owner)
	owner.register_state_normalizer("dayPendingPlacements",normalize_pending)
	_sync_epoch()


func _object(reference: WeakRef,method: StringName) -> Object:
	var object: Object = reference.get_ref() if reference != null else null
	return object if object != null and object.has_method(method) else null
func _sync_epoch() -> bool:
	if host == null: return false
	if not is_same(_player_epoch,host.p) or not is_same(_state_epoch,host.s):
		_player_epoch = host.p; _state_epoch = host.s
		_prepared.clear(); _scheduled.clear(); _missing.clear(); _retry_ms = 0.0; close()
		host.s.dayPendingPlacements = normalize_pending(host.s.get("dayPendingPlacements"))
	return true
func _notice(key: String) -> void:
	if host != null and not _missing.has(key):
		_missing[key] = true; host.emit_event("dependency_missing",{"system":"days","key":key})
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _feed(text: String,author: String = "@crackheadcent") -> void:
	var communication: Object = _object(_communications_ref,&"post")
	if communication == null or communication.post(text,author) != true: _notice("feed")
func _save() -> void: host.emit_event("save_requested")
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _now() -> float:
	if not _unix_ms.is_valid(): return NAN
	var value: Variant = _unix_ms.call()
	return float(value) if _finite(value) and value >= 0 else NAN
static func _finite(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
static func _bounded_point(record: Dictionary) -> bool:
	return _finite(record.get("x")) and _finite(record.get("y")) and record.x >= 0 and record.y >= 0 and record.x <= 8600 and record.y <= 5600


func ready() -> bool:
	if not _sync_epoch() or not is_finite(_now()): return false
	for method: StringName in [&"clear_placement",&"stage_cash_pickup",&"can_reach_target",&"can_use_zone"]:
		if _object(_spatial_ref,method) == null: return false
	if _object(_progression_ref,&"roll_hustles") == null or _object(_progression_ref,&"check_hustles") == null: return false
	if _object(_travel_ref,&"on_natural_dawn") == null or _object(_campaign_ref,&"prepare_day") == null: return false
	var communication: Object = _object(_communications_ref,&"day_capabilities_ready")
	return communication != null and _object(_communications_ref,&"dispatch_day_callback") != null and _object(_communications_ref,&"post") != null and _object(_communications_ref,&"broadcast") != null and _object(_communications_ref,&"flush_pending_events") != null and communication.day_capabilities_ready() == true


func install() -> bool:
	if not ready(): return false
	host.on_day_preflight = preflight_day; host.on_day_started = commit_day
	return true


func preflight_day(cause: String) -> bool:
	if cause not in CAUSES or not ready(): return false
	if int(host.s.day) >= 1000000000: return false
	if _prepared.get("day",0) == host.s.day and _prepared.get("cause","") == cause: return true
	var result: Variant = _campaign_ref.get_ref().call(&"prepare_day",int(host.s.day)+1)
	if not result is Dictionary or result.get("ok") != true or not result.get("actors") is Array or not result.get("kingdom") is Dictionary: return false
	if result.actors.size() > 16: return false
	var planned: Array[Dictionary] = []
	for actor: Variant in result.actors:
		if not actor is Dictionary: return false
		var record: Dictionary = _pending("campaign",actor,int(host.s.day)+1)
		if normalize_pending([record]).size() != 1: return false
		planned.append(record)
	var persistent: int = 0
	for record: Dictionary in host.s.dayPendingPlacements:
		if record.kind != "campaign": persistent += 1
	if persistent+planned.size()+1 > MAX_PENDING: return false
	_prepared = {"day":int(host.s.day),"cause":cause,"actors":planned,"kingdom":result.kingdom.duplicate(true)}
	return true


func commit_day(cause: String) -> void:
	# Core has incremented once after this same synchronous preflight. No fallible
	# owner call remains; physical refusals are retained as pending records.
	if host == null or _prepared.get("day",-1)+1 != host.s.day or _prepared.get("cause","") != cause:
		_notice("unprepared_day_commit"); return
	var plan: Dictionary = _prepared; _prepared = {}
	var roll: float = host.random_float()
	host.s.weather = "clear" if roll < 0.65 else ("rain" if roll < 0.88 else "fog")
	for key: String in host.definition("src/systems/daily_hideouts.js","DAILY_COUNTER_KEYS",[]): host.s.counters[key] = 0
	if host.s.office is Dictionary and host.s.office.get("workDay",0) != host.s.day:
		host.s.office.workDay = host.s.day; host.s.office.workToday = 0
	host.s.kingdom = plan.kingdom
	for index: int in range(host.npcs.size()-1,-1,-1):
		if host.npcs[index].get("kingdomGuard",false) or host.npcs[index].get("kingdomPretender",false):
			host.emit_event("actor_removed",{"actor_id":host.npcs[index].id}); host.npcs.remove_at(index)
	for index: int in range(host.s.dayPendingPlacements.size()-1,-1,-1):
		if host.s.dayPendingPlacements[index].kind == "campaign": host.s.dayPendingPlacements.remove_at(index)
	for record: Dictionary in plan.actors: _place_or_defer(record)
	_progression_ref.get_ref().call(&"roll_hustles")
	_communications_ref.get_ref().call(&"flush_pending_events")
	if cause == "natural":
		if host.s.day >= 7: host.unlock_achievement("tuesday_again")
		_toast("· day %d ·\n%s" % [host.s.day,"it is raining." if host.s.weather == "rain" else ("fog." if host.s.weather == "fog" else "a tuesday.")],2400)
		_communications_ref.get_ref().call(&"broadcast","day %d has arrived. weather: %s." % [host.s.day,host.s.weather])
		_feed("it is day %d. this is somehow your life." % host.s.day)
		if host.random_float() < 0.5: _schedule("garbage_truck",8000.0)
	_fire_day_events()
	if cause == "natural":
		_schedule("mom_proud",12000.0+host.random_float()*30000.0)
		_travel_ref.get_ref().call(&"on_natural_dawn")
	elif cause in ["office_sleep","block_sleep"] and host.s.day >= 7: host.unlock_achievement("tuesday_again")
	host.emit_event("weather_changed",{"weather":host.s.weather,"day":host.s.day})


func advance_sleep_day(kind: String) -> bool:
	if kind not in ["hideout_sleep","office_sleep","block_sleep"] or not _sync_epoch() or float(host.s.dayTime) <= 0.3: return false
	if not ready() or not host.on_day_started.is_valid() or host.on_day_started != commit_day: return false
	return host._advance_day(kind)


func sleep_at_block() -> Dictionary:
	if not _sync_epoch() or host.s.mode not in ["playing","dialogue"] or host.s.get("bossKind","") == "kingdom": return {"ok":false,"reason":"unavailable"}
	var spatial: Object = _object(_spatial_ref,&"can_use_zone")
	var at: Vector2 = host.player_center()
	var inside: bool = false
	for zone: Dictionary in host.content.world.zones:
		if zone.id == "block": inside = at.x >= zone.x and at.x <= zone.x+zone.w and at.y >= zone.y and at.y <= zone.y+zone.h; break
	if not inside or spatial == null or spatial.can_use_zone("block") != true: return {"ok":false,"reason":"out_of_reach"}
	var progression: Object = _object(_progression_ref,&"check_hustles")
	var rollover: bool = float(host.s.dayTime) > 0.3
	if progression == null or (rollover and (host.on_day_started != commit_day or not preflight_day("block_sleep"))): return {"ok":false,"reason":"missing_day_owner"}
	host.s.counters.slept = int(host.s.counters.get("slept",0))+1
	progression.check_hustles()
	if rollover: host._advance_day("block_sleep")
	else: host.s.dayTime = 0.3
	host.p.hp = minf(host.p.maxHp,host.p.hp+50); host.p.brain = minf(100.0,host.p.brain+25)
	host.p.shakes = minf(100.0,host.p.shakes+15); host.p.wanted = maxi(0,host.p.wanted-1)
	_sound("coin"); _toast("you sleep on the crate.\nyou dream of a chimichanga that has opinions.\n+50 hp · +25 brain",3000)
	_feed("slept on the block. felt like 7 hours. was 14 minutes."); _save()
	return {"ok":true,"rolled_day":rollover}


func _schedule(kind: String,delay: float) -> void:
	_scheduled.append({"kind":kind,"due":_wall_ms+delay})
	_scheduled.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.due < b.due)
func tick_wall(monotonic_ms: float) -> bool:
	if not _sync_epoch() or not is_finite(monotonic_ms) or monotonic_ms < _wall_ms: return false
	_wall_ms = monotonic_ms
	while not _scheduled.is_empty() and float(_scheduled[0].due) <= _wall_ms:
		var item: Dictionary = _scheduled.pop_front()
		var communication: Object = _object(_communications_ref,&"dispatch_day_callback")
		if communication == null or communication.dispatch_day_callback(item.kind) != true: _notice("day_callback:"+str(item.kind))
	return true


func is_night() -> bool: return host != null and (float(host.s.dayTime) < 0.25 or float(host.s.dayTime) > 0.75)
func actor_visible(body: Dictionary) -> bool:
	return not (is_night() and (body.get("id","") in ["mom","pete"] or body.get("daytimeOnly",false)))


func tick_active(dt_ms: float) -> bool:
	if not _sync_epoch() or host.s.mode != "playing" or not is_finite(dt_ms) or dt_ms <= 0 or dt_ms > 50: return false
	if host.s.day % 3 == 0 and host.s.flags.get("priceGuyDay",0) != host.s.day: _spawn_price_guy()
	if is_night() and host.s.flags.get("parkNightCashDay",0) != host.s.day:
		if host.s.dayPendingPlacements.size() >= OPTIONAL_PENDING_LIMIT: _notice("pending_capacity:park")
		else:
			host.s.flags.parkNightCashDay = host.s.day
			if host.random_float() < 0.30:
				var base: int = 20+int(floor(host.random_float()*21.0))
				var multiplier: float = float(host.s.get("territoryCashMult",1.0))
				if multiplier == 0.0: multiplier = 1.0 # Source ||1 fallback.
				var amount: int = int(floor(base*multiplier+0.5))
				var pile := {"id":"cp_park_night_%d" % host.s.day,"x":2510.0,"y":1320.0,"amt":amount,"collected":false}
				_place_or_defer(_pending("park",pile,host.s.day))
				_feed("the swings move on their own at night. they don't.")
	var pete: Dictionary = _actor("pete")
	if not pete.is_empty(): pete.shopClosed = is_night()
	_retry_ms -= dt_ms
	if _retry_ms <= 0:
		_retry_ms = 250.0
		for attempt: int in range(mini(2,host.s.dayPendingPlacements.size())):
			var record: Dictionary = host.s.dayPendingPlacements.pop_front()
			if _place(record): _save()
			else: host.s.dayPendingPlacements.append(record)
	return true


func _fire_day_events() -> void:
	match int(host.s.day):
		3:
			if not host.s.flags.get("day3Fired",false): _fire_visitor()
		7:
			if not host.s.flags.get("day7Fired",false):
				host.s.flags.day7Fired = true; host.s.flags.silenceUntilT = _now()+240000.0
				_toast("the radio is off.\nthe phones are off.\nthe city is listening to something.",5400); _save()
		14:
			if not host.s.flags.get("day14Fired",false):
				host.s.flags.day14Fired = true
				var x: float = clampf(host.p.x+(host.random_float()-0.5)*320.0,40,8560)
				var y: float = clampf(host.p.y+(host.random_float()-0.5)*320.0,40,5560)
				_place_or_defer(_pending("inheritance",{"id":"cp_inheritance_%d" % int(_now()),"x":x,"y":y,"amt":500,"isInheritance":true,"collected":false},host.s.day))
				_toast("something arrived today.\nyou don't know what.\nyou will, when you find it.",4200); _save()
		30:
			if not host.s.flags.get("day30Fired",false): _fire_bus()


func _fire_visitor() -> void:
	host.s.flags.day3Fired = true
	var actor := {"id":"day3_visitor_%d" % int(_now()),"name":"SOMEONE YOU DON'T KNOW","sprite":"lurch","x":clampf(host.p.x+80,40,8560),"y":clampf(host.p.y+30,40,5560),"w":24.0,"h":28.0,"color":"#3a3030","hp":30,"maxHp":30,"speed":0.6,"hostile":false,"archetype":"passive","isDay3Visitor":true,"hasFloater":"?"}
	_place_or_defer(_pending("visitor",actor,host.s.day))
	_toast("someone you don't know is on the block today.\nthey are not moving.\nthey are watching.",4200)
	_feed("someone was on the block today. someone was watching."); _save()


func _fire_bus() -> void:
	host.s.flags.day30Fired = true
	if host.s.flags.get("busTaken",false) or host.s.flags.get("busRefused",false): return
	if not _actor("bus_driver").is_empty() or _has_pending("bus_driver"): return
	var actor := {"id":"bus_driver","name":"THE BUS DRIVER","sprite":"lurch","x":1330.0,"y":1260.0,"w":24.0,"h":28.0,"color":"#1a2a3a","hp":60,"maxHp":60,"speed":0.0,"hostile":false,"archetype":"passive","isBusDriver":true,"hasFloater":"?"}
	_place_or_defer(_pending("bus",actor,host.s.day))
	_toast("a bus is at the stop.\nit hasn't been there in a while.\nthe driver is looking at you.",5400)
	_feed("the bus is back. it does not come back often."); _save()


func _spawn_price_guy() -> void:
	if host.s.dayPendingPlacements.size() >= OPTIONAL_PENDING_LIMIT: _notice("pending_capacity:price"); return
	_remove_actor("price_guy")
	host.s.flags.priceGuyDay = host.s.day
	var actor := {"id":"price_guy","name":"THE PRICE GUY","sprite":"price_guy","x":2940.0,"y":1860.0,"w":26.0,"h":32.0,"color":"#1a1818","hp":80,"maxHp":80,"speed":0.0,"hostile":false,"isPriceGuy":true,"hasFloater":"?"}
	_place_or_defer(_pending("price",actor,host.s.day))
	_feed("the price guy is back. nobody saw him arrive.")


func rehydrate() -> bool:
	if not _sync_epoch(): return false
	if host.s.flags.get("day30Fired",false) and not host.s.flags.get("busTaken",false) and not host.s.flags.get("busRefused",false): _fire_bus()
	return true


func _pending(kind: String,payload: Dictionary,day: int) -> Dictionary:
	return {"kind":kind,"id":str(payload.id),"source_x":float(payload.x),"source_y":float(payload.y),"source_day":day,"payload":payload.duplicate(true)}
func _has_pending(id: String) -> bool:
	for record: Dictionary in host.s.dayPendingPlacements:
		if record.id == id: return true
	return false
func _place_or_defer(record: Dictionary) -> void:
	if _place(record): return
	if _has_pending(record.id): return
	if host.s.dayPendingPlacements.size() >= MAX_PENDING: _notice("pending_capacity:required"); return
	host.s.dayPendingPlacements.append(record); _save()
func _place(record: Dictionary) -> bool:
	var spatial: Object = _spatial_ref.get_ref() if _spatial_ref != null else null
	if spatial == null: return false
	var payload: Dictionary = record.payload.duplicate(true)
	var point := Vector2(record.source_x,record.source_y)
	var placed: Variant
	if record.kind in ["inheritance","park"]:
		for pile: Dictionary in host.cash_piles:
			if str(pile.id) == record.id: return true
		if record.id in host.s.cashPilesCollected: return true
		if not spatial.has_method(&"stage_cash_pickup"): return false
		placed = spatial.call(&"stage_cash_pickup",point,RECOVERY_PX)
	else:
		if not _actor(record.id).is_empty(): return true
		if record.kind == "bus" and (host.s.flags.get("busTaken",false) or host.s.flags.get("busRefused",false)): return true
		if not spatial.has_method(&"clear_placement"): return false
		placed = spatial.call(&"clear_placement",payload)
	if not placed is Vector2 or not placed.is_finite() or placed.distance_to(point) > RECOVERY_PX+0.0001: return false
	payload.x = placed.x; payload.y = placed.y
	if not _bounded_point(payload): return false
	if record.kind in ["inheritance","park"]:
		host.cash_piles.append(payload); host.emit_event("cash_spawned",{"id":record.id})
	else:
		if payload.x+payload.w > 8600 or payload.y+payload.h > 5600: return false
		host.npcs.append(payload); host.emit_event("actor_spawned",{"actor_id":record.id})
	host.emit_event("day_placement",{"id":record.id,"kind":record.kind,"source_position":point,"position":placed,"recovered_px":point.distance_to(placed)})
	return true


static func normalize_pending(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Dictionary = {}
	if not raw is Array: return result
	for value: Variant in raw:
		if result.size() >= MAX_PENDING: break
		if not value is Dictionary or not value.get("payload") is Dictionary: continue
		var id: Variant = value.get("id"); var kind: Variant = value.get("kind")
		if not id is String or id.length() > 96 or ids.has(id) or kind not in ["visitor","bus","price","inheritance","park","campaign"]: continue
		if not _finite(value.get("source_x")) or not _finite(value.get("source_y")) or not _finite(value.get("source_day")): continue
		if value.source_day < 1 or value.source_day > 1000000000 or floor(value.source_day) != value.source_day: continue
		var payload: Dictionary = value.payload
		if payload.get("id") != id or not _bounded_point(payload): continue
		if payload.x != value.source_x or payload.y != value.source_y: continue
		var clean: Dictionary = {}
		if kind in ["inheritance","park"]:
			var prefix: String = "cp_inheritance_" if kind == "inheritance" else "cp_park_night_"
			if not _numbered_id(id,prefix): continue
			if kind == "park" and id != "cp_park_night_%d" % int(value.source_day): continue
			if not _finite(payload.get("amt")) or payload.amt < 0 or payload.amt > 1000000 or floor(payload.amt) != payload.amt: continue
			if kind == "inheritance" and payload.amt != 500: continue
			clean = {"id":id,"x":float(payload.x),"y":float(payload.y),"amt":int(payload.amt),"collected":false}
			if kind == "inheritance": clean.isInheritance = true
		else:
			var identity: bool = (kind == "visitor" and _numbered_id(id,"day3_visitor_") and payload.get("name") == "SOMEONE YOU DON'T KNOW" and payload.get("sprite") == "lurch" and payload.get("isDay3Visitor") == true) or (kind == "bus" and id == "bus_driver" and payload.get("name") == "THE BUS DRIVER" and payload.get("sprite") == "lurch" and payload.get("isBusDriver") == true) or (kind == "price" and id == "price_guy" and payload.get("name") == "THE PRICE GUY" and payload.get("sprite") == "price_guy" and payload.get("isPriceGuy") == true)
			if kind == "campaign": identity = _campaign_identity(payload,int(value.source_day))
			if not identity: continue
			var dimensions: bool = true
			for key: String in ["w","h","hp","maxHp","speed"]:
				if not _finite(payload.get(key)) or payload[key] < 0 or payload[key] > 1000000: dimensions = false
			if not dimensions or payload.w <= 0 or payload.h <= 0 or payload.w > 160 or payload.h > 160 or payload.speed > 10 or payload.hp <= 0 or payload.hp > payload.maxHp: continue
			if payload.x+payload.w > 8600 or payload.y+payload.h > 5600: continue
			if kind != "campaign":
				var expected_hp: int = 30 if kind == "visitor" else (60 if kind == "bus" else 80)
				if payload.w != (26 if kind == "price" else 24) or payload.h != (32 if kind == "price" else 28) or payload.hp != expected_hp or payload.maxHp != expected_hp or payload.speed != (0.6 if kind == "visitor" else 0.0) or payload.get("hostile") != false: continue
			for key: String in ACTOR_KEYS:
				if not payload.has(key): continue
				var item: Variant = payload[key]
				if item is bool or item is String or _finite(item): clean[key] = item
				elif key == "zoneOnly" and item is Dictionary and _bounded_point(item) and _finite(item.get("w")) and _finite(item.get("h")) and item.w > 0 and item.h > 0 and item.x+item.w <= 8600 and item.y+item.h <= 5600: clean.zoneOnly = {"x":item.x,"y":item.y,"w":item.w,"h":item.h}
		result.append({"kind":kind,"id":id,"source_x":float(value.source_x),"source_y":float(value.source_y),"source_day":int(value.source_day),"payload":clean}); ids[id] = true
	return result


static func _numbered_id(id: String,prefix: String) -> bool:
	if not id.begins_with(prefix): return false
	var suffix: String = id.trim_prefix(prefix)
	return not suffix.is_empty() and suffix.is_valid_int() and str(int(suffix)) == suffix and int(suffix) >= 0
static func _campaign_identity(payload: Dictionary,day: int) -> bool:
	var id: String = str(payload.get("id",""))
	var clan: String = str(payload.get("kingdomClan",""))
	if clan not in ["blue_tarp","cart_cavalry","copper_choir","throne"]: return false
	if payload.get("sprite") not in ["blue_tarp_guard","receipt_guard","wire_guard"]: return false
	if payload.get("archetype") not in ["charger","swarmer","ranged","grabber"]: return false
	if payload.get("w") != 32 or payload.get("h") != 32 or payload.get("hostile") != true or payload.get("noComboReward") != true: return false
	var zone: Variant = payload.get("zoneOnly")
	if not zone is Dictionary or not _bounded_point(zone) or not _finite(zone.get("w")) or not _finite(zone.get("h")) or zone.w <= 0 or zone.h <= 0 or zone.x+zone.w > 8600 or zone.y+zone.h > 5600: return false
	if payload.get("kingdomPretender",false) == true:
		return id == "curb_pretender_%d" % day and _numbered_id(str(payload.get("name","")),"CURB PRETENDER No. ")
	if payload.get("kingdomGuard",false) != true: return false
	var prefix: String = "kingdom_guard_%s_%d_" % [clan,day]
	return _numbered_id(id,prefix) and int(id.trim_prefix(prefix)) < (3 if clan == "throne" else 4) and payload.get("name") in ["TARP KNIGHT","CART LANCER","WIRE DEACON","KNIGHT EMERITUS"]


func _actor(id: String) -> Dictionary:
	if host != null:
		for actor: Dictionary in host.npcs:
			if str(actor.id) == id: return actor
	return {}
func _remove_actor(id: String) -> void:
	for index: int in range(host.npcs.size()-1,-1,-1):
		if str(host.npcs[index].id) == id: host.npcs.remove_at(index); host.emit_event("actor_removed",{"actor_id":id})
	for index: int in range(host.s.dayPendingPlacements.size()-1,-1,-1):
		if host.s.dayPendingPlacements[index].id == id: host.s.dayPendingPlacements.remove_at(index)
func supports(id: String) -> bool:
	var actor: Dictionary = _actor(id)
	return (id == "price_guy" and actor.get("isPriceGuy",false)) or (id == "bus_driver" and actor.get("isBusDriver",false)) or (id.begins_with("day3_visitor_") and actor.get("isDay3Visitor",false))
func _reason(id: String) -> String:
	if not _sync_epoch() or host.s.mode not in ["playing","dialogue"]: return "wrong_mode"
	if host.s.get("bossKind","") == "kingdom": return "active_boss"
	var actor: Dictionary = _actor(id)
	if not supports(id) or actor.get("dead",false): return "missing_actor"
	if host.player_center().distance_squared_to(Vector2(actor.x+actor.w*0.5,actor.y+actor.h*0.5)) >= 3600: return "out_of_reach"
	return ""
func _options(id: String) -> Array[Dictionary]:
	if id == "bus_driver": return [{"id":"take_bus","label":"yes. get on the bus.","enabled":true},{"id":"refuse_bus","label":"no. not today.","enabled":true}]
	if id == "price_guy" and not _actor(id).get("priceResolved",false): return [{"id":"pay","label":"pay the price. ($%d)" % host.p.cash if host.p.cash > 0 else "you have nothing to pay.","enabled":host.p.cash > 0},{"id":"leave","label":"walk away.","enabled":true}]
	return [{"id":"leave","label":"leave.","enabled":true}]
func open(id: String) -> Dictionary:
	close()
	var reason: String = _reason(id)
	if not reason.is_empty(): return {"ok":false,"reason":reason}
	var options: Array[Dictionary] = _options(id)
	var actions: Array[String] = []
	for option: Dictionary in options: actions.append(option.id)
	var started: Dictionary = session.begin(id,actions)
	if not started.ok: return started
	_opened_id = id; host.s.mode = "dialogue"
	var text: String
	if id == "bus_driver": text = "the bus is here.\nit hasn't been here in a while.\nthe driver looks at you.\n\nare you getting on?"
	elif id == "price_guy": text = "he is gone.\nhe was here." if _actor(id).get("priceResolved",false) else "the price guy. he has it. you have the price.\n\n\n'the price is what you have on you.\nall of it. or nothing.'"
	else: text = "someone you don't know.\nthey say:\n\n'i heard about you.'\n\nthat's all they say."
	return {"ok":true,"token":started.token,"actor":id,"title":_actor(id).name,"text":text,"options":options}
func close() -> void:
	if session != null: session.close()
	_opened_id = ""
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok: return accepted
	var id: String = accepted.target
	var reason: String = _reason(id)
	if not reason.is_empty(): return {"ok":false,"reason":reason}
	var enabled: bool = false
	for option: Dictionary in _options(id):
		if option.id == action: enabled = option.enabled
	if not enabled: return {"ok":false,"reason":"action_unavailable"}
	host.s.mode = "playing"; _opened_id = ""
	var actor: Dictionary = _actor(id)
	if id == "bus_driver":
		if host.s.flags.get("busTaken",false) or host.s.flags.get("busRefused",false): return {"ok":false,"reason":"resolved"}
		_remove_actor(id)
		if action == "take_bus":
			host.s.flags.busTaken = true; host.unlock_achievement("the_bus"); host.s.mode = "ending"; host.s.endingContinue = true
			host.emit_event("ending",{"title":"THE BUS","text":"you got on the bus.\nthe bus left.\nyou survived rock bottom.\nthe bus has a destination. it has not told you.","day":host.s.day,"rocks_smoked":host.p.lifetime.get("rocksSmoked",0),"cred":int(host.p.cred)})
		else:
			host.s.flags.busRefused = true; _toast("the bus leaves.\nit doesn't come back.\nthat was your chance.",5200); _feed("the bus left. someone watched it leave.")
		_save()
	elif id == "price_guy":
		if action == "pay": _pay_price(actor)
		elif not actor.get("priceResolved",false): _toast("he watches you leave.\nhe does not move.\nthe price was the price.",2800)
	else:
		actor.wanderOff = true; actor.speed = 1.2; actor.targetX = 8680; actor.targetY = actor.y
	return {"ok":true,"closed":true}


func _pay_price(actor: Dictionary) -> void:
	host.s.flags.priceGuyVisits = int(host.s.flags.get("priceGuyVisits",0))+1; actor.priceResolved = true
	var paid: int = host.p.cash; host.p.cash = 0; host.unlock_achievement("the_price_paid")
	var roll: float = host.random_float()
	if roll < 0.20:
		host.p.weapon = "knife"; _toast("you paid $%d.\nhe handed you a knife.\nthe handle is warm.\n(+ knife)" % paid,4200)
		_feed("the price guy handed someone a knife. the someone walked away with it.")
	elif roll < 0.35:
		host.p.cash += 200; _toast("you paid $%d.\nhe handed you $200.\nyou are net positive on this transaction.\nyou are not.\n(+ $200)" % paid,5400)
		_feed("the price guy gave someone $200. the someone gave him $%d. the math is moral." % paid)
	elif roll < 0.45 and not inventory.owns_tool("propane_torch"):
		var displaced: Variant = host.equip_tool("propane_torch")
		_toast("you paid $%d.\nhe handed you a propane torch.\nit smells like a parking lot.\n(+ propane torch)" % paid+("\nthe crowbar goes to pete's glass.\nyou cook now. you do not pry." if displaced != null else ""),5400)
		_feed("the price guy gave someone a propane torch. he had one. now they do.")
	elif roll < 0.70:
		host.p.rocks += 1; _toast("you paid $%d.\nhe handed you a rock.\nyou suspect it is real.\n(+ 1 rock)" % paid,4200)
	else: _toast("you paid $%d.\nhe handed you nothing.\nhe nods.\nyou nod. the transaction is complete." % paid,5400)
	actor.priceWalkOff = true; actor.speed = 1.4; actor.targetX = -80; actor.targetY = actor.y; actor.wanderOff = true; _save()
