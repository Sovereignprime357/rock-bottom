extends SceneTree
## Full composition gate. Root runs centrally; isolated IO, real gameplay/physics.
const FullScene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
const State = preload("res://scripts/game_state.gd")
const Props = preload("res://scripts/prop_state.gd")
class MemoryStore extends "res://scripts/save_store.gd":
	var data: Dictionary = {}
	var writes: int = 0
	func read_save() -> Dictionary: return data.duplicate(true)
	func write_save(value: Dictionary) -> bool:
		data = value.duplicate(true); writes += 1; return true
var scene: Node3D
var memory_store: Node
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _draws(seed: int,count: int) -> Dictionary:
	var values: Array[float] = []
	for index: int in range(count):
		seed = (seed*1664525+1013904223)&0xffffffff
		values.append(float(seed)/4294967296.0)
	return {"seed":seed,"values":values}
func _place(center: Vector2) -> void:
	scene.runtime.p.x = center.x-scene.runtime.p.w*0.5
	scene.runtime.p.y = center.y-scene.runtime.p.h*0.5
	scene._sync_player()
func _idle_clocks() -> void:
	scene.runtime.s.phoneT = 1000000000.0
	scene.runtime.s.flags.momIntroFired = true
	scene.runtime.s.eventT = 1000000000.0
	scene.runtime.s.hustleCheckT = 0.0
	scene.runtime.s.flags.silenceUntilT = 0.0
func _arm() -> void:
	scene.runtime.s.flags.introDone = true
	scene.runtime.s.flags.incidentDay = scene.runtime.s.day
	scene.runtime.s.flags.incidentMask = 0
	scene.runtime.s.flags.incidentsToday = 0
	scene.runtime.s.incidentT = 1.0
	_idle_clocks()
func _step(seconds: float = 1.0/60.0) -> void: scene._process(seconds)
func _diagnostic(label: String) -> void:
	var runtime: RefCounted = scene.runtime; var center: Vector2 = runtime.state.player_center()
	var nearby: Array[Dictionary] = []
	for actor: Dictionary in runtime.state.npcs:
		if actor.get("dead",false): continue
		var distance: float = Vector2(actor.x+actor.w*0.5,actor.y+actor.h*0.5).distance_to(center)
		if actor.get("aggro",false) and distance < 400 or actor.get("isDay3Visitor",false) or actor.id == "bus_driver":
			nearby.append({"id":actor.id,"aggro":actor.get("aggro",false),"distance":distance,"visitor":actor.get("isDay3Visitor",false)})
	print("INCIDENT RUNTIME DIAGNOSTIC: ",JSON.stringify({"label":label,"center":center,"mode":runtime.s.mode,"incident":runtime.s.get("incident"),"corridor":runtime.incident_corridors.status(),"failure":runtime.get("_incident_failure"),"timer":runtime.s.get("incidentT"),"hitpause":runtime.s.get("hitPause"),"boss":runtime.s.get("bossActive"),"boss_kind":runtime.s.get("bossKind"),"older":runtime.s.get("brutusOlderActive"),"combat_busy":runtime.incidents._combat_busy(),"script_busy":runtime.incidents._script_busy(),"choices":runtime.incidents._choices(0),"nearby":nearby}))
func _flush() -> void:
	for frame: int in range(60):
		if not scene.saving and scene.pending_save.is_empty(): return
		await process_frame
	_check(false,"isolated scene save queue drains")
func _bottles(expected: Dictionary,label: String) -> void:
	var rows: Array = scene.runtime.props.interactive_records()
	_check(rows.size() == 14,label+" retains six cans/eight bottles")
	if rows.size() != 14: return
	for index: int in range(8):
		var draw: int = 1+index*3
		var point: Vector2 = Props.BOTTLE_INITIAL_POINTS[mini(15,int(floor(expected.values[draw]*16.0)))]
		point += Vector2((expected.values[draw+1]-0.5)*40.0,(expected.values[draw+2]-0.5)*40.0)
		var id := "interactive:%d" % (index+6)
		var row: Dictionary = rows[index+6]
		var pending: Dictionary = scene.runtime.interactive_props._pending.get(id,{})
		if not pending.is_empty(): _check(pending.point.distance_to(point) < 0.001,label+" pending bottle retains exact three-draw source candidate "+id)
		else: _check(Vector2(row.x,row.y).distance_to(point) <= 100.001,label+" physical bottle stays within source candidate bound "+id)
		_check(row.type == "b_bottle" and not row.broken,label+" resets source bottle state "+id)
	_check(scene.runtime.state.rng_seed == expected.seed,label+" consumes exactly one prefix draw then24 contiguous bottle draws")
func _cold_and_fresh() -> void:
	var runtime: RefCounted = scene.runtime
	for key: String in ["incidents","incident_paths","incident_corridors"]:
		_check(runtime.get(key) != null,"actual Runtime retains strong "+key)
	_check(scene.get("incident_view") != null,"actual Scene retains one incident presenter")
	if runtime.get("incidents") == null or runtime.get("incident_paths") == null or runtime.get("incident_corridors") == null or scene.get("incident_view") == null: return
	_check(runtime.incidents.ready() and runtime.incident_paths.ready() and runtime.incident_corridors.ready(),"real cold source/map/corridor capabilities ready")
	_check(scene.incident_view.metrics().banks == 6,"one cached bank per source incident")
	var timer: float = float(runtime.s.incidentT); var seed: int = runtime.state.rng_seed
	_step(0.1)
	_check(runtime.s.mode == "title" and runtime.s.incident == null and runtime.s.incidentT == timer and runtime.state.rng_seed == seed,"cold title advances neither incident clock nor RNG")
	scene._new_game()
	_check(runtime.s.mode == "playing" and runtime.s.incident == null and runtime.incident_corridors.status().active.is_empty(),"fresh actual Scene has no stale scene/reservation")
	var expected: Dictionary = _draws(State.DEFAULT_SEED,25)
	_check(is_equal_approx(float(runtime.s.publicPhoneT),240000.0+expected.values[0]*240000.0),"fresh source public-phone draw precedes bottle24")
	_bottles(expected,"fresh")
	groups += 1
func _clock_and_menus() -> void:
	var runtime: RefCounted = scene.runtime
	var block: Dictionary = scene.world.service_points["smoke:block"]
	_place(Content.to_source(block.approach)); runtime.p.rocks = 1
	_check(runtime.smoke("block").ok and runtime.p.rockedT == 18000,"actual source smoke starts one18s high")
	_place(Vector2(1080,960)); _arm()
	_step()
	_check(runtime.s.incident is Dictionary and runtime.s.incident.id == "runaway_mattress","actual Runtime scheduler activates mapped mattress")
	_check(runtime.incident_corridors.status().active == "runaway_mattress" and scene.incident_view.metrics().active_id == "runaway_mattress","actual model reservation and visible bank activate together")
	if not runtime.s.incident is Dictionary: return
	var time: float = runtime.s.incident.t; var high: float = runtime.p.rockedT
	scene._ledger(false); _step(0.1)
	_check(runtime.s.mode == "dialogue" and runtime.s.incident.t == time and runtime.p.rockedT == high,"actual Q menu freezes source incident/high clocks")
	scene._resume(); _step()
	_check(runtime.s.incident.t > time and runtime.p.rockedT < high,"closing actual menu resumes both source clocks once")
	scene._pause(); time = runtime.s.incident.t; _step(0.1)
	_check(runtime.s.incident.t == time and runtime.s.mode == "paused","actual pause retains source incident")
	scene._resume()
	var elapsed: float = 2.0/60.0
	while runtime.p.rockedT > 0 and elapsed < 18.2:
		_step(0.05); elapsed += 0.05
	_check(elapsed >= 18.0 and elapsed <= 18.1 and runtime.p.crashT > 0,"active incident preserves18s high transition")
	var crash_start: float = elapsed
	while runtime.p.crashT > 0 and elapsed-crash_start < 8.2:
		_step(0.05); elapsed += 0.05
	_check(elapsed-crash_start >= 7.9 and elapsed-crash_start <= 8.1 and runtime.p.rockedT <= 0 and runtime.p.crashT <= 0,"active incident preserves8s crash recovery")
	_check(runtime.s.incident == null and runtime.incident_corridors.status().active.is_empty() and scene.incident_view.metrics().active_id.is_empty(),"source25s finish releases and hides real scene")
	await _flush()
	groups += 1
func _cart_and_prop_reservations() -> void:
	var runtime: RefCounted = scene.runtime; var adapter: RefCounted = scene.physics
	# The preceding26s clock proof retains genuine pursuing actors. Start this
	# independent physical fixture through the real new-game lifecycle instead of
	# erasing NPCs or overriding their source aggro state.
	await _flush(); scene._new_game()
	_check(runtime.state.npcs.size() == 56 and not runtime.incidents._combat_busy() and not runtime.incidents._script_busy(),"real new-game boundary supplies complete fresh roster and source-idle scheduling")
	var block: Dictionary = scene.world.service_points["smoke:block"]
	_place(Content.to_source(block.approach)); runtime.p.rocks = 1
	_check(runtime.smoke("block").ok,"independent cart fixture completes source intro through actual smoke command")
	runtime.progression.ensure_route()
	_check(runtime.progression.valid_route(runtime.s.blockRoute),"independent fixture has real source route before later restore RNG check")
	_check(scene.world.get("dynamic_cart") == true and scene.get("cart_view") != null,"real adopted cart is an incident integration dependency")
	if scene.world.get("dynamic_cart") != true or scene.get("cart_view") == null: return
	var cart: Dictionary = runtime.travel.cart_record()
	var approach: Vector3 = adapter.cart_approach(Vector2(cart.x,cart.y))
	_check(approach.is_finite(),"real parked cart has a physical mounting approach")
	if not approach.is_finite(): return
	_place(Content.to_source(approach))
	_check(runtime.travel.interact_cart().ok and runtime.p.cartMounted,"actual Travel mounts its sole authoritative cart")
	_check(adapter.sync_cart(),"mounted cart removes its parked solid before incident planning")
	await physics_frame; await physics_frame
	_place(Vector2(1080,960)); _arm()
	var preview: Dictionary = runtime.incidents.preview_scene("runaway_mattress")
	var plan: Dictionary = runtime.incident_paths.mattress_segments(preview)
	var candidate := Vector2.INF
	if plan.get("ok",false):
		for segment: Dictionary in plan.segments:
			for ratio: float in [0.25,0.5,0.75]:
				var proposed: Vector2 = Content.to_source(segment.from.lerp(segment.to,ratio))-Vector2(12,10)
				if adapter.find_cart_drop(proposed,0.0) is Vector2:
					candidate = proposed; break
			if candidate.is_finite(): break
	_check(candidate.is_finite(),"actual unreserved route contains a clear cart-drop counterexample")
	if not candidate.is_finite(): return
	_step()
	if not runtime.s.incident is Dictionary or adapter._reservation_clear(adapter._cart_envelope(candidate)): _diagnostic("cart_reserved_candidate")
	_check(runtime.s.incident is Dictionary and not adapter._reservation_clear(adapter._cart_envelope(candidate)),"real scheduler reserves the certified drop candidate in the same frame")
	var before: Dictionary = runtime.snapshot(); var seed: int = runtime.state.rng_seed
	_check(adapter.find_cart_drop(candidate,0.0) == null,"actual cart drop refuses active corridor before any later physics frame")
	var bottle: Vector2 = candidate+Vector2(12,10)
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",bottle,0.0) == null,"actual bottle staging refuses same reserved sweep")
	_check(runtime.snapshot() == before and runtime.state.rng_seed == seed,"both physical refusals leave authoritative state/RNG unchanged")
	runtime.s.flags.silenceUntilT = Time.get_unix_time_from_system()*1000.0+60000.0
	_step()
	_check(runtime.s.incident == null and runtime.incident_corridors.status().active.is_empty() and scene.incident_view.metrics().active_id.is_empty(),"source busy/silence interruption releases live reservation and mesh")
	runtime.s.flags.silenceUntilT = 0.0
	_check(adapter.find_cart_drop(candidate,0.0) is Vector2,"same exact cart candidate recovers after synchronous release")
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",bottle,0.0) == bottle,"same exact bottle candidate recovers after release")
	adapter._interactive_approaches.erase("interactive:6")
	await _flush()
	groups += 1
func _restore_and_fresh_epochs() -> void:
	var runtime: RefCounted = scene.runtime
	_place(Vector2(1080,960)); _arm(); _step()
	if not runtime.s.incident is Dictionary: _diagnostic("restore_fixture")
	_check(runtime.s.incident is Dictionary,"restore fixture has a real active reserved incident")
	await _flush()
	var saved: Dictionary = runtime.snapshot(); saved.rng_seed = 0x1847a39b
	memory_store.data = saved.duplicate(true)
	var old_player: Dictionary = runtime.p; var old_state: Dictionary = runtime.s
	await scene._load()
	_check(not is_same(old_player,runtime.p) and not is_same(old_state,runtime.s) and runtime.s.mode == "paused","actual scene load replaces both epochs then awaits Continue")
	_check(runtime.s.incident == null and runtime.s.incidentPaperT == 0 and runtime.s.incidentWetT == 0 and runtime.incident_corridors.status().active.is_empty() and scene.incident_view.metrics().active_id.is_empty(),"actual restore clears scene/cosmetics/reservation/presenter")
	_check(runtime.s.flags.incidentMask == saved.state.flags.incidentMask and runtime.s.flags.incidentsToday == saved.state.flags.incidentsToday,"restore retains exact source incident history")
	var expected: Dictionary = _draws(saved.rng_seed,25)
	_check(is_equal_approx(float(runtime.s.incidentT),35000.0+expected.values[0]*20000.0),"restore source incident-delay draw precedes bottle24")
	_bottles(expected,"restore")
	var seed: int = runtime.state.rng_seed
	_check(runtime.incidents.reset_session("restore") and runtime.interactive_props.reset_session("restore") and runtime.state.rng_seed == seed,"same-epoch rebind cannot reroll delay or eight bottles")
	scene._resume(); _place(Vector2(1080,960)); _arm(); _step()
	_check(runtime.s.incident is Dictionary,"fresh fixture starts actual source incident")
	await _flush()
	old_player = runtime.p; old_state = runtime.s; scene._new_game()
	_check(not is_same(old_player,runtime.p) and not is_same(old_state,runtime.s) and runtime.s.incident == null and runtime.incident_corridors.status().active.is_empty(),"actual new game drops old incident epoch before new staging")
	_check(scene.incident_view.metrics().active_id.is_empty(),"new game leaves no old scene meshes")
	groups += 1
func _run() -> void:
	scene = FullScene.new(); scene.qa_mode = true; root.add_child(scene)
	for frame: int in range(700):
		await process_frame
		if scene.ready_for_play: break
	_check(scene.ready_for_play,"actual full Scene completes cold composition")
	if scene.ready_for_play:
		scene.set_process(false)
		var old_store: Node = scene.store; memory_store = MemoryStore.new(); scene.add_child(memory_store); scene.store = memory_store; old_store.queue_free()
		_cold_and_fresh()
		if scene.runtime.get("incidents") != null and scene.get("incident_view") != null:
			await _clock_and_menus()
			await _cart_and_prop_reservations()
			await _restore_and_fresh_epochs()
	_check(groups == 4,"all four real composition groups executed without skipped dependencies")
	await _flush()
	for failure: String in failures: push_error(failure)
	print("3D INCIDENT RUNTIME GATE: %s (%d checks;4 actual Scene groups; cold/fresh/load/menu/clock/cart/props)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	scene.free(); quit(0 if failures.is_empty() else 1)
