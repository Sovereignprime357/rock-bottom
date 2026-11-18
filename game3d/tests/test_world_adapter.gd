extends SceneTree
const Adapter = preload("res://scripts/world_adapter.gd")
const State = preload("res://scripts/game_state.gd")
const Content = preload("res://scripts/content_catalog.gd")
class TestWorld extends Node3D:
	var service_points: Dictionary = {}
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _box(parent: Node3D,location: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1; body.collision_mask = 0
	parent.add_child(body); body.position = location
	var shape := BoxShape3D.new(); shape.size = size
	var collider := CollisionShape3D.new(); collider.shape = shape; body.add_child(collider)
	return body
func _run() -> void:
	var world := TestWorld.new(); root.add_child(world)
	_box(world,Vector3(0,-0.1,0),Vector3(100,0.2,100))
	var wall: StaticBody3D = _box(world,Vector3(0,1.5,0),Vector3(0.2,3,20))
	wall.set_meta("source_owner","test_wall")
	var model: RefCounted = State.new()
	model.npcs.clear() # Static-wall fixture; actor contact has separate physical witnesses.
	var adapter: RefCounted = Adapter.new(world,model)
	await physics_frame; await physics_frame
	var body: Dictionary = {"id":"player","x":1000.0,"y":840.0,"w":24.0,"h":28.0}
	var copy: Dictionary = body.duplicate(true)
	var moved: Dictionary = adapter.move_body(body,Vector2(1100,840),null,true)
	_check(moved.blocked and moved.position.x > 1000 and moved.position.x < 1036,"high-speed body sweep stops before wall with full capsule radius")
	_check(body == copy,"physical adapter never mutates authoritative geometry record")
	_check(adapter.clear_placement(body) == Vector2(1000,840),"valid exact placement is retained")
	var slide: Dictionary = adapter.move_body(body,Vector2(1100,900),null,false)
	var charge: Dictionary = adapter.move_body(body,Vector2(1100,900),null,true)
	_check(slide.blocked and slide.position.y > charge.position.y+5.0,"ordinary motion slides while charge stops on impact")
	_check(slide.position.x < 1036 and charge.position.x < 1036,"slide cannot leak through wall")
	_check(adapter.move_body(body,Vector2(NAN,3)).position == Vector2(1000,840),"invalid intended position cannot move")
	_check(adapter.clear_placement({"x":-1000,"y":-1000,"w":24,"h":28}) == null,"clear placement cannot choose outside world bounds")
	var from := Vector2(1000,854)
	var to := Vector2(1100,854)
	_check(not adapter.can_hit(from,to,"player","tony"),"live wall rejects combat LOS")
	var shot: Dictionary = adapter.sweep_projectile(from,to,0.5)
	_check(shot.blocked and shot.fraction > 0 and shot.fraction < 0.5 and shot.position.x < 1050,"projectile sweep catches first thin wall at high speed")
	_check(adapter.sweep_projectile(Vector2(1050,854),to,0.5).fraction == 0,"projectile starting inside wall fails closed")
	model.p.x = 1000; model.p.y = 840
	world.service_points.test = {"target":Content.to_world(Vector2(1060,854),1.25),"reach":2.4,"structure_id":"","kind":"route"}
	_check(not adapter.can_reach_target("test"),"interaction cannot reach through unrelated wall")
	world.service_points.contact = {"target":Content.to_world(Vector2(1050,854),1.25),"reach":2.4,"structure_id":"test_wall","kind":"route"}
	_check(adapter.can_reach_target("contact"),"declared visible wall contact is reachable")
	_check(not adapter.can_reach_target("missing"),"unknown service fails closed")
	wall.queue_free(); await process_frame; await physics_frame
	_check(adapter.can_hit(from,to,"player","tony") and adapter.can_reach_target("test"),"wall removal updates live combat and service visibility without cached permission")
	_check(not adapter.sweep_projectile(from,to,0.5).blocked,"removed wall no longer blocks projectiles")
	_check(adapter.move_body(body,Vector2(1100,840)).position.is_equal_approx(Vector2(1100,840)),"clear motion reaches exact intended source position")
	model.npcs.clear()
	model.npcs.append({"id":"vendor","x":1018,"y":840,"w":28,"h":32,"dead":false})
	_check(adapter.can_reach_target("vendor"),"moving source actor is queried at current position")
	model.npcs[0].x = 1200
	_check(not adapter.can_reach_target("vendor"),"actor movement invalidates prior reach")
	model.cash_piles.clear()
	model.cash_piles.append({"id":"near","x":1012,"y":854,"amt":10,"collected":false})
	_check(adapter.can_reach_target("cash:near"),"cash uses live source coordinates")
	model.cash_piles[0].collected = true
	_check(not adapter.can_reach_target("cash:near"),"collected cash is no longer an eligible target")
	world.queue_free(); await process_frame
	_check(not adapter.can_hit(from,to,"player","vendor"),"freed physics world fails closed")
	if failures.is_empty():
		print("3D PHYSICS ADAPTER GATE: PASS (%d checks; native shape/ray/sphere sweeps, slide/charge, live access, no model mutation)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D PHYSICS ADAPTER GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
