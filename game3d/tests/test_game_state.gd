extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_defaults_and_isolation()
	_test_equipment_and_reputation()
	_test_boundaries()
	_test_withdrawal_partition()
	_test_failure()
	_test_save_and_normalization()
	_test_slice_migration()
	if failures.is_empty():
		print("3D FULL STATE GATE: PASS (%d checks; source defaults, clocks, equipment, failure and schema2 migration; scene integration pending)" % checks)
		quit(0)
	else:
		for message: String in failures: push_error(message)
		print("3D FULL STATE GATE: FAIL (%d failures / %d checks)" % [failures.size(), checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)


func _near(actual: float, expected: float, message: String, tolerance: float = 0.00001) -> void:
	_check(absf(actual - expected) <= tolerance, "%s: got %.9f expected %.9f" % [message, actual, expected])


func _has_event(model: RefCounted, kind: String) -> bool:
	for event: Dictionary in model.events:
		if event.kind == kind: return true
	return false


func _event_count(model: RefCounted, kind: String) -> int:
	var count: int = 0
	for event: Dictionary in model.events:
		if event.kind == kind: count += 1
	return count


func _bind_boundary(model: RefCounted, calls: Array) -> void:
	# An injected domain handler deliberately owns the effects, as MemoryLoop does.
	# No production ignition/boundary implementation is duplicated in GameState.
	var model_ref: WeakRef = weakref(model)
	model.on_high_expired = func(was_hitter: bool, center: Vector2) -> void:
		var owner: RefCounted = model_ref.get_ref()
		if owner == null: return
		calls.append({"hitter": was_hitter, "center": center})
		owner.p.crashT = 14000.0 if was_hitter else 8000.0
		owner.p.shakes = minf(100.0, float(owner.p.shakes) + (35.0 if was_hitter else 30.0))
		owner.p.hitterHigh = false


func _test_defaults_and_isolation() -> void:
	var content: Dictionary = Content.load_content()
	_check(not content.is_empty(), "real exported content is required")
	var a = GameState.new()
	var b = GameState.new()
	_check(a.last_error.is_empty(), "fresh source state loads")
	_check(a.s.quests.size() == 24 and a.content.catalogs.achievements.size() == 49, "all source quest/achievement definitions present")
	_check(a.npcs.size() == 56 and a.cash_piles.size() == 29, "source actor and fresh cash populations present")
	_check(a.p.cash == 0 and a.p.hp == 100 and a.p.brain == 70 and a.p.shakes == 20, "source fresh stats override slice simplifications")
	_near(a.s.dayTime, 0.35, "source fresh clock")
	_check(a.p.equip.has("tool") and a.p.equip.tool == null, "fresh missing tool slot repaired")
	a.p.cash = 71; a.s.quests.intro_smoke.done = true; a.npcs[0].hp = 1
	_check(b.p.cash == 0 and b.s.quests.intro_smoke.done == false and b.npcs[0].hp != 1, "model instances do not share mutable state")
	_check(content.initial.player.cash == 0 and content.initial.state.quests.intro_smoke.done == false, "model mutation cannot alter content cache")
	var payload: Dictionary = {"values": [1]}
	a.emit_event("example", payload)
	payload["values"].append(2)
	_check(a.events[0].payload["values"] == [1], "event owns detached payload")
	var drained: Array = a.drain_events()
	_check(drained.size() == 1 and a.events.is_empty(), "one event queue drains once")
	_check(a.fresh() and a.p.cash == 0 and a.s.quests.intro_smoke.done == false, "fresh resets every prior model")
	var injected: Dictionary = content.duplicate(true)
	injected.initial.player.cash = 13
	var custom = GameState.new(injected)
	_check(custom.p.cash == 13 and content.initial.player.cash == 0, "decoded content injection works without changing shared source")


func _test_equipment_and_reputation() -> void:
	var model = GameState.new()
	model.p.equip = {"shoes": "crocs", "coat": "parka", "hat": "helmet", "tool": null}
	model.p.cartMounted = true
	model.apply_equip_stats()
	_near(model.p.speed, 4.1, "source equipment/cart additive cap")
	_near(model.p.maxHp, 130.0, "source cart/clothing maximum HP")
	_check(model.p.credBonus == 5, "equipment cred is a derived bonus")
	model.p.equip.hat = "pigeon_crown"
	model.apply_equip_stats()
	_check(model.vendor_price(15) == 14 and model.vendor_price(35) == 32 and model.vendor_price(1) == 1, "vendor discount uses JS nonnegative half-up rounding and floor")
	model.p.equip.hat = "priest_collar"
	model.apply_equip_stats()
	_near(model.p.wantedDecayMult, 1.3, "priest collar decay modifier")
	_check(model.vendor_price(15) == 15, "removed crown removes charisma discount")
	model.equip_tool("propane_torch")
	_check(model.equip_tool("crowbar") == "propane_torch" and model.s.flags.peteToolLocker == "propane_torch", "equipping tool preserves displaced ownership")
	model.equip_tool("propane_torch")
	_check(model.p.equip.tool == "propane_torch" and model.s.flags.peteToolLocker == "crowbar", "free tool swap never destroys the other")
	model.equip_tool("made_up")
	_check(model.p.equip.tool == "propane_torch", "unknown tool cannot equip")
	model.apply_rep({"street": 25, "scrap": -1000, "spiritual": 10, "made_up": 10})
	_check(model.p.faction == {"street": 25, "scrap": -50, "spiritual": 10}, "faction signs, thresholds and allowed keys preserved")
	_check(model.s.achievements.has("the_block_knows") and _event_count(model, "faction_tier_changed") == 3, "tier crossings produce canonical achievement/event")
	_check(not model.unlock_achievement("the_block_knows") and not model.unlock_achievement("made_up"), "achievement cannot replay or invent IDs")
	var prior_cred: int = model.p.cred
	_check(model.complete_intro_smoke() and not model.complete_intro_smoke(), "intro smoke is one-shot")
	_check(model.p.cred == prior_cred + 2 and model.s.flags.introDone and model.s.quests.intro_smoke.done, "intro's local resource/quest mutations match source")
	_check(_event_count(model, "intro_completed") == 1, "routes/hustles orchestration is requested exactly once")


func _test_boundaries() -> void:
	var model = GameState.new()
	var calls: Array = []
	_bind_boundary(model, calls)
	model.p.rockedT = 18000.0
	model.p.shakes = 0.0
	_check(model.tick(20.0, {"at_block": false}), "supported catch-up accepted")
	_check(calls.size() == 1 and calls[0].center == Vector2(1062.0, 854.0), "high hook receives canonical player center once")
	_near(model.p.crashT, 6000.0, "remaining two seconds spend crash time")
	_near(model.p.shakes, 46.0, "continuous shakes and one normal boundary effect")
	_check(_event_count(model, "high_expired") == 1, "boundary informational event emitted once")
	model.tick(6.0, {"at_block": false})
	_near(model.p.crashT, 0.0, "normal cycle ends at26 seconds")
	_check(_event_count(model, "crash_ended") == 1, "crash end emitted once")
	model.p.rockedT = 6000.0; model.p.hitterHigh = true
	model.tick(7.0, {"at_block": false})
	_near(model.p.crashT, 13000.0, "hitter handler determines longer crash before remainder")
	_check(calls.size() == 2 and calls[1].hitter and not model.p.hitterHigh, "high-kind flag reaches handler then clears")
	var missing = GameState.new()
	missing.p.rockedT = 10.0
	var before: Dictionary = missing.snapshot()
	_check(not missing.tick(0.02), "missing expiry hook rejects entire interval")
	_check(missing.snapshot() == before and missing.p.rockedT == 10.0 and missing.events.is_empty(), "missing hook leaves time, RNG, resources and events unchanged")
	_check(missing.tick(0.005), "missing hook permits interval not crossing high")
	_near(missing.p.rockedT, 5.0, "noncrossing high time still advances")
	before = missing.snapshot()
	for invalid: float in [-1.0, 0.0, NAN, INF, 240.001]:
		_check(not missing.tick(invalid), "invalid/out-of-bound delta rejected")
	_check(missing.snapshot() == before and missing.p.rockedT == 5.0, "invalid delta has no partial mutation")
	_check(missing.tick(10.0, {"advance_world": false}) and missing.snapshot() == before, "paused world does not require expiry or spend time")
	var dawn = GameState.new()
	dawn.s.dayTime = 0.999
	dawn.s.counters.peteCashToday = 200; dawn.s.counters.heistsToday = 3; dawn.s.counters.robLastClockMs = 9000
	dawn.tick(0.5, {"at_block": true})
	_check(dawn.s.day == 2 and dawn.s.counters.peteCashToday == 0 and dawn.s.counters.heistsToday == 0, "dawn resets source accumulating daily counters")
	_check(dawn.s.counters.robLastClockMs == 9000 and _event_count(dawn, "day_started") == 1, "robbery world timestamp survives dawn and one orchestration event fires")
	_near(dawn.s.dayTime, 0.26 / 240.0, "dawn retains fractional remainder")
	var sprint = GameState.new()
	sprint.tick(1.0, {"moving": true, "sprinting": true, "at_block": false})
	_near(sprint.p.shakes, 32.8, "moving sprint adds source12 plus passive0.8 shakes")
	var heal = GameState.new()
	heal.p.hp = 50.0
	heal.tick(1.0)
	_near(heal.p.hp, 56.0, "Block detection uses source zone when no scene override")


func _test_withdrawal_partition() -> void:
	var whole = GameState.new()
	var split = GameState.new()
	whole.p.shakes = 100.0; split.p.shakes = 100.0
	whole.tick(30.0, {"at_block": false})
	# Incommensurate fractions expose accidental one-roll-per-call implementations.
	for ignored: int in range(300):
		split.tick(0.037, {"at_block": false})
		split.tick(0.063, {"at_block": false})
	_near(split.p.hp, whole.p.hp, "withdrawal HP invariant under time partition")
	_near(split.p.iframes, whole.p.iframes, "withdrawal iframes invariant under partition")
	_near(split.s.dayTime, whole.s.dayTime, "world time invariant under partition")
	_check(split.rng_seed == whole.rng_seed and split.events == whole.events, "withdrawal draw order/events invariant under partition")
	_check(whole.p.hp < 100.0, "seeded interval actually exercises withdrawal damage")
	var guarded = GameState.new()
	guarded.hurt(10.0)
	guarded.tick(0.499, {"at_block": false})
	guarded.hurt(10.0)
	_near(guarded.p.hp, 90.0, "damage rejected within500ms iframe")
	guarded.tick(0.001, {"at_block": false})
	guarded.hurt(10.0)
	_near(guarded.p.hp, 80.0, "damage allowed exactly at500ms")
	var rng = GameState.new()
	var initial_seed: int = rng.rng_seed
	_check(rng.random_index(0) == -1 and rng.rng_seed == initial_seed, "invalid random index consumes no roll")
	var expected_seed: int = (initial_seed * 1664525 + 1013904223) & 0xffffffff
	_near(rng.random_float(), float(expected_seed) / 4294967296.0, "LCG independent numeric oracle", 0.0000000001)
	for ignored: int in range(100):
		var index: int = rng.random_index(7)
		_check(index >= 0 and index < 7, "random index stays bounded")


func _test_failure() -> void:
	var model = GameState.new()
	model.p.cash = 101; model.p.rocks = 4; model.p.soapRocks = 2; model.p.cred = 7
	model.p.rockedT = 9000.0; model.p.crashT = 0.0
	model.p.inventory = [{"id": "food", "n": "a can of food (unmarked)", "q": 2}]
	model.s.hideoutStash.cash = 123
	model.npcs.append({"id": "cop_test", "isCop": true})
	model.die()
	_check(model.p.hp == 60 and model.p.shakes == 30 and model.p.cred == 0 and model.p.wanted == 0, "source death stats")
	_check(model.p.cash == 101 and model.p.rocks == 4 and model.p.inventory[0].q == 2 and model.s.hideoutStash.cash == 123, "death keeps resources/items/stash")
	_near(model.p.rockedT, 9000.0, "death preserves active high unlike former slice")
	_check(model.p.x == 1050 and model.p.y == 840 and model.p.iframes == 1000, "death resets placement/protection")
	var cops_left: int = 0
	for actor: Dictionary in model.npcs:
		if actor.get("isCop", false): cops_left += 1
	_check(cops_left == 0, "death removes police")
	model.p.iframes = 0.0
	model.arrest()
	_check(model.p.cash == 31 and model.p.rocks == 0 and model.p.soapRocks == 2, "arrest removes floor70percent cash and real rocks only")
	_check(model.p.hp == 40 and model.p.shakes == 100 and model.p.lifetime.arrests == 1, "source arrest stats and count")
	_check(model.p.inventory[0].q == 2 and model.s.hideoutStash.cash == 123 and model.p.rockedT == 9000, "arrest preserves other inventory/stash/active high")
	var fatal = GameState.new()
	fatal.p.cash = 10
	_check(fatal.hurt(200, {"id": "cop", "isCop": true}) and fatal.p.hp == 40 and fatal.p.cash == 3, "fatal cop hit dispatches arrest")
	var unchanged: Dictionary = fatal.snapshot()
	_check(not fatal.hurt(NAN) and not fatal.hurt(-2) and not fatal.hurt(INF), "invalid damage rejected")
	_check(fatal.snapshot() == unchanged, "invalid damage cannot mutate state")


func _test_save_and_normalization() -> void:
	var model = GameState.new()
	model.p.cash = 87; model.p.cred = -5; model.p.equip.tool = "crowbar"
	model.s.flags.peteToolLocker = "propane_torch"
	model.s.flags.silenceUntilT = 1795000000000.0
	model.s.concessionClocks.seed = 4000000000
	model.p.rockedT = 4000.0; model.p.stunT = 500.0
	model.s.quests.first_rock.done = true
	model.s.achievements.append("soap_tongue")
	model.npcs[0].dead = true
	model.npcs.append({"id": "temp_dead", "dead": true, "transient": true})
	model.npcs.append({"id": "guard_dead", "dead": true, "kingdomGuard": true})
	model.npcs.append({"id": "essential_dead", "dead": true, "essential": true})
	var saved: Dictionary = model.snapshot()
	_check(saved.state.flags.get("peteToolLocker") == "propane_torch", "snapshot retains dynamically created locker ownership")
	model.s.flags[&"runtimeReceipt"] = &"retained"
	_check(model.snapshot().state.flags.get("runtimeReceipt") == "retained", "Godot interned keys and values serialize as ordinary JSON strings")
	_check(saved.schema == 2 and saved.format == "rock-bottom-full-state", "schema2 envelope identified")
	_check(not saved.player.has("rockedT") and not saved.player.has("stunT") and not saved.state.has("bossNPC"), "snapshot excludes active timers/scene objects")
	_check(saved.npcs_killed.has("tony") and not saved.npcs_killed.has("temp_dead") and not saved.npcs_killed.has("guard_dead") and not saved.npcs_killed.has("essential_dead"), "durable death filtering")
	model.p.cash = 0; model.s.quests.first_rock.done = false
	_check(saved.player.cash == 87 and saved.state.quests.first_rock.done, "snapshot detached from mutable dictionaries")
	var loaded = GameState.new()
	var result: Dictionary = loaded.restore(saved)
	_check(result.ok and result.needs_clear_placement and not result.placement_reset, "schema2 asks scene to resolve placement")
	_check(loaded.p.cash == 87 and loaded.p.cred == -5 and loaded.p.equip.tool == "crowbar", "valid resource/equipment roundtrip")
	_check(loaded.s.flags.peteToolLocker == "propane_torch" and loaded.s.quests.first_rock.done and loaded.s.achievements.has("soap_tongue"), "durable locker/quests/achievements roundtrip: locker=%s quest=%s achievements=%s" % [str(loaded.s.flags.get("peteToolLocker")), str(loaded.s.quests.first_rock.done), str(loaded.s.achievements)])
	_check(loaded.s.flags.silenceUntilT == 1795000000000.0 and loaded.s.concessionClocks.seed == 4000000000, "generic serialization does not resource-clamp timestamps or uint32 seeds")
	_check(loaded.p.rockedT == 0 and loaded.p.crashT == 0 and loaded.p.stunT == 0 and loaded.events.is_empty(), "load clears transients without reward events")
	_check(loaded.npcs[0].dead and loaded.rng_seed == saved.rng_seed, "NPC death/RNG restore")
	var broken: Dictionary = saved.duplicate(true)
	broken.player.cash = INF; broken.player.rocks = "5"; broken.player.copper = -9
	broken.player.brain = 500; broken.player.shakes = NAN; broken.player.cred = -500
	broken.player.cartMounted = "yes"; broken.player.wanted = 99
	broken.player.supplies = 3; broken.player.dirtySupplies = 90
	broken.player.equip = {"hat": "made_up", "coat": "pigeon_crown", "tool": "crowbar"}
	broken.player.weapon = "laser"
	broken.player.inventory = [{"id": "food", "q": 2, "n": "a can"}, {"id": "made_up", "q": 1}, {"id": "junk", "q": -2}]
	broken.player.x = INF; broken.player.y = -10
	broken.state.day = -8; broken.state.dayTime = 99
	broken.state.counters = {"rocksBought": -1, "peteCashToday": INF, "heistsToday": 99999999999.0}
	broken.state.quests = {"first_rock": {"done": true, "title": "injected"}, "fake": {"done": true}}
	broken.state.achievements = ["soap_tongue", "soap_tongue", "fake"]
	broken.state.flags.introDone = "yes"
	broken.state.office = "bad"; broken.state.kingdom = {"stage": "tarp_boss", "bossId": "darryl_under_blue"}
	loaded.restore(broken)
	_check(loaded.p.cash == 0 and loaded.p.rocks == 0 and loaded.p.copper == 0, "invalid resource types/signs normalize")
	_check(loaded.p.brain == 100 and loaded.p.shakes == 20 and loaded.p.cred == -50 and loaded.p.wanted == 3, "bounded player stats normalize")
	_check(loaded.p.dirtySupplies == 3 and not loaded.p.cartMounted, "dirty packets cannot exceed total and bool is strict")
	_check(loaded.p.equip.hat == null and loaded.p.equip.coat == null and loaded.p.weapon == "fists", "unknown/wrong-slot equipment rejected")
	_check(loaded.p.inventory.size() == 1 and loaded.p.inventory[0].id == "food" and loaded.p.inventory[0].q == 2, "inventory IDs and positive quantities validated")
	_check(loaded.p.x == 1050 and loaded.p.y == 0, "nonfinite position defaults; source coordinate bounds applied")
	_check(loaded.s.day == 1 and loaded.s.dayTime < 1 and loaded.s.counters.rocksBought == 0 and loaded.s.counters.heistsToday == 1000000000, "clock/counter structural clamp")
	_check(loaded.s.quests.size() == 24 and not loaded.s.quests.has("fake") and loaded.s.quests.first_rock.title != "injected", "save cannot invent quest definitions or rewrite content")
	_check(loaded.s.achievements == ["soap_tongue"] and loaded.s.flags.introDone == false, "achievement IDs dedupe and flag bool normalize")
	_check(loaded.s.office is Dictionary and loaded.s.kingdom.stage == "tarp_marks" and loaded.s.kingdom.marks == 7, "corrupt office recovers and interrupted kingdom challenge is retryable")
	var normalizer_calls: Array = []
	loaded.register_state_normalizer("recognition", func(raw: Variant) -> Dictionary:
		normalizer_calls.append(raw)
		return {"normalized": true})
	loaded.restore(saved)
	_check(loaded.s.recognition == {"normalized": true} and normalizer_calls.size() >= 2, "domain-owned normalizer invoked during restore")
	_check(loaded.s.recognitionVisit == {"venue": "", "seen": {}}, "restored recognition visit starts fresh")
	var fractional: Dictionary = saved.duplicate(true)
	fractional.schema = 2.5
	_check(not loaded.restore(fractional).ok and loaded.p.cash == 0, "fractional schema cannot masquerade as schema2")
	_check(not loaded.restore({"schema": 99}).ok and loaded.s.quests.size() == 24, "unknown schema safely restores full fresh defaults")


func _test_slice_migration() -> void:
	var model = GameState.new()
	var v1: Dictionary = {"schema": 1, "hp": 71, "cash": 31, "rocks": 2, "copper": 4,
		"shakes": 66, "brain": 88, "cred": 17, "junk": 3, "food": 2, "day": 8,
		"day_time": 120, "pete_paid": 199, "position": [9999, 200, -9999], "yaw": 1.2,
		"collected": {"cash_1": true, "dumpster_2": true, "fake": true}, "defeated": {"lurch": true}}
	var result: Dictionary = model.restore(v1)
	_check(result.ok and result.migrated_from == 1 and result.placement_reset and result.reason == "slice_world_replaced", "v1 returns explicit migration/relocation receipt")
	_check(model.p.x == 1050 and model.p.y == 840, "re-spaced slice placement never treated as full-world coordinates")
	_check(model.p.hp == 71 and model.p.cash == 31 and model.p.rocks == 2 and model.p.copper == 4 and model.p.cred == 17, "migration retains paid resources/stats without rewards")
	_check(model.p.inventory.size() == 2 and model.p.inventory[0].id == "junk" and model.p.inventory[0].q == 3 and model.p.inventory[1].q == 2, "slice counts become source item records")
	_check(model.p.inventory[0].get("migration_units") == true and model.p.inventory[1].get("migration_units") == true, "legacy quantities carry the explicit virtual-record marker")
	_check(model.s.day == 8 and model.s.dayTime == 0.5 and model.s.counters.peteCashToday == 199, "slice clock and daily merchant cap retained")
	_check(model.s.flags.introDone and model.s.quests.intro_smoke.done and model.events.is_empty(), "migrated save skips one-shot intro without paying it")
	var lurch_dead: bool = false
	for actor: Dictionary in model.npcs:
		if actor.get("id") == "lurch": lurch_dead = actor.get("dead", false)
	_check(lurch_dead and model.s.counters.alleyKills == 1 and model.p.cred == 17, "migrated Lurch defeat retained without another payout")
	_check(model.s.migration.slice_collected == ["cash_1", "dumpster_2"] and model.s.cashPilesCollected.is_empty(), "unmappable slice pickups stay explicit receipt, not unrelated full-world consumption")
	var again = GameState.new()
	again.restore(model.snapshot())
	_check(again.p.cash == 31 and again.s.migration == model.s.migration and again.events.is_empty(), "schema2 migration result roundtrips without repeating grants")
	_check(again.p.inventory == model.p.inventory, "schema2 preserves marked migrated inventory stacks")
	var malformed: Dictionary = model.snapshot()
	malformed.player.inventory = [{"id":"food","q":2,"migration_units":"true"},{"id":"license","q":9,"migration_units":true}]
	again.restore(malformed)
	_check(not again.p.inventory[0].has("migration_units") and not again.p.inventory[1].has("migration_units"), "migration marker requires strict boolean and an eligible legacy item")
