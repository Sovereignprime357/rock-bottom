extends SceneTree
const Runtime = preload("res://scripts/full_runtime.gd")
class Spatial extends RefCounted:
	var visible: bool = true
	var calls: Array[String] = []
	var blocked: bool = false
	func can_reach_target(id: String) -> bool:
		calls.append(id)
		return visible
	func can_use_zone(_id: String) -> bool: return visible
	func move_body(body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary:
		return {"position":Vector2(body.x,body.y) if blocked else intended,"blocked":blocked}
	func clear_placement(body: Dictionary) -> Variant:
		return Vector2(body.x,body.y) if not blocked else null
	func can_hit(_from: Vector2,_to: Vector2,_source: String,_target: String) -> bool: return visible
	func sweep_projectile(start: Vector2,end: Vector2,_radius: float) -> Dictionary:
		return {"blocked":blocked,"fraction":0.0 if blocked else 1.0,"position":start if blocked else end}
class DaySpatial extends Spatial:
	func stage_cash_pickup(center: Vector2,_maximum: float) -> Variant: return center if not blocked else null
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _put(runtime: RefCounted,point: Vector2) -> void:
	runtime.p.x = point.x-float(runtime.p.w)*0.5
	runtime.p.y = point.y-float(runtime.p.h)*0.5
func _actor(runtime: RefCounted,id: String) -> Dictionary:
	for actor: Dictionary in runtime.state.npcs:
		if actor.id == id: return actor
	return {}
func _run() -> void:
	_test_intro_chain()
	_test_boundaries()
	_test_pickups()
	_test_movement()
	_test_actor_and_travel_composition()
	_test_resident_composition()
	_test_quest_ordering()
	_test_street_robbery_and_restore()
	_test_communications_composition()
	_test_day_composition()
	_test_border_clock()
	_test_wall_markings_composition()
	_test_profile_workload()
	if failures.is_empty():
		print("3D FULL RUNTIME GATE: PASS (%d checks; composed intro/vendor/loop/save chain, pause, stale capabilities and physical access boundaries; full scene pending)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FULL RUNTIME GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks])
		quit(1)

func _test_profile_workload() -> void:
	var spatial := Spatial.new(); var runtime := Runtime.new(spatial)
	runtime.fresh(); runtime.profile_enabled = true
	var control_spatial := Spatial.new(); var control := Runtime.new(control_spatial)
	control.fresh()
	runtime.advance(0.05); control.advance(0.05)
	_check(runtime.profile_calls.get("movement",0) == 3 and runtime.profile_calls.get("progression",0) == 3,"50ms reports three actual source world subdivisions")
	_check(is_equal_approx(runtime.last_advanced_ms,50.0),"active diagnostic retains exact supplied time")
	_check(runtime.snapshot() == control.snapshot(),"diagnostic counters cannot mutate saved source state or RNG")
	runtime.set_mode("paused"); runtime.advance(0.05)
	_check(runtime.profile_calls.is_empty() and runtime.last_advanced_ms == 0.0,"paused advance clears diagnostic work")
	runtime.set_mode("playing"); runtime.s.hitPause = 100.0; runtime.advance(0.05)
	_check(runtime.profile_calls.is_empty() and runtime.last_advanced_ms == 0.0,"hitpause does not claim active stage work")
	runtime.advance(NAN)
	_check(runtime.profile_calls.is_empty(),"invalid advance retains no stale workload")
	runtime.profile_enabled = false; runtime.s.hitPause = 0.0; runtime.advance(0.05)
	_check(runtime.profile_calls.is_empty(),"normal release leaves counters disabled")

func _test_wall_markings_composition() -> void:
	var spatial := Spatial.new()
	var runtime := Runtime.new(spatial)
	_check(runtime.fresh() and runtime.wall_markings.inspect().bound,"fresh runtime prepares one source wall-layout owner")
	_check(runtime.wall_markings.inspect().draws > 0 and runtime.s.graffiti.size() >= 12 and runtime.s.graffiti.size() <= 18,"fresh wall layouts consume shared RNG instead of replaying the captured fixture")
	var saved: Dictionary = runtime.snapshot()
	var draws: int = runtime.wall_markings.inspect().draws
	_check(runtime.restore(saved) and runtime.s.graffiti == saved.state.graffiti and runtime.s.posters == saved.state.posters,"real restore preserves valid measured wall layouts")
	_check(runtime.wall_markings.inspect().draws == draws,"valid restored layouts consume no wall generation draws")
	var oversized: Dictionary = saved.duplicate(true)
	oversized.state.graffiti = []
	for index: int in range(1025): oversized.state.graffiti.append(saved.state.graffiti[0].duplicate(true))
	var nested: Dictionary = {"end":"too deep"}
	for depth: int in range(12): nested = {"next":nested}
	var wide: Dictionary = {}
	for index: int in range(513): wide[str(index)] = index
	var row: Dictionary = {}
	for index: int in range(32): row[str(index)] = index
	var bulk: Array = []
	for index: int in range(1025): bulk.append(row.duplicate())
	oversized.state.posters = [{"text":"p".repeat(4097),"nested":nested,"wide":wide,"bulk":bulk}]
	var normalized := Runtime.State.new()
	_check(normalized.restore(oversized).ok,"stress save passes the real State codec")
	_check(normalized.s.graffiti.size() == 1024 and normalized.s.posters[0].text.length() == 4096 and normalized.s.posters[0].wide.size() == 512 and normalized.s.posters[0].bulk.size() < 1024,"stress fixture reaches array/string/dictionary and nested total-budget limits")
	_check(runtime.restore(oversized) and runtime.s.graffiti == normalized.s.graffiti and runtime.s.posters == normalized.s.posters,"Runtime cannot replace normalized wall records with raw oversized or deeply nested data")
	_check(runtime.wall_markings.inspect().draws == draws,"bounded valid layouts retain source zero-draw reuse")
	_check(runtime.wall_markings.prepare_start("restore",oversized.state) and runtime.s.graffiti == normalized.s.graffiti and runtime.s.posters == normalized.s.posters,"direct wall-owner restore uses the same codec and full nested budget")
	_check(oversized.state.graffiti.size() == 1025 and oversized.state.posters[0].text.length() == 4097,"normalization cannot mutate the supplied raw save")
	for value: Variant in [null,[],{"invalid":"layout"}]:
		var malformed: Dictionary = saved.duplicate(true)
		malformed.state.graffiti = value; malformed.state.posters = value
		var builds: int = runtime.wall_markings.inspect().graffiti_builds
		_check(runtime.restore(malformed) and runtime.wall_markings.inspect().graffiti_builds == builds+1,"explicit null/empty/malformed wall fields follow source rebuild semantics")
	draws = runtime.wall_markings.inspect().draws
	var legacy: Dictionary = saved.duplicate(true); legacy.state.erase("graffiti"); legacy.state.erase("posters")
	_check(runtime.restore(legacy) and runtime.wall_markings.inspect().draws > draws,"missing raw save fields regenerate rather than inheriting fixed exported defaults")
	var before: Dictionary = runtime.snapshot()
	_check(not runtime.restore({"schema":999}) and runtime.snapshot() == before,"rejected save envelope cannot regenerate or replace live wall layouts")
	runtime.set_mode("paused"); draws = runtime.wall_markings.inspect().draws
	_check(runtime.wall_markings.before_world_draw() and runtime.wall_markings.inspect().draws == draws,"valid walls remain stable through paused world draws")
	_check(runtime.restore({"schema":1,"state":"legacy unrelated value"}) and runtime.wall_markings.inspect().bound,"schema1 migration ignores unrelated legacy state fields when rebuilding wall layouts")

func _test_border_clock() -> void:
	var spatial := Spatial.new()
	var runtime := Runtime.new(spatial)
	runtime.fresh(); runtime.s.flags.introDone = true
	runtime.s.lastZoneId = null; runtime.s.territoryZoneId = null; runtime.s.territoryT = 2000.0
	runtime.advance(1.0/60.0)
	var initial: String = runtime.progression.current_zone().id
	_check(runtime.s.lastZoneId == initial and runtime.s.borderGlowT == 0.0,"first actual territory tick initializes border identity without flashing")
	for zone: Dictionary in runtime.Content.load_content().world.zones:
		_put(runtime,Vector2(zone.x+zone.w*0.5,zone.y+zone.h*0.5))
		if runtime.progression.current_zone().get("id") != initial: break
	runtime.s.territoryT = 2000.0
	runtime.advance(1.0/60.0)
	_check(runtime.s.borderGlowT == 600.0 and runtime.s.lastZoneId == runtime.s.territoryZoneId,"real territory change arms source border after the ticker")
	runtime.set_mode("paused"); runtime.advance(0.1)
	_check(runtime.s.borderGlowT == 600.0,"paused runtime freezes border source timer")
	runtime.set_mode("playing"); runtime.s.hitPause = 5.0; runtime.advance(1.0/60.0)
	_check(runtime.s.borderGlowT == 600.0,"hitpause skips the entire border step")
	runtime.advance(1.0/60.0)
	_check(is_equal_approx(runtime.s.borderGlowT,600.0-Runtime.STEP_MS),"active runtime consumes border time once on its accepted step")
	var saved: Dictionary = runtime.snapshot()
	_check(not saved.state.has("borderGlowT") and not saved.state.has("lastZoneId"),"transient border fields do not enter persistent saves")
	_check(runtime.restore(saved) and not runtime.s.has("borderGlowT") and not runtime.s.has("territoryZoneId"),"accepted3D load epoch resets both border and territory tuple together")
	runtime.s.borderGlowT = 415.0; runtime.s.lastZoneId = "park"; runtime.s.territoryZoneId = "park"; runtime.s.territoryT = 1900.0
	_check(runtime.fresh() and not runtime.s.has("borderGlowT") and not runtime.s.has("lastZoneId") and not runtime.s.has("territoryT"),"fresh epoch cannot retain a previous border flash or partial territory tick")

func _test_day_composition() -> void:
	var spatial := DaySpatial.new()
	var runtime := Runtime.new(spatial,null,func(): return 1000.0)
	_check(runtime.days_enabled and runtime.state.on_day_started.is_valid(),"real Campaign/Day owners install one rollover")
	runtime.fresh(); runtime.drain_events(); runtime.s.flags.introDone = true
	runtime.s.counters.heistsToday = 2; runtime.s.counters.copperStripped = 7
	runtime.s.dayTime = 0.9999
	var survived: int = runtime.p.lifetime.dayCount
	runtime.advance(0.05)
	_check(runtime.s.day == 2 and runtime.p.lifetime.dayCount == 2 and runtime.p.lifetime.dayCount > survived,"natural composed day increments exactly once")
	_check(runtime.s.counters.heistsToday == 0 and runtime.s.counters.copperStripped == 7,"composed daily reset retains permanent copper count")
	var guards: int = 0
	for actor: Dictionary in runtime.state.npcs:
		if actor.get("kingdomGuard",false): guards += 1; _check("_2_" in str(actor.id),"new day replaces old force generation")
	_check(guards == 15,"single real Campaign generation after dawn")
	var day_events: int = 0
	for event: Dictionary in runtime.drain_events():
		if event.kind == "day_started": day_events += 1; _check(event.payload.handled,"day receipt identifies real owner")
	_check(day_events == 1,"one day-start event with no duplicate fallback rollover")
	runtime.s.dayTime = 0.8
	var slept: Dictionary = runtime.sleep_at_block()
	_check(slept.get("ok",false) and runtime.s.day == 3,"actual block sleep delegates to same Day owner")
	runtime.advance(1.0/60.0)
	_check(not _actor(runtime,"price_guy").is_empty(),"day3 active scheduler creates real Price Guy")
	var visitor: String = ""
	for actor: Dictionary in runtime.state.npcs:
		if actor.get("isDay3Visitor",false): visitor = actor.id
	_check(not visitor.is_empty(),"day3 sleep event creates source visitor")
	var price: Dictionary = _actor(runtime,"price_guy")
	_put(runtime,Vector2(price.x+price.w*0.5,price.y+price.h*0.5))
	var menu: Dictionary = runtime.open_day_actor("price_guy")
	_check(menu.get("ok",false),"conditional resident uses real Day menu")
	runtime.set_mode("paused")
	_check(not runtime.select_day_actor(menu.get("token"),"pay").get("ok",false),"pause invalidates conditional menu")
	runtime.s.dayTime = 0.8
	_check(not runtime.days.actor_visible({"id":"mom"}) and not runtime.days.actor_visible({"id":"pete"}) and not runtime.days.actor_visible({"id":"hopper","daytimeOnly":true}),"source night visibility covers three explicit resident categories")

func _test_communications_composition() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial,null,func(): return 1000.0)
	runtime.fresh(); runtime.drain_events()
	_check(runtime.props.ready() and runtime.communications.day_capabilities_ready(),"actual prop/feed owners composed")
	runtime.state.emit_event("feed",{"text":"the ledger has a page.","author":"@phone_guy"})
	runtime.drain_events()
	_check(runtime.communications.snapshot().posts.size() == 3,"queued source post reaches real feed once after two source startup posts")
	runtime.drain_events()
	_check(runtime.communications.snapshot().posts.size() == 3,"draining event sink cannot duplicate source feed")
	runtime.fresh()
	_check(runtime.communications.snapshot().posts.size() == 5 and runtime.communications.snapshot().posts[2].t == "the ledger has a page." and runtime.props.ready(),"fresh retains source session feed, adds its source pair and rebinds actual props")
	runtime.s.momTipT = 1.0; runtime.s.flags.silenceUntilT = 9000
	runtime.s.phoneT = 1.0; runtime.s.eventT = 1.0
	var seed: int = runtime.state.rng_seed
	runtime.advance(1.0/60.0)
	_check(runtime.s.flags.momIntroFired and runtime.s.phoneT >= 90000 and runtime.s.eventT >= 15000,"intro/silence reset ambient clocks while forced Mom tip fires")
	_check(runtime.state.rng_seed != seed and runtime.communications.snapshot().posts.size() == 5,"suppressed ambient reset consumes source RNG without feed")
	runtime.set_mode("paused")
	var timer: float = runtime.s.phoneT
	runtime.advance(1.0)
	_check(runtime.s.phoneT == timer,"paused play freezes source ambient timers")
	runtime.advance_wall(1000.0)
	var news: String = runtime.communications.snapshot().news_text
	runtime.advance_wall(51000.0)
	_check(runtime.communications.snapshot().news_text != news,"source wall ticker rotates during pause and silence")
	runtime.fresh(); runtime.s.flags.introDone = true
	var phone: Dictionary = _actor(runtime,"phoneguy")
	_put(runtime,Vector2(phone.x+phone.w*0.5,phone.y+phone.h*0.5)); runtime.p.cash = 10
	var menu: Dictionary = runtime.open_street("phoneguy")
	_check(menu.get("ok",false) and runtime.communications.snapshot().visible,"PhoneGuy opens the real source feed")
	var posts: int = runtime.communications.snapshot().posts.size()
	_check(runtime.select_street(menu.token,"content").get("ok",false) and runtime.p.cash == 7 and runtime.communications.snapshot().posts.size() == mini(8,posts+1),"paid phone content costs once and publishes once")

func _test_street_robbery_and_restore() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial); runtime.fresh()
	_check(runtime.enable_actor_simulation(),"new domains compose")
	var pinky: Dictionary = _actor(runtime,"pinky")
	_put(runtime,Vector2(pinky.x+pinky.w*0.5,pinky.y+pinky.h*0.5)); runtime.p.cash = 100
	var menu: Dictionary = runtime.open_street("pinky")
	_check(menu.get("ok",false) and runtime.select_street(menu.token,"buy_one").get("ok",false) and runtime.p.dirtySupplies == 1,"Pinky uses real Street supply transaction")
	menu = runtime.open_street("pinky")
	var before: Dictionary = runtime.snapshot()
	var candidate: Dictionary = before.duplicate(true); candidate.state.flags.omalleyFallen = true
	candidate.player.cash = 999; spatial.blocked = true
	_check(not runtime.restore(candidate) and runtime.snapshot() == before and runtime.s.mode == "dialogue","blocked Fallen restore preserves live state and menu")
	spatial.blocked = false
	_check(runtime.select_street(menu.token,"buy_pass").get("ok",false),"blocked restore preserves valid source menu capability")
	runtime.close_dialogue()
	var skid: Dictionary = _actor(runtime,"skid_lurch")
	_check(runtime.director.supported(skid),"real robbery owner supports source skid grabber")
	runtime.state.npcs.clear(); runtime.state.npcs.append(skid)
	skid.x = runtime.p.x; skid.y = runtime.p.y; skid.speed = 0; skid.aggro = true; skid.attackCd = 0
	if skid.has("zoneOnly"): skid.erase("zoneOnly")
	runtime.advance(1.0/60.0)
	_check(runtime.s.counters.get("robberiesToday",0) == 1 and runtime.p.stunT > 0,"real landed grab invokes robbery once")
	runtime.fresh(); var karaoke: Dictionary = _actor(runtime,"karaoke")
	_put(runtime,Vector2(karaoke.x+karaoke.w*0.5,karaoke.y+karaoke.h*0.5)); runtime.p.cash = 10
	menu = runtime.open_street("karaoke")
	var chosen: Dictionary = runtime.select_street(menu.token,"sing")
	_check(chosen.get("ok",false) and chosen.get("domain") == "activities" and runtime.p.cash == 5,"Street transfers to real paid rhythm owner")
	runtime.set_mode("paused")
	_check(not runtime.select_activity(chosen.get("token"),"left").get("ok",false) and runtime.p.cash == 5,"pause cancels rhythm capability without refund")

func _test_actor_and_travel_composition() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial)
	runtime.fresh()
	_check(runtime.enable_actor_simulation(),"full Runtime composes actual combat/director/boss modules")
	var tony: Dictionary = _actor(runtime,"tony")
	runtime.state.npcs.clear(); runtime.state.npcs.append(tony)
	tony.x = 1090.0; tony.y = 840.0
	runtime.p.cred = 100; runtime.p.cash = 20
	runtime.advance_wall(1000.0)
	var menu: Dictionary = runtime.open_vendor("tony")
	_check(menu.get("ok",false) and runtime.select_vendor(menu.token,"challenge").get("ok",false) and runtime.s.bossActive,"vendor action starts composed real Tony encounter")
	var attack: Dictionary = runtime.attack(Vector2.RIGHT)
	_check(attack.get("ok",false) and attack.get("connected",false) and tony.hp < 200,"composed attack applies actual damage immediately")
	var cooldown: float = runtime.p.attackCd
	var hp: float = tony.hp
	runtime.advance(1.0/60.0)
	_check(runtime.p.attackCd == cooldown and tony.hp == hp,"composed contact hitpause freezes both actor and player timers")
	runtime.s.hitPause = 0.0
	runtime.set_mode("paused")
	runtime.advance_wall(2000.0)
	_check(runtime.p.attackCd == cooldown,"wall callbacks do not tick active cooldowns while paused")
	_check(not runtime.advance_wall(1999.0),"wall clock rejects rewind")
	runtime.fresh()
	_check(runtime.advance_wall(3000.0),"wall clock remains monotonic across fresh state epoch")
	# Different domain menus cannot retain valid stale capabilities.
	var pinky: Dictionary = _actor(runtime,"pinky")
	_put(runtime,Vector2(pinky.x+pinky.w*0.5,pinky.y+pinky.h*0.5))
	runtime.p.cash = 100
	var travel_menu: Dictionary = runtime.open_travel("pinky")
	_check(travel_menu.get("ok",false),"composed travel opens its real vendor menu")
	tony = _actor(runtime,"tony")
	_put(runtime,Vector2(tony.x+tony.w*0.5,tony.y+tony.h*0.5))
	menu = runtime.open_vendor("tony")
	_check(menu.get("ok",false) and not runtime.select_travel(travel_menu.token,"buy_pass").get("ok",false),"opening vendor invalidates travel capability")
	_put(runtime,Vector2(pinky.x+pinky.w*0.5,pinky.y+pinky.h*0.5))
	travel_menu = runtime.open_travel("pinky")
	_check(travel_menu.get("ok",false) and not runtime.select_vendor(menu.token,"buy_rock").get("ok",false),"opening travel invalidates vendor capability")
	runtime.close_dialogue()
	# Same-process restore preserves only the unsaved cart's actual previous position.
	runtime.s.travelRuntime.cart.x = 1200.0
	var saved: Dictionary = runtime.snapshot()
	_check(not saved.state.has("travelRuntime"),"cart scratch remains excluded from durable source schema")
	_check(runtime.restore(saved) and runtime.travel.cart_record().x == 1200.0,"composed restore keeps same-process parked cart position")
	_check(runtime.advance_wall(4000.0),"wall callbacks accept next monotonic time after restore")

func _test_resident_composition() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial)
	runtime.fresh(); runtime.enable_actor_simulation()
	var lurch: Dictionary = _actor(runtime,"lurch")
	_put(runtime,Vector2(lurch.x+lurch.w*0.5,lurch.y+lurch.h*0.5))
	runtime.p.cash = 10
	var menu: Dictionary = runtime.open_resident("lurch")
	_check(menu.get("ok",false) and runtime.select_resident(menu.token,"give").get("ok",false) and runtime.p.cash == 9,"composed resident action consumes canonical source dollar")
	menu = runtime.open_resident("lurch")
	var tony: Dictionary = _actor(runtime,"tony")
	_put(runtime,Vector2(tony.x+tony.w*0.5,tony.y+tony.h*0.5))
	var vendor: Dictionary = runtime.open_vendor("tony")
	_check(vendor.get("ok",false) and not runtime.select_resident(menu.token,"fight").get("ok",false),"vendor opening invalidates resident action")
	_put(runtime,Vector2(lurch.x+lurch.w*0.5,lurch.y+lurch.h*0.5))
	menu = runtime.open_resident("lurch")
	_check(not runtime.select_vendor(vendor.token,"short").get("ok",false),"resident opening invalidates vendor action")
	runtime.set_mode("paused")
	_check(not runtime.select_resident(menu.token,"fight").get("ok",false) and runtime.s.mode == "paused","stale resident button cannot unpause")
	runtime.set_mode("playing")
	menu = runtime.open_resident("lurch")
	_check(runtime.select_resident(menu.token,"fight").get("ok",false) and lurch.aggro,"resident fight reaches same composed combat actor")

func _test_quest_ordering() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial)
	runtime.fresh(); runtime.enable_actor_simulation()
	var conductor: Dictionary = _actor(runtime,"conductor")
	var lurch: Dictionary = _actor(runtime,"lurch")
	var pete: Dictionary = _actor(runtime,"pete")
	var at := Vector2(conductor.x+conductor.w*0.5,conductor.y+conductor.h*0.5)
	_put(runtime,at)
	lurch.x = at.x+100.0; lurch.y = at.y; lurch.hostile = true; lurch.aggro = true
	var lurch_start: float = lurch.x
	runtime.state.npcs.assign([conductor,lurch,pete])
	runtime.state.cash_piles.clear()
	runtime.state.cash_piles.append({"id":"quest_order_cash","x":at.x,"y":at.y,"amt":5,"collected":false})
	runtime.s.crownPickup = {"x":at.x,"y":at.y,"collected":false}
	runtime.s.flags.hasStripePackage = true
	runtime.inventory.append_item("stripe_package","a package from stripe")
	runtime.s.quests.stripe_package.available = true
	runtime.combat.spawn_projectile({"x":at.x+500,"y":at.y+500,"tx":at.x+700,"ty":at.y+500})
	runtime.drain_events(); runtime.advance(0.1)
	_check(runtime.p.cash == 45 and runtime.s.crownPickup.collected and runtime.p.equip.hat == "pigeon_crown","cash/crown/package commit actual source resources in one step")
	_check(runtime.s.mode == "dialogue" and not runtime.s.flags.hasStripePackage and runtime.inventory.count_records("stripe_package") == 0,"automatic package delivery owns real modal and consumes records")
	_check(lurch.x < lurch_start and runtime.state.projectiles[0].life < 4000,"same delivery step still advances actor/projectile work")
	_check(absf(runtime._elapsed_ms-Runtime.STEP_MS) < 0.00001 and absf(runtime.state.projectiles[0].life-(4000-Runtime.STEP_MS)) < 0.00001,"later fixed steps pause immediately after delivery step")
	var events: Array[Dictionary] = runtime.drain_events()
	var crown_event: int = -1; var delivery_event: int = -1; var menu: Dictionary = {}
	for index: int in range(events.size()):
		if events[index].kind == "quest_pickup_changed": crown_event = index
		if events[index].kind == "package_delivered": delivery_event = index
		if events[index].kind == "dialogue_requested": menu = events[index].payload.menu
	_check(crown_event >= 0 and delivery_event > crown_event and menu.get("page") == "delivery","event presenter observes crown before automatic delivery menu")
	_check(runtime.select_quest(menu.token,"leave").get("ok",false),"automatic receipt has live one-use quest capability")
	runtime.s.dayTime = 0.8; runtime.advance(0.001)
	_check(pete.shopClosed and runtime.p.cash == 45,"Pete follows exact night closure and delivery never pays twice")
	var invalid: Dictionary = runtime.snapshot(); invalid.state.crownPickup = {"x":INF,"y":12,"collected":false}
	_check(runtime.restore(invalid) and runtime.s.crownPickup == null,"quest normalizer is active before composed restore")

func _test_movement() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial)
	for entry: Dictionary in [
		{"sprint":false,"high":0,"crash":0,"slow":0,"expected":137.5},
		{"sprint":true,"high":0,"crash":0,"slow":0,"expected":233.75},
		{"sprint":true,"high":2000,"crash":0,"slow":0,"expected":420.75},
		{"sprint":false,"high":0,"crash":2000,"slow":0,"expected":68.75},
		{"sprint":false,"high":0,"crash":0,"slow":2000,"expected":68.75}]:
		runtime.fresh(); runtime.p.x = 1100.0; runtime.p.y = 900.0
		runtime.p.rockedT = entry.high; runtime.p.crashT = entry.crash; runtime.p.slowT = entry.slow
		runtime.advance(1.0,{"input_vector":Vector2.RIGHT,"sprinting":entry.sprint})
		# Physics Vector2 coordinates use float32: allow0.01sourcepx (0.4mm) accumulated in1s.
		_check(absf(float(runtime.p.x)-1100.0-float(entry.expected)) < 0.01,"source walk/sprint/status speed " + str(entry)+" actual="+str(runtime.p.x-1100)+" base="+str(runtime.p.speed))
	runtime.fresh(); runtime.p.x = 1100.0; runtime.p.y = 900.0
	runtime.advance(1.0,{"input_vector":Vector2(1,1)})
	_check(Vector2(runtime.p.x-1100,runtime.p.y-900).distance_to(Vector2.ONE.normalized()*137.5) < 0.01,"diagonal movement cannot boost speed")
	var before := Vector2(runtime.p.x,runtime.p.y)
	spatial.blocked = true
	runtime.advance(1.0,{"input_vector":Vector2.RIGHT,"sprinting":true})
	_check(Vector2(runtime.p.x,runtime.p.y) == before,"physical rejection cannot move player")
	spatial.blocked = false
	runtime.p.stunT = 2000.0
	runtime.advance(1.0,{"input_vector":Vector2.RIGHT})
	_check(Vector2(runtime.p.x,runtime.p.y) == before and absf(runtime.p.stunT-1000) < 0.001,"stun prevents movement while counting down once")
	runtime.p.stunT = 0.0
	runtime.s.hitPause = 40.0
	runtime.advance(0.02,{"input_vector":Vector2.RIGHT})
	_check(Vector2(runtime.p.x,runtime.p.y) == before,"hitpause freezes actual movement")
	var untouched: String = JSON.stringify(runtime.snapshot())
	for invalid: Variant in [Vector2(NAN,0),Vector2(INF,0),"right"]:
		_check(not runtime.advance(1.0,{"input_vector":invalid}) and JSON.stringify(runtime.snapshot()) == untouched,"bad input atomic rejection")
	runtime.s.hitPause = 0.0
	runtime.p.x = 0.0; runtime.p.y = 0.0
	runtime.advance(1.0,{"input_vector":Vector2(-1,-1)})
	_check(runtime.p.x == 0 and runtime.p.y == 0,"world boundary clamps intended motion before cast")

func _test_intro_chain() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial)
	_check(runtime.s.mode == "title" and runtime.p.cash == 0 and runtime.p.brain == 70,"canonical fresh defaults before play")
	_check(runtime.fresh() and runtime.s.mode == "playing","fresh enters play")
	_check(runtime.s.hustles.is_empty() and runtime.s.blockRoute == null,"intro suppresses hustles/routes")
	runtime.drain_events()
	_put(runtime,Vector2(1180,870))
	_check(runtime.collect_cash("cp_intro_remember"),"real canonical intro pile collected")
	_check(runtime.p.cash == 10 and runtime.p.cred == 1 and runtime.s.quests.intro_remember.done and runtime.s.quests.intro_tony.available,"intro cash/remember transaction")
	_check(not runtime.collect_cash("cp_intro_remember") and runtime.p.cash == 10,"intro collection is once only")
	var tony: Dictionary = _actor(runtime,"tony")
	_put(runtime,Vector2(tony.x+tony.w*0.5,tony.y+tony.h*0.5))
	var menu: Dictionary = runtime.open_vendor("tony")
	_check(menu.ok and runtime.s.mode == "dialogue" and runtime.p.cred == 2 and runtime.s.quests.intro_smoke.available,"Tony open advances real intro")
	var bought: Dictionary = runtime.select_vendor(menu.token,"buy_rock")
	_check(bought.ok and runtime.p.cash == 0 and runtime.p.rocks == 1 and runtime.s.mode == "playing","canonical Tony purchase through one-use session")
	_check(not runtime.select_vendor(menu.token,"buy_rock").ok and runtime.p.rocks == 1,"double selection cannot buy twice")
	_put(runtime,Vector2(1062,854))
	_check(runtime.smoke("block").ok,"composed real smoke accepts at Block")
	_check(runtime.s.flags.introDone and runtime.s.quests.intro_smoke.done and runtime.p.rocks == 0 and runtime.p.cred == 5,"single smoke/intro resource authority")
	_check(runtime.s.hustles.size() == 3 and runtime.progression.valid_route(runtime.s.blockRoute),"intro event rolls real hustles/routes synchronously")
	var saves: Array = []
	for event: Dictionary in runtime.drain_events():
		if event.kind == "save_requested": saves.append(event.payload.snapshot)
	_check(saves.size() == 1,"all intro transaction save requests coalesce after consequences")
	var final_save: Dictionary = runtime.snapshot()
	_check(JSON.stringify(saves[0]) == JSON.stringify(final_save),"queued snapshot is final committed state including next route")
	_check(runtime.drain_events().is_empty(),"event queue drained once")
	runtime.advance(17.99)
	_check(absf(float(runtime.p.rockedT)-10.0) < 0.001 and runtime.p.crashT == 0,"composed high before18s")
	runtime.advance(0.02)
	_check(runtime.p.rockedT == 0 and absf(float(runtime.p.crashT)-7990.0) < 0.001,"composed high crosses into exact crash remainder")
	runtime.advance(7.99)
	_check(runtime.p.crashT == 0,"composed cycle completes at26s")
	var before_cred: int = runtime.p.cred
	_check(runtime.restore(final_save) and runtime.p.rockedT == 0 and runtime.p.crashT == 0,"full restore clears unsaved ephemeral statuses")
	_check(runtime.p.cred == before_cred and runtime.s.hustles.size() == 3 and runtime.progression.valid_route(runtime.s.blockRoute),"restore never repays intro or rolls away current progress")
	_check(runtime.s.cashPilesCollected.has("cp_intro_remember"),"real pickup identity retained through full restore")

func _test_boundaries() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial)
	runtime.fresh()
	runtime.p.rocks = 1
	_put(runtime,Vector2(1062,854))
	spatial.visible = false
	_check(not runtime.smoke("block").ok and runtime.p.rocks == 1,"smoke rechecks valid physical player placement")
	spatial.visible = true
	_check(runtime.smoke("block").ok,"valid access accepts smoke")
	var high: float = runtime.p.rockedT
	var shakes: float = runtime.p.shakes
	var day_time: float = runtime.s.dayTime
	runtime.set_mode("paused")
	_check(runtime.advance(20) and runtime.p.rockedT == high and runtime.p.shakes == shakes and runtime.s.dayTime == day_time,"pause freezes every model clock/resource")
	_check(runtime.last_advanced_ms == 0.0,"pause exposes no cosmetic active time")
	_check(not runtime.craft_hitter().ok and not runtime.use_hitter().ok,"pause cannot invoke pocket transactions")
	runtime.set_mode("playing")
	for bad: float in [-1.0,NAN,INF,241.0]:
		_check(not runtime.advance(bad) and runtime.p.rockedT == high,"invalid time rejected before any mutation")
	runtime.s.hitPause = 20.0
	runtime.advance(1.0/60.0)
	_check(runtime.p.rockedT == high and runtime.s.hitPause > 0,"first hitpause step freezes world")
	_check(runtime.last_advanced_ms == 0.0,"hitpause exposes no cosmetic active time")
	runtime.advance(1.0/60.0)
	_check(runtime.p.rockedT == high and runtime.s.hitPause == 0,"fractional hitpause remainder still consumes whole source step")
	runtime.advance(1.0/60.0)
	_check(runtime.p.rockedT < high,"world resumes after hitpause")
	var tony: Dictionary = _actor(runtime,"tony")
	_put(runtime,Vector2(tony.x+tony.w*0.5,tony.y+tony.h*0.5))
	var menu: Dictionary = runtime.open_vendor("tony")
	var saved: Dictionary = runtime.snapshot()
	_check(runtime.restore(saved) and not runtime.select_vendor(menu.token,"leave").ok,"restore invalidates old menu capability")
	menu = runtime.open_vendor("tony")
	runtime.set_mode("paused")
	_check(not runtime.select_vendor(menu.token,"leave").ok and runtime.s.mode == "paused","pause closes dialogue token without escaping pause")
	runtime.set_mode("playing")
	menu = runtime.open_vendor("tony")
	runtime.fresh()
	_check(not runtime.select_vendor(menu.token,"buy_rock").ok,"fresh invalidates old menu capability")
	_check(not runtime.restore({"schema":999}) and runtime.s.mode == "playing","unknown save schema leaves live mode intact")

func _test_pickups() -> void:
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial)
	runtime.fresh()
	_put(runtime,Vector2(1194,870))
	_check(not runtime.collect_cash("cp_intro_remember"),"cash exact14px edge rejected")
	_put(runtime,Vector2(1193.99,870))
	spatial.visible = false
	_check(not runtime.collect_cash("cp_intro_remember") and runtime.p.cash == 0,"blocked cash cannot be collected through geometry")
	spatial.visible = true
	runtime.advance(0.01)
	_check(runtime.p.cash == 10 and runtime.s.quests.intro_remember.done,"actual active-step pickup scan applies intro transaction")
	runtime.state.equip_tool("crowbar")
	runtime.state.cash_piles.append({"id":"test_torch","x":1193.99,"y":870,"tool":"propane_torch","collected":false})
	_check(runtime.collect_cash("test_torch") and runtime.p.equip.tool == "propane_torch" and runtime.s.flags.peteToolLocker == "crowbar","torch pickup preserves displaced tool")
	runtime.state.equip_tool("crowbar")
	runtime.state.cash_piles.append({"id":"test_duplicate_torch","x":1193.99,"y":870,"tool":"propane_torch","collected":false})
	_check(runtime.collect_cash("test_duplicate_torch") and runtime.p.equip.tool == "crowbar" and runtime.s.flags.peteToolLocker == "propane_torch","owned locker torch is not duplicated or auto-equipped")
	runtime.state.cash_piles.append({"id":"test_inheritance","x":1193.99,"y":870,"amt":30,"isInheritance":true,"collected":false})
	_check(runtime.collect_cash("test_inheritance") and runtime.s.flags.day14Collected and runtime.p.faction.street == 2 and runtime.p.faction.spiritual == -1,"inheritance receipt applies canonical factions")
