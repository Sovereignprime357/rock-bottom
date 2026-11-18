extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_core_cycle()
	_test_transactions()
	_test_daily_guards()
	_test_withdrawal()
	_test_failure_and_save()
	_test_bad_save()
	if failures.is_empty():
		print("3D SIMULATION GATE: PASS (%d checks; transactions, exact 18/8 boundary, daily governors, death and save normalization)" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("3D SIMULATION GATE: FAIL (%d failures / %d checks)" % [failures.size(), checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.00001, "%s: got %.8f, expected %.8f" % [message, actual, expected])


func _test_core_cycle() -> void:
	var sim = Simulation.new()
	_check(not sim.transact("buy_rock").ok, "empty pocket cannot buy")
	_check(not sim.transact("smoke").ok, "zero rocks cannot smoke")
	_check(sim.rocks == 0 and sim.cash == 0, "refusal cannot subtract below zero")
	sim.cash = 10
	_check(sim.transact("buy_rock").ok, "ten dollars purchases a real rock")
	_check(sim.cash == 0 and sim.rocks == 1, "purchase consumes ten dollars exactly")
	_check(not sim.transact("buy_rock").ok, "duplicate purchase rechecks cash")
	sim.shakes = 70.0
	_check(not sim.transact("smoke", "park").ok, "unported venues do not grant permission")
	_check(sim.transact("smoke", "block").ok, "crate smoke succeeds")
	_check(sim.rocks == 0 and sim.cred == 1, "smoke consumes and credits once")
	_near(sim.shakes, 20.0, "real rock shakes relief")
	_near(sim.brain, 96.0, "real rock brain cost")
	_near(sim.speed_multiplier(), 1.8, "high speed")
	_near(sim.damage(), 27.0, "high punch damage")
	sim.rocks = 1
	_check(not sim.transact("smoke").ok and sim.rocks == 1, "duplicate smoke while high spends nothing")
	# A modal pause means the scene never ticks the simulation. Inspection and
	# snapshotting must not consume time or let a second transaction through.
	var before_pause: Dictionary = sim.snapshot(Vector3.ZERO, 0.0)
	for ignored: int in range(10):
		sim.snapshot(Vector3.ZERO, 0.0)
	_check(before_pause == sim.snapshot(Vector3.ZERO, 0.0), "paused inspection does not mutate state")
	_near(sim.high_remaining, 18.0, "pause retains full high")
	var events: Array[String] = sim.tick(17.9)
	_check(events.is_empty(), "no premature crash")
	_near(sim.high_remaining, 0.1, "seventeen point nine seconds leaves point one")
	events = sim.tick(0.1)
	_check(events == ["crash"], "one crash event at eighteen seconds")
	_near(sim.high_remaining, 0.0, "high is exhausted")
	_near(sim.crash_remaining, 8.0, "crash begins at eight seconds")
	_near(sim.shakes, 64.4, "crash boundary adds thirty shakes")
	_near(sim.speed_multiplier(), 0.5, "crash speed")
	_near(sim.damage(), 18.0, "crash has normal damage")
	events = sim.tick(7.9)
	_check(events.is_empty(), "crash cannot end early")
	events = sim.tick(0.1)
	_check(events == ["crash_end"], "one crash-end event")
	_near(sim.speed_multiplier(), 1.0, "normal speed resumes")
	sim.transact("smoke")
	events = sim.tick(20.0)
	_check(events == ["crash"], "oversized step crosses high once")
	_near(sim.crash_remaining, 6.0, "oversized step spends leftover in crash")
	events = sim.tick(6.0)
	_check(events == ["crash_end"], "oversized transition still totals twenty-six seconds")
	sim.rocks = 1
	sim.transact("smoke")
	events = sim.tick(26.0)
	_check(events == ["crash", "crash_end"], "single step handles both exact boundaries")
	var stable: Dictionary = sim.snapshot(Vector3.ZERO, 0.0)
	_check(sim.tick(-1.0).is_empty() and sim.tick(NAN).is_empty() and sim.tick(INF).is_empty(), "invalid time steps rejected")
	_check(stable == sim.snapshot(Vector3.ZERO, 0.0), "invalid delta cannot mutate")


func _test_transactions() -> void:
	var sim = Simulation.new()
	_check(not sim.transact("collect_cash", "made_up").ok, "unknown collectible rejected")
	for id: String in ["cash_1", "cash_2", "cash_3"]:
		_check(sim.transact("collect_cash", id).ok, "known cash find accepted")
		_check(not sim.transact("collect_cash", id).ok, "cash cannot be collected twice")
	_check(sim.cash == 12, "fixed cash finds total twelve")
	_check(sim.transact("collect_copper", "copper_1").ok, "copper find succeeds")
	_check(not sim.transact("collect_copper", "copper_1").ok and sim.copper == 1, "copper cannot duplicate")
	_check(sim.transact("sell_copper_yuri").ok and sim.cash == 37, "yuri pays twenty-five")
	_check(not sim.transact("sell_copper_yuri").ok, "yuri refuses absent copper")
	_check(sim.transact("dumpster_cash", "dumpster_1").ok, "dumpster cash choice succeeds")
	_check(not sim.transact("dumpster_junk", "dumpster_1").ok, "a second dumpster choice cannot pay")
	_check(sim.transact("dumpster_junk", "dumpster_2").ok and sim.junk == 3, "junk choice pays three pieces")
	_check(sim.transact("sell_junk").ok and sim.junk == 0 and sim.pete_paid == 3, "junk sale pays per consumed item")
	_check(sim.transact("dumpster_food", "dumpster_3").ok and sim.food == 1, "food choice pays one can")
	_check(not sim.transact("eat_food").ok and sim.food == 1, "full hp does not waste food")
	sim.hp = 90.0
	_check(sim.transact("eat_food").ok and sim.food == 0, "hurt player can eat")
	_near(sim.hp, 100.0, "food healing clamps")
	_check(sim.transact("buy_food").ok and sim.food == 1, "food purchase")
	var before_unknown: Dictionary = sim.snapshot(Vector3.ZERO, 0.0)
	_check(not sim.transact("invent_currency").ok, "unknown action rejected")
	_check(before_unknown == sim.snapshot(Vector3.ZERO, 0.0), "unknown action cannot mutate")


func _test_daily_guards() -> void:
	var sim = Simulation.new()
	for ignored: int in range(200):
		sim.transact("pawn_sock")
	_check(sim.pete_paid == 200 and sim.cash == 200, "sock fallback capped at two hundred")
	_check(not sim.transact("pawn_sock").ok, "capped sock refusal")
	sim.junk = 3
	sim.copper = 1
	_check(not sim.transact("sell_junk").ok and sim.junk == 3, "cap preserves unsold junk")
	_check(not sim.transact("sell_copper_pete").ok and sim.copper == 1, "cap preserves unsold copper")
	sim.pete_paid = 199
	_check(sim.transact("sell_junk").ok and sim.junk == 2 and sim.pete_paid == 200, "partial junk sale consumes paid pieces only")
	sim.pete_paid = 199
	_check(sim.transact("sell_copper_pete").ok and sim.copper == 0 and sim.pete_paid == 200, "pete partial copper payout retains v22 cap ordering")
	_check(sim.transact("defeat_lurch").ok and sim.cred == 3, "lurch pays three cred")
	_check(not sim.transact("defeat_lurch").ok and sim.cred == 3, "lurch pays once per day")
	sim.transact("collect_cash", "cash_1")
	var events: Array[String] = sim.tick(239.9)
	_check(not events.has("day") and sim.collected.has("cash_1"), "governors survive until dawn")
	events = sim.tick(0.1)
	_check(events.has("day") and sim.day == 2, "day advances at exact boundary")
	_check(sim.pete_paid == 0 and sim.collected.is_empty() and sim.defeated.is_empty(), "dawn clears daily governors together")
	_check(sim.transact("pawn_sock").ok and sim.transact("collect_cash", "cash_1").ok, "earning remains possible after dawn")
	_check(sim.transact("defeat_lurch").ok, "new day permits encounter reward")
	sim.tick(481.0)
	_check(sim.day == 4, "multiple elapsed days normalize without repeated rewards")
	_near(sim.day_time, 1.0, "multiple day remainder")


func _test_failure_and_save() -> void:
	var sim = Simulation.new()
	sim.cash = 50
	sim.cred = 15
	sim.rocks = 2
	sim.transact("smoke")
	_check(not sim.hurt(-9.0) and not sim.hurt(NAN), "invalid damage ignored")
	_near(sim.hp, 100.0, "invalid damage cannot heal or kill")
	_check(sim.hurt(200.0), "lethal damage reports death")
	_near(sim.hp, 60.0, "death recovery hp")
	_near(sim.shakes, 30.0, "death recovery shakes")
	_check(sim.cred == 6 and sim.cash == 50 and sim.rocks == 1, "death penalty preserves inventory and money")
	_check(sim.high_remaining == 0.0 and sim.crash_remaining == 0.0, "death clears transient timers")
	sim.tick(5.0, false, true)
	_near(sim.hp, 90.0, "block heals six hp per active second")
	sim.shakes = 20.0
	sim.tick(1.0, true)
	_near(sim.shakes, 32.8, "moving sprint adds twelve extra shakes per second")
	sim.transact("collect_cash", "cash_1")
	sim.transact("defeat_lurch")
	sim.transact("pawn_sock")
	sim.transact("smoke")
	var saved: Dictionary = sim.snapshot(Vector3(8.0, 0.0, -12.0), 0.7)
	_check(not saved.has("high_remaining") and not saved.has("crash_remaining"), "transient timers not persisted")
	var encoded: String = JSON.stringify(saved)
	var decoded: Dictionary = JSON.parse_string(encoded)
	var loaded = Simulation.new()
	var placement: Dictionary = loaded.restore(decoded)
	_check(loaded.cash == sim.cash and loaded.cred == sim.cred and loaded.rocks == sim.rocks, "resources survive real JSON roundtrip")
	_check(loaded.collected.has("cash_1") and loaded.defeated.has("lurch") and loaded.pete_paid == 1, "daily governors survive JSON roundtrip")
	_check(loaded.high_remaining == 0.0 and loaded.crash_remaining == 0.0, "fresh load resets timers")
	_check(placement.position == Vector3(8.0, 0.0, -12.0), "position roundtrip")
	_near(float(placement.yaw), 0.7, "yaw roundtrip")
	saved.collected.clear()
	_check(sim.collected.has("cash_1"), "snapshot does not alias live collection ledger")


func _test_withdrawal() -> void:
	var sim = Simulation.new()
	sim.shakes = 99.2
	sim.tick(1.0)
	_near(sim.shakes, 100.0, "withdrawal reaches cap")
	_near(sim.hp, 100.0, "no damage before time spent at cap")
	sim.tick(10.0)
	_near(sim.hp, 92.8, "withdrawal damage is point seven two per second")
	var sliced = Simulation.new()
	sliced.shakes = 99.2
	for ignored: int in range(660):
		sliced.tick(1.0 / 60.0)
	_near(sliced.hp, sim.hp, "withdrawal is frame-rate independent")
	sim.hp = 50.0
	sim.tick(1.0, false, true)
	_near(sim.hp, 55.28, "block recovery offsets withdrawal continuously")
	sim.hp = 0.5
	var events: Array[String] = sim.tick(1.0)
	_check(events.has("death"), "withdrawal death signals caller to relocate")
	_near(sim.hp, 60.0, "withdrawal uses same death recovery")
	_near(sim.shakes, 30.0, "withdrawal death resets shakes")


func _test_bad_save() -> void:
	var sim = Simulation.new()
	var placement: Dictionary = sim.restore({"schema": 900, "cash": 8000})
	_check(sim.cash == 0 and placement.position == Simulation.SPAWN, "unknown schema resets safely")
	placement = sim.restore({
		"schema": 1, "cash": -5, "rocks": "900", "hp": 0, "brain": INF,
		"shakes": NAN, "cred": true, "copper": 2.9, "food": 1e20,
		"pete_paid": 999, "day": -2, "day_time": 999999.0,
		"collected": {"cash_1": true, "cash_2": 1, "fabricated": true},
		"defeated": {"lurch": true, "tony": true},
		"position": [9999.0, 500.0, -9999.0], "yaw": INF,
		"high_remaining": 999, "crash_remaining": 999,
	})
	_check(sim.cash == 0 and sim.rocks == 0 and sim.cred == 0, "negative/string/bool resources rejected")
	_check(sim.copper == 2 and sim.food == Simulation.RESOURCE_LIMIT, "fractional and excessive inventory normalized")
	_near(sim.hp, 60.0, "dead save loads recoverable")
	_near(sim.brain, 100.0, "infinite stat defaults")
	_near(sim.shakes, 20.0, "nan stat defaults")
	_check(sim.day == 1 and sim.day_time < 240.0 and sim.pete_paid == 200, "clocks and cap normalized")
	_check(sim.collected == {"cash_1": true} and sim.defeated == {"lurch": true}, "only known exact boolean ledger entries retained")
	_check(placement.position == Vector3(40.0, 0.0, -36.0), "position clamped to world and ground")
	_near(float(placement.yaw), 0.0, "invalid yaw defaults")
	placement = sim.restore({"schema": 1, "position": [NAN, 0, 4], "collected": "oops", "defeated": 9})
	_check(placement.position == Simulation.SPAWN and sim.collected.is_empty() and sim.defeated.is_empty(), "malformed geometry and ledgers default safely")
