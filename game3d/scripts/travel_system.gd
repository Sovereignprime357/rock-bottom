class_name RockBottomTravel
extends RefCounted
## Source travel/household transactions. Scene and day adapters provide live physical effects.
const Inventory = preload("res://scripts/inventory.gd")
const Session = preload("res://scripts/action_session.gd")
const BUS_DELAY_MS := 380.0
const MAX_DROP_PX := 50.0
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _day_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var inventory: RefCounted
var session: RefCounted
var _service: String = ""
var _page: int = 0
var _pending: Dictionary = {}
var _notifications: Array[Dictionary] = []
var _cart_id: String = ""


func _init(owner: RefCounted, spatial_adapter: Object, day_adapter: Object = null) -> void:
	_host_ref = weakref(owner)
	_spatial_ref = weakref(spatial_adapter) if spatial_adapter != null else null
	_day_ref = weakref(day_adapter) if day_adapter != null else null
	inventory = Inventory.new(owner)
	session = Session.new(owner, spatial_adapter)
	for index: int in range(owner.content.props.size()):
		if owner.content.props[index].type == "cart": _cart_id = "prop:%d" % index; break
	reset_session("cold")


func _spawn() -> Dictionary:
	var point: Dictionary = host.definition("src/data/props.js", "RIDEABLE_CART_SPAWN", {"x":1000,"y":1600})
	return {"x":float(point.x),"y":float(point.y),"w":24.0,"h":20.0,"type":"cart"}


func reset_session(reason: String, previous_cart: Dictionary = {}) -> void:
	close()
	_pending.clear()
	_notifications.clear()
	if host == null: return
	var cart: Dictionary = _spawn()
	if reason == "restore" and _valid_point(previous_cart):
		cart.x = float(previous_cart.x); cart.y = float(previous_cart.y)
	host.s.travelRuntime = {"cart":cart,"naturalDawnDay":0}
	_emit_cart()


func _valid_point(value: Dictionary) -> bool:
	for key: String in ["x","y"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])): return false
	var bounds: Dictionary = host.content.world.bounds
	return float(value.x) >= 0.0 and float(value.y) >= 0.0 and float(value.x)+24.0 <= float(bounds.w) and float(value.y)+20.0 <= float(bounds.h)


func _runtime() -> Dictionary:
	if not host.s.get("travelRuntime") is Dictionary:
		host.s.travelRuntime = {"cart":_spawn(),"naturalDawnDay":0}
	return host.s.travelRuntime


func cart_record() -> Dictionary:
	return _runtime().cart.duplicate(true) if host != null else {}


func has_bus_pass() -> bool: return host != null and inventory.count_records("bus_pass") > 0


func buy_pinky_pass() -> Dictionary:
	var reason: String = _reason("pinky")
	if not reason.is_empty(): return _fail(reason)
	if host.faction_tier(int(host.p.faction.get("street",0))) == "hated": return _fail("street_hated")
	var reached: Dictionary = session.probe("pinky")
	if not reached.ok: return reached
	if has_bus_pass(): return _fail("already_has_pass")
	if host.p.cash < 20: return _fail("insufficient_cash")
	if not inventory.append_item("bus_pass","a bus pass"): return _fail("inventory_rejected")
	host.p.cash -= 20
	_toast("- $20\n+ a bus pass\npinky shrugs.\n'is paper. is the bus. is paper.'",3400)
	host.emit_event("sound",{"id":"coin"}); _save()
	return {"ok":true}


func _actor(id: String) -> Dictionary:
	for actor: Dictionary in host.npcs:
		if actor.get("id") == id: return actor
	return {}


func _flag(key: String) -> bool: return host.s.flags.get(key, false) == true


func _owned(kind: String) -> bool:
	if kind == "office": return host.s.office.get("owned",false) == true
	return kind in ["mom","scrap"] and _flag(kind + "HideoutOwned")


func _target(service: String) -> String:
	if service in ["bus","pinky"]: return "pinky"
	if service in ["mom","biggu"]: return service
	if service.begins_with("office:") or service == "chest:office": return "office"
	if service.begins_with("chest:"): return "hideout:" + service.trim_prefix("chest:")
	return service


func _reason(service: String) -> String:
	if host == null: return "missing_owner"
	if host.s.mode not in ["playing","dialogue"]: return "wrong_mode"
	if host.s.get("bossKind","") == "kingdom": return "active_boss"
	if not _pending.is_empty(): return "travel_pending"
	if service not in ["bus","pinky","mom","biggu","hideout:mom","hideout:scrap","chest:mom","chest:scrap","chest:office","office:cot","office:chest"]: return "unknown_service"
	var target: String = _target(service)
	if target in ["mom","pinky","biggu"]:
		var actor: Dictionary = _actor(target)
		if actor.is_empty() or actor.get("dead",false) == true: return "missing_actor"
		var center := Vector2(float(actor.x)+float(actor.w)*0.5,float(actor.y)+float(actor.h)*0.5)
		if host.player_center().distance_squared_to(center) >= 3600.0: return "out_of_reach"
	else:
		var kind: String = "office" if target == "office" else target.trim_prefix("hideout:")
		if not _owned(kind): return "not_owned"
		var door: Dictionary = host.definition("src/systems/campaigns.js","OFFICE_DOOR",{}) if kind == "office" else host.definition("src/systems/daily_hideouts.js","HIDEOUT_DOORS",{}).get(kind,{})
		if door.is_empty(): return "missing_door"
		var center := Vector2(float(door.x)+float(door.w)*0.5,float(door.y)+float(door.h)*0.5)
		var reach: float = 44.0 if kind == "office" else 40.0
		if host.player_center().distance_squared_to(center) >= reach*reach: return "out_of_reach"
		if kind == "office":
			var upgrade: String = "cot" if service == "office:cot" else "locker"
			if host.s.office.upgrades.get(upgrade,false) != true: return "missing_upgrade"
	return ""


func _option(id: String, label: String, enabled: bool = true, reason: String = "") -> Dictionary:
	return {"id":id,"label":label,"enabled":enabled,"reason":reason if not enabled else ""}


func combat_active() -> bool:
	if float(host.p.wanted) > 0: return true
	for actor: Dictionary in host.npcs:
		if actor.get("dead",false) or actor.get("isPet",false): continue
		if not (actor.get("hostile",false) or actor.get("aggro",false)): continue
		var center := Vector2(float(actor.x)+float(actor.w)*0.5,float(actor.y)+float(actor.h)*0.5)
		if host.player_center().distance_squared_to(center) < 220.0*220.0: return true
	return false


func _zone() -> String:
	var center: Vector2 = host.player_center()
	var best: String = ""
	var rank: float = -1.0
	for zone: Dictionary in host.content.world.zones:
		if center.x < zone.x or center.x > zone.x+zone.w or center.y < zone.y or center.y > zone.y+zone.h: continue
		var faction: String = str(zone.get("faction","neutral"))
		var strength: float = 0.0 if faction == "neutral" else absf(float(host.p.faction.get(faction,0)))
		if strength > rank: rank = strength; best = str(zone.id)
	return best


func destinations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target: Dictionary in host.definition("src/dialogue/vendors_places.js","BUS_ZONE_TARGETS",[]):
		if target.get("flag") != null and not _flag(str(target.flag)): continue
		result.append(target.duplicate(true))
	return result


func bind_day_owner(owner: Object) -> void:
	_day_ref = weakref(owner) if owner != null else null

func _day_available() -> bool:
	var adapter: Object = _day_ref.get_ref() if _day_ref != null else null
	return adapter != null and adapter.has_method(&"advance_sleep_day")


func _options(service: String, page: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	match service:
		"pinky":
			if has_bus_pass(): options.append(_option("use_pass","use the bus pass."))
			else: options.append(_option("buy_pass","buy a bus pass. $20." if host.p.cash >= 20 else "a bus pass is $20.",host.p.cash >= 20,"insufficient_cash"))
		"mom":
			if host.p.faction.spiritual >= 10 and not _owned("mom"):
				options.append(_option("rent_couch","ask mom if you can stay over. ($30/night.)" if host.p.cash >= 30 else "ask mom if you can stay over. ($30 — short.)",host.p.cash >= 30,"insufficient_cash"))
		"biggu":
			options.append(_option("buy_cart","trade 5 PURE COPPER for the cart." if host.p.copper >= 5 else "you need 5 pure copper.",host.p.copper >= 5,"insufficient_copper"))
			options.append(_option("height","ask how tall."))
		"bus":
			if has_bus_pass() and host.s.flags.get("busPassUsedDay",0) != host.s.day:
				var targets: Array[Dictionary] = destinations()
				var current: String = _zone()
				var combat: bool = combat_active()
				var last_page: int = maxi(0,int(ceil(targets.size()/6.0))-1)
				page = clampi(page,0,last_page)
				for index: int in range(page*6,mini(page*6+6,targets.size())):
					var target: Dictionary = targets[index]
					var here: bool = current == target.zoneId
					var label: String = str(target.label) + " — the bus is not your friend right now." if combat else (str(target.label) + " — you're already where the bus is." if here else "take the bus to " + str(target.label) + ".")
					options.append(_option("ride:"+str(target.zoneId),label,not combat and not here,"combat_active" if combat else "already_here"))
				if page > 0: options.append(_option("page:%d" % (page-1),"previous destinations."))
				if page < last_page: options.append(_option("page:%d" % (page+1),"more destinations."))
		"hideout:mom", "hideout:scrap":
			var mom: bool = service == "hideout:mom"
			options.append(_option("chest","open the chest. (stash survives death.)"))
			options.append(_option("rest","rest 30 minutes. (+%d hp · -1 wanted)" % (12 if mom else 8)))
			options.append(_option("sleep","sleep until morning. advances a day.",host.s.dayTime <= 0.3 or _day_available(),"missing_day_adapter"))
			if mom: options.append(_option("phone","use the apartment phone. (skip the next ambient call.)"))
		"office:cot":
			var powered: bool = host.s.office.upgrades.get("generator",false) == true
			options.append(_option("rest","rest 30 minutes. (+%d hp%s · -1 wanted)" % [18 if powered else 10," · +5 brain" if powered else ""]))
			options.append(_option("sleep","sleep until morning. (+55 hp · +25 brain · +15 shakes)",host.s.dayTime <= 0.3 or _day_available(),"missing_day_adapter"))
		"chest:mom", "chest:scrap", "chest:office", "office:chest":
			var stash: Dictionary = host.s.hideoutStash
			options.append(_option("deposit:rocks","deposit 1 rock. (chest: %d)" % stash.rocks if host.p.rocks > 0 else "deposit a rock. (you have none.)",host.p.rocks > 0,"insufficient_rocks"))
			options.append(_option("withdraw:rocks","withdraw 1 rock. (chest: %d)" % stash.rocks if stash.rocks > 0 else "withdraw a rock. (chest empty.)",stash.rocks > 0,"stash_short"))
			options.append(_option("deposit:copper","deposit 1 copper. (chest: %d)" % stash.copper if host.p.copper > 0 else "deposit copper. (you have none.)",host.p.copper > 0,"insufficient_copper"))
			options.append(_option("withdraw:copper","withdraw 1 copper. (chest: %d)" % stash.copper if stash.copper > 0 else "withdraw copper. (chest empty.)",stash.copper > 0,"stash_short"))
			options.append(_option("deposit:cash","deposit $10. (chest: $%d)" % stash.cash if host.p.cash >= 10 else "deposit $10. (short.)",host.p.cash >= 10,"insufficient_cash"))
			options.append(_option("withdraw:cash","withdraw $10. (chest: $%d)" % stash.cash if stash.cash >= 10 else "withdraw $10. (chest short.)",stash.cash >= 10,"stash_short"))
	if service.begins_with("chest:") or service == "office:chest": options.append(_option("back","close the chest."))
	elif service == "office:cot": options.append(_option("back","back to the office."))
	else: options.append(_option("leave","put the pass away." if service == "bus" else "leave."))
	return options


func _text(service: String) -> Dictionary:
	match service:
		"pinky": return {"title":"PINKY POLENTA","text":"is paper. is the bus. is paper."}
		"mom": return {"title":"WHOLE FOODS MOM","text":"oh. oh sweetie.\nshe is wearing vibram five-fingers.\nshe is holding kombucha."}
		"biggu": return {"title":"THE BIG GUY","text":"i am the big guy.\nhe is, in fact, tall.\nhe lives under here."}
		"hideout:mom": return {"title":"MOM'S COUCH","text":"the apartment is warm.\nben is at work.\nthe couch is cleared.\nyou recognize this couch."}
		"hideout:scrap": return {"title":"THE SHED","text":"the shed smells like dust and old grease.\nthere is a chest in the corner.\nthere is a cot.\nthe door locks from the inside."}
		"office:cot": return {"title":"THE COT","text":"the cot is one inch shorter than you.\nthis has been entered as adequate."}
		"bus":
			if not has_bus_pass(): return {"title":"BUS STOP","text":"you do not have a bus pass.\nthe bus does not care that you tried."}
			if host.s.flags.get("busPassUsedDay",0) == host.s.day: return {"title":"BUS STOP","text":"you already rode today.\nthe bus does not run twice for you."}
			return {"title":"BUS STOP · PAGE %d/%d" % [_page+1,maxi(1,int(ceil(destinations().size()/6.0)))],"text":"you take the pass out of your pocket.\nthe pass smells like a wallet that wasn't yours.\nwhere are you going."}
	var stash: Dictionary = host.s.hideoutStash
	return {"title":"THE CHEST","text":"metal box. dented. heavy.\nin the chest:\n  rocks: %d\n  pure copper: %d\n  cash: $%d\n  items: %d" % [stash.rocks,stash.copper,stash.cash,stash.items.size()]}


func open(service: String, page: int = 0) -> Dictionary:
	close()
	var reason: String = _reason(service)
	if not reason.is_empty(): return _fail(reason)
	_page = clampi(page,0,maxi(0,int(ceil(destinations().size()/6.0))-1)) if service == "bus" else 0
	var options: Array[Dictionary] = _options(service,_page)
	var ids: Array[String] = []
	for option: Dictionary in options: ids.append(option.id)
	var opened: Dictionary = session.begin(_target(service),ids)
	if not opened.ok: return opened
	_service = service
	host.s.mode = "dialogue"
	var result: Dictionary = _text(service)
	result.merge({"ok":true,"service":service,"token":opened.token,"page":_page,"options":options})
	return result


func close() -> void:
	if session != null: session.close()
	_service = ""
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"


func select(token: Variant, action: String) -> Dictionary:
	var service: String = _service
	var page: int = _page
	var permitted: Dictionary = session.consume(token,action)
	if not permitted.ok:
		if permitted.reason != "stale_session": _service = ""
		return permitted
	_service = ""
	var reason: String = _reason(service)
	if not reason.is_empty(): return _fail(reason)
	var choice: Dictionary = {}
	for option: Dictionary in _options(service,page):
		if option.id == action: choice = option; break
	if choice.is_empty(): return _fail("action_unavailable")
	if not choice.enabled: return _fail(str(choice.reason))
	host.s.mode = "playing"
	if action == "leave": return {"ok":true}
	if action == "back":
		if service in ["chest:mom","chest:scrap"]: return open("hideout:"+service.trim_prefix("chest:"))
		host.emit_event("menu_requested",{"target":"office"})
		return {"ok":true,"navigation":"office"}
	if action == "use_pass": return open("bus")
	if action.begins_with("page:"): return open("bus",int(action.trim_prefix("page:")))
	if action == "chest": return open("chest:"+service.trim_prefix("hideout:"))
	if action.begins_with("ride:"): return _ride(action.trim_prefix("ride:"))
	if action.begins_with("deposit:") or action.begins_with("withdraw:"):
		var resource: String = action.get_slice(":",1)
		var amount: int = 10 if resource == "cash" else 1
		var direction: int = 1 if action.begins_with("deposit:") else -1
		host.p[resource] -= amount*direction
		host.s.hideoutStash[resource] += amount*direction
		var noun: String = "$10" if resource == "cash" else ("1 rock" if resource == "rocks" else "1 copper")
		_toast("- " + noun + " · → chest" if direction == 1 else "← chest · + " + noun,1400)
		_save()
		return open(service)
	match action:
		"buy_pass": return buy_pinky_pass()
		"rent_couch":
			host.p.cash -= 30; host.s.flags.momHideoutOwned = true; host.s.flags.momRentDay = host.s.day
			host.apply_rep({"spiritual":2})
			_toast("- $30\n'oh sweetie.\nthe couch is yours.\nben works late.'\n(the spare key is on the hook.)",4200)
			_feed("got a couch tonight. ben works late.","@crackheadcent"); _save()
		"buy_cart":
			host.p.copper -= 5; host.p.cartMounted = true; host.apply_equip_stats(); _emit_cart()
			_toast("- 5 pure copper\n+ THE BIG GUY'S CART\n+10 max hp. faster.\n(the wheels do not align.)"); _save()
		"height": _toast("tall.\nthat is the answer he gives. tall.")
		"rest":
			var office: bool = service == "office:cot"
			var powered: bool = office and host.s.office.upgrades.get("generator",false) == true
			var hp: int = (18 if powered else 10) if office else (12 if service == "hideout:mom" else 8)
			host.p.hp = minf(host.p.maxHp,host.p.hp+hp); host.p.wanted = maxf(0.0,host.p.wanted-1)
			if powered: host.p.brain = minf(100.0,host.p.brain+5)
			_toast("the generator clicks.\nthe cot files no complaint." if office else "you sit down.\nthe walls have nothing to say.\n+ %d hp · - 1 wanted" % hp,2400 if office else 2800); _save()
		"sleep": return _sleep(service)
		"phone":
			host.s.phoneT = 90000.0+host.random_float()*150000.0
			_toast("the phone goes back on the hook.\nben uses this phone.\nben is at work.",2400)
	return {"ok":true}


func _sleep(service: String) -> Dictionary:
	var office: bool = service == "office:cot"
	var mom: bool = service == "hideout:mom"
	var rolled: bool = float(host.s.dayTime) > 0.3
	if rolled:
		if not _day_available(): return _fail("missing_day_adapter")
		var result: Variant = _day_ref.get_ref().call(&"advance_sleep_day","office_sleep" if office else "hideout_sleep")
		if not result is bool or not result: return _fail("day_adapter_rejected")
	host.s.dayTime = 0.3
	var powered: bool = office and host.s.office.upgrades.get("generator",false) == true
	host.p.hp = minf(host.p.maxHp,host.p.hp+(55 if office else (60 if mom else 50)))
	host.p.brain = minf(100.0,host.p.brain+((30 if powered else 25) if office else (30 if mom else 25)))
	host.p.shakes = minf(100.0,host.p.shakes+15)
	host.p.wanted = maxf(0.0,host.p.wanted-2)
	if not office:
		if mom: host.apply_rep({"spiritual":1})
		else: host.apply_rep({"scrap":1})
	elif rolled and host.s.day >= 7: host.unlock_achievement("tuesday_again")
	_toast("you slept at the office.\nthe office opened before you did.\nthe day is the next day." if office else "you slept.\nyou are still here.\nthe day is the next day.",3200 if office else 3000)
	_save()
	return {"ok":true,"rolled_day":rolled}


func _exact_clear(point: Vector2) -> bool:
	var adapter: Object = _spatial_ref.get_ref() if _spatial_ref != null else null
	if adapter == null or not adapter.has_method(&"clear_placement"): return false
	var body := {"id":"player","x":point.x,"y":point.y,"w":host.p.w,"h":host.p.h}
	var result: Variant = adapter.call(&"clear_placement",body)
	return result is Vector2 and result.is_finite() and result.distance_squared_to(point) < 0.00000001


func _ride(id: String) -> Dictionary:
	var destination: Dictionary = {}
	for target: Dictionary in destinations():
		if target.zoneId == id: destination = target; break
	if destination.is_empty(): return _fail("unknown_destination")
	var bounds: Dictionary = host.content.world.bounds
	var point := Vector2(clampf(float(destination.x)-host.p.w*0.5,20.0,float(bounds.w)-20.0-host.p.w),clampf(float(destination.y)-host.p.h*0.5,20.0,float(bounds.h)-20.0-host.p.h))
	if not _exact_clear(point): return _fail("blocked_destination")
	var index: int = -1
	for offset: int in range(host.p.inventory.size()):
		if host.p.inventory[offset].id == "bus_pass": index = offset; break
	if index < 0: return _fail("missing_pass")
	var record: Dictionary = host.p.inventory[index].duplicate(true)
	if inventory.remove_first_record("bus_pass") != 1: return _fail("missing_pass")
	_pending = {"remaining":BUS_DELAY_MS,"p":host.p,"s":host.s,"destination":point,"zone":id,"record":record,"index":index,"stamp":host.s.day,"previous_stamp":host.s.flags.get("busPassUsedDay",0)}
	host.s.flags.busPassUsedDay = host.s.day
	host.emit_event("travel_fade",{"duration_ms":BUS_DELAY_MS,"phase":"departure"})
	return {"ok":true,"pending":true,"delay_ms":BUS_DELAY_MS}


func _same_pending_epoch() -> bool:
	return host != null and not _pending.is_empty() and is_same(host.p,_pending.p) and is_same(host.s,_pending.s)


func _cancel_ride(refund: bool) -> void:
	if refund and _same_pending_epoch():
		host.p.inventory.insert(mini(int(_pending.index),host.p.inventory.size()),_pending.record.duplicate(true))
		if host.s.flags.get("busPassUsedDay",0) == _pending.stamp: host.s.flags.busPassUsedDay = _pending.previous_stamp
		host.emit_event("travel_cancelled",{"reason":"blocked_destination"})
		_save()
	_pending.clear()


func cancel_travel(reason: String) -> void:
	# Runtime calls this synchronously on death/arrest, before the recovered HP hides that event.
	if reason not in ["death","arrest","fresh","restore"]: return
	_cancel_ride(reason in ["death","arrest"])
	close()


func tick_real(milliseconds: float) -> void:
	if not is_finite(milliseconds) or milliseconds <= 0.0 or milliseconds > 240000.0: return
	if not _pending.is_empty():
		if not _same_pending_epoch(): _cancel_ride(false)
		elif host.s.mode == "dead": _cancel_ride(true)
		else:
			_pending.remaining -= milliseconds
			if _pending.remaining <= 0.0:
				var point: Vector2 = _pending.destination
				if not _exact_clear(point): _cancel_ride(true)
				else:
					host.p.x = point.x; host.p.y = point.y
					host.s.territoryHeat = 0.0; host.s.territoryGreeted = []; host.s.territoryZoneId = null
					host.emit_event("placement_reset",{"source_position":host.player_center(),"reason":"bus"})
					host.emit_event("travel_fade",{"duration_ms":500.0,"phase":"arrival"})
					_toast("the bus took you.\nthe bus does not explain how.",3000); _save(); _pending.clear()
	for index: int in range(_notifications.size()-1,-1,-1):
		var notice: Dictionary = _notifications[index]
		if host == null or not is_same(host.s,notice.epoch): _notifications.remove_at(index); continue
		notice.remaining -= milliseconds
		if notice.remaining <= 0.0: _toast(notice.text,3200); _notifications.remove_at(index)


func on_natural_dawn() -> void:
	if host == null or int(_runtime().naturalDawnDay) == int(host.s.day): return
	_runtime().naturalDawnDay = int(host.s.day)
	if host.p.faction.spiritual >= 10 and host.s.flags.get("momBusPassDay",0) != host.s.day:
		host.s.flags.momBusPassDay = host.s.day
		if not has_bus_pass() and inventory.append_item("bus_pass","a bus pass"):
			_feed("mom left a bus pass on the door. mom does not say where it came from.","@hardcandy")
			_notifications.append({"remaining":6000.0,"epoch":host.s,"text":"+ a bus pass\nmom left it on the door.\nthe door does not lock."})
	if _owned("mom"):
		if host.p.cash >= 30:
			host.p.cash -= 30; host.s.flags.momRentDay = host.s.day
			_toast("- $30\nmom's couch costs.\nshe says it does not.\nit does.",3000)
		else:
			host.s.flags.momHideoutOwned = false; host.apply_rep({"spiritual":-3})
			_toast("ben put your bag in the hallway.\nthe spare key does not fit anymore.\n(mom's couch — closed.)",4000)
			_feed("got put out. ben works late, ben changed the locks.","@crackheadcent")


func interact_cart() -> Dictionary:
	if host == null: return _fail("missing_owner")
	if host.s.mode != "playing" or not _pending.is_empty(): return _fail("wrong_mode")
	if host.s.get("bossKind","") == "kingdom": return _fail("active_boss")
	if _cart_id.is_empty(): return _fail("missing_cart")
	if host.p.cartMounted:
		var adapter: Object = _spatial_ref.get_ref() if _spatial_ref != null else null
		if adapter == null or not adapter.has_method(&"find_cart_drop"): return _fail("missing_cart_adapter")
		var preferred := Vector2(float(host.p.x)+4.0,float(host.p.y)+8.0)
		var player_epoch: Dictionary = host.p; var state_epoch: Dictionary = host.s
		var drop: Variant = adapter.call(&"find_cart_drop",preferred,MAX_DROP_PX)
		if host == null or not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return _fail("stale_epoch")
		if not drop is Vector2 or not drop.is_finite() or drop.distance_squared_to(preferred) > MAX_DROP_PX*MAX_DROP_PX: return _fail("blocked_cart_drop")
		var bounds: Dictionary = host.content.world.bounds
		if drop.x < 0 or drop.y < 0 or drop.x+24.0 > bounds.w or drop.y+20.0 > bounds.h: return _fail("blocked_cart_drop")
		var player_rect := Rect2(float(host.p.x),float(host.p.y),float(host.p.w),float(host.p.h))
		if player_rect.intersects(Rect2(drop,Vector2(24,20))): return _fail("blocked_cart_drop")
		_runtime().cart.x = drop.x; _runtime().cart.y = drop.y
		host.p.cartMounted = false; host.apply_equip_stats(); _emit_cart()
		_toast("you abandon the cart.\nit rolls slightly. accuses you.",1800)
		return {"ok":true,"mounted":false,"source_drop":drop,"preferred_source_drop":preferred}
	var cart: Dictionary = _runtime().cart
	if host.player_center().distance_squared_to(Vector2(cart.x,cart.y)) >= 36.0*36.0: return _fail("out_of_reach")
	var reach: Dictionary = session.probe(_cart_id)
	if not reach.ok: return reach
	host.p.cartMounted = true; host.apply_equip_stats(); host.unlock_achievement("cart_baron"); _emit_cart()
	_toast("+ shopping cart\n+1 speed. you can hit people now.",2200)
	return {"ok":true,"mounted":true}


func _emit_cart() -> void:
	host.emit_event("cart_changed",{"mounted":host.p.cartMounted,"cart":cart_record(),"target_id":_cart_id})


func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _save() -> void: host.emit_event("save_requested")
func _toast(text: String, duration_ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":duration_ms})
func _feed(text: String, author: String) -> void: host.emit_event("feed",{"text":text,"author":author})
