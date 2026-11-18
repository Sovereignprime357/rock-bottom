class_name RockBottomMemoryLoop
extends RefCounted
## One smoke transaction and the neighborhood's memory. All durable values live in GameState.
## Source: recognition.js / concessions.js / discovery.js / hitter.js. Timers are milliseconds.

const Content = preload("res://scripts/content_catalog.gd")
const VENUES := ["park", "laundromat", "underpass", "choir_office"]
const VERBS := ["sit", "bother", "buy", "sell", "full_high"]
const COUNTER_CAP := 1000000
const CLOCK_SEED := 0x0bf1a75
const TEXT := {
	"park": {"hint":"consult the bench", "condition":"night only", "keeper":"the bench does not know you yet.", "refusal":"the philosopher opens one eye.\nthe arrangement is off."},
	"choir_office": {"hint":"consult the office", "condition":"office hours · b flat to b flat", "keeper":"the office does not know you yet.", "refusal":"b flat ends.\nthe office is closed."},
	"underpass": {"hint":"consult the bridge", "condition":"while the dog is present", "keeper":"the bridge does not know you yet.", "refusal":"the dog has left.\nthe arrangement left with it."},
	"laundromat": {"hint":"consult the dryer", "condition":"mid-cycle only", "keeper":"the dryer does not know you yet.", "refusal":"the dryer finished.\nthe cover is gone."},
}
var _host_ref: WeakRef
var host: RefCounted:
	get:
		return _host_ref.get_ref() if _host_ref != null else null
var venues: Array = []
var spots: Array = []
var reactions: Dictionary = {}


func _init(state_owner: RefCounted) -> void:
	# GameState owns the boundary callback; a weak back-reference avoids a retain cycle.
	_host_ref = weakref(state_owner)
	venues = Content.definition("src/systems/recognition.js", "REGULAR_VENUES", [])
	spots = Content.definition("src/systems/concessions.js", "SMOKE_SPOTS", [])
	reactions = Content.definition("src/systems/recognition.js", "RECOGNITION_REACTIONS", {})
	host.on_high_expired = _high_expired
	host.register_state_normalizer("recognition", normalize_recognition)
	host.register_state_normalizer("concessionClocks", normalize_clocks)
	host.register_state_normalizer("discoveredVenues", normalize_discovered)
	normalize_state()


static func _natural(value: Variant, cap: int = COUNTER_CAP) -> int:
	if not (value is int or value is float) or not is_finite(float(value)): return 0
	return int(clampf(floor(float(value)), 0.0, float(cap)))


static func normalize_recognition(raw: Variant) -> Dictionary:
	var ledger: Dictionary = {}
	for venue: String in VENUES:
		ledger[venue] = {}
		var source: Dictionary = raw.get(venue, {}) if raw is Dictionary and raw.get(venue) is Dictionary else {}
		for verb: String in VERBS: ledger[venue][verb] = _natural(source.get(verb))
	return ledger


static func normalize_discovered(raw: Variant) -> Array:
	var result: Array = []
	if raw is Array:
		for id: Variant in raw:
			if id is String and id in VENUES and not result.has(id): result.append(id)
	return result


static func _clock_random(clocks: Dictionary) -> float:
	clocks.seed = (int(clocks.seed) * 1664525 + 1013904223) & 0xffffffff
	return float(clocks.seed) / 4294967296.0


static func _closed_time(clocks: Dictionary) -> float:
	return 90000.0 + floor(_clock_random(clocks) * 60000.0)


static func _idle_time(clocks: Dictionary) -> float:
	return 50000.0 + floor(_clock_random(clocks) * 40000.0)


static func fresh_clocks() -> Dictionary:
	var clocks: Dictionary = {"seed": CLOCK_SEED}
	clocks.choir = {"phase":"closed", "t":_closed_time(clocks)}
	clocks.dryer = {"phase":"idle", "t":_idle_time(clocks)}
	return clocks


static func normalize_clocks(raw: Variant) -> Dictionary:
	var clocks: Dictionary = fresh_clocks()
	if not raw is Dictionary: return clocks
	var raw_seed: Variant = raw.get("seed")
	if (raw_seed is int or raw_seed is float) and is_finite(float(raw_seed)):
		clocks.seed = int(fmod(float(raw_seed), 4294967296.0)) & 0xffffffff
	for id: String in ["choir", "dryer"]:
		var item: Variant = raw.get(id)
		if not item is Dictionary: continue
		var valid_phases: Array = ["closed", "open"] if id == "choir" else ["idle", "running"]
		var value: Variant = item.get("t")
		if item.get("phase") not in valid_phases or not (value is int or value is float): continue
		if not is_finite(float(value)) or float(value) <= 0.0: continue
		var cap: float = (55000.0 if item.phase == "open" else 150000.0) if id == "choir" else (70000.0 if item.phase == "running" else 90000.0)
		clocks[id] = {"phase":item.phase, "t":minf(cap, floor(float(value)))}
	return clocks


func normalize_state() -> void:
	host.s.recognition = normalize_recognition(host.s.get("recognition"))
	host.s.recognitionVisit = {"venue":"", "seen":{}}
	host.s.discoveredVenues = normalize_discovered(host.s.get("discoveredVenues", []))
	host.s.concessionClocks = normalize_clocks(host.s.get("concessionClocks"))


static func total(counters: Variant) -> int:
	if not counters is Dictionary: return 0
	var count: int = 0
	for verb: String in VERBS: count += _natural(counters.get(verb))
	return count


static func tier(counters: Variant) -> String:
	var count: int = total(counters) if counters is Dictionary else _natural(counters)
	if count >= 15: return "conceded"
	if count >= 8: return "furniture"
	if count >= 3: return "counted"
	return "stranger"


func player_center() -> Vector2:
	return Vector2(float(host.p.x) + float(host.p.w) * 0.5, float(host.p.y) + float(host.p.h) * 0.5)


func _zone_contains(id: String, point: Vector2) -> bool:
	var zones: Array = Content.load_content().get("world", {}).get("zones", [])
	for zone: Dictionary in zones:
		if zone.id == id:
			return point.x >= zone.x and point.x <= zone.x + zone.w and point.y >= zone.y and point.y <= zone.y + zone.h
	return false


func venue_at(point: Vector2) -> String:
	for venue: Dictionary in venues:
		if _zone_contains(venue.zoneId, point): return venue.id
	return ""


func sync_visit() -> String:
	var current: String = venue_at(player_center())
	var visit: Variant = host.s.get("recognitionVisit")
	if not visit is Dictionary or visit.get("venue") != current:
		host.s.recognitionVisit = {"venue":current, "seen":{}}
	return current


func _counted_venues() -> int:
	var count: int = 0
	for id: String in VENUES:
		if total(host.s.recognition[id]) >= 3: count += 1
	return count


func record(venue: String, verb: String, witness: String = "", defer_ms: int = 0) -> Dictionary:
	if venue not in VENUES or verb not in VERBS: return {"credited":false, "tier":"stranger"}
	if sync_visit() != venue: return {"credited":false, "tier":tier(host.s.recognition[venue])}
	if verb in ["sit", "bother"]:
		var key: String = verb + ":" + (witness if not witness.is_empty() else verb)
		if host.s.recognitionVisit.seen.has(key): return {"credited":false, "tier":tier(host.s.recognition[venue])}
		host.s.recognitionVisit.seen[key] = true
	var lane: Dictionary = host.s.recognition[venue]
	var before: String = tier(lane)
	var counted: int = _counted_venues()
	var old: int = int(lane[verb])
	lane[verb] = mini(COUNTER_CAP, old + 1)
	if int(lane[verb]) == old: return {"credited":false, "tier":before}
	var after: String = tier(lane)
	if after != before:
		var beat: Dictionary = reactions.get(venue, {}).get(after, {})
		var lines: Array = beat.get("lines", [])
		var label: String = venue
		for row: Dictionary in venues:
			if row.id == venue: label = row.label
		host.emit_event("toast", {"text":"· THE REGULAR ·\n%s · %s\n%s" % [label, after.to_upper(), "\n".join(lines)], "defer_ms":maxi(0,defer_ms), "duration_ms":3600})
		host.emit_event("feed", {"text":" ".join(lines), "author":"@blocklog"})
		if counted == 0 and _counted_venues() > 0:
			host.emit_event("feed", {"text":"he is still here. that is the whole post.", "author":"@blocklog"})
	host.emit_event("save_requested")
	return {"credited":true, "tier":after, "tierChanged":after != before, "total":total(lane)}


func bother(npc_id: String) -> Dictionary:
	for venue: Dictionary in venues:
		if npc_id in venue.botherIds: return record(venue.id, "bother", npc_id)
	return {"credited":false, "tier":"stranger"}


func discovered(venue: String) -> bool:
	return venue in host.s.discoveredVenues


func discover(venue: String) -> String:
	if venue not in VENUES: return ""
	if discovered(venue): return "known"
	host.s.discoveredVenues.append(venue)
	host.emit_event("save_requested")
	return "revealed"


func tell(venue: String, reveal_text: String, repeat_text: String, feed_line: String) -> String:
	var result: String = discover(venue)
	if result.is_empty(): return result
	var text: String = repeat_text if result == "known" else reveal_text
	if result == "revealed" and unlocked(venue): text += "\nyou already know.\nthe room knows you know."
	host.emit_event("toast", {"text":text})
	if result == "revealed" and not feed_line.is_empty(): host.emit_event("feed", {"text":feed_line, "author":"@crackheadcent"})
	return result


func unlocked(venue: String) -> bool:
	return venue in VENUES and tier(host.s.recognition[venue]) == "conceded"


func condition(venue: String) -> bool:
	var clocks: Dictionary = host.s.concessionClocks
	match venue:
		"park": return float(host.s.dayTime) < 0.25 or float(host.s.dayTime) > 0.75
		"choir_office": return clocks.choir.phase == "open"
		"laundromat": return clocks.dryer.phase == "running" and float(clocks.dryer.t) >= 15000.0 and float(clocks.dryer.t) <= 55000.0
		"underpass":
			if float(host.s.get("freedDogFollowT", 0.0)) <= 0.0: return false
			for actor: Dictionary in host.npcs:
				if actor.id == "freed_dog_follower" and not actor.get("dead", false): return true
	return false


func available(venue: String) -> bool:
	return unlocked(venue) and condition(venue)


func tick(dt_ms: float) -> void:
	if not is_finite(dt_ms) or dt_ms <= 0.0 or dt_ms > 240000.0: return
	sync_visit()
	var clocks: Dictionary = host.s.concessionClocks
	for id: String in ["choir", "dryer"]:
		var item: Dictionary = clocks[id]
		item.t = float(item.t) - dt_ms
		while float(item.t) <= 0.0:
			var venue: String = "choir_office" if id == "choir" else "laundromat"
			var line: String
			if id == "choir":
				item.phase = "closed" if item.phase == "open" else "open"
				item.t += 55000.0 if item.phase == "open" else _closed_time(clocks)
				line = "b flat begins.\nthe office is open." if item.phase == "open" else "b flat ends.\nthe office is closed."
			else:
				item.phase = "idle" if item.phase == "running" else "running"
				item.t += 70000.0 if item.phase == "running" else _idle_time(clocks)
				line = "the dryer starts.\nprofessional courtesy resumes." if item.phase == "running" else "the dryer stops.\nthe laundromat is just a room again."
			if unlocked(venue) and venue_at(player_center()) == venue:
				host.emit_event("toast", {"text":line})


func nearest_legal(point: Vector2, legal: Array) -> Dictionary:
	var best: Dictionary = {}
	var block: Dictionary = {}
	var best_distance: float = INF
	var tied: bool = false
	for spot: Dictionary in spots:
		if spot.id == "block": block = spot
		elif spot.id not in legal: continue
		var distance: float = point.distance_squared_to(Vector2(spot.x, spot.y))
		if distance < best_distance:
			best = spot
			best_distance = distance
			tied = false
		elif distance == best_distance: tied = true
	return block if tied or best.is_empty() else best


func bad_idea_spot(point: Vector2) -> Dictionary:
	var legal: Array = []
	for id: String in VENUES:
		if available(id): legal.append(id)
	return nearest_legal(point, legal)


func _reject(text: String) -> Dictionary:
	host.emit_event("toast", {"text":text})
	return {"ok":false, "text":text}


func _accept(text: String, sound: String, gesture: String) -> Dictionary:
	host.emit_event("toast", {"text":text})
	host.emit_event("sound", {"id":sound})
	host.emit_event("gesture", {"action":gesture})
	host.emit_event("save_requested")
	return {"ok":true, "text":text, "event":sound}


func smoke(spot_id: String) -> Dictionary:
	var spot: Dictionary = {}
	for item: Dictionary in spots:
		if item.id == spot_id: spot = item
	if spot.is_empty(): return _reject("there is no arrangement here.")
	if spot_id == "block":
		if not _zone_contains("block", player_center()): return _reject("the crate is elsewhere.")
	elif not available(spot_id) or venue_at(player_center()) != spot_id:
		return _reject(TEXT[spot_id].refusal)
	if float(host.p.rockedT) > 0.0: return _reject("the sun is already moving.")
	if int(host.p.rocks) + int(host.p.soapRocks) <= 0: return _reject("you have no rocks.")
	if int(host.p.soapRocks) > 0:
		host.p.soapRocks -= 1
		host.p.lifetime.rocksSmoked += 1
		host.emit_event("sound", {"id":"glassBreak"})
		host.unlock_achievement("soap_tongue")
		host.complete_intro_smoke()
		host.emit_event("feed", {"text":"smoked soap. tasted it. did it again.", "author":"@crackheadcent"})
		return _accept("you smoke it. it's soap.\nyou knew. you smoked it anyway.", "hurt", "smoke")
	host.p.rocks -= 1
	host.p.hitterHigh = false
	host.p.rockedT = 18000.0
	host.p.crashT = 0.0
	host.p.shakes = maxf(0.0, float(host.p.shakes) - 50.0)
	host.p.brain = maxf(0.0, float(host.p.brain) - 4.0)
	host.p.cred += 1
	host.p.lifetime.rocksSmoked += 1
	host.emit_event("flash", {"rgba":[232,192,64,0.5], "strength":1.0})
	var royal: bool = spot_id == "block" and host.s.kingdom.get("stage") == "anoint"
	if royal:
		host.s.kingdom.stage = "emperor_gate"
		host.s.kingdom.marks = 0
		host.emit_event("kingdom_changed")
		host.emit_event("news", {"text":"ROYAL STATIC RECEIVED. ONE DITCH ACKNOWLEDGES THE SIGNAL."})
		host.emit_event("feed", {"text":"the rock had a crown in the reception. the ditch is calling.", "author":"@blocklog"})
	host.apply_rep({"street":1, "spiritual":-1})
	host.complete_intro_smoke()
	host.emit_event("feed", {"text":"smoked a rock at " + str(spot.feedName) + ". for the bit.", "author":"@crackheadcent"})
	return _accept("· ROYAL STATIC ·\nthe sun moves. the throne ditch answers.\nbrain -4. shakes -50. emperor available." if royal else "· smoke a rock ·\nthe sun moves.\nbrain -4. shakes -50.", "rockUp", "smoke")


func dumpster_hitter_roll(far_factor: float) -> bool:
	return is_finite(far_factor) and far_factor > 0.25 and host.random_float() < 0.04


func grant_found_hitter() -> Dictionary:
	# Internal loot outcome; the dumpster session owns take-once validation.
	host.p.hitters += 1
	host.emit_event("feed", {"text":"found a pipe in a dumpster. still warm. asked nothing.", "author":"@crackheadcent"})
	return _accept("+ the emergency hitter\n(it is still warm. you do not ask.)", "pickup", "pickup")


func craft_hitter() -> Dictionary:
	if int(host.p.copper) < 2: return _reject("you need 2 pure copper.")
	host.p.copper -= 2
	host.p.hitters += 1
	return _accept("- 2 pure copper\n+ 1 emergency hitter\nthe copper stops singing.", "pickup", "equip")


func use_hitter() -> Dictionary:
	if int(host.p.hitters) <= 0 or float(host.p.rockedT) > 0.0: return _reject("the pocket has no business now.")
	host.p.hitters -= 1
	host.p.rockedT = 6000.0
	host.p.crashT = 0.0
	host.p.hitterHigh = true
	host.p.shakes = maxf(0.0, float(host.p.shakes) - 20.0)
	host.p.brain = maxf(0.0, float(host.p.brain) - 8.0)
	host.emit_event("flash", {"rgba":[208,96,48,0.4], "strength":1.0})
	host.emit_event("feed", {"text":"hit the emergency pipe. it counts.", "author":"@crackheadcent"})
	return _accept("· the emergency hitter ·\nit tastes like pennies.\nbrain -8. shakes -20.", "hurt", "smoke")


func _high_expired(was_hitter: bool, position: Vector2) -> void:
	host.p.hitterHigh = false
	host.p.crashT = 14000.0 if was_hitter else 8000.0
	host.p.shakes = minf(100.0, float(host.p.shakes) + (35.0 if was_hitter else 30.0))
	host.emit_event("sound", {"id":"crash"})
	host.emit_event("flash", {"rgba":[180,80,180,0.35], "strength":1.0})
	host.emit_event("toast", {"text":"the crash arrives.\nahead of schedule." if was_hitter else "the crash arrives.\non schedule.", "duration_ms":2200})
	if not was_hitter:
		var venue: String = venue_at(position)
		if not venue.is_empty(): record(venue, "full_high", "high_boundary",2300)


func condition_status(venue: String) -> String:
	match venue:
		"park": return "the philosopher is asleep enough." if condition(venue) else "daylight."
		"choir_office": return "in session." if condition(venue) else "closed."
		"underpass": return "the dog is here." if condition(venue) else "the dog is elsewhere."
		"laundromat":
			if condition(venue): return "mid-cycle."
			return "running. not mid." if host.s.concessionClocks.dryer.phase == "running" else "idle."
	return ""


func ledger_line(venue: String) -> String:
	if venue not in VENUES: return ""
	if unlocked(venue): return "concession: " + TEXT[venue].condition + " · " + condition_status(venue)
	if discovered(venue): return "known: " + TEXT[venue].condition + " · " + TEXT[venue].keeper
	return ""


func action_hint(point: Vector2) -> String:
	var venue: String = venue_at(point)
	if venue.is_empty() or not (unlocked(venue) or discovered(venue)): return ""
	return TEXT[venue].hint
