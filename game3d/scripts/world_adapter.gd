class_name RockBottomWorldAdapter
extends RefCounted
## Actual3D query bridge. The model commits returned positions; this adapter never changes it.
const Content = preload("res://scripts/content_catalog.gd")
const Navigation = preload("res://scripts/actor_navigation.gd")
const Roster = preload("res://scripts/character_roster.gd")
const SCALE := 0.04
const FEET := 0.06
const CONTACT_SKIN := 0.0025
var _world_ref: WeakRef
var _state_ref: WeakRef
var _bodies: Dictionary = {}
var _height_profiles: Dictionary = {}
var _shapes: Dictionary = {}
var _spheres: Dictionary = {}
var _navigation: RefCounted
var _navigation_player: Dictionary = {}
var _navigation_state: Dictionary = {}
var _placement_clear: Dictionary = {}
var _placement_render: int = -1
var _placement_physics: int = -1
var _collision_revision: int = 0
var placement_cache_hits: int = 0
var placement_overlap_queries: int = 0
var query_count: int = 0

func _init(world_node: Node3D, game_state: RefCounted = null) -> void:
	_world_ref = weakref(world_node)
	_state_ref = weakref(game_state) if game_state != null else null
	var bounds: Dictionary = Content.load_content().world.bounds
	_navigation = Navigation.new(Rect2(0,0,float(bounds.w),float(bounds.h)))
	if world_node != null and world_node.has_method(&"obstacle_records"):
		_navigation.set_obstacles(world_node.call(&"obstacle_records"))

func bind_state(game_state: RefCounted) -> void:
	_state_ref = weakref(game_state)
	reset_navigation()

func _sync_navigation_epoch() -> void:
	var host: RefCounted = _host()
	if host != null and (not is_same(_navigation_player,host.p) or not is_same(_navigation_state,host.s)):
		reset_navigation()

func begin_navigation_frame(render_serial: int,active_ms: float) -> void:
	_sync_navigation_epoch()
	if render_serial != _placement_render:
		_placement_clear.clear()
		_placement_render = render_serial
	_navigation.begin_frame(render_serial,active_ms)

func reset_navigation() -> void:
	_navigation.reset()
	_height_profiles.clear()
	invalidate_placement_cache()
	var host: RefCounted = _host()
	_navigation_player = host.p if host != null else {}
	_navigation_state = host.s if host != null else {}

func invalidate_navigation_actor(id: String) -> void:
	_navigation.invalidate_actor(id)
	_placement_clear.erase(id)
func invalidate_placement_cache() -> void:
	_collision_revision += 1
	_placement_clear.clear()
func update_navigation_obstacles(owner: String,records: Array) -> bool:
	var changed: bool = _navigation.update_obstacles(owner,records)
	if changed: invalidate_placement_cache()
	return changed
func navigation_metrics() -> Dictionary:
	var result: Dictionary = _navigation.metrics()
	result.placement_cache_hits = placement_cache_hits
	result.placement_overlap_queries = placement_overlap_queries
	return result
func navigation_status(id: String) -> Dictionary: return _navigation.actor_status(id)

func register_body(id: String,node: Node3D,height: float = 1.8) -> void:
	if not id.is_empty() and node != null and is_finite(height) and height > 0.05:
		invalidate_navigation_actor(id)
		_height_profiles.erase(id)
		_bodies[id] = {"node":weakref(node),"height":height}

func unregister_body(id: String) -> void:
	_bodies.erase(id)
	_height_profiles.erase(id)
	invalidate_navigation_actor(id)

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
func _height(id: String,hints: Dictionary = {}) -> float:
	var entry: Dictionary = _bodies.get(id,{})
	if not entry.is_empty() and entry.node.get_ref() != null: return float(entry.height)
	if id == "player": return 1.8
	var record: Dictionary = hints
	if not record.has("name") or not record.has("sprite"):
		var host: RefCounted = _host()
		if host != null:
			for actor: Dictionary in host.npcs:
				if str(actor.get("id","")) == id:
					record = actor
					break
	var cached: Dictionary = _height_profiles.get(id,{})
	if record.has("name") and record.has("sprite"):
		var visual: StringName = Roster.visual_for_actor(record)
		if not cached.is_empty() and cached.visual == visual: return float(cached.height)
		var definition: Dictionary = Roster.definition(visual) if not visual.is_empty() else {}
		if not definition.is_empty():
			var height: float = float(definition.height)
			if is_finite(height) and height > 0.05:
				_height_profiles[id] = {"visual":visual,"height":height}
				return height
		_height_profiles.erase(id)
	elif not cached.is_empty(): return float(cached.height)
	return 1.8
func _shape(body: Dictionary) -> Shape3D:
	var id: String = str(body.get("id","player"))
	var height: float = _height(id,body)
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
	query.transform = Transform3D(Basis.IDENTITY,Content.to_world(center,FEET+_height(str(body.get("id","player")),body)*0.5))
	query.collision_mask = 1
	query.margin = 0.002
	return query
func _clear(body: Dictionary,point: Vector2,allow_certificate: bool = true) -> bool:
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null: return false
	var bounds: Dictionary = Content.load_content().world.bounds
	if point.x < 0 or point.y < 0 or point.x+float(body.w) > float(bounds.w) or point.y+float(body.h) > float(bounds.h): return false
	var physics_frame: int = Engine.get_physics_frames()
	if physics_frame != _placement_physics:
		_placement_clear.clear(); _placement_physics = physics_frame
	var id: String = str(body.get("id","player"))
	var height: float = _height(id,body)
	if allow_certificate and _placement_render >= 0:
		var cached: Dictionary = _placement_clear.get(id,{})
		if not cached.is_empty() and cached.point == point and cached.width == body.w and cached.depth == body.h and cached.height == height and cached.revision == _collision_revision:
			placement_cache_hits += 1
			return true
	query_count += 1
	placement_overlap_queries += 1
	var clear: bool = space.intersect_shape(_query(body,point),1).is_empty()
	if clear and allow_certificate and _placement_render >= 0:
		_placement_clear[id] = {"point":point,"width":body.w,"depth":body.h,"height":height,"revision":_collision_revision}
	elif not clear: _placement_clear.erase(id)
	return clear

func move_body(body: Dictionary,intended: Vector2,goal: Variant = null,stop_on_block: bool = false) -> Dictionary:
	if not _valid_body(body): return {"position":Vector2.ZERO,"blocked":true}
	var origin := Vector2(float(body.get("x",0)),float(body.get("y",0)))
	var failed := {"position":origin,"blocked":true}
	if not intended.is_finite() or (goal != null and (not goal is Vector2 or not goal.is_finite())): return failed
	_sync_navigation_epoch()
	var bounds: Dictionary = Content.load_content().world.bounds
	intended = intended.clamp(Vector2.ZERO,Vector2(float(bounds.w)-float(body.w),float(bounds.h)-float(body.h)))
	var id: String = str(body.get("id","player"))
	if id == "player": return _move_body_raw(body,intended,stop_on_block)
	if stop_on_block:
		_navigation.invalidate_actor(id)
		return _move_body_raw(body,intended,true)
	var height: float = _height(id,body)
	var steering: Dictionary = _navigation.steering(body,intended,goal,height)
	var result: Dictionary = _move_body_raw(body,steering.intended,false)
	_navigation.note_motion(body,origin,intended,result,goal,height)
	return result

func _move_body_raw(body: Dictionary,intended: Vector2,stop_on_block: bool) -> Dictionary:
	var origin := Vector2(float(body.x),float(body.y))
	var failed := {"position":origin,"blocked":true}
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null or not _clear(body,origin): return failed
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
		var step_from: Vector2 = position
		var plane_motion := Vector2(motion.x,motion.z)/SCALE
		var proposed: Vector2 = step_from+plane_motion*safe
		var endpoint_clear: bool = _clear(body,proposed,false)
		if safe >= 0.999999 and endpoint_clear:
			position = proposed
			break
		blocked = true
		# A cast's safe fraction can still fail the same-margin overlap query on the
		# next frame. Retain skin before contact; never weaken _clear to hide it.
		var skinned: float = maxf(0.0,safe-CONTACT_SKIN/maxf(motion.length(),0.000001))
		proposed = step_from+plane_motion*skinned
		if _clear(body,proposed,false): position = proposed
		else:
			# Rare glancing-contact fallback: find a verified point on this same
			# already cast segment, bounded to8 overlap probes, never a teleport.
			var low: float = 0.0
			var high: float = skinned
			position = step_from
			for probe: int in range(8):
				var fraction: float = (low+high)*0.5
				var candidate: Vector2 = step_from+plane_motion*fraction
				if _clear(body,candidate,false): low = fraction; position = candidate
				else: high = fraction
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
	_sync_navigation_epoch()
	var origin := Vector2(float(body.x),float(body.y))
	if _clear(body,origin): return origin
	for radius: float in [4.0,8.0,16.0,24.0,40.0,64.0,100.0]:
		for index: int in range(16):
			var angle: float = float(index)*TAU/16.0
			var candidate := origin+Vector2(cos(angle),sin(angle))*radius
			if _clear(body,candidate): return candidate
	var id: String = str(body.get("id","player"))
	if not _bodies.has(id): _height_profiles.erase(id)
	return null


func stage_cash_pickup(source_center: Vector2,maximum_px: float = 100.0) -> Variant:
	if not source_center.is_finite() or not is_finite(maximum_px) or maximum_px < 0.0 or maximum_px > 100.0: return null
	var bounds: Dictionary = Content.load_content().world.bounds
	if source_center.x < 0 or source_center.y < 0 or source_center.x > float(bounds.w) or source_center.y > float(bounds.h): return null
	var host: RefCounted = _host()
	if host == null or not _valid_body(host.p): return null
	_sync_navigation_epoch()
	var half := Vector2(float(host.p.w),float(host.p.h))*0.5
	var body := {"id":"player","x":0.0,"y":0.0,"w":host.p.w,"h":host.p.h}
	var candidates: Array[Vector2] = [source_center]
	var radii: Array[float] = []
	for radius: float in [4.0,8.0,16.0,24.0,40.0,64.0,100.0]:
		if radius <= maximum_px: radii.append(radius)
	if maximum_px > 0.0 and (radii.is_empty() or radii[-1] != maximum_px): radii.append(maximum_px)
	for radius: float in radii:
		for index: int in range(16):
			var angle: float = float(index)*TAU/16.0
			candidates.append(source_center+Vector2(cos(angle),sin(angle))*radius)
	for center: Vector2 in candidates:
		if center.distance_to(source_center) > maximum_px+0.0001: continue
		if center != source_center and not _ray(Content.to_world(source_center,0.18),Content.to_world(center,0.18)).is_empty(): continue
		var top_left: Vector2 = center-half
		body.x = top_left.x; body.y = top_left.y
		if not _clear(body,top_left,false): continue
		var eye: Vector3 = Content.to_world(center,FEET+_height("player")*0.8)
		if _ray(eye,Content.to_world(center,0.18)).is_empty(): return center
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
	if id == "quest:crown":
		var crown: Variant = host.s.get("crownPickup")
		if not crown is Dictionary or crown.get("collected",true): return false
		target = Content.to_world(Vector2(crown.x,crown.y),0.14); reach = 0.72; found = true
	elif id.begins_with("cash:"):
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
	var eye: Vector3 = Content.to_world(origin,FEET+1.63)
	if Vector2(eye.x,eye.z).distance_to(Vector2(target.x,target.z)) >= reach: return false
	var hit: Dictionary = _ray(eye,target)
	return hit.is_empty() or (not owner.is_empty() and hit.get("collider") is CollisionObject3D and str(hit.collider.get_meta("source_owner","")) == owner)

func can_use_zone(id: String) -> bool:
	# Zone verbs do not require a walk or ray to their map guidance marker.
	# Exact venue membership and availability are owned by MemoryLoop.
	var known: bool = false
	for spot: Dictionary in Content.definition("src/systems/concessions.js","SMOKE_SPOTS",[]):
		if spot.id == id: known = true; break
	if not known: return false
	var host: RefCounted = _host()
	if host == null: return false
	var body := {"id":"player","x":host.p.x,"y":host.p.y,"w":host.p.w,"h":host.p.h}
	return _valid_body(body) and _clear(body,Vector2(body.x,body.y))
