extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Session = preload("res://scripts/action_session.gd")
const Vendors = preload("res://scripts/vendors_core.gd")
const Memory = preload("res://scripts/memory_loop.gd")
var checks: int = 0
var failures: Array[String] = []

class Spatial:
	extends RefCounted
	var visible: bool = true
	var calls: int = 0
	func can_reach_target(_id: String) -> bool:
		calls += 1
		return visible

class Boss:
	extends RefCounted
	var owner_ref: WeakRef
	var available: bool = true
	var accepts: bool = true
	var starts: int = 0
	func _init(owner: RefCounted) -> void: owner_ref = weakref(owner)
	func can_start_tony() -> bool: return available
	func start_tony() -> bool:
		if not accepts: return false
		starts += 1
		var owner: RefCounted = owner_ref.get_ref()
		# Test double for the synchronous combat seam, not a production fight.
		owner.s.bossActive = true; owner.s.bossKind = "tony"; owner.s.bossPhase = 1
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_oracle()
	_test_inventory()
	_test_sessions()
	_test_live_guards()
	_test_boss_seam()
	_test_intro_and_loan()
	_test_migration()
	if failures.is_empty():
		print("3D ECONOMY GATE: PASS (%d checks; 23 source fixtures, inventory/migration, live action sessions and Tony/Pete/Yuri; scene/combat integration pending)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D ECONOMY GATE: FAIL (%d failures / %d checks)" % [failures.size(), checks])
		quit(1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)


func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 0.00001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not _same(a[index], b[index]): return false
		return true
	return a == b


func _at(game: RefCounted, id: String) -> void:
	for actor: Dictionary in game.npcs:
		if actor.get("id") == id:
			game.p.x = float(actor.x) + (float(actor.w) - float(game.p.w)) * 0.5
			game.p.y = float(actor.y) + (float(actor.h) - float(game.p.h)) * 0.5
			return


func _option(menu: Dictionary, id: String) -> Dictionary:
	for option: Dictionary in menu.get("options", []):
		if option.id == id: return option
	return {}


func _act(vendors: RefCounted, game: RefCounted, vendor: String, action: String) -> Dictionary:
	_at(game, vendor)
	var menu: Dictionary = vendors.open(vendor)
	if not menu.ok: return menu
	return vendors.select(menu.token, action)


func _event_count(game: RefCounted, kind: String) -> int:
	var count: int = 0
	for event: Dictionary in game.events:
		if event.kind == kind: count += 1
	return count


func _test_source_oracle() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/economy_reference.json"))
	_check(fixture is Dictionary and fixture.get("cases", []).size() == 23, "source economy fixtures available")
	if not fixture is Dictionary: return
	for test: Dictionary in fixture.cases:
		var game: RefCounted = State.new()
		var spatial: RefCounted = Spatial.new()
		var boss: RefCounted = Boss.new(game)
		var vendors: RefCounted = Vendors.new(game, spatial, null, boss)
		for key: String in test.setup.player:
			var value: Variant = test.setup.player[key]
			game.p[key] = value.duplicate(true) if value is Dictionary or value is Array else value
		for key: String in test.setup.flags: game.s.flags[key] = test.setup.flags[key]
		for key: String in test.setup.counters: game.s.counters[key] = test.setup.counters[key]
		game.s.quests.first_rock.done = test.setup.firstRock
		game.s.quests.intro_tony.available = false
		game.s.achievements = test.setup.achievements.duplicate()
		game.s.day = test.setup.day
		for operation: Array in test.operations:
			_at(game, operation[0])
			var menu: Dictionary = vendors.open(operation[0])
			_check(menu.ok, "oracle %s opens %s" % [test.id, operation[0]])
			if not menu.ok: continue
			var choice: Dictionary = _option(menu, operation[1])
			if not choice.is_empty() and choice.enabled: vendors.select(menu.token, operation[1])
			else: vendors.close()
		for key: String in test.expected.player:
			_check(_same(game.p[key], test.expected.player[key]), "oracle %s player.%s: %s != %s" % [test.id, key, str(game.p[key]), str(test.expected.player[key])])
		for key: String in test.expected.counters:
			_check(_same(game.s.counters.get(key, 0), test.expected.counters[key]), "oracle %s counter.%s" % [test.id, key])
		for key: String in test.expected.flags:
			_check(_same(game.s.flags.get(key), test.expected.flags[key]), "oracle %s flag.%s: %s != %s" % [test.id, key, str(game.s.flags.get(key)), str(test.expected.flags[key])])
		_check(game.s.quests.first_rock.done == test.expected.firstRock, "oracle %s first rock quest" % test.id)
		var achievements: Array = game.s.achievements.duplicate()
		achievements.sort()
		_check(_same(achievements, test.expected.achievements), "oracle %s achievements" % test.id)
		_check(game.s.bossActive == test.expected.boss.active and game.s.bossKind == test.expected.boss.kind and game.s.bossPhase == test.expected.boss.phase, "oracle %s boss handoff" % test.id)


func _test_inventory() -> void:
	var game: RefCounted = State.new()
	var inventory: RefCounted = Inventory.new(game)
	_check(inventory.append_item("junk", "a piece of junk", 7) and inventory.append_item("junk", "another piece", 1), "append preserves source variants and displayed quantities")
	_check(inventory.count_records("junk") == 2 and inventory.quantity("junk") == 8, "ordinary source q does not become extra sale records")
	_check(inventory.remove_first_record("junk") == 1 and inventory.quantity("junk") == 1, "ordinary removal consumes whole matching record")
	var before: Array = game.p.inventory.duplicate(true)
	for invalid: Variant in [0, -1, 1.5, NAN, INF, "2", true]:
		_check(not inventory.append_item("junk", "a piece of junk", invalid), "invalid item quantity rejected")
		_check(inventory.remove_records("junk", invalid) == 0, "invalid removal count rejected")
	_check(not inventory.append_item("invented", "made up") and game.p.inventory == before, "invalid inventory operations are atomic")
	_check(inventory.remove_records("junk", 2) == 0 and game.p.inventory == before, "insufficient removal does not partially consume")
	game.p.inventory.append({"id":"food", "n":"a can of food (unmarked)", "q":4, "migration_units":true})
	_check(inventory.count_records("food") == 4 and inventory.remove_first_record("food") == 1 and inventory.quantity("food") == 3, "marked stack acts as virtual source records")
	game.equip_tool("crowbar"); game.equip_tool("propane_torch")
	_check(inventory.owns_tool("crowbar") and inventory.owns_tool("propane_torch"), "tool ownership includes locker")
	_check(inventory.swap_locker().ok and game.p.equip.tool == "crowbar" and game.s.flags.peteToolLocker == "propane_torch", "free swap preserves both tools")
	var owner_ref: WeakRef = weakref(game)
	game = null
	_check(owner_ref.get_ref() == null and inventory.count_records("junk") == 0, "inventory holds only a weak owner")


func _test_sessions() -> void:
	var game: RefCounted = State.new()
	var spatial: RefCounted = Spatial.new()
	var session: RefCounted = Session.new(game, spatial)
	var actions: Array[String] = ["one", "two"]
	var first: Dictionary = session.begin("tony", actions)
	_check(first.ok and spatial.calls == 1, "opening invokes live spatial adapter")
	spatial.visible = false
	_check(not session.consume(first.token, "one").ok and spatial.calls == 2, "selection rechecks changed visibility")
	spatial.visible = true
	_check(not session.consume(first.token, "one").ok and spatial.calls == 2, "refused token is spent and cannot retry")
	first = session.begin("tony", actions)
	var replacement: Dictionary = session.begin("pete", actions)
	_check(not session.consume(first.token, "one").ok and session.consume(replacement.token, "one").ok, "new menu invalidates old menu token")
	first = session.begin("tony", actions)
	_check(not session.consume(first.token, "invented").ok and not session.consume(first.token, "one").ok, "unknown choice consumes session without execution")
	first = session.begin("tony", actions)
	game.fresh()
	_check(session.consume(first.token, "one").reason == "replaced_state", "fresh replaces session identity even with equal state values")
	first = session.begin("tony", actions)
	game.restore(game.snapshot())
	_check(session.consume(first.token, "one").reason == "replaced_state", "restore invalidates old action epoch")
	var other: RefCounted = Session.new(game, spatial)
	first = session.begin("tony", actions)
	var foreign: Dictionary = other.begin("tony", actions)
	_check(not session.consume(foreign.token, "one").ok and session.consume(first.token, "one").ok, "tokens cannot cross session instances")
	first = session.begin("tony", actions)
	spatial = null
	_check(not session.consume(first.token, "one").ok, "freed spatial adapter fails closed")
	var missing: RefCounted = Session.new(game, null)
	_check(not missing.begin("tony", actions).ok, "missing geometry adapter cannot open a menu")


func _test_live_guards() -> void:
	var game: RefCounted = State.new()
	var spatial: RefCounted = Spatial.new()
	var memory: RefCounted = Memory.new(game)
	var vendors: RefCounted = Vendors.new(game, spatial, memory)
	game.p.cash = 100
	_at(game, "tony")
	var menu: Dictionary = vendors.open("tony")
	game.p.cash = 1
	_check(not vendors.select(menu.token, "buy_rock").ok and game.p.cash == 1 and game.p.rocks == 0, "spending revalidates balance after opening")
	game.p.cash = 9; game.p.faction.street = 0
	menu = vendors.open("tony")
	game.p.faction.street = 10
	_check(vendors.select(menu.token, "buy_rock").ok and game.p.cash == 0 and game.p.rocks == 1, "price is recomputed from current faction at execution")
	_check(not vendors.select(menu.token, "buy_rock").ok and game.p.rocks == 1, "duplicate purchase cannot mint a second rock")
	game.p.cash = 100
	menu = vendors.open("tony")
	game.p.x += 60.0
	_check(not vendors.select(menu.token, "buy_rock").ok and game.p.cash == 100, "exact60px source reach boundary rejects despite adapter true")
	_at(game, "tony")
	menu = vendors.open("tony")
	spatial.visible = false
	_check(not vendors.select(menu.token, "buy_rock").ok and game.p.cash == 100, "wall appearing after menu open prevents purchase")
	spatial.visible = true; vendors.close()
	_at(game, "pete")
	menu = vendors.open("pete")
	for actor: Dictionary in game.npcs:
		if actor.id == "pete": actor.shopClosed = true
	_check(not vendors.select(menu.token, "buy_food").ok and game.p.cash == 100, "shop closure rechecked at selection")
	for actor: Dictionary in game.npcs:
		if actor.id == "pete": actor.shopClosed = false
	menu = vendors.open("pete")
	game.p.faction.scrap = -10
	_check(not vendors.select(menu.token, "buy_food").ok and game.p.cash == 100, "changed hated faction blocks entire Pete menu")
	game.p.faction.scrap = 0
	menu = vendors.open("pete")
	game.equip_tool("crowbar")
	_check(not vendors.select(menu.token, "buy_crowbar").ok and game.p.cash == 100, "tool acquired elsewhere cannot be bought again from stale menu")
	menu = vendors.open("pete")
	for actor: Dictionary in game.npcs:
		if actor.id == "pete": actor.dead = true
	_check(not vendors.select(menu.token, "sock").ok and game.p.cash == 100, "dead vendor cannot transact")
	_check(game.s.recognition.park.buy == 0 and game.s.recognition.laundromat.buy == 0, "core vendors do not invent venue recognition")
	game.s.mode = "paused"
	_check(not vendors.open("yuri").ok, "paused mode cannot open new transactions")


func _test_boss_seam() -> void:
	var game: RefCounted = State.new()
	var spatial: RefCounted = Spatial.new()
	game.p.cash = 10; game.p.tonyOffenses = 2; game.p.cred = 100
	var unavailable: RefCounted = Vendors.new(game, spatial)
	_check(not _act(unavailable, game, "tony", "short").ok and game.p.cash == 10 and game.p.tonyOffenses == 2, "missing boss adapter rejects third short before spending")
	_check(not _act(unavailable, game, "tony", "challenge").ok and not game.s.bossActive, "corner challenge cannot fake a boss")
	var boss: RefCounted = Boss.new(game)
	var vendors: RefCounted = Vendors.new(game, spatial, null, boss)
	boss.accepts = false
	_check(not _act(vendors, game, "tony", "short").ok and game.p.cash == 10 and game.p.tonyOffenses == 2 and boss.starts == 0, "synchronous rejected boss leaves vendor costs/offenses untouched")
	boss.accepts = true
	_check(_act(vendors, game, "tony", "short").ok and game.p.cash == 5 and game.p.tonyOffenses == 3 and boss.starts == 1 and game.s.bossActive, "successful boss handoff pays exactly once")
	_check(not vendors.open("tony").ok, "active boss refuses a second vendor session")


func _test_intro_and_loan() -> void:
	var game: RefCounted = State.new()
	var spatial: RefCounted = Spatial.new()
	var vendors: RefCounted = Vendors.new(game, spatial)
	game.s.quests.intro_tony.available = true
	var before_cred: int = int(game.p.cred)
	_act(vendors, game, "tony", "leave")
	_act(vendors, game, "tony", "leave")
	_check(game.p.cred == before_cred + 1 and game.s.quests.intro_tony.done and game.s.quests.intro_smoke.available, "Tony introduction grants once and opens smoke quest")
	_check(game.s.metVendors.count("tony") == 1 and _event_count(game, "quest_completed") == 1, "contact identity and intro quest dedupe")
	game.p.faction.scrap = 25; game.p.cred = 3
	game.s.counters.peteCashToday = 200
	_check(_act(vendors, game, "pete", "loan").ok and game.p.cash == 50 and game.p.cred == 2 and game.s.counters.peteCashToday == 200, "loan is outside daily outgoing cap")
	_check(not _act(vendors, game, "pete", "loan").ok and game.p.cash == 50, "loan cannot repeat within day")
	game.s.dayTime = 0.999
	game.tick(0.5, {"at_block":false})
	_check(_act(vendors, game, "pete", "loan").ok and game.p.cash == 100 and game.p.cred == 1, "natural dawn permits exactly one new loan")
	game.s.counters.peteCashToday = 199
	game.events.clear()
	_check(_act(vendors, game, "pete", "sock").ok and game.s.counters.peteCashToday == 200, "sock fallback reaches cap without inventory")
	_check(_event_count(game, "save_requested") == 0, "sock retains source lack of immediate save request")
	var cash: int = game.p.cash
	_check(not _act(vendors, game, "pete", "sock").ok and game.p.cash == cash, "empty Pete has no extra sock payment")
	game.p.cash = 3
	_check(_act(vendors, game, "pete", "buy_food").ok and game.p.cash == 0, "Pete food sale remains available at outgoing cap")


func _test_migration() -> void:
	var game: RefCounted = State.new()
	game.restore({"schema":1, "junk":5, "food":4, "pete_paid":198, "day":3})
	var spatial: RefCounted = Spatial.new()
	var vendors: RefCounted = Vendors.new(game, spatial)
	_check(_act(vendors, game, "pete", "sell_junk").ok and game.p.cash == 2 and vendors.inventory.count_records("junk") == 3, "migrated junk partial cap retains every unpaid unit")
	_check(vendors.inventory.remove_first_record("food") == 1 and vendors.inventory.count_records("food") == 3, "single migrated food use consumes one unit")
	var encoded: Variant = JSON.parse_string(JSON.stringify(game.snapshot()))
	var restored: RefCounted = State.new()
	restored.restore(encoded)
	var inventory: RefCounted = Inventory.new(restored)
	_check(inventory.count_records("junk") == 3 and inventory.count_records("food") == 3 and restored.p.cash == 2, "migration sale/use survives actual JSON serialization")
	_check(restored.p.inventory[0].migration_units and restored.p.inventory[1].migration_units, "remaining migration stacks retain compatibility marker")
	game.restore({"schema":1, "junk":1000000000, "food":1000000000})
	_check(vendors.inventory.count_records("junk") == 1000000000 and vendors.inventory.count_records("food") == 1000000000 and game.p.inventory.size() == 2, "migration keeps supported full quantities compact without added truncation")
	_check(vendors.inventory.remove_first_record("food") == 1 and vendors.inventory.count_records("food") == 999999999, "large migrated stack consumes in bounded work")
