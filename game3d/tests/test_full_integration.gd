extends SceneTree
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Runtime = preload("res://scripts/full_runtime.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node3D
var physics: RefCounted
var runtime: RefCounted
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _place(point: Vector3) -> void:
	var at: Vector2 = Content.to_source(point)
	runtime.p.x = at.x-float(runtime.p.w)*0.5; runtime.p.y = at.y-float(runtime.p.h)*0.5
func _run() -> void:
	world = World.new(); root.add_child(world); world.build()
	physics = Adapter.new(world)
	runtime = Runtime.new(physics); physics.bind_state(runtime.state)
	runtime.fresh()
	await physics_frame
	await physics_frame
	for key: String in world.service_points:
		var service: Dictionary = world.service_points[key]
		_place(service.approach)
		_check(physics.can_reach_target(key),"production live reach " + key)
	var office: Dictionary = world.service_points.office
	_place(office.target+Vector3(0,0,1.60))
	_check(physics.can_reach_target("office"),"office source reach includes40px")
	_place(office.target+Vector3(0,0,1.7596))
	_check(physics.can_reach_target("office"),"office source reach includes43.99px with real sight")
	_place(office.target+Vector3(0,0,1.76))
	_check(not physics.can_reach_target("office"),"office strict44px edge rejects")
	# Use the real capsule adapter for a canonical first-person intro chain.
	runtime.fresh(); runtime.drain_events()
	var pickup: Vector3 = world.service_points["cash:cp_intro_remember"].approach
	_place(pickup)
	_check(runtime.collect_cash("cp_intro_remember") and runtime.p.cash == 10,"actual low pickup visibility and guaranteed intro cash")
	var destination: Vector3 = world.service_points.tony.approach
	var route: PackedVector3Array = world.find_route(pickup,destination)
	_check(not route.is_empty(),"physical cash to Tony route exists")
	var walk_seconds: float = 0.0
	for waypoint: Vector3 in route:
		for step: int in range(12000):
			var offset: Vector2 = Content.to_source(waypoint)-runtime.state.player_center()
			if offset.length() < 0.1: break
			var delta: float = minf(1.0/60.0,offset.length()/137.5)
			var before: Vector2 = runtime.state.player_center()
			runtime.advance(delta,{"input_vector":offset.normalized()})
			walk_seconds += delta
			if runtime.state.player_center().distance_to(before) < 0.00001:
				_check(false,"cash to Tony controller blocked at " + str(before)); break
		_check(Content.to_source(waypoint).distance_to(runtime.state.player_center()) < 0.15,"controller reaches actual route waypoint")
	var menu: Dictionary = runtime.open_vendor("tony")
	_check(menu.get("ok",false),"Tony physically reachable from walked approach")
	if menu.get("ok",false):
		_check(runtime.select_vendor(menu.token,"buy_rock").get("ok",false) and runtime.p.rocks == 1,"actual spatial vendor purchase")
	_place(world.service_points["smoke:block"].approach)
	_check(runtime.smoke("block").get("ok",false) and runtime.s.flags.get("introDone",false),"real Block position/visibility and complete intro smoke")
	print("FULL INTEGRATION WALK: ",walk_seconds,"s; physics queries ",physics.query_count)
	_walk_critical_route()
	world.free(); runtime = null; physics = null
	await process_frame
	if failures.is_empty():
		print("3D FULL INTEGRATION GATE: PASS (%d checks; real world services, controller walk, purchase and smoke)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FULL INTEGRATION GATE: FAIL (%d / %d checks)" % [failures.size(),checks]); quit(1)

func _walk_critical_route() -> void:
	runtime.fresh()
	var start: Vector3 = world.service_points["route:pawn_sill"].approach
	var finish: Vector3 = world.service_points["route:ditch_gauge"].approach
	_place(start)
	var route: PackedVector3Array = world.find_route(start,finish)
	_check(not route.is_empty(),"critical route available for actual controller")
	var seconds: float = 0.0
	var blocked: bool = false
	for waypoint: Vector3 in route:
		for step: int in range(4000):
			var offset: Vector2 = Content.to_source(waypoint)-runtime.state.player_center()
			if offset.length() < 0.1: break
			var delta: float = minf(1.0/60.0,offset.length()/137.5)
			var before: Vector2 = runtime.state.player_center()
			runtime.advance(delta,{"input_vector":offset.normalized()})
			seconds += delta
			if runtime.state.player_center().distance_to(before) < 0.00001 or seconds > 60.0:
				blocked = true; break
		if blocked: break
	_check(not blocked,"critical controller walk has no stuck corner or60s budget crossing at " + str(runtime.state.player_center()))
	_check(Content.to_source(finish).distance_to(runtime.state.player_center()) < 0.15,"critical controller reaches real ditch approach")
	_check(seconds <= 60.0,"critical controller stays within60s at source base walk")
	print("FULL INTEGRATION CRITICAL WALK: ",seconds,"s; ",route.size()," waypoints; blocked=",blocked,"; actual fixed-step movement, no sprint/teleport between endpoints")
