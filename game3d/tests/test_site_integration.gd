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
	var center: Vector2 = Content.to_source(point)
	runtime.p.x = center.x-runtime.p.w*0.5; runtime.p.y = center.y-runtime.p.h*0.5
func _run() -> void:
	world = World.new(); root.add_child(world); world.build()
	physics = Adapter.new(world); runtime = Runtime.new(physics); physics.bind_state(runtime.state)
	await physics_frame; await physics_frame
	var sides_found: int = 0
	for target: String in world.service_points:
		if not target.begins_with("copper:") and not target.begins_with("breakin:"): continue
		runtime.fresh(); runtime.p.equip.tool = "crowbar"; runtime.p.cred = 80; runtime.p.cash = 100
		var id: String = target.get_slice(":",1)
		var service: Dictionary = world.service_points[target]
		_place(service.approach)
		_check(physics.can_use_site(target),"actual entrance access "+id)
		_check(runtime.heists.site_at(runtime.state.player_center()) == id,"actual source expanded rectangle "+id)
		var menu: Dictionary = runtime.open_heist(id)
		_check(menu.get("ok",false) and menu.get("domain") == "heist","production site menu "+id)
		if not menu.get("ok",false): continue
		var before: float = runtime.s.dayTime
		runtime.advance(0.5)
		_check(runtime.s.dayTime == before,"modal pauses authoritative world "+id)
		runtime.close_dialogue()
		_check(not runtime.heists.is_active() and not runtime.select_heist(menu.token,"entry:0").get("ok",false),"closed source capability cannot replay "+id)
		# A side wall can be eligible even when the guidance front marker is far away.
		var rect: Rect2 = service.site_rect
		var side_ok: bool = false
		for point: Vector3 in [Vector3(rect.position.x-0.73,0,rect.get_center().y),Vector3(rect.end.x+0.73,0,rect.get_center().y),Vector3(rect.get_center().x,0,rect.position.y-0.73)]:
			_place(point)
			if physics.can_use_site(target) and not physics.can_reach_target(target): side_ok = true; break
		if side_ok: sides_found += 1
		_place(Vector3(rect.get_center().x,0,rect.end.y+0.80001))
		_check(not physics.can_use_site(target) and not runtime.open_heist(id).get("ok",false),"strict source20px edge rejects "+id)
	_check(sides_found >= 7,"source side-wall access covers at least7sites without front-radius proxy; found%d" % sides_found)
	_check(not physics.can_use_site("copper:unknown") and not physics.can_use_site("tony"),"unknown and non-site services fail closed")
	# Place an unrelated obstacle beyond the player's capsule but before its facade ray.
	var target: String = "copper:abandoned"
	var rect: Rect2 = world.service_points[target].site_rect
	_place(Vector3(rect.position.x-0.78,0,rect.get_center().y))
	_check(physics.can_use_site(target),"clear west facade before dynamic obstruction")
	var focus: Vector3 = physics.site_focus(target)
	var eye: Vector3 = Content.to_world(runtime.state.player_center(),Adapter.FEET+1.63)
	var blocker := StaticBody3D.new(); blocker.collision_layer = 1; blocker.collision_mask = 0
	blocker.set_meta("source_owner","unrelated"); world.add_child(blocker)
	blocker.position = eye.lerp(focus,0.85)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(0.04,0.25,0.4)
	shape.shape = box; blocker.add_child(shape)
	await physics_frame; await physics_frame; physics.invalidate_placement_cache()
	_check(physics.can_use_zone("block"),"obstruction does not embed the player capsule")
	_check(not physics.can_use_site(target),"unrelated facade obstruction rejects actual LOS")
	blocker.free(); await physics_frame; physics.invalidate_placement_cache()
	_check(physics.can_use_site(target),"removal restores live facade visibility")
	# The availability latch and authored boards survive fresh/restore in the same session.
	runtime.p.rank = 4; runtime.heists.sync_rank_unlock()
	for event: Dictionary in runtime.drain_events():
		if event.kind == "site_availability_changed": world.set_site_available(event.payload.id,event.payload.available)
	_check(not world.site_boards.abandoned.visible and not runtime.heists.site_available("abandoned"),"rank4 removes source trigger and visible boards")
	runtime.fresh()
	_check(not runtime.heists.site_available("abandoned"),"new game retains source session unboarding")
	world.free(); runtime = null; physics = null
	await process_frame
	if failures.is_empty():
		print("3D SITE INTEGRATION GATE: PASS (%d checks;9actual sites,facade/capsule/LOS,modal and rank latch)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D SITE INTEGRATION GATE: FAIL (%d/%d checks)" % [failures.size(),checks]); quit(1)
