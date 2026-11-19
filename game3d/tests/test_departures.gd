extends SceneTree
## Real source owners and static-world sweeps; no engine run by the packet author.
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Runtime = preload("res://scripts/full_runtime.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Roster = preload("res://scripts/character_roster.gd")
var world: Node3D
var adapter: RefCounted
var runtime: RefCounted
var checks := 0
var failures: Array[String] = []
var serial := 0
var native_pads: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok and failures.size() < 80: failures.append(label)
func _actor(id: String) -> Dictionary:
	for actor: Dictionary in runtime.state.npcs:
		if actor.id == id: return actor
	return {}
func _center(body: Dictionary) -> Vector2: return Vector2(body.x+body.w*0.5,body.y+body.h*0.5)
func _body(actor: Dictionary) -> Dictionary: return runtime.combat._geometry(actor)
func _frame() -> void:
	serial += 1; adapter.begin_navigation_frame(serial,float(serial)*50.0)
func _fresh() -> void:
	_check(runtime.fresh(),"real fresh composition succeeds")
	adapter.reset_navigation(); runtime.state.drain_events()
func _spawn_pair() -> Dictionary:
	runtime.days._fire_visitor(); runtime.days._spawn_price_guy()
	var visitor: Dictionary = {}
	for actor: Dictionary in runtime.state.npcs:
		if actor.get("isDay3Visitor",false): visitor = actor
	return {"visitor":visitor,"price":_actor("price_guy")}
func _near(actor: Dictionary) -> bool:
	var center: Vector2 = _center(actor)
	for offset: Vector2 in [Vector2(0,40),Vector2(40,0),Vector2(-40,0),Vector2(0,-40),Vector2(28,28),Vector2(-28,28)]:
		var point: Vector2 = center+offset-Vector2(runtime.p.w,runtime.p.h)*0.5
		var body: Dictionary = runtime.p.duplicate(true); body.id = "player"
		if not adapter._clear(body,point,false): continue
		runtime.p.x = point.x; runtime.p.y = point.y
		if adapter.can_reach_target(str(actor.id)): return true
	return false
func _trigger(actor: Dictionary,action: String) -> bool:
	if not _near(actor): _check(false,"real player can approach "+str(actor.id)); return false
	var opened: Dictionary = runtime.open_day_actor(str(actor.id))
	_check(opened.get("ok",false),"live source Day menu opens "+str(actor.id))
	if not opened.get("ok",false): return false
	var result: Dictionary = runtime.select_day_actor(opened.token,action)
	_check(result.get("ok",false) and actor.get("wanderOff",false),"source callback commits wanderOff "+str(actor.id))
	return result.get("ok",false) and actor.get("wanderOff",false)
func _plan(actor: Dictionary,edge: String,limit: int = 14000) -> Dictionary:
	for index: int in range(limit):
		_frame()
		var result: Dictionary = adapter.resolve_departure(_body(actor),edge)
		if not result.is_empty(): return result
		var status: Dictionary = adapter.departure_status(str(actor.id))
		if status.status == "failed":
			_check(false,"actual plan failed "+str(actor.id)+": "+JSON.stringify(status)); return {}
		if index%32 == 0: await physics_frame
	_check(false,"bounded actual plan did not finish "+str(actor.id)+": "+JSON.stringify(adapter.departure_status(str(actor.id))))
	return {}
func _certify(route: Dictionary,actor: Dictionary) -> void:
	_check(not route.is_empty(),"real actual route exists "+str(actor.id))
	if route.is_empty(): return
	_check(route.route.size() > 1 and route.route.size() <= 2048 and route.route[-1] == route.target,"route ends at named pad "+str(actor.id))
	var named: bool = false
	for pad: Dictionary in world.departure_pads():
		if pad.id == route.exit_id and pad.source == route.target: named = true
	_check(named,"target is an authored visible pad "+str(actor.id))
	var half := Vector2(actor.w,actor.h)*0.5
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for index: int in range(route.route.size()-1):
		var a: Vector2 = route.route[index]; var b: Vector2 = route.route[index+1]
		var query: PhysicsShapeQueryParameters3D = adapter._query(_body(actor),a-half)
		_check(space.intersect_shape(query,1).is_empty(),"actual full-height route start clears "+str(actor.id))
		query.motion = Vector3(b.x-a.x,0,b.y-a.y)*0.04
		var fraction: PackedFloat32Array = space.cast_motion(query)
		_check(fraction.size() == 2 and fraction[0] >= 0.999999,"actual full-height route segment clears "+str(actor.id))
		query.motion = Vector3.ZERO
		query.transform.origin = Content.to_world(b,Adapter.FEET+adapter._height(str(actor.id),actor)*0.5)
		_check(space.intersect_shape(query,1).is_empty(),"actual full-height route end clears "+str(actor.id))
func _walk_pair() -> void:
	_fresh()
	var canonical: Array[String] = []
	for row: Dictionary in runtime.state.npcs: canonical.append(row.id)
	var pair: Dictionary = _spawn_pair()
	_check(not pair.visitor.is_empty() and not pair.price.is_empty(),"actual Day owners stage both canonical departure actors")
	if pair.visitor.is_empty() or pair.price.is_empty(): return
	runtime.p.cash = 17
	if not _trigger(pair.visitor,"leave") or not _trigger(pair.price,"pay"): return
	_check(pair.visitor.speed == 1.2 and pair.visitor.targetX == 8680 and pair.price.speed == 1.4 and pair.price.targetX == -80,"source exact direction/speed remains owned by transactions")
	var player_before: Dictionary = runtime.p.duplicate(true)
	var seed: int = runtime.state.rng_seed
	var actor_flags: Dictionary = runtime.s.flags.duplicate(true)
	runtime.state.drain_events()
	# Keep the full live source roster. Only the departure consumer is accelerated;
	# this is physical arrival evidence, not an artificial60-AI performance claim.
	var routes: Dictionary = {}
	for actor: Dictionary in [pair.visitor,pair.price]:
		var visual: StringName = Roster.visual_for_actor(actor)
		var height: float = float(Roster.definition(visual).height)
		_check(is_equal_approx(adapter._height(str(actor.id),actor),height),"real rig metadata defines departure box height "+str(actor.id))
	for tick: int in range(14000):
		_frame()
		for actor: Dictionary in [pair.visitor,pair.price]:
			if _actor(str(actor.id)).is_empty(): continue
			var edge: String = "west" if actor.id == "price_guy" else "east"
			var route: Dictionary = adapter.resolve_departure(_body(actor),edge)
			if not route.is_empty() and not routes.has(actor.id): routes[actor.id] = route; _certify(route,actor)
			var status: Dictionary = adapter.departure_status(str(actor.id))
			if status.status == "failed": _check(false,"traversal route failed "+str(actor.id)+": "+JSON.stringify(status)); return
			var before: Vector2 = _center(actor)
			var removed: bool = runtime.director._depart(actor,50.0)
			_check(before.distance_to(_center(actor)) <= float(actor.speed)*50.0/16.0+0.002,"actual sweep never grants extra source movement "+str(actor.id))
			if removed:
				_check(not route.is_empty() and _center(actor).distance_to(route.target) <= 4.0001,"despawn requires actual edge-pad arrival "+str(actor.id))
				adapter.unregister_body(str(actor.id))
			else:
				_check(adapter._clear(_body(actor),Vector2(actor.x,actor.y),false),"every traversed body endpoint remains actually clear "+str(actor.id))
		if _actor(str(pair.visitor.id)).is_empty() and _actor("price_guy").is_empty(): break
		if tick%32 == 0: await physics_frame
	_check(_actor(str(pair.visitor.id)).is_empty() and _actor("price_guy").is_empty(),"both source day actors physically leave")
	_check(routes.size() == 2,"both simultaneous bounded planners reach certified routes")
	_check(runtime.p == player_before and runtime.state.rng_seed == seed and runtime.s.flags == actor_flags,"departure grants no payout/state/RNG changes after exact source transactions")
	for id: String in canonical: _check(not _actor(id).is_empty(),"departure keeps canonical actor "+id)
	var departed: int = 0
	for event: Dictionary in runtime.state.drain_events():
		if event.kind == "actor_departed": departed += 1
		_check(event.kind not in ["actor_died","save_requested","achievement","cash_pickup"],"departure emits no death/reward/save substitute")
	_check(departed == 2,"exactly two physical departure receipts")
func _block_pad(point: Vector2,owner: String) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(2.4,3.1,2.4); collider.shape = shape
	body.add_child(collider); world.add_child(body); body.position = Content.to_world(point,1.55)
	adapter.update_navigation_obstacles(owner,[{"owner":owner,"bounds":AABB(body.position-shape.size*0.5,shape.size)}])
	return body
func _fallback_and_lifetimes() -> void:
	_fresh(); runtime.days._spawn_price_guy()
	var actor: Dictionary = _actor("price_guy"); runtime.p.cash = 5
	if actor.is_empty() or not _trigger(actor,"pay"): return
	var first: Dictionary = await _plan(actor,"west"); _certify(first,actor)
	if first.is_empty(): return
	var original_target: Vector2 = first.target
	first.route[0] = Vector2(-999,-999); first.target = Vector2(-999,-999)
	var fresh: Dictionary = adapter.resolve_departure(_body(actor),"west")
	_check(not fresh.is_empty() and fresh.target == original_target and fresh.route[0].x >= 0,"caller route edits cannot mutate cached authority")
	var blocker: StaticBody3D = _block_pad(original_target,"departure_fixture:late_cart")
	_frame()
	_check(adapter.resolve_departure(_body(actor),"west").is_empty(),"same-frame newly published solid invalidates old route before physics publication")
	await physics_frame; await physics_frame
	var alternate: Dictionary = await _plan(actor,"west"); _certify(alternate,actor)
	_check(not alternate.is_empty() and alternate.target != original_target,"occupied current exit selects another authored same-edge pad")
	blocker.free(); adapter.update_navigation_obstacles("departure_fixture:late_cart",[])
	await physics_frame
	var seed: int = runtime.state.rng_seed
	var player_epoch: Dictionary = runtime.state.p
	runtime.state.p = player_epoch.duplicate(true)
	_frame(); _check(adapter.resolve_departure(_body(actor),"west").is_empty(),"p-only epoch cannot reuse old physical certificate")
	var state_epoch: Dictionary = runtime.state.s
	runtime.state.s = state_epoch.duplicate(true)
	_frame(); _check(adapter.resolve_departure(_body(actor),"west").is_empty(),"s-only epoch cannot reuse old physical certificate")
	_check(runtime.state.rng_seed == seed,"epoch/cache cleanup consumes no gameplay RNG")
	var replacement: Dictionary = actor.duplicate(true)
	for index: int in range(runtime.state.npcs.size()):
		if is_same(runtime.state.npcs[index],actor): runtime.state.npcs[index] = replacement; break
	_frame(); _check(adapter.resolve_departure(_body(replacement),"west").is_empty(),"same-ID live actor replacement cannot reuse previous route")
	_check(adapter._departure_entries.is_empty() or is_same(adapter._departure_entries.price_guy.actor,replacement),"route retains the current exact live actor")
	var stale: Dictionary = _body(replacement); stale.x += 1
	_check(adapter.resolve_departure(stale,"west").is_empty(),"stale detached body cannot drive live departure")
	_check(adapter.resolve_departure(_body(replacement),"east").is_empty(),"wrong direction refuses rather than routing to opposite edge")
	replacement.dead = true
	_check(adapter.resolve_departure(_body(replacement),"west").is_empty() and adapter.departure_status("price_guy").status == "absent","dead actor cannot retain departure work")
func _bounded_failure() -> void:
	_fresh(); runtime.days._spawn_price_guy()
	var actor: Dictionary = _actor("price_guy"); runtime.p.cash = 3
	if actor.is_empty() or not _trigger(actor,"pay"): return
	var solids: Array[StaticBody3D] = []
	for pad: Dictionary in world.departure_pads():
		if pad.edge == "west": solids.append(_block_pad(pad.source,"departure_fixture:"+pad.id))
	await physics_frame; await physics_frame
	_frame()
	for index: int in range(400): adapter.resolve_departure(_body(actor),"west")
	var before: Dictionary = adapter.departure_metrics()
	_check(int(before.work) <= 256 and int(before.max_sweeps) <= 4,"repeated caller cannot reset per-render work or sweep caps")
	for frame: int in range(20): _frame(); adapter.resolve_departure(_body(actor),"west")
	var status: Dictionary = adapter.departure_status("price_guy")
	_check(status.status == "failed","all occupied exit pads produce explicit finite failure")
	var started: int = adapter.departure_metrics().started
	var position: Vector2 = _center(actor)
	for frame: int in range(20): _frame(); runtime.director._depart(actor,50.0)
	_check(adapter.departure_metrics().started == started and _center(actor) == position and not _actor("price_guy").is_empty(),"failed route neither spins retries nor teleports/deletes actor")
	for solid: StaticBody3D in solids: solid.free()
	for pad: Dictionary in world.departure_pads():
		if pad.edge == "west": adapter.update_navigation_obstacles("departure_fixture:"+pad.id,[])
	await physics_frame
func _run() -> void:
	world = World.new(); root.add_child(world); world.build()
	adapter = Adapter.new(world); runtime = Runtime.new(adapter,null,func(): return 1763424000000.0)
	adapter.bind_state(runtime.state)
	await physics_frame; await physics_frame
	_check(runtime.enable_actor_simulation(),"real Runtime retains Combat/Director")
	_check(runtime.days_enabled,"real Day owner installed")
	native_pads = world.departure_pads()
	var west: int = 0; var east: int = 0
	for pad: Dictionary in native_pads:
		if pad.edge == "west": west += 1
		else: east += 1
		_check(world.is_clear_position(Content.to_world(pad.source),0.7),"authored edge pad retains source world clearance "+pad.id)
	_check(west >= 2 and east >= 2,"both source edges have actual visible fallback pads")
	var found_signs: int = 0
	for child: Node in world.get_children():
		if child is Label3D and child.text == "exit": found_signs += 1
	_check(found_signs == native_pads.size(),"every published pad has a real lowercase mounted sign")
	await _walk_pair()
	await _fallback_and_lifetimes()
	await _bounded_failure()
	var metrics: Dictionary = adapter.departure_metrics()
	_check(metrics.max_entries <= 2 and metrics.max_work <= 256 and metrics.max_sweeps <= 4,"bounded departure memory/work/physical-query caps remain enforced")
	print("DEPARTURE METRICS: ",JSON.stringify(metrics))
	if failures.is_empty(): print("3D DEPARTURE PHYSICS GATE: PASS (%d checks; actual two-source transactions, full-height paths and physical removals; no native timing claim)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D DEPARTURE PHYSICS GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
