class_name RockBottomProgression
extends RefCounted
## Source-faithful progression. GameState owns all resources and random draws.
const Content = preload("res://scripts/content_catalog.gd")
const MODULE := "src/systems/progression_routes.js"
const FACTIONS := "src/systems/factions.js"
const TARGETS := {"rocks_3":3,"copper_4":4,"pawn_2":2,"pan_5":1,"church_2":5,"fight_2":2,"dump_3":3,"possum_1":1,"tony_2":2,"sleep_1":1,"eat_taco":1,"cook_2":2,"fence_3":3,"laundry_1":1}
const LIFETIME_KEYS := ["rocksSmoked","rocksCooked","rocksFenced"]
const COUNTER_KEYS := ["copperStripped","peteSold","churchDonations","alleyKills","dumpDives","possumProphecies","rocksBought","slept","tacosEaten","laundryDone"]
var _host_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref()
var stops: Array = []
var stop_by_id: Dictionary = {}
var hustles: Array = []
var hustle_by_id: Dictionary = {}

func _init(owner: RefCounted) -> void:
	_host_ref = weakref(owner)
	stops = Content.definition(MODULE,"ROUTE_STOPS",[])
	hustles = Content.definition(MODULE,"HUSTLE_TEMPLATES",[])
	for stop: Dictionary in stops: stop_by_id[stop.id] = stop
	for job: Dictionary in hustles: hustle_by_id[job.id] = job
	host.register_state_normalizer("blockRoute", normalize_route)
	host.register_state_normalizer("hustles", normalize_hustles)

func _int(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value)

func valid_route(raw: Variant) -> bool:
	if not raw is Dictionary or not raw.get("stops") is Array or raw.stops.size() != 3: return false
	var seen: Array = []
	for id: Variant in raw.stops:
		if not id is String or not stop_by_id.has(id) or seen.has(id): return false
		seen.append(id)
	return _int(raw.get("cursor")) and raw.cursor >= 0 and raw.cursor <= 3 and _int(raw.get("serial")) and raw.serial >= 1 and raw.get("lastStopId") is String and (raw.lastStopId == "" or stop_by_id.has(raw.lastStopId))

func normalize_route(raw: Variant) -> Variant:
	if not valid_route(raw): return null
	return {"stops":raw.stops.duplicate(),"cursor":int(raw.cursor),"serial":mini(1000000000,int(raw.serial)),"lastStopId":raw.lastStopId}

func normalize_hustles(raw: Variant) -> Array:
	var result: Array = []
	var seen: Array = []
	if not raw is Array: return result
	for item: Variant in raw:
		if result.size() >= 3: break
		if not item is Dictionary or not item.get("id") is String or not hustle_by_id.has(item.id) or seen.has(item.id): continue
		var definition: Dictionary = hustle_by_id[item.id]
		result.append({"id":item.id,"desc":definition.desc,"reward":definition.reward.duplicate(true),"done":item.get("done",false) == true})
		seen.append(item.id)
	return result

func _live(id: String) -> bool:
	for actor: Dictionary in host.npcs:
		if actor.get("id") == id and actor.get("dead",false) != true: return true
	return false

func _eligible(id: String) -> bool:
	match id:
		"fight_2": return int(_live("lurch")) + int(_live("sherri")) + int(_live("paulie")) >= 2
		"church_2": return _live("priest") and not host.s.flags.get("omalleyFallen",false)
		"pawn_2": return _live("pete")
		"tony_2": return _live("tony")
		"fence_3": return _live("stripe") and not host.s.flags.get("stripeBetrayed",false)
		"possum_1": return _live("possum")
	return true

func _shuffle(pool: Array) -> void:
	for i: int in range(pool.size() - 1,0,-1):
		var j: int = host.random_index(i+1)
		var previous: Variant = pool[i]
		pool[i] = pool[j]; pool[j] = previous

func roll_hustles() -> void:
	if not host.s.flags.get("introDone",false):
		host.s.hustles = []
		return
	var pool: Array = []
	for job: Dictionary in hustles:
		if _eligible(job.id): pool.append(job)
	_shuffle(pool)
	var snapshot: Dictionary = {"bigPan":0}
	for key: String in LIFETIME_KEYS: snapshot[key] = host.p.lifetime.get(key,0)
	for key: String in COUNTER_KEYS: snapshot[key] = host.s.counters.get(key,0)
	host.s.hustleSnapshot = snapshot
	host.s.counters.bigPan = 0
	var chosen: Array = []
	for job: Dictionary in pool.slice(0,3):
		chosen.append({"id":job.id,"desc":job.desc,"reward":job.reward.duplicate(true),"done":false})
	host.s.hustles = chosen
	if int(host.s.day) > 1:
		_toast("· new hustles posted ·\n(Q to view)")
		host.emit_event("news",{"text":"today's hustles posted in the back alley. (press Q to see them.)"})

func _progress(id: String) -> int:
	if not hustle_by_id.has(id): return 0
	var key: String = hustle_by_id[id].key
	if id == "pan_5": return int(host.s.counters.get("bigPan",0))
	var current: int = int(host.p.lifetime.get(key,0)) if key in LIFETIME_KEYS else int(host.s.counters.get(key,0))
	return current - int(host.s.hustleSnapshot.get(key,0))

func hustle_progress(job: Dictionary) -> String:
	var id: String = str(job.get("id",""))
	if not TARGETS.has(id): return ""
	var progress: int = _progress(id)
	var target: int = TARGETS[id]
	if id == "church_2":
		progress = int(floor(float(progress)/5.0)); target = 1
	return "%d/%d" % [clampi(progress,0,target),target]

func check_hustles() -> int:
	var paid: int = 0
	for job: Dictionary in host.s.hustles:
		var id: String = str(job.get("id",""))
		if job.get("done",false) == true or not TARGETS.has(id) or _progress(id) < int(TARGETS[id]): continue
		job.done = true
		var reward: Dictionary = hustle_by_id[id].reward
		host.p.cash += int(reward.get("cash",0)); host.p.cred += int(reward.get("cred",0))
		host.p.brain = minf(100.0,float(host.p.brain)+float(reward.get("brain",0)))
		var receipt: Array[String] = []
		for key: String in reward:
			receipt.append("+ $%d" % reward[key] if key == "cash" else "+ %d %s" % [reward[key],key])
		_toast("· HUSTLE DONE ·\n%s\n%s" % [hustle_by_id[id].desc," · ".join(receipt)])
		_feed("knocked out today's hustle: " + str(hustle_by_id[id].desc),"@crackheadcent")
		host.emit_event("audio",{"id":"rankUp"}); host.emit_event("save_requested")
		paid += 1
	return paid

static func route_leg_budget() -> float:
	return 0.60 * ((100.0-20.0)/0.0008) * (2.2/16.0)

func current_stop() -> Dictionary:
	var route: Variant = host.s.get("blockRoute")
	if not valid_route(route) or int(route.cursor) >= 3: return {}
	return stop_by_id[route.stops[int(route.cursor)]]

func patch_tier() -> int:
	return mini(4,int(floor(float(host.p.lifetime.get("routesCompleted",0))/5.0)))

func roll_route(silent: bool = false, forced_last: String = "") -> Variant:
	if not host.s.flags.get("introDone",false):
		host.s.blockRoute = null
		return null
	var previous: Dictionary = host.s.blockRoute if valid_route(host.s.get("blockRoute")) else {}
	var completed: int = int(host.p.lifetime.get("routesCompleted",0))
	var pool: Array = []
	for stop: Dictionary in stops:
		if completed < 2 and not (stop.x < 2100 and stop.y < 2100): continue
		if stop.has("unlockFlag") and not host.s.flags.get(stop.unlockFlag,false): continue
		pool.append(stop)
	var last: String = forced_last if not forced_last.is_empty() else str(previous.get("lastStopId",""))
	if pool.size() > 3 and not last.is_empty(): pool = pool.filter(func(stop: Dictionary) -> bool: return stop.id != last)
	_shuffle(pool)
	var selected: Array = []
	if not pool.is_empty(): selected.append(pool.pop_front())
	while selected.size() < 3 and not pool.is_empty():
		var previous_stop: Dictionary = selected[-1]
		var origin := Vector2(previous_stop.x,previous_stop.y)
		var pick: int = -1
		var nearest: int = 0
		var best_distance: float = INF
		for i: int in range(pool.size()):
			var distance: float = origin.distance_to(Vector2(pool[i].x,pool[i].y))
			if distance <= route_leg_budget():
				pick = i; break
			if distance < best_distance: best_distance = distance; nearest = i
		if pick < 0: pick = nearest
		selected.append(pool[pick]); pool.remove_at(pick)
	var ids: Array = []
	for stop: Dictionary in selected: ids.append(stop.id)
	host.s.blockRoute = {"stops":ids,"cursor":0,"serial":int(previous.get("serial",0))+1,"lastStopId":last}
	if not silent: _toast("· BLOCK ROUTE %d ·\nthree boxes. one pen. the pen works." % host.s.blockRoute.serial)
	return host.s.blockRoute

func ensure_route() -> void:
	if not host.s.flags.get("introDone",false): host.s.blockRoute = null
	elif not valid_route(host.s.get("blockRoute")) or int(host.s.blockRoute.cursor) >= 3: roll_route(true)

func active_office_contract() -> bool:
	var office: Variant = host.s.get("office")
	return office is Dictionary and (office.get("claimJob") != null or office.get("workJob") != null)

func stamp_route(context: Dictionary = {}) -> bool:
	if host.s.get("mode") != "playing" or context.get("hidden",false) == true or context.get("reachable",true) == false or float(host.p.stunT) > 0 or host.s.get("bossActive",false) == true or host.s.get("brutusOlderActive",false) == true or active_office_contract(): return false
	var stop: Dictionary = current_stop()
	if stop.is_empty() or host.player_center().distance_squared_to(Vector2(stop.x,stop.y)) >= 58.0*58.0: return false
	host.s.blockRoute.cursor += 1
	if int(host.s.blockRoute.cursor) < 3:
		host.emit_event("audio",{"id":"coin"})
		_toast("%s\n[%d/3 stamped]" % [stop.stamp,host.s.blockRoute.cursor])
		host.emit_event("save_requested")
		return true
	host.p.lifetime.routesCompleted = int(host.p.lifetime.get("routesCompleted",0))+1
	var total: int = host.p.lifetime.routesCompleted
	var office_unlocked: bool = maybe_unlock_office(false)
	var cash: int = mini(24,6+int(floor(float(total)/5.0))*2)
	var cred: int = mini(4,1+int(floor(float(total)/20.0)))
	host.p.cash += cash; host.p.cred += cred
	var achievement: String = {5:"route_five",20:"route_twenty",50:"route_fifty"}.get(total,"")
	# Achievement emits a deferred request; persistence snapshots after this synchronous command.
	if not achievement.is_empty(): host.unlock_achievement(achievement)
	roll_route(true,stop.id)
	host.emit_event("audio",{"id":"rankUp"})
	_toast("%s\n· ROUTE FILED %d ·  + $%d · + %d cred\na new sheet is under the brick.%s" % [stop.stamp,total,cash,cred,"\nthe leasing guy has a key in the lot." if office_unlocked else ""])
	_feed("filed block route %d. the clipboard did not say good job." % total,"@crackheadcent")
	host.emit_event("save_requested")
	return true

func maybe_unlock_office(persist: bool = true) -> bool:
	if not host.s.flags.get("introDone",false) or host.s.office.get("owned",false): return false
	var quest: Dictionary = host.s.quests.get("office_space",{})
	if quest.is_empty() or quest.get("done",false) or int(host.p.lifetime.get("routesCompleted",0)) < 3: return false
	if quest.get("available") != false: return false
	quest.available = true
	_toast("· NEW BAD IDEA ·\nthe leasing guy has a unit.\nwalk-ins are somehow accepted.")
	_feed("three routes filed. a leasing guy has noticed.","@crackheadcent")
	if persist: host.emit_event("save_requested")
	return true

func update_ranks() -> int:
	var ranks: Array = Content.load_content().catalogs.ranks
	var count: int = 0
	while int(host.p.rank) < ranks.size()-1 and int(host.p.cred) >= int(ranks[int(host.p.rank)+1].cred):
		host.p.rank += 1; count += 1
		var title: String = ranks[int(host.p.rank)].name
		host.emit_event("audio",{"id":"rankUp"})
		_toast("· RANK UP ·\n" + title.to_upper())
		_feed("promoted to %s. the corner watches." % title,"@the_corner")
		host.emit_event("news",{"text":"%s has been promoted. the streets react with mild interest." % title.to_upper()})
		if int(host.p.rank) >= 5: host.unlock_achievement("glass_mayor")
	return count

func current_zone() -> Dictionary:
	var center: Vector2 = host.player_center()
	var best: Dictionary = {}
	var best_rank: int = -1
	for zone: Dictionary in Content.load_content().world.zones:
		if center.x < zone.x or center.x > zone.x+zone.w or center.y < zone.y or center.y > zone.y+zone.h: continue
		var faction: String = zone.get("faction","neutral")
		var rank: int = 0 if faction == "neutral" else absi(int(host.p.faction.get(faction,0)))
		if rank > best_rank: best_rank = rank; best = zone
	return best

func tick_territory(delta_ms: float, monotonic_ms: float) -> void:
	if host.s.get("mode") != "playing" or not is_finite(delta_ms) or delta_ms <= 0 or delta_ms > 240000 or not is_finite(monotonic_ms): return
	host.s.territoryT = float(host.s.get("territoryT",0))+delta_ms
	if float(host.s.territoryT) < 2000: return
	host.s.territoryT = 0.0
	var zone: Dictionary = current_zone()
	var faction: String = zone.get("faction","neutral")
	var id: Variant = zone.get("id")
	if host.s.get("territoryZoneId") != id:
		host.s.territoryHeat = 0; host.s.territoryGreeted = []; host.s.territoryZoneId = id
	if zone.is_empty() or faction == "neutral":
		host.s.territoryHeat = 0; host.s.territoryCashMult = 1.0
		return
	var tier: String = host.faction_tier(int(host.p.faction.get(faction,0)))
	if tier == "hated":
		host.s.territoryHeat = int(host.s.get("territoryHeat",0))+1
		host.s.territoryCashMult = 1.0
		if int(host.s.territoryHeat) % 15 == 7: _ambient("TERRITORY_HATED_LINES",faction,false)
		if int(host.s.territoryHeat) >= 30:
			host.s.territoryHeat = 0
			if int(host.p.wanted) < 3:
				host.p.wanted += 1; host.p.wantedT = 0.0
				_toast("a phone call was made.\nwanted +1")
		return
	if tier == "neutral":
		host.s.territoryHeat = 0; host.s.territoryCashMult = 1.0
		return
	host.s.territoryCashMult = 1.4 if tier == "loved" else 1.2
	if tier == "loved":
		host.s.territoryBrainTicks = int(host.s.get("territoryBrainTicks",0))+1
		if int(host.s.territoryBrainTicks) >= 5:
			host.s.territoryBrainTicks = 0; host.p.brain = minf(100.0,float(host.p.brain)+1.0)
		var key: String = "lovedAmbient_" + faction + "_day"
		if host.s.flags.get(key) != host.s.day:
			host.s.flags[key] = host.s.day; _ambient("TERRITORY_LOVED_LINES",faction,true)
	var targets: Array = Content.definition(FACTIONS,"TERRITORY_NPC_TARGETS",[])
	if not host.s.get("territoryGreetLast") is Dictionary: host.s.territoryGreetLast = {}
	if not host.s.get("territoryGreeted") is Array: host.s.territoryGreeted = []
	for actor: Dictionary in host.npcs:
		if actor.get("dead",false) == true or not targets.has(actor.get("id")): continue
		var center := Vector2(float(actor.x)+float(actor.w)*0.5,float(actor.y)+float(actor.h)*0.5)
		if host.player_center().distance_squared_to(center) > 80.0*80.0: continue
		if tier == "liked":
			if host.s.territoryGreeted.has(actor.id): continue
			host.s.territoryGreeted.append(actor.id)
		else:
			if monotonic_ms-float(host.s.territoryGreetLast.get(actor.id,0)) < 10000: continue
			host.s.territoryGreetLast[actor.id] = monotonic_ms
		var pool: Array = Content.definition(FACTIONS,"TERRITORY_GREETINGS",{}).get(faction,[])
		if not pool.is_empty(): _toast(pool[host.random_index(pool.size())])
		break

func _ambient(table: String, faction: String, with_toast: bool) -> void:
	var lines: Array = Content.definition(FACTIONS,table,{}).get(faction,[])
	if lines.is_empty(): return
	var colon: int = str(lines[0]).find(": ")
	_feed(str(lines[0]).substr(colon+2) if colon >= 0 else lines[0],str(lines[0]).substr(0,colon) if colon >= 0 else lines[0])
	if with_toast and lines.size() > 1: _toast(lines[1])

func _toast(text: String) -> void: host.emit_event("toast",{"text":text})
func _feed(text: String, author: String) -> void: host.emit_event("feed",{"text":text,"author":author})
