extends SceneTree
const Runtime = preload("res://scripts/full_runtime.gd")
class Spatial extends RefCounted:
	var visible: bool = true
	var calls: Array[String] = []
	var blocked: bool = false
	func can_reach_target(id: String) -> bool:
		calls.append(id)
		return visible
	func move_body(body: Dictionary,intended: Vector2) -> Dictionary:
		return {"position":Vector2(body.x,body.y) if blocked else intended,"blocked":blocked}
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
	if failures.is_empty():
		print("3D FULL RUNTIME GATE: PASS (%d checks; composed intro/vendor/loop/save chain, pause, stale capabilities and physical access boundaries; full scene pending)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FULL RUNTIME GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks])
		quit(1)

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
	_check(not runtime.smoke("block").ok and runtime.p.rocks == 1,"smoke rechecks live physical access")
	spatial.visible = true
	_check(runtime.smoke("block").ok,"valid access accepts smoke")
	var high: float = runtime.p.rockedT
	var shakes: float = runtime.p.shakes
	var day_time: float = runtime.s.dayTime
	runtime.set_mode("paused")
	_check(runtime.advance(20) and runtime.p.rockedT == high and runtime.p.shakes == shakes and runtime.s.dayTime == day_time,"pause freezes every model clock/resource")
	_check(not runtime.craft_hitter().ok and not runtime.use_hitter().ok,"pause cannot invoke pocket transactions")
	runtime.set_mode("playing")
	for bad: float in [-1.0,NAN,INF,241.0]:
		_check(not runtime.advance(bad) and runtime.p.rockedT == high,"invalid time rejected before any mutation")
	runtime.s.hitPause = 20.0
	runtime.advance(1.0/60.0)
	_check(runtime.p.rockedT == high and runtime.s.hitPause > 0,"first hitpause step freezes world")
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
