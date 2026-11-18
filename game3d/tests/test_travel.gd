extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Travel = preload("res://scripts/travel_system.gd")
var checks: int = 0
var failures: Array[String] = []
var fixture: Dictionary = {}

class Spatial:
	extends RefCounted
	var visible: bool = true
	var placement: String = "exact"
	var drop_mode: String = "clear"
	var reach_calls: int = 0
	var placement_calls: int = 0
	func can_reach_target(_id: String) -> bool:
		reach_calls += 1
		return visible
	func clear_placement(body: Dictionary) -> Variant:
		placement_calls += 1
		if placement == "blocked": return null
		return Vector2(body.x,body.y) + (Vector2(1,0) if placement == "nearby" else Vector2.ZERO)
	func find_cart_drop(preferred: Vector2, _maximum: float) -> Variant:
		match drop_mode:
			"blocked": return null
			"far": return preferred+Vector2(51,0)
			"inside": return preferred
			"nan": return Vector2(NAN,0)
			_: return preferred+Vector2(25,0)

class Day:
	extends RefCounted
	var owner_ref: WeakRef
	var causes: Array[String] = []
	var accepts: bool = true
	func _init(owner: RefCounted) -> void: owner_ref = weakref(owner)
	func advance_sleep_day(kind: String) -> bool:
		if not accepts: return false
		causes.append(kind)
		owner_ref.get_ref()._advance_day()
		return true


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/travel_reference.json"))
	_check(decoded is Dictionary,"source travel fixture parses")
	if decoded is Dictionary:
		fixture = decoded
		_source_cases()
		_bus_cases()
		_gates_and_zones()
		_tokens_and_guards()
		_public_pinky_pass()
		_pending_safety()
		_cart_safety()
		_day_and_storage()
	if failures.is_empty():
		print("3D TRAVEL GATE: PASS (%d checks;%d source action cases,18 bus arrivals,12 combat boundaries; live scene/day integration pending)" % [checks,fixture.cases.size()])
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D TRAVEL GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks])
		quit(1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)


func _same(a: Variant, b: Variant) -> bool:
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


func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


func _setup(game: RefCounted, data: Dictionary, office: Dictionary = {}) -> void:
	for key: String in data.player: game.p[key] = _copy(data.player[key])
	for key: String in data.flags: game.s.flags[key] = _copy(data.flags[key])
	for key: String in data.counters: game.s.counters[key] = _copy(data.counters[key])
	game.s.hideoutStash = data.stash.duplicate(true)
	game.s.day = data.day; game.s.dayTime = data.dayTime; game.p.lifetime.dayCount = data.lifetimeDay
	game.s.achievements = data.achievements.duplicate()
	game.s.territoryHeat = data.territoryHeat; game.s.territoryGreeted = data.territoryGreeted.duplicate(); game.s.territoryZoneId = data.territoryZoneId
	game.s.phoneT = data.phoneT
	game.s.mode = "playing"
	if not office.is_empty(): game.s.office = office.duplicate(true)
	for actor: Dictionary in game.npcs: actor.hostile = false; actor.aggro = false
	game.rng_seed = 0x19c0ffee
	game.drain_events()


func _at(game: RefCounted, service: String) -> void:
	var location: Dictionary = {}
	if service in ["bus","pinky","mom","biggu"]:
		var id: String = "pinky" if service == "bus" else service
		for actor: Dictionary in game.npcs:
			if actor.id == id: location = actor; break
	elif service.contains("office"): location = game.definition("src/systems/campaigns.js","OFFICE_DOOR",{})
	else: location = game.definition("src/systems/daily_hideouts.js","HIDEOUT_DOORS",{})[service.get_slice(":",1)]
	game.p.x = location.x+location.w*0.5-game.p.w*0.5
	game.p.y = location.y+location.h*0.5-game.p.h*0.5


func _option(menu: Dictionary, id: String) -> Dictionary:
	for option: Dictionary in menu.get("options",[]):
		if option.id == id: return option
	return {}


func _act(travel: RefCounted, game: RefCounted, service: String, action: String, page: int = 0) -> Dictionary:
	_at(game,service)
	var menu: Dictionary = travel.open(service,page)
	if not menu.ok: return menu
	if _option(menu,action).is_empty(): travel.close(); return {"ok":false,"reason":"missing_option"}
	return travel.select(menu.token,action)


func _compare(game: RefCounted, travel: RefCounted, expected: Dictionary, label: String, cart_adapted: bool = false) -> void:
	for key: String in expected.player:
		_check(_same(game.p[key],expected.player[key]),"%s player.%s: %s != %s" % [label,key,str(game.p[key]),str(expected.player[key])])
	for key: String in expected.flags:
		_check(_same(game.s.flags.get(key),expected.flags[key]),"%s flag.%s" % [label,key])
	for key: String in expected.counters:
		_check(_same(game.s.counters.get(key,0),expected.counters[key]),"%s counter.%s" % [label,key])
	_check(_same(game.s.hideoutStash,expected.stash),label+" shared stash")
	_check(_same(game.s.day,expected.day),label+" day")
	_check(_same(game.s.dayTime,expected.dayTime),label+" day time")
	_check(_same(game.p.lifetime.dayCount,expected.lifetimeDay),label+" lifetime day")
	var achievements: Array = game.s.achievements.duplicate(); achievements.sort()
	_check(_same(achievements,expected.achievements),label+" achievements")
	for key: String in ["territoryHeat","territoryGreeted","territoryZoneId","phoneT"]:
		_check(_same(game.s.get(key),expected[key]),label+" "+key)
	var cart: Dictionary = travel.cart_record()
	if not cart_adapted:
		_check(_same(cart.x,expected.cart.x) and _same(cart.y,expected.cart.y),label+" cart source position")
	else:
		_check(Vector2(cart.x,cart.y).distance_to(Vector2(expected.cart.x,expected.cart.y)) <= 50.0,label+" explicitly adapted bounded cart drop")


func _source_cases() -> void:
	_check(fixture.counts.cases == 48 and fixture.cases.size() == 48,"48 independent source action cases including raw HP/stun counterexamples")
	for test: Dictionary in fixture.cases:
		var game := State.new()
		var spatial := Spatial.new()
		var day := Day.new(game)
		var travel := Travel.new(game,spatial,day)
		_setup(game,test.setup,test.office)
		for index: int in range(test.operations.size()):
			var operation: Dictionary = test.operations[index]
			match operation.kind:
				"menu":
					_at(game,operation.service)
					var menu: Dictionary = travel.open(operation.service,int(operation.get("page",0)))
					_check(menu.ok,"%s opens %s" % [test.id,operation.service])
					if not menu.ok: continue
					var choice: Dictionary = _option(menu,operation.action)
					_check(not choice.is_empty() == test.offered[index].present,"%s offer %s" % [test.id,operation.action])
					_check((not choice.is_empty() and choice.enabled) == test.offered[index].enabled,"%s enabled %s" % [test.id,operation.action])
					if not choice.is_empty() and choice.enabled:
						_check(travel.select(menu.token,operation.action).ok,"%s executes %s" % [test.id,operation.action])
					else: travel.close()
				"bus_tick": travel.tick_real(380.0)
				"dawn": game.s.dayTime = 0.0; game._advance_day(); travel.on_natural_dawn()
				"mount":
					var cart: Dictionary = travel.cart_record()
					game.p.x = cart.x-game.p.w*0.5+operation.get("offset",0); game.p.y = cart.y-game.p.h*0.5
					travel.interact_cart()
				"dismount": game.p.x = operation.x; game.p.y = operation.y; travel.interact_cart()
		_compare(game,travel,test.expected,test.id,test.id == "cart_source_dismount")
		if str(test.id).contains("sleep"):
			_check(day.causes.size() == (1 if test.setup.dayTime > 0.3 else 0),str(test.id)+" exact rollover adapter count")


func _bus_cases() -> void:
	_check(fixture.busCases.size() == 18,"all18 source bus arrivals")
	for test: Dictionary in fixture.busCases:
		var game := State.new()
		var spatial := Spatial.new()
		var travel := Travel.new(game,spatial)
		_setup(game,test.setup)
		for target: Dictionary in game.definition("src/dialogue/vendors_places.js","BUS_ZONE_TARGETS",[]):
			if target.flag != null: game.s.flags[target.flag] = true
		var result: Dictionary = _act(travel,game,"bus","ride:"+str(test.target.zoneId),test.page)
		_check(result.ok,"bus starts "+str(test.target.zoneId))
		_compare(game,travel,test.selected,"bus selected "+str(test.target.zoneId))
		var origin := Vector2(game.p.x,game.p.y)
		travel.tick_real(379.0)
		_check(Vector2(game.p.x,game.p.y) == origin,"bus waits379ms")
		travel.tick_real(1.0)
		_compare(game,travel,test.arrived,"bus arrived "+str(test.target.zoneId))
		var arrived := Vector2(game.p.x,game.p.y)
		travel.tick_real(1000.0)
		_check(Vector2(game.p.x,game.p.y) == arrived and spatial.placement_calls == 2,"bus arrival occurs once with2 live clearance checks")


func _gates_and_zones() -> void:
	var game := State.new()
	var spatial := Spatial.new()
	var travel := Travel.new(game,spatial)
	var known: Array[String] = []
	for target: Dictionary in travel.destinations(): known.append(target.zoneId)
	_check(_same(known,fixture.knownZones),"six always-known bus destinations")
	for gate: Dictionary in fixture.gatedZones:
		game.fresh(); game.s.flags[gate.flag] = true
		known.clear()
		for target: Dictionary in travel.destinations(): known.append(target.zoneId)
		_check(_same(known,gate.zones),"exact destination flag "+str(gate.flag))
	for test: Dictionary in fixture.busGates:
		game.fresh(); game.p.wanted = 0.0
		var center: Vector2 = game.player_center()
		game.npcs.clear()
		game.npcs.append({"id":"fixture","x":center.x+test.distance-12,"y":center.y-14,"w":24,"h":28,"hostile":test.variant != "aggro","aggro":test.variant == "aggro","dead":test.variant == "dead","isPet":test.variant == "pet"})
		_check(travel.combat_active() == test.active,"combat gate %s/%s" % [test.variant,test.distance])
	for test: Dictionary in fixture.zoneCases:
		game.p.x = test.point.x-game.p.w*0.5; game.p.y = test.point.y-game.p.h*0.5; game.p.faction = test.faction.duplicate()
		_check(travel._zone() == test.expected,"source overlapping-zone precedence")
	game.fresh(); game.p.inventory.append({"id":"bus_pass","n":"a bus pass","q":1}); game.s.mode = "playing"
	for actor: Dictionary in game.npcs: actor.hostile = false; actor.aggro = false
	_at(game,"bus")
	# The same-zone guard is independently checked at a destination, bypassing only NPC-distance in this private pure option query.
	game.p.x = 1050-game.p.w*0.5; game.p.y = 840-game.p.h*0.5
	_check(not _option({"options":travel._options("bus",0)},"ride:block").enabled,"bus rejects current zone")


func _public_pinky_pass() -> void:
	var game := State.new()
	var spatial := Spatial.new()
	var travel := Travel.new(game,spatial)
	game.s.mode = "playing"; game.p.cash = 100; game.p.charisma = 1
	_at(game,"pinky")
	spatial.visible = false
	_check(not travel.buy_pinky_pass().ok and game.p.cash == 100 and not travel.has_bus_pass(),"public Pinky purchase performs fresh LOS before mutation")
	spatial.visible = true; game.p.faction.street = -10
	_check(travel.buy_pinky_pass().get("reason") == "street_hated" and game.p.cash == 100,"public Pinky purchase keeps source street-hated refusal")
	game.p.faction.street = -9; game.p.cash = 19
	_check(travel.buy_pinky_pass().get("reason") == "insufficient_cash" and not travel.has_bus_pass(),"public Pinky purchase checks current cash")
	game.p.cash = 100; game.s.mode = "dialogue"
	var calls: int = spatial.reach_calls
	_check(travel.buy_pinky_pass().ok and game.p.cash == 80 and travel.has_bus_pass() and spatial.reach_calls == calls+1,"full-menu transaction uses fixed20 price and a live spatial answer")
	_check(game.s.mode == "dialogue","public transaction does not replace the caller menu")
	_check(not travel.buy_pinky_pass().ok and game.p.cash == 80 and travel.inventory.count_records("bus_pass") == 1,"public duplicate purchase cannot stack or spend twice")
	travel.inventory.remove_all("bus_pass"); game.s.mode = "playing"; game.p.stunT = 1
	game.p.hp = -3
	_check(travel.buy_pinky_pass().ok and game.p.cash == 60,"source negative HP and stun do not substitute for actual death lifecycle")
	travel.inventory.remove_all("bus_pass")
	game.p.stunT = 0; game.p.x += 60
	_check(not travel.buy_pinky_pass().ok and game.p.cash == 60,"public purchase cannot bypass strict60px reach")
	_at(game,"pinky")
	var menu: Dictionary = travel.open("pinky")
	game.p.faction.street = -10
	_check(not travel.select(menu.token,"buy_pass").ok and game.p.cash == 60,"legacy submenu delegates live hated gate to same transaction")


func _tokens_and_guards() -> void:
	var game := State.new()
	var spatial := Spatial.new()
	var travel := Travel.new(game,spatial)
	game.p.cash = 100; game.s.mode = "playing"
	_at(game,"pinky")
	var menu: Dictionary = travel.open("pinky")
	spatial.visible = false
	_check(not travel.select(menu.token,"buy_pass").ok and game.p.cash == 100,"wall introduced after menu blocks purchase")
	spatial.visible = true
	menu = travel.open("pinky")
	_check(not travel.select(menu.token,"made_up").ok,"unknown action consumes token")
	_check(not travel.select(menu.token,"buy_pass").ok,"consumed token cannot replay valid action")
	menu = travel.open("pinky"); game.p.cash = 0
	_check(not travel.select(menu.token,"buy_pass").ok and not travel.has_bus_pass(),"live resource recheck")
	game.p.cash = 100; menu = travel.open("pinky")
	game.fresh(); game.s.mode = "playing"; game.p.cash = 100; _at(game,"pinky")
	_check(not travel.select(menu.token,"buy_pass").ok and game.p.cash == 100,"fresh state invalidates menu epoch")
	menu = travel.open("pinky")
	_check(travel.select(menu.token,"buy_pass").ok,"purchase succeeds once")
	_check(not travel.select(menu.token,"buy_pass").ok and game.p.cash == 80,"purchase replay cannot double spend")
	game.s.flags.momHideoutOwned = true; _at(game,"hideout:mom")
	menu = travel.open("hideout:mom"); game.s.flags.momHideoutOwned = false
	var hp: float = game.p.hp
	_check(not travel.select(menu.token,"rest").ok and game.p.hp == hp,"ownership lost after opening")
	game.s.flags.momHideoutOwned = true; game.s.mode = "playing"; _at(game,"hideout:mom")
	game.p.x += 40.0
	_check(not travel.open("hideout:mom").ok,"hideout strict40px boundary")
	_at(game,"hideout:mom"); game.p.stunT = 1
	game.p.hp = -3
	menu = travel.open("hideout:mom")
	_check(menu.ok and travel.select(menu.token,"rest").ok and game.p.hp == 9,"source household rest recovers raw negative HP while stunned")
	game.p.stunT = 0; game.s.mode = "paused"
	_check(not travel.open("pinky").ok,"pause blocks action")
	game.s.mode = "playing"
	_check(not travel.open("invented_house").ok,"unknown service rejected")
	game.s.office.owned = true; _at(game,"office:cot")
	_check(not travel.open("office:cot").ok,"office cot upgrade required")
	_check(not travel.open("chest:office").ok,"office locker upgrade required")
	game.s.bossActive = true; game.s.bossKind = "tony"; game.p.hp = 40
	_at(game,"hideout:mom")
	menu = travel.open("hideout:mom")
	_check(menu.ok and travel.select(menu.token,"rest").ok and game.p.hp == 52,"ordinary Tony fight does not add a source-absent hideout lock")
	game.s.bossKind = "kingdom"
	_check(not travel.open("hideout:mom").ok and game.p.hp == 52,"source kingdom blanket interaction lock remains")


func _bus_ready(game: RefCounted, travel: RefCounted) -> void:
	game.s.mode = "playing"; game.p.wanted = 0
	for actor: Dictionary in game.npcs: actor.hostile = false; actor.aggro = false
	game.p.inventory = [{"id":"junk","n":"a piece of junk","q":1},{"id":"bus_pass","n":"a bus pass","q":9},{"id":"food","n":"a can of food (unmarked)","q":1}]
	game.s.flags.busPassUsedDay = 0
	_at(game,"bus")
	travel.reset_session("cold")


func _pending_safety() -> void:
	var game := State.new()
	var spatial := Spatial.new()
	var travel := Travel.new(game,spatial)
	_bus_ready(game,travel)
	var before: Array = game.p.inventory.duplicate(true)
	spatial.placement = "nearby"
	_check(not _act(travel,game,"bus","ride:block").ok and _same(game.p.inventory,before),"bus refuses nearest-spawn substitution")
	spatial.placement = "blocked"
	_check(not _act(travel,game,"bus","ride:block").ok and game.s.flags.busPassUsedDay == 0,"blocked departure does not spend stamp")
	spatial.placement = "exact"
	_check(_act(travel,game,"bus","ride:block").ok,"pending safety bus starts")
	var at: Vector2 = game.player_center()
	_check(not travel.open("pinky").ok,"second pending travel/menu blocked")
	spatial.placement = "blocked"; travel.tick_real(380)
	_check(game.player_center() == at and _same(game.p.inventory,before) and game.s.flags.busPassUsedDay == 0,"new obstruction refunds exact record/index and stamp")
	travel.tick_real(380)
	_check(_same(game.p.inventory,before),"refund is one-shot")
	spatial.placement = "exact"
	_check(_act(travel,game,"bus","ride:block").ok,"second independent bus starts")
	game.fresh(); game.s.mode = "playing"
	var fresh: Dictionary = game.snapshot()
	travel.tick_real(380)
	_check(_same(game.snapshot(),fresh),"state replacement receives neither refund nor relocation")
	_bus_ready(game,travel)
	_check(_act(travel,game,"bus","ride:block").ok,"death cancellation bus starts")
	game.die(); travel.cancel_travel("death"); var respawn: Vector2 = game.player_center()
	travel.tick_real(1000)
	_check(game.player_center() == respawn and travel.has_bus_pass(),"runtime death hook cancels pending ride after recovered HP")
	_bus_ready(game,travel); game.p.hp = -3; game.p.stunT = 500
	_check(_act(travel,game,"bus","ride:block").ok,"raw negative HP and stun permit source bus departure")
	travel.tick_real(380)
	_check(game.player_center().distance_to(Vector2(1050,840)) < 0.0001 and not travel.has_bus_pass() and game.p.hp == -3,"raw HP does not cancel committed source bus callback")
	_bus_ready(game,travel)
	_check(_act(travel,game,"bus","ride:block").ok,"explicit dead-mode fallback ride starts")
	var dead_origin: Vector2 = game.player_center()
	game.s.mode = "dead"; travel.tick_real(380)
	_check(game.player_center() == dead_origin and travel.has_bus_pass(),"actual dead mode cancels and refunds instead of arriving")
	_bus_ready(game,travel)
	_check(_act(travel,game,"bus","ride:block").ok,"wall-clock modal bus starts")
	game.s.mode = "paused"; travel.tick_real(379); var prior: Vector2 = game.player_center()
	travel.tick_real(NAN); travel.tick_real(-1); travel.tick_real(240001)
	_check(game.player_center() == prior,"invalid wall-time deltas cannot force travel")
	travel.tick_real(1)
	_check(game.player_center().distance_to(Vector2(1050,840)) < 0.0001,"380ms timer can complete while paused like source setTimeout")


func _cart_safety() -> void:
	var game := State.new()
	var spatial := Spatial.new()
	var travel := Travel.new(game,spatial)
	game.s.mode = "playing"; game.p.cartMounted = true; game.apply_equip_stats(); game.p.hp = 109
	for invalid: String in ["blocked","far","inside","nan"]:
		spatial.drop_mode = invalid
		_check(not travel.interact_cart().ok and game.p.cartMounted and game.p.hp == 109,"invalid cart drop atomic "+invalid)
	spatial.drop_mode = "clear"
	var result: Dictionary = travel.interact_cart()
	_check(result.ok and not game.p.cartMounted and game.p.maxHp == 100 and game.p.hp == 100,"valid parked drop clamps maxHP without healing")
	var position: Dictionary = travel.cart_record()
	_check(Vector2(position.x,position.y).distance_to(result.preferred_source_drop) <= 50,"cart placement bound")
	game.p.x = position.x-game.p.w*0.5; game.p.y = position.y-game.p.h*0.5
	spatial.visible = false
	_check(not travel.interact_cart().ok,"cart mounting requires live visibility")
	spatial.visible = true
	_check(travel.interact_cart().ok and game.p.cartMounted,"mounted unique cart")
	var saved: Dictionary = game.snapshot()
	_check(not saved.state.has("travelRuntime"),"cart location excluded from durable save")
	game.restore(saved); travel.reset_session("restore",position)
	_check(_same(travel.cart_record().x,position.x) and game.p.cartMounted,"same-process restore retains cart location and saved mount")
	game.fresh(); travel.reset_session("fresh")
	_check(travel.cart_record().x == fixture.saveLifecycle.fresh.cart.x and travel.cart_record().y == fixture.saveLifecycle.fresh.cart.y and not game.p.cartMounted,"fresh resets unique cart exactly")
	_check(fixture.saveLifecycle.loaded.cart.x == 2300 and fixture.saveLifecycle.loaded.cart.y == 2400 and fixture.saveLifecycle.loaded.savedCartKeys.is_empty(),"source oracle confirms unsaved mutable cart")


func _day_and_storage() -> void:
	var game := State.new()
	var spatial := Spatial.new()
	var travel := Travel.new(game,spatial)
	game.s.mode = "playing"; game.s.flags.momHideoutOwned = true; game.s.dayTime = 0.8
	game.p.hp = 20; _at(game,"hideout:mom")
	var before: Dictionary = game.snapshot()
	var result: Dictionary = _act(travel,game,"hideout:mom","sleep")
	_check(not result.ok and result.reason == "missing_day_adapter" and _same(game.snapshot(),before),"rollover without day authority rejects atomically")
	game.s.dayTime = 0.3
	_check(_act(travel,game,"hideout:mom","sleep").ok and game.s.day == 1,"nonrollover sleep needs no day increment dependency")
	var day := Day.new(game)
	travel = Travel.new(game,spatial,day); day.accepts = false; game.s.dayTime = 0.9
	before = game.snapshot()
	_check(not _act(travel,game,"hideout:mom","sleep").ok and _same(game.snapshot(),before),"day adapter rejection atomic")
	game.s.day = 9; game.s.flags.momBusPassDay = 0; game.p.faction.spiritual = 10; game.p.cash = 60
	travel.on_natural_dawn(); var after: Dictionary = game.snapshot(); travel.on_natural_dawn()
	_check(_same(game.snapshot(),after) and game.p.cash == 30,"duplicate dawn hook cannot charge twice")
	game.p.rocks = 1; game.p.copper = 1; game.p.cash = 10
	_check(_act(travel,game,"chest:mom","deposit:rocks").ok,"stash rock deposit")
	_check(_act(travel,game,"chest:mom","deposit:copper").ok,"stash copper deposit")
	_check(_act(travel,game,"chest:mom","deposit:cash").ok,"stash cash deposit")
	game.s.hideoutStash.items.append({"id":"junk","n":"a piece of junk","q":1})
	var stash: Dictionary = game.s.hideoutStash.duplicate(true)
	game.die(); _check(_same(game.s.hideoutStash,stash),"death preserves shared stash")
	game.arrest(); _check(_same(game.s.hideoutStash,stash),"arrest preserves shared stash")
	var save: Dictionary = game.snapshot(); game.restore(save); travel.reset_session("restore")
	_check(_same(game.s.hideoutStash,stash),"codec preserves shared stash and existing item records")
	game.s.flags.momHideoutOwned = true; game.s.mode = "playing"; _at(game,"chest:mom")
	var menu: Dictionary = travel.open("chest:mom")
	_check(menu.options.size() == 7 and _option(menu,"deposit:items").is_empty(),"source chest has six resource moves and no invented item actions")
	_check(travel.select(menu.token,"back").get("service") == "hideout:mom","chest close returns to owned hideout")
