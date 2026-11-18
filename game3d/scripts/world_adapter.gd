class_name RockBottomWorldAdapter
extends RefCounted
## Actual3D query bridge. The model commits returned positions; this adapter never changes it.
const Content = preload("res://scripts/content_catalog.gd")
const SCALE := 0.04
const FEET := 0.06
var _world_ref: WeakRef
var _state_ref: WeakRef
var _bodies: Dictionary = {}
var _shapes: Dictionary = {}
var _spheres: Dictionary = {}
var query_count: int = 0

func _init(world_node: Node3D, game_state: RefCounted = null) -> void:
	_world_ref = weakref(world_node)
	_state_ref = weakref(game_state) if game_state != null else null

func bind_state(game_state: RefCounted) -> void: _state_ref = weakref(game_state)

func register_body(id: String,node: Node3D,height: float = 1.8) -> void:
	if not id.is_empty() and node != null and is_finite(height) and height > 0.05:
		_bodies[id] = {"node":weakref(node),"height":height}

func _world() -> Node3D: return _world_ref.get_ref() as Node3D
func _host() -> RefCounted: return _state_ref.get_ref() if _state_ref != null else null
func _space() -> PhysicsDirectSpaceState3D:
	var world: Node3D = _world()
	return world.get_world_3d().direct_space_state if world != null and world.is_inside_tree() else null
func _valid_body(body: Dictionary) -> bool:
	for key: String in ["x","y","w","h"]:
		var value: Variant = body.get(key)
		if not (value is int or value is float) or not is_finite(float(value)): return false
	return float(body.w) > 0 and float(body.h) > 0
func _height(id: String) -> float:
	var entry: Dictionary = _bodies.get(id,{})
	if not entry.is_empty() and entry.node.get_ref() != null: return float(entry.height)
	return 1.8
func _shape(body: Dictionary) -> Shape3D:
	var id: String = str(body.get("id","player"))
	var height: float = _height(id)
	var key: String = "%s/%s/%s/%s" % [id == "player",body.w,body.h,height]
	if _shapes.has(key): return _shapes[key]
	var shape: Shape3D
	if id == "player":
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.48; capsule.height = maxf(0.96,height); shape = capsule
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(float(body.w)*SCALE,height,float(body.h)*SCALE); shape = box
	_shapes[key] = shape
	return shape
func _query(body: Dictionary,point: Vector2) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape(body)
	var center := point+Vector2(float(body.w),float(body.h))*0.5
	query.transform = Transform3D(Basis.IDENTITY,Content.to_world(center,FEET+_height(str(body.get("id","player")))*0.5))
	query.collision_mask = 1
	query.margin = 0.002
	return query
func _clear(body: Dictionary,point: Vector2) -> bool:
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null: return false
	var bounds: Dictionary = Content.load_content().world.bounds
	if point.x < 0 or point.y < 0 or point.x+float(body.w) > float(bounds.w) or point.y+float(body.h) > float(bounds.h): return false
	query_count += 1
	return space.intersect_shape(_query(body,point),1).is_empty()

func move_body(body: Dictionary,intended: Vector2,goal: Variant = null,stop_on_block: bool = false) -> Dictionary:
	var origin := Vector2(float(body.get("x",0)),float(body.get("y",0)))
	var failed := {"position":origin,"blocked":true}
	if not _valid_body(body) or not intended.is_finite() or (goal != null and (not goal is Vector2 or not goal.is_finite())): return failed
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null or not _clear(body,origin): return failed
	var bounds: Dictionary = Content.load_content().world.bounds
	intended = intended.clamp(Vector2.ZERO,Vector2(float(bounds.w)-float(body.w),float(bounds.h)-float(body.h)))
	var position: Vector2 = origin
	var motion: Vector3 = Vector3(intended.x-origin.x,0,intended.y-origin.y)*SCALE
	var blocked: bool = false
	for iteration: int in range(2):
		if motion.length_squared() < 0.00000001: break
		var query: PhysicsShapeQueryParameters3D = _query(body,position)
		query.motion = motion
		query_count += 1
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions.size() < 2: return failed
		var safe: float = fractions[0]
		position += Vector2(motion.x,motion.z)*safe/SCALE
		if safe >= 0.999999: break
		blocked = true
		if stop_on_block: break
		# Query the first unsafe overlap for the current live wall normal.
		query.transform.origin += motion*minf(1.0,float(fractions[1])+0.0001)
		query.motion = Vector3.ZERO
		query_count += 1
		var contact: Dictionary = space.get_rest_info(query)
		if contact.is_empty(): break
		var normal: Vector3 = contact.normal
		motion = (motion*(1.0-safe)).slide(normal)
	return {"position":position,"blocked":blocked}

func clear_placement(body: Dictionary) -> Variant:
	if not _valid_body(body): return null
	var origin := Vector2(float(body.x),float(body.y))
	if _clear(body,origin): return origin
	for radius: float in [4.0,8.0,16.0,24.0,40.0,64.0,100.0]:
		for index: int in range(16):
			var angle: float = float(index)*TAU/16.0
			var candidate := origin+Vector2(cos(angle),sin(angle))*radius
			if _clear(body,candidate): return candidate
	return null

func _ray(from: Vector3,to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null: return {"unavailable":true}
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	query.hit_from_inside = true
	query_count += 1
	return space.intersect_ray(query)

func can_hit(from_center: Vector2,to_center: Vector2,source_id: String,target_id: String) -> bool:
	if not from_center.is_finite() or not to_center.is_finite(): return false
	return _ray(Content.to_world(from_center,FEET+_height(source_id)*0.6),Content.to_world(to_center,FEET+_height(target_id)*0.6)).is_empty()

func sweep_projectile(start: Vector2,end: Vector2,radius: float) -> Dictionary:
	var stopped := {"blocked":true,"fraction":0.0,"position":start}
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null or not start.is_finite() or not end.is_finite() or not is_finite(radius) or radius <= 0: return stopped
	var metres: float = maxf(0.005,radius*SCALE)
	if not _spheres.has(metres):
		var created := SphereShape3D.new()
		created.radius = metres; _spheres[metres] = created
	var sphere: SphereShape3D = _spheres[metres]
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere; query.collision_mask = 1; query.margin = 0.0
	query.transform = Transform3D(Basis.IDENTITY,Content.to_world(start,1.0))
	query_count += 1
	if not space.intersect_shape(query,1).is_empty(): return stopped
	query.motion = Content.to_world(end,1.0)-query.transform.origin
	query_count += 1
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() < 2: return stopped
	var fraction: float = clampf(fractions[0],0.0,1.0)
	return {"blocked":fraction < 0.999999,"fraction":fraction,"position":start.lerp(end,fraction)}

func can_reach_target(id: String) -> bool:
	var host: RefCounted = _host()
	var world: Node3D = _world()
	if host == null or world == null or not world.is_inside_tree(): return false
	var origin: Vector2 = host.player_center()
	var target: Vector3
	var reach: float = 0.0
	var owner: String = ""
	var found: bool = false
	if id.begins_with("cash:"):
		for pile: Dictionary in host.cash_piles:
			if str(pile.id) != id.substr(5) or pile.get("collected",false) == true: continue
			target = Content.to_world(Vector2(pile.x,pile.y),0.14); reach = 0.56; found = true; break
		if not found: return false
	else:
		for actor: Dictionary in host.npcs:
			if str(actor.id) != id: continue
			if actor.get("dead",false) == true: return false
			target = Content.body_position(actor,FEET+_height(id)*0.7); reach = 2.4; found = true; break
	var services: Variant = world.get("service_points")
	if services is Dictionary and services.has(id):
		var service: Dictionary = services[id]
		owner = str(service.structure_id) if service.kind != "actor" else ""
		if not found: target = service.target; reach = float(service.reach); found = true
	if not found or not target.is_finite(): return false
	var eye: Vector3 = Content.to_world(origin,1.63)
	if Vector2(eye.x,eye.z).distance_to(Vector2(target.x,target.z)) >= reach: return false
	var hit: Dictionary = _ray(eye,target)
	return hit.is_empty() or (not owner.is_empty() and hit.get("collider") is CollisionObject3D and str(hit.collider.get_meta("source_owner","")) == owner)
