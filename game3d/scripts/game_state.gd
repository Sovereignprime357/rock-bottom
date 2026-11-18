class_name RockBottomGameState
extends RefCounted
## Full model foundation. Composition owns gameplay handlers; scenes own presentation/IO.

const Content = preload("res://scripts/content_catalog.gd")
const SAVE_SCHEMA: int = 2
const SAVE_FORMAT: String = "rock-bottom-full-state"
const DAY_MS: float = 240000.0
const MAX_TICK_SECONDS: float = 240.0
const QUANTUM_MS: float = 1000.0 / 60.0
const LIMIT: int = 1000000000
const DEFAULT_SEED: int = 0x19c0ffee
const EPSILON: float = 0.000001
const SPAWN: Vector2 = Vector2(1050.0, 840.0)
const FACTIONS: Array[String] = ["street", "scrap", "spiritual"]
const SLOTS: Array[String] = ["shoes", "hat", "coat", "tool"]
const RESOURCES: Array[String] = ["cash", "rocks", "copper", "supplies", "dirtySupplies", "soapRocks", "hitters"]
const PLAYER_TIMERS: Array[String] = ["attackCd", "attacking", "hitFlash", "iframes", "stunT", "slowT"]
const PLAYER_SAVE_KEYS: Array[String] = [
	"x", "y", "hp", "cash", "rocks", "copper", "supplies", "dirtySupplies", "shakes", "cred",
	"brain", "wanted", "rank", "inventory", "lifetime", "tonyOffenses", "equip", "cartMounted",
	"weapon", "brutusDefeated", "stripeLoyalty", "charisma", "soapRocks", "hitters", "faction",
]
const STATE_SAVE_KEYS: Array[String] = [
	"cashPilesCollected", "achievements", "counters", "quests", "hustles", "hustleSnapshot",
	"blockRoute", "office", "districtClaims", "kingdom", "day", "dayTime", "weather", "lootedDumpsters",
	"barbAside", "metVendors", "flags", "crownPickup", "graffiti", "posters", "publicPhoneAnswered",
	"hideoutStash", "recognition", "concessionClocks", "discoveredVenues", "migration",
]

var content: Dictionary = {}
var p: Dictionary = {}
var s: Dictionary = {}
var npcs: Array[Dictionary] = []
var cash_piles: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var events: Array[Dictionary] = []
var on_high_expired: Callable
var last_error: String = ""
var rng_seed: int = DEFAULT_SEED
var _quantum_remaining: float = QUANTUM_MS
var _normalizers: Dictionary = {}
var _dead_ids: Array[String] = []


func _init(decoded_content: Dictionary = {}) -> void:
	content = decoded_content if not decoded_content.is_empty() else Content.load_content()
	fresh()


func definition(module_path: String, export_name: String, fallback: Variant = null) -> Variant:
	var modules: Dictionary = _dict(content.get("definitions"))
	return _dict(modules.get(module_path)).get(export_name, fallback)


func fresh() -> bool:
	last_error = ""
	events.clear()
	var initial: Dictionary = _dict(content.get("initial"))
	if not initial.get("player") is Dictionary or not initial.get("state") is Dictionary:
		last_error = "Full source defaults are missing."
		p = {}; s = {}; npcs.clear(); cash_piles.clear(); projectiles.clear()
		return false
	p = initial.player.duplicate(true)
	s = initial.state.duplicate(true)
	rng_seed = DEFAULT_SEED
	_quantum_remaining = QUANTUM_MS
	_dead_ids.clear()
	npcs = _records(_dict(content.get("actors")).get("day1", []))
	cash_piles = _records(initial.get("cashPiles", []))
	projectiles.clear()
	_normalize_player(p.duplicate(true))
	_normalize_state(s.duplicate(true))
	_reset_ephemeral()
	return true


func emit_event(kind: String, payload: Dictionary = {}) -> void:
	events.append({"kind": kind, "payload": payload.duplicate(true)})


func drain_events() -> Array[Dictionary]:
	var drained: Array[Dictionary] = events.duplicate(true)
	events.clear()
	return drained


func register_state_normalizer(key: String, callback: Callable) -> void:
	if callback.is_valid():
		_normalizers[key] = callback
		if s.has(key): s[key] = callback.call(s[key])


func random_float() -> float:
	rng_seed = (rng_seed * 1664525 + 1013904223) & 0xffffffff
	return float(rng_seed) / 4294967296.0


func random_index(count: int) -> int:
	if count <= 0: return -1
	return mini(count - 1, int(floor(random_float() * count)))


func player_center() -> Vector2:
	return Vector2(float(p.x) + float(p.w) * 0.5, float(p.y) + float(p.h) * 0.5)


func tick(seconds: float, context: Dictionary = {}) -> bool:
	if p.is_empty() or not is_finite(seconds) or seconds <= 0.0 or seconds > MAX_TICK_SECONDS:
		return false
	if context.get("advance_world", true) == false: return true
	var remaining: float = seconds * 1000.0
	# A rejected call cannot partially spend world time, RNG or resources.
	if float(p.rockedT) > 0.0 and float(p.rockedT) <= remaining + EPSILON and not on_high_expired.is_valid():
		last_error = "A high-expiry handler is required before advancing through the boundary."
		return false
	last_error = ""
	var body_context: Dictionary = context.duplicate()
	while remaining > EPSILON:
		var was_high: bool = float(p.rockedT) > EPSILON
		var was_crash: bool = not was_high and float(p.crashT) > EPSILON
		var day_left: float = (1.0 - float(s.dayTime)) * DAY_MS
		var step: float = minf(remaining, minf(_quantum_remaining, day_left))
		if was_high: step = minf(step, float(p.rockedT))
		elif was_crash: step = minf(step, float(p.crashT))
		var shake_rate: float = 0.0008
		if body_context.get("moving", false) == true and body_context.get("sprinting", false) == true:
			shake_rate += 0.012
		p.shakes = clampf(float(p.shakes) + step * shake_rate, 0.0, 100.0)
		if _at_block(body_context): p.hp = minf(float(p.maxHp), float(p.hp) + step * 0.006)
		for key: String in PLAYER_TIMERS:
			p[key] = maxf(0.0, float(p.get(key, 0.0)) - step)
		if was_high: p.rockedT = maxf(0.0, float(p.rockedT) - step)
		elif was_crash: p.crashT = maxf(0.0, float(p.crashT) - step)
		s.dayTime = float(s.dayTime) + step / DAY_MS
		remaining -= step
		_quantum_remaining -= step
		if _quantum_remaining <= EPSILON:
			_quantum_remaining = QUANTUM_MS
			if float(p.shakes) >= 100.0 and random_float() < 0.006:
				if hurt(2.0): body_context.erase("at_block")
		if was_high and float(p.rockedT) <= EPSILON:
			p.rockedT = 0.0
			var was_hitter: bool = p.get("hitterHigh", false) == true
			var center: Vector2 = player_center()
			emit_event("high_expired", {"was_hitter": was_hitter, "position": center})
			on_high_expired.call(was_hitter, center)
		elif was_crash and float(p.crashT) <= EPSILON:
			p.crashT = 0.0
			emit_event("crash_ended")
		if float(s.dayTime) >= 1.0 - EPSILON / DAY_MS:
			s.dayTime = maxf(0.0, float(s.dayTime) - 1.0)
			_advance_day()
	return true


func _at_block(context: Dictionary) -> bool:
	if context.has("at_block"): return context.at_block == true
	var zones: Array = _array(_dict(content.get("world")).get("zones"))
	var center: Vector2 = player_center()
	for value: Variant in zones:
		if value is Dictionary and value.get("id") == "block":
			return Rect2(float(value.x), float(value.y), float(value.w), float(value.h)).has_point(center)
	return false


func _advance_day() -> void:
	s.day = mini(LIMIT, int(s.day) + 1)
	p.lifetime.dayCount = s.day
	var daily_keys: Array = definition("src/systems/daily_hideouts.js", "DAILY_COUNTER_KEYS", [])
	for value: Variant in daily_keys:
		if value is String: s.counters[value] = 0
	if s.office is Dictionary:
		s.office.workDay = s.day
		s.office.workToday = 0
	emit_event("day_started", {"day": s.day})


func apply_equip_stats() -> void:
	var equipment: Dictionary = _dict(_catalog("equipment"))
	var base_speed: float = 2.2
	var maximum_hp: float = 110.0 if p.get("cartMounted", false) == true else 100.0
	var cred_bonus: int = 0
	var charisma: int = 0
	var decay: float = 1.0
	for slot: String in SLOTS:
		var id: Variant = _dict(p.get("equip")).get(slot)
		if not id is String or not equipment.has(id): continue
		var entry: Dictionary = equipment[id]
		base_speed += float(entry.get("speed", 0.0))
		maximum_hp += float(entry.get("hp", 0.0))
		cred_bonus += int(entry.get("cred", 0))
		charisma += int(entry.get("charisma", 0))
		decay += float(entry.get("wantedDecay", 0.0))
	if p.get("cartMounted", false) == true: base_speed = minf(base_speed * 1.7, base_speed + 1.5)
	p.speed = maxf(0.8, base_speed)
	p.maxHp = maximum_hp
	p.hp = minf(float(p.get("hp", maximum_hp)), maximum_hp)
	p.credBonus = cred_bonus
	p.charisma = charisma
	p.wantedDecayMult = decay


func equip_tool(id: String) -> Variant:
	if not id in ["propane_torch", "crowbar"]: return null
	var displaced: Variant = p.equip.get("tool")
	if displaced == id: return null
	if displaced != null: s.flags.peteToolLocker = displaced
	elif s.flags.get("peteToolLocker") == id: s.flags.peteToolLocker = null
	p.equip.tool = id
	apply_equip_stats()
	return displaced


func vendor_price(base: int) -> int:
	return maxi(1, int(floor(float(base) * 0.9 + 0.5))) if int(p.get("charisma", 0)) >= 1 else base


func faction_tier(value: int) -> String:
	if value <= -10: return "hated"
	if value >= 25: return "loved"
	if value >= 10: return "liked"
	return "neutral"


func apply_rep(deltas: Dictionary) -> void:
	var loved_ids: Dictionary = {"street": "the_block_knows", "scrap": "yuri_counts_you", "spiritual": "mom_is_proud"}
	for faction: String in FACTIONS:
		if not _is_number(deltas.get(faction)): continue
		var before: int = int(p.faction.get(faction, 0))
		var after: int = clampi(before + int(clampf(float(deltas[faction]), -100.0, 100.0)), -50, 50)
		p.faction[faction] = after
		if faction_tier(before) != faction_tier(after):
			emit_event("faction_tier_changed", {"faction": faction, "before": faction_tier(before), "after": faction_tier(after)})
			if faction_tier(after) == "loved": unlock_achievement(loved_ids[faction])


func unlock_achievement(id: String) -> bool:
	var definitions: Dictionary = _dict(_catalog("achievements"))
	if not definitions.has(id) or s.achievements.has(id): return false
	s.achievements.append(id)
	emit_event("achievement", {"id": id, "definition": definitions[id]})
	emit_event("save_requested")
	return true


func complete_intro_smoke() -> bool:
	var quest: Dictionary = _dict(s.quests.get("intro_smoke"))
	if quest.is_empty() or quest.get("done", false) == true: return false
	quest.done = true
	p.cred = mini(LIMIT, int(p.cred) + 2)
	s.flags.introDone = true
	emit_event("quest_completed", {"id": "intro_smoke"})
	emit_event("intro_completed")
	emit_event("save_requested")
	return true


func hurt(amount: float, source: Dictionary = {}) -> bool:
	if not is_finite(amount) or amount <= 0.0 or float(p.iframes) > EPSILON: return false
	p.hp = maxf(0.0, float(p.hp) - amount)
	p.iframes = 500.0
	p.hitFlash = 250.0
	s.combo = 0
	emit_event("hurt", {"amount": amount, "source_id": source.get("id", "")})
	if float(p.hp) > 0.0: return false
	if source.get("id") == "brutus":
		s.counters.brutusDeaths = _natural(s.counters.get("brutusDeaths")) + 1
		if int(s.counters.brutusDeaths) >= 3: unlock_achievement("brutus_remembers")
	if source.get("isCop", false) == true: arrest()
	else: die()
	return true


func die() -> void:
	_abort_encounter()
	p.hp = 60.0; p.shakes = 30.0; p.cred = maxi(0, int(p.cred) - 10); p.wanted = 0
	p.x = SPAWN.x; p.y = SPAWN.y; p.iframes = 1000.0
	_remove_police()
	emit_event("death", {"position": SPAWN})
	emit_event("save_requested")


func arrest() -> void:
	_abort_encounter()
	p.lifetime.arrests = mini(LIMIT, _natural(p.lifetime.get("arrests")) + 1)
	var lost_cash: int = int(floor(float(p.cash) * 0.7))
	p.cash = int(p.cash) - lost_cash; p.rocks = 0; p.shakes = 100.0; p.wanted = 0; p.hp = 40.0
	p.x = SPAWN.x; p.y = SPAWN.y
	_remove_police()
	emit_event("arrest", {"lost_cash": lost_cash, "position": SPAWN})
	emit_event("save_requested")


func _abort_encounter() -> void:
	if s.get("bossKind") == "kingdom": emit_event("kingdom_abort_requested")


func _remove_police() -> void:
	for index: int in range(npcs.size() - 1, -1, -1):
		if npcs[index].get("isCop", false) == true: npcs.remove_at(index)


func snapshot() -> Dictionary:
	var player: Dictionary = {}
	var state: Dictionary = {}
	for key: String in PLAYER_SAVE_KEYS:
		if p.has(key): player[key] = _safe_data(p[key])
	for key: String in STATE_SAVE_KEYS:
		if s.has(key): state[key] = _safe_data(s[key])
	var deaths: Array[String] = _dead_ids.duplicate()
	for actor: Dictionary in npcs:
		if actor.get("dead", false) == true and actor.get("essential", false) != true and actor.get("transient", false) != true and actor.get("kingdomGuard", false) != true and actor.get("kingdomPretender", false) != true:
			var id: String = str(actor.get("id", ""))
			if not id.is_empty() and not deaths.has(id): deaths.append(id)
	return {"schema": SAVE_SCHEMA, "format": SAVE_FORMAT, "player": player, "state": state,
		"npcs_killed": deaths, "rng_seed": rng_seed}


func restore(data: Dictionary) -> Dictionary:
	if not fresh(): return {"ok": false, "reason": "missing_content", "placement_reset": true}
	var schema: int = int(_number(data.get("schema"), -1.0))
	if schema == 1 and _number(data.get("schema"), -1.0) == 1.0:
		return _restore_slice(data)
	if schema != SAVE_SCHEMA or _number(data.get("schema"), -1.0) != float(SAVE_SCHEMA) or data.get("format") != SAVE_FORMAT or not data.get("player") is Dictionary or not data.get("state") is Dictionary:
		return {"ok": false, "reason": "unsupported_or_invalid_save", "placement_reset": true}
	_normalize_player(data.player)
	_normalize_state(data.state)
	rng_seed = int(_bounded(data.get("rng_seed"), float(DEFAULT_SEED), 0.0, 4294967295.0))
	_dead_ids = _string_set(data.get("npcs_killed"))
	_rehydrate_deaths()
	_reset_ephemeral()
	return {"ok": true, "schema": SAVE_SCHEMA, "placement_reset": false, "needs_clear_placement": true,
		"position": Vector2(float(p.x), float(p.y))}


func _restore_slice(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = p.duplicate(true)
	for key: String in ["hp", "cash", "rocks", "copper", "shakes", "brain", "cred"]:
		if data.has(key): migrated[key] = data[key]
	migrated.inventory = []
	for id: String in ["junk", "food"]:
		var count: int = _natural(data.get(id))
		if count > 0: migrated.inventory.append({"id": id, "n": "a piece of junk" if id == "junk" else "a can of food (unmarked)", "q": count, "migration_units": true})
	_normalize_player(migrated)
	s.day = maxi(1, _natural(data.get("day")))
	s.dayTime = _bounded(data.get("day_time"), 0.0, 0.0, 239.999999) / 240.0
	s.counters.peteCashToday = mini(200, _natural(data.get("pete_paid")))
	s.flags.introDone = true
	s.flags.momIntroFired = true
	for id: String in ["intro_remember", "intro_tony", "intro_smoke"]:
		if s.quests.get(id) is Dictionary:
			s.quests[id].done = true; s.quests[id].available = true
	var defeated: Dictionary = _dict(data.get("defeated"))
	if _true(defeated.get("lurch")):
		_dead_ids.append("lurch")
		s.counters.alleyKills = 1
	var old_collected: Array[String] = []
	var collected: Dictionary = _dict(data.get("collected"))
	for id: String in ["cash_1", "cash_2", "cash_3", "copper_1", "dumpster_1", "dumpster_2", "dumpster_3"]:
		if _true(collected.get(id)): old_collected.append(id)
	s.migration = {"from_schema": 1, "placement_reason": "slice_world_replaced", "slice_collected": old_collected}
	p.x = SPAWN.x; p.y = SPAWN.y
	p.lifetime.dayCount = s.day
	_rehydrate_deaths()
	_reset_ephemeral()
	return {"ok": true, "schema": SAVE_SCHEMA, "migrated_from": 1, "placement_reset": true,
		"reason": "slice_world_replaced", "needs_clear_placement": true, "position": SPAWN}


func _normalize_player(raw: Dictionary) -> void:
	for key: String in RESOURCES: p[key] = _natural(raw.get(key, p.get(key, 0)))
	p.dirtySupplies = mini(int(p.dirtySupplies), int(p.supplies))
	for key: String in ["brain", "shakes"]: p[key] = _bounded(raw.get(key), float(p.get(key, 0.0)), 0.0, 100.0)
	p.cred = int(_bounded(raw.get("cred"), float(p.get("cred", 0)), -50.0, float(LIMIT)))
	p.wanted = mini(3, _natural(raw.get("wanted", p.get("wanted", 0))))
	var ranks: Array = _array(_catalog("ranks"))
	p.rank = mini(maxi(0, ranks.size() - 1), _natural(raw.get("rank", p.get("rank", 0))))
	p.cartMounted = _true(raw.get("cartMounted"))
	p.tonyOffenses = _natural(raw.get("tonyOffenses", 0))
	p.brutusDefeated = _natural(raw.get("brutusDefeated", 0))
	p.stripeLoyalty = int(_bounded(raw.get("stripeLoyalty"), 0.0, -1.0, float(LIMIT)))
	p.lifetime = _natural_record(raw.get("lifetime"), _dict(p.get("lifetime")))
	p.faction = {}
	for faction: String in FACTIONS:
		p.faction[faction] = int(_bounded(_dict(raw.get("faction")).get(faction), 0.0, -50.0, 50.0))
	var equipment: Dictionary = _dict(_catalog("equipment"))
	p.equip = {}
	for slot: String in SLOTS:
		var id: Variant = _dict(raw.get("equip")).get(slot)
		p.equip[slot] = id if id is String and equipment.has(id) and equipment[id].get("slot") == slot else null
	var weapon: Variant = raw.get("weapon", "fists")
	p.weapon = weapon if weapon is String and _dict(_catalog("weapons")).has(weapon) else "fists"
	p.inventory = _inventory(raw.get("inventory"))
	var bounds: Dictionary = _dict(_dict(content.get("world")).get("bounds"))
	p.x = _bounded(raw.get("x"), SPAWN.x, 0.0, float(bounds.get("w", 8600.0)) - float(p.get("w", 24.0)))
	p.y = _bounded(raw.get("y"), SPAWN.y, 0.0, float(bounds.get("h", 5600.0)) - float(p.get("h", 28.0)))
	p.hp = _bounded(raw.get("hp"), 100.0, 0.0, 1000.0)
	apply_equip_stats()
	if float(p.hp) <= 0.0: p.hp = minf(60.0, float(p.maxHp))


func _normalize_state(raw: Dictionary) -> void:
	# Persist only deliberate save fields; source-generated defaults retain other transient keys.
	for key: String in STATE_SAVE_KEYS:
		if raw.has(key): s[key] = _safe_data(raw[key])
	s.day = maxi(1, _natural(raw.get("day", 1)))
	s.dayTime = _bounded(raw.get("dayTime"), 0.35, 0.0, 1.0 - EPSILON)
	var weather: Variant = raw.get("weather", "clear")
	s.weather = weather if weather in ["clear", "rain", "fog"] else "clear"
	var defaults: Dictionary = _dict(_dict(content.get("initial")).get("state"))
	s.counters = _natural_record(raw.get("counters"), _dict(defaults.get("counters")))
	s.flags = _dict(_safe_data(raw.get("flags", defaults.get("flags", {}))))
	for key: Variant in _dict(defaults.get("flags")):
		var fallback: Variant = defaults.flags[key]
		if not s.flags.has(key) or (fallback is bool and not s.flags[key] is bool): s.flags[key] = fallback
	var held: Variant = s.flags.get("peteToolLocker")
	if not held in ["propane_torch", "crowbar"] or held == p.equip.tool: s.flags.peteToolLocker = null
	var known_quests: Dictionary = _dict(defaults.get("quests"))
	s.quests = known_quests.duplicate(true)
	for id: Variant in known_quests:
		var quest: Dictionary = _dict(_dict(raw.get("quests")).get(id))
		if quest.has("done"): s.quests[id].done = _true(quest.done)
		if quest.get("available") is bool: s.quests[id].available = quest.available
		if id == "scrap_dog" and quest.get("state") in ["idle", "fed", "freed", "left"]: s.quests[id].state = quest.state
	s.achievements = _known_set(raw.get("achievements"), _dict(_catalog("achievements")).keys())
	s.metVendors = _string_set(raw.get("metVendors"))
	s.cashPilesCollected = _string_set(raw.get("cashPilesCollected"))
	s.lootedDumpsters = _string_set(raw.get("lootedDumpsters"))
	s.discoveredVenues = _string_set(raw.get("discoveredVenues"))
	s.publicPhoneAnswered = _natural(raw.get("publicPhoneAnswered"))
	s.barbAside = _true(raw.get("barbAside"))
	s.hustles = _records(raw.get("hustles"))
	s.hustleSnapshot = _natural_record(raw.get("hustleSnapshot"))
	for key: String in ["office", "districtClaims", "kingdom", "recognition", "concessionClocks"]:
		if not s.get(key) is Dictionary: s[key] = _dict(defaults.get(key)).duplicate(true)
	var stash: Dictionary = _dict(raw.get("hideoutStash"))
	s.hideoutStash = {"cash": _natural(stash.get("cash")), "copper": _natural(stash.get("copper")),
		"rocks": _natural(stash.get("rocks")), "items": _inventory(stash.get("items"))}
	for key: Variant in _normalizers:
		var callback: Callable = _normalizers[key]
		s[key] = callback.call(raw.get(key, s.get(key)))


func _reset_ephemeral() -> void:
	for key: String in PLAYER_TIMERS: p[key] = 0.0
	p.rockedT = 0.0; p.crashT = 0.0; p.hitterHigh = false; p.wantedT = 0.0
	p.vx = 0.0; p.vy = 0.0; p.frame = 0; p.frameT = 0.0; p.facing = "down"
	s.mode = "playing"; s.keys = []; s.stickX = 0.0; s.stickY = 0.0; s.stickMag = 0.0
	s.bossActive = false; s.bossKind = ""; s.bossPhase = 0; s.bossNPC = null; s.kingdomBattle = null
	s.incident = null; s.incidentPaperT = 0.0; s.incidentWetT = 0.0
	s.heat = null; s.combo = 0; s.comboT = 0.0; s.hitPause = 0.0
	s.recognitionVisit = {"venue": "", "seen": {}}
	s.endingContinue = false; s.endingSavePromise = null
	projectiles.clear()
	_quantum_remaining = QUANTUM_MS
	# A missing campaign adapter must not leave a restored boss stage permanently live.
	if s.kingdom is Dictionary:
		var retries: Dictionary = {"tarp_boss": "tarp_marks", "cart_boss": "cart_marks", "wire_boss": "wire_marks", "emperor_boss": "emperor_gate"}
		var stage: Variant = s.kingdom.get("stage")
		if stage is String and retries.has(stage):
			s.kingdom.stage = retries[stage]
			if stage != "emperor_boss": s.kingdom.marks = 7
		s.kingdom.bossId = ""


func _rehydrate_deaths() -> void:
	for actor: Dictionary in npcs:
		if _dead_ids.has(str(actor.get("id", ""))) and actor.get("essential", false) != true and actor.get("kingdomGuard", false) != true and actor.get("kingdomPretender", false) != true:
			actor.dead = true
	for pile: Dictionary in cash_piles:
		if s.cashPilesCollected.has(str(pile.get("id", ""))): pile.collected = true


func _catalog(key: String) -> Variant:
	return _dict(content.get("catalogs")).get(key)


func _inventory(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var known_ids: Array[String] = []
	for item: Variant in _array(_catalog("items")):
		if item is Dictionary and item.get("id") is String and not known_ids.has(item.id): known_ids.append(item.id)
	for entry: Dictionary in _records(value):
		var id: Variant = entry.get("id")
		if not id is String or not known_ids.has(id): continue
		var count: int = _natural(entry.get("q", 1))
		if count <= 0: continue
		var name_value: Variant = entry.get("n", id)
		var item: Dictionary = {"id": id, "n": name_value.substr(0, 512) if name_value is String else id, "q": count}
		if id in ["junk", "food"] and _true(entry.get("migration_units")): item.migration_units = true
		result.append(item)
	return result


func _natural_record(value: Variant, defaults: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in defaults:
		if key is String: result[key] = _natural(defaults[key])
	var raw: Dictionary = _dict(value)
	var count: int = 0
	for key: Variant in raw:
		if count >= 512: break
		if key is String and key.length() <= 128:
			result[key] = _natural(raw[key]); count += 1
	return result


func _known_set(value: Variant, allowed: Array) -> Array[String]:
	var result: Array[String] = []
	for key: String in _string_set(value):
		if allowed.has(key): result.append(key)
	return result


func _string_set(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var raw: Array = _array(value)
	for index: int in range(mini(raw.size(), 1024)):
		var item: Variant = raw[index]
		if item is String and item.length() <= 128 and not result.has(item): result.append(item)
	return result


func _records(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Array = _array(value)
	var budget: Array[int] = [20000]
	for index: int in range(mini(raw.size(), 1024)):
		if budget[0] <= 0: break
		if raw[index] is Dictionary: result.append(_dict(_safe_data(raw[index], 0, budget)))
	return result


func _safe_data(value: Variant, depth: int = 0, budget: Array[int] = []) -> Variant:
	if budget.is_empty(): budget.append(20000)
	if depth > 8 or budget[0] <= 0: return null
	budget[0] -= 1
	if value == null or value is bool: return value
	# Generic JSON contains epoch timestamps and uint32 concession seeds. Domain
	# normalizers cap resources; generic copying must not corrupt those other numbers.
	if _is_number(value): return value
	if value is String or value is StringName: return str(value).substr(0, 4096)
	if value is Array:
		var list: Array = []
		for index: int in range(mini(value.size(), 1024)):
			if budget[0] <= 0: break
			list.append(_safe_data(value[index], depth + 1, budget))
		return list
	if value is Dictionary:
		var record: Dictionary = {}
		var count: int = 0
		for key: Variant in value:
			if count >= 512 or budget[0] <= 0: break
			if (key is String or key is StringName) and str(key).length() <= 128:
				record[str(key)] = _safe_data(value[key], depth + 1, budget); count += 1
		return record
	return null


func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value if value is Array else []


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _true(value: Variant) -> bool:
	return value is bool and value


func _number(value: Variant, fallback: float) -> float:
	return float(value) if _is_number(value) else fallback


func _bounded(value: Variant, fallback: float, low: float, high: float) -> float:
	return clampf(_number(value, fallback), low, high)


func _natural(value: Variant) -> int:
	return int(floor(_bounded(value, 0.0, 0.0, float(LIMIT))))
