extends SceneTree
const Runtime = preload("res://scripts/full_runtime.gd")
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []

class Spatial extends RefCounted:
	func can_reach_target(_id: String) -> bool: return true
	func can_use_zone(_id: String) -> bool: return true
	func move_body(body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary:
		return {"position":intended,"blocked":false}
	func clear_placement(body: Dictionary) -> Vector2: return Vector2(body.x,body.y)
	func can_hit(_from: Vector2,_to: Vector2,_source: String,_target: String) -> bool: return true
	func sweep_projectile(_start: Vector2,end: Vector2,_radius: float) -> Dictionary: return {"blocked":false,"fraction":1.0,"position":end}

func _initialize() -> void: call_deferred("_run")
func _check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
func _run() -> void:
	_frame_and_same_mode()
	_atomic_save_and_lifecycle()
	_forced_modes_and_real_ending()
	_death_arrest()
	_epoch_receipts()
	_kingdom_ending()
	_check(groups == 6,"all six Runtime groups complete without abort")
	if failures.is_empty():
		print("3D COOKING RUNTIME GATE: PASS (%d checks; real cook commands/boss wall ending, atomic settlement, lifecycle precedence, forced epochs, clocks and receipt isolation)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D COOKING RUNTIME GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks])
		quit(1)

func _rig(actors: bool = false) -> Dictionary:
	var spatial := Spatial.new()
	var runtime := Runtime.new(spatial,null,func(): return 1000.0)
	_check(runtime.fresh(),"real Runtime starts a fresh session")
	if actors: _check(runtime.enable_actor_simulation(),"real Combat/Bosses wall owners are bound")
	runtime.advance_wall(1000.0); runtime.drain_events()
	return {"runtime":runtime,"spatial":spatial}

func _begin(runtime: RefCounted,amount: int = 6000,mode: String = "all") -> void:
	runtime.p.supplies = amount; runtime.p.dirtySupplies = 0
	var menu: Dictionary = runtime.open_cooking()
	_check(menu.get("ok",false),"real Block cooking menu opens")
	var result: Dictionary = runtime.select_cooking(menu.get("token",""),mode)
	_check(result.get("started",false) and runtime.s.mode == "cookmini","real one-use option starts heat")
	runtime.drain_events()

func _accept(runtime: RefCounted) -> void:
	_begin(runtime)
	runtime.s.heat.progress = runtime.s.heat.sweetCenter
	_check(runtime.lock_cooking().get("outcome") == "perfect","actual lock selects source perfect outcome")
	runtime.s.heat.holdT = 1.0
	runtime.advance(0.05)
	_check(runtime.cooking.is_resolving() and runtime.p.supplies == 6000,"first accepted chunk leaves all supplies unpaid")
	runtime.drain_events()

func _finish(runtime: RefCounted) -> void:
	var turns: int = 0
	while runtime.cooking.is_resolving() and turns < 8:
		runtime.advance(0.05); turns += 1
	_check(not runtime.cooking.is_resolving() and turns > 0 and turns < 8,"bounded frames finish the accepted batch")

func _events(events: Array[Dictionary],kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.kind == kind: result.append(event)
	return result

func _toast_count(events: Array[Dictionary],text: String) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if event.kind == "toast" and event.payload.get("text") == text: count += 1
	return count

func _frame_and_same_mode() -> void:
	var rig := _rig()
	var r: RefCounted = rig.runtime
	_check(not r.set_mode("cookmini") and r.s.mode == "playing","cookmini cannot be entered without authoritative heat")
	_begin(r,1,"slow")
	r.p.rockedT = 18000.0; r.p.crashT = 8000.0
	var day: float = r.s.dayTime
	var epoch: Dictionary = r.s.heat
	_check(r.set_mode("cookmini") and is_same(epoch,r.s.heat),"same-mode fill request preserves the actual heat record")
	r.advance(0.2,{"input_vector":Vector2.RIGHT,"sprinting":true})
	_check(r.s.heat.t == 50.0 and r.last_advanced_ms == 0,"cooking gets one clamped frame rather than catch-up world steps")
	_check(r.p.rockedT == 18000.0 and r.p.crashT == 8000.0 and r.s.dayTime == day,"high/crash/day clocks do not advance during heat")
	r.s.heat.t = 3990.0; r.advance(0.05)
	_check(r.s.heat.phase == "idle" and r.s.heat.idleAfterFill == 1000.0,"fill crossing does not spend leftover time on idle")
	_check(r.set_mode("cookmini") and is_same(epoch,r.s.heat),"same-mode idle request preserves heat")
	r.s.hitPause = 20.0; r.s.smokeT = 2000.0
	r.advance(0.05); r.advance_presentation(0.05)
	_check(r.s.hitPause == 0 and r.s.heat.idleAfterFill == 1000.0 and r.s.smokeT == 1950.0,"hitpause consumes only its frame while smoke decays once afterward")
	r.lock_cooking()
	_check(r.set_mode("cookmini") and is_same(epoch,r.s.heat),"same-mode hold request preserves accepted lock")
	r.advance(1.0)
	_check(r.s.heat.holdT == 550.0,"long render delay still advances hold by one clamped source frame")
	_check(r.bail_cooking().get("ok",false) and r.p.supplies == 0,"hold Escape still uses paid bail rather than free cancellation")
	r.set_mode("paused"); r.s.hitPause = 30.0; r.advance_presentation(0.05)
	_check(r.s.hitPause == 0 and r.s.smokeT == 1900.0,"nonplaying presentation decays hitpause and smoke without a world tick")
	_check(not r.advance(NAN) and not r.advance_presentation(INF),"malformed frame deltas are refused")
	groups += 1

func _atomic_save_and_lifecycle() -> void:
	var rig := _rig(); var r: RefCounted = rig.runtime
	_accept(r)
	var old_player: Dictionary = r.p
	_check(r.set_mode("cookmini") and r.cooking.is_resolving(),"same-mode resolution cannot invoke refused cleanup")
	r.request_save()
	_check(_events(r.drain_events(),"save_requested").is_empty(),"save request stays pending while resources remain uncommitted")
	_check(not r.set_mode("paused") and not r.fresh() and r.s.mode == "cookmini","first lifecycle waits and later lifecycle cannot replace it")
	_check(not r.bail_cooking().get("ok",false) and not r.open_vendor("tony").get("ok",false),"accepted resolve rejects bail and replacement menu")
	_finish(r)
	var events: Array[Dictionary] = r.drain_events()
	_check(r.s.mode == "paused" and is_same(old_player,r.p) and r.p.supplies == 0 and r.p.rocks > 0,"first pause wins only after one real settlement")
	var saves := _events(events,"save_requested")
	_check(saves.size() == 1 and saves[0].payload.snapshot.player.supplies == 0 and saves[0].payload.snapshot.player.rocks == r.p.rocks,"single deferred save contains the settled resource state")
	var lifecycle := _events(events,"lifecycle_applied")
	_check(lifecycle.size() == 1 and lifecycle[0].payload.kind == "mode" and lifecycle[0].payload.ok,"pending lifecycle reports one successful application")
	_check(_events(r.drain_events(),"save_requested").is_empty() and not r.lock_cooking().get("ok",false),"draining and repeated input cannot resettle or resave the accepted batch")
	var restore_rig := _rig(); r = restore_rig.runtime
	r.p.cash = 77; var saved: Dictionary = r.snapshot()
	_accept(r); old_player = r.p
	_check(not r.restore(saved),"validated restore queues while resolution is accepted")
	saved.player.cash = 999
	_finish(r)
	_check(old_player.supplies == 0 and not is_same(old_player,r.p) and r.p.cash == 77,"queued restore settles old epoch then uses a detached captured save")
	_check(_events(r.drain_events(),"lifecycle_applied").size() == 1,"restore emits one lifecycle completion")
	var fresh_rig := _rig(); r = fresh_rig.runtime
	_accept(r); old_player = r.p
	_check(not r.fresh(),"fresh waits for accepted old batch")
	_finish(r)
	_check(old_player.supplies == 0 and not is_same(old_player,r.p) and r.s.mode == "playing","fresh replaces epoch only after old cost commits")
	groups += 1

func _forced_modes_and_real_ending() -> void:
	for desired: String in ["paused","title","dialogue","ending"]:
		var rig := _rig(); var r: RefCounted = rig.runtime
		_accept(r)
		r.s.mode = desired
		r.advance(0.05)
		_check(r.cooking.is_resolving() and r.s.mode == "cookmini",desired+" forced write cannot strand an accepted batch")
		_finish(r)
		_check(r.s.mode == desired and r.p.supplies == 0,desired+" is applied after settlement")
	for earlier_pause: bool in [false,true]:
		var rig := _rig(true); var r: RefCounted = rig.runtime
		_check(r.bosses.start_tony() and r.combat.damage_actor("tony",10000.0),"real Tony defeat schedules its authored ending")
		r.drain_events()
		_accept(r)
		if earlier_pause: _check(not r.set_mode("paused"),"earlier explicit pause is retained ahead of wall ending")
		r.advance_wall(5000.0)
		var events: Array[Dictionary] = r.drain_events()
		_check(r.s.mode == "cookmini" and r.cooking.is_resolving() and _events(events,"ending_requested").is_empty(),"actual Bosses mode write and ending presentation wait behind resolution")
		_check(_events(events,"save_requested").is_empty(),"boss save cannot snapshot partially processed cooking")
		_finish(r); events = r.drain_events()
		_check(r.p.supplies == 0 and r.s.mode == ("paused" if earlier_pause else "title"),"actual ending cannot strand or override the first lifecycle")
		_check(_events(events,"ending_requested").size() == (0 if earlier_pause else 1),"ending presentation occurs once only when its destination wins")
	groups += 1

func _death_arrest() -> void:
	for kind: String in ["death","arrest"]:
		var rig := _rig(); var r: RefCounted = rig.runtime
		_accept(r)
		if kind == "death": r.state.die()
		else: r.state.arrest()
		var hp: float = r.p.hp
		var events: Array[Dictionary] = r.drain_events()
		_check(r.cooking.is_resolving() and _events(events,kind).is_empty() and r.s.mode == "cookmini",kind+" refused cancel retains accepted work and defers transition presentation")
		_finish(r); events = r.drain_events()
		_check(r.p.supplies == 0 and r.p.hp == hp and _events(events,kind).size() == 1,kind+" keeps authoritative recovery and releases one presentation after settlement")
		_check(_events(r.drain_events(),kind).is_empty(),kind+" cannot replay its transition receipt")
	groups += 1

func _epoch_receipts() -> void:
	for replacement: String in ["none","player","state","fresh","restore"]:
		var rig := _rig(); var r: RefCounted = rig.runtime
		var saved: Dictionary = r.snapshot()
		r.state.emit_event("delayed_toast",{"delay_ms":2200,"text":"epoch receipt","duration_ms":2800})
		r.drain_events()
		match replacement:
			"player": r.state.p = r.p.duplicate(true)
			"state": r.state.s = r.s.duplicate(true)
			"fresh": r.fresh()
			"restore": r.restore(saved)
		r.advance_wall(3199.0)
		_check(_toast_count(r.drain_events(),"epoch receipt") == 0,replacement+" delayed receipt never fires early")
		r.advance_wall(3200.0)
		_check(_toast_count(r.drain_events(),"epoch receipt") == (1 if replacement == "none" else 0),replacement+" delayed receipt honors both p/s epoch identities")
		r.advance_wall(4000.0)
		_check(_toast_count(r.drain_events(),"epoch receipt") == 0,replacement+" delayed receipt cannot repeat")
	for replacement: String in ["player","state"]:
		var rig := _rig(); var r: RefCounted = rig.runtime
		_accept(r); r.set_mode("paused")
		r.state.emit_event("ending_requested",{"kind":"tony"}); r.drain_events()
		if replacement == "player": r.state.p = r.p.duplicate(true)
		else: r.state.s = r.s.duplicate(true)
		var supplies: int = r.p.supplies; var rocks: int = r.p.rocks
		r.advance(0.05)
		var events: Array[Dictionary] = r.drain_events()
		_check(not r.cooking.is_active() and r.s.mode == "playing" and r.p.supplies == supplies and r.p.rocks == rocks,replacement+" forced epoch invalidates old work without stale payment or orphaned cook mode")
		_check(_events(events,"lifecycle_applied").is_empty() and _events(events,"ending_requested").is_empty(),replacement+" forced epoch drops stale lifecycle and transition presentation")
	groups += 1

func _win_kingdom(r: RefCounted) -> void:
	r.s.kingdom.stage = "emperor_gate"; r.s.kingdom.defeats = []
	for clan: Dictionary in r.kingdom.clans: r.s.kingdom.defeats.append(clan.bossId)
	_check(r.kingdom.start_boss("emperor"),"real Kingdom stages emperor from canonical three-seal fixture")
	var emperor: Dictionary = r.combat.actor("curb_emperor")
	if emperor.is_empty(): return
	emperor.hp = 0
	_check(r.handle_death("curb_emperor") and r.s.kingdom.stage == "complete","real Bosses death delegates Kingdom completion")
	r.drain_events()

func _kingdom_ending() -> void:
	var rig := _rig(); var r: RefCounted = rig.runtime
	r.advance_wall(100000.0)
	_check(r.enable_actor_simulation(),"actor owners can be enabled after wall clock starts")
	_win_kingdom(r)
	_check(r.kingdom._ending_at == 102600.0,"late-bound Kingdom schedules full2600ms from current wall time")
	_accept(r)
	r.advance_wall(102599.0)
	_check(_events(r.drain_events(),"ending_requested").is_empty(),"Kingdom ending cannot fire one millisecond early")
	r.advance_wall(102600.0)
	_check(r.s.mode == "cookmini" and r.cooking.is_resolving() and not r.s.get("endingContinue",false),"Kingdom ending waits behind accepted cooking settlement")
	_check(_events(r.drain_events(),"ending_requested").is_empty(),"unsettled Kingdom ending emits no premature presentation")
	_finish(r)
	var events: Array[Dictionary] = r.drain_events()
	var endings: Array[Dictionary] = _events(events,"ending_requested")
	_check(endings.size() == 1 and endings[0].payload.title == "ONE CRACKLORD" and r.s.endingContinue,"settled cooking releases one canonical Kingdom ending")
	_check(r.s.mode == "ending" and r.p.supplies == 0,"settlement commits resources before ending mode")
	r.advance_wall(110000.0)
	_check(_events(r.drain_events(),"ending_requested").is_empty(),"Kingdom ending never repeats")
	r.fresh(); r.advance_wall(120000.0); _win_kingdom(r)
	r.fresh(); r.advance_wall(130000.0)
	_check(_events(r.drain_events(),"ending_requested").is_empty() and not r.s.get("endingContinue",false),"fresh epoch cancels delayed Kingdom ending")
	groups += 1
