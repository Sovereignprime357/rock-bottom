class_name RockBottomWorldAdapter
extends RefCounted
## Actual3D query bridge. The model commits returned positions; this adapter never changes it.
const Content = preload("res://scripts/content_catalog.gd")
const Navigation = preload("res://scripts/actor_navigation.gd")
const Roster = preload("res://scripts/character_roster.gd")
const Contact = preload("res://scripts/actor_contact.gd")
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
var _incident_reservation: Dictionary = {}
var _incident_query_shapes: Dictionary = {}
var placement_cache_hits: int = 0
var placement_overlap_queries: int = 0
var query_count: int = 0
var body_contact_tests: int = 0
var body_contacts: int = 0
var body_repairs: int = 0
var body_repairs_deferred: int = 0
var _contact_index: Dictionary = {}
var _contact_index_array: Variant = null
var _contact_index_player: Dictionary = {}
var _contact_index_state: Dictionary = {}
var _contact_index_size: int = -1
var _contact_index_frame: int = -1
var _contact_index_unique: bool = true
var contact_index_builds: int = 0
var _interactive_actions_ref: WeakRef
var _interactive_view_ref: WeakRef
var _interactive_approaches: Dictionary = {}
var _interactive_shapes: Dictionary = {}
var _interactive_epoch_player: Dictionary = {}
var _interactive_epoch_state: Dictionary = {}
var _cart_travel_ref: WeakRef
var _cart_view_ref: WeakRef
var _cart_player_epoch: Dictionary = {}
var _cart_state_epoch: Dictionary = {}
var _cart_certificate: Dictionary = {}
var _cart_query_shape: BoxShape3D

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
	_departure_pump()

func reset_navigation() -> void:
	_navigation.reset()
	_departure_entries.clear(); _departure_queue.clear()
	_height_profiles.clear()
	invalidate_placement_cache()
	var host: RefCounted = _host()
	_navigation_player = host.p if host != null else {}
	_navigation_state = host.s if host != null else {}

func invalidate_navigation_actor(id: String) -> void:
	_navigation.invalidate_actor(id)
	_departure_forget(id)
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
	result.body_contact_tests = body_contact_tests
	result.body_contacts = body_contacts
	result.body_repairs = body_repairs
	result.body_repairs_deferred = body_repairs_deferred
	result.contact_index_builds = contact_index_builds
	return result
func navigation_status(id: String) -> Dictionary: return _navigation.actor_status(id)

# Incident reservations constrain environmental prop staging only. They never
# enter actor/player motion, the nav obstacle index, persistence or wall clocks.
func _incident_epoch_current() -> bool:
	var host: RefCounted = _host()
	if host == null: _incident_reservation.clear(); return false
	if not _incident_reservation.is_empty() and (not is_same(_incident_reservation.player_epoch,host.p) or not is_same(_incident_reservation.state_epoch,host.s)):
		_incident_reservation.clear()
	return true
func incident_geometry_snapshot() -> Dictionary:
	if not _incident_epoch_current() or _space() == null: return {"ok":false}
	var records: Array[Dictionary] = []
	# Navigation is already the sole updated obstacle index. Reconstruct detached
	# world-space bounds from its normalized source-space records instead of keeping
	# a parallel mutable registry in this adapter.
	for record: Dictionary in _navigation._records:
		var rect: Rect2 = record.rect
		var point: Vector3 = Content.to_world(rect.position,float(record.low))
		records.append({"owner":str(record.owner),"bounds":AABB(point,Vector3(rect.size.x*SCALE,float(record.high)-float(record.low),rect.size.y*SCALE))})
	var host: RefCounted = _host()
	return {"ok":true,"revision":_collision_revision,"records":records,"player_epoch":host.p,"state_epoch":host.s}
func _incident_segment_valid(segment: Variant) -> bool:
	if not segment is Dictionary or not segment.get("from") is Vector3 or not segment.get("to") is Vector3 or not segment.get("size") is Vector3: return false
	var a: Vector3 = segment.from; var b: Vector3 = segment.to; var size: Vector3 = segment.size
	if not a.is_finite() or not b.is_finite() or not size.is_finite() or minf(size.x,minf(size.y,size.z)) <= 0 or maxf(size.x,maxf(size.y,size.z)) > 12.0: return false
	if a.y-size.y*0.5 < 0.001 or b.y-size.y*0.5 < 0.001 or maxf(a.y,b.y)+size.y*0.5 > 12.0: return false
	var bounds: Dictionary = Content.load_content().world.bounds
	for point: Vector3 in [a,b]:
		var source: Vector2 = Content.to_source(point)
		if source.x < -100 or source.y < -100 or source.x > float(bounds.w)+100 or source.y > float(bounds.h)+100: return false
	return true
func reserve_incident_corridor(id: String,expected_revision: int,segments: Array,player_epoch: Dictionary,state_epoch: Dictionary) -> bool:
	if not _incident_epoch_current() or id.is_empty() or id.length() > 128 or segments.is_empty() or segments.size() > 2048: return false
	var host: RefCounted = _host(); var space: PhysicsDirectSpaceState3D = _space()
	if space == null or expected_revision != _collision_revision or not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return false
	if not _incident_reservation.is_empty(): return _incident_reservation.id == id and _incident_reservation.segments == segments
	var frozen: Array = segments.duplicate(true)
	var published: Dictionary = incident_geometry_snapshot()
	if published.get("ok") != true or published.revision != expected_revision: return false
	for segment: Variant in frozen:
		if not _incident_segment_valid(segment): return false
		# A collider writer can publish its bounds before PhysicsServer observes the
		# transform. Keep the actual casts below and reject that logical overlap too.
		for obstacle: Dictionary in published.records:
			if _incident_hits_bounds(segment,obstacle.bounds): return false
		var size: Vector3 = segment.size; var key: String = str(size)
		if not _incident_query_shapes.has(key):
			if _incident_query_shapes.size() >= 64: _incident_query_shapes.clear()
			var shape := BoxShape3D.new(); shape.size = size; _incident_query_shapes[key] = shape
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = _incident_query_shapes[key]; query.collision_mask = 1; query.margin = 0.002
		query.transform = Transform3D(Basis.IDENTITY,segment.from); query_count += 1
		if not space.intersect_shape(query,1).is_empty(): return false
		query.motion = segment.to-segment.from; query_count += 1
		var fraction: PackedFloat32Array = space.cast_motion(query)
		if fraction.size() != 2 or fraction[0] < 0.999999: return false
		query.transform.origin = segment.to; query.motion = Vector3.ZERO; query_count += 1
		if not space.intersect_shape(query,1).is_empty(): return false
	if expected_revision != _collision_revision or not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return false
	_incident_reservation = {"id":id,"segments":frozen,"player_epoch":player_epoch,"state_epoch":state_epoch,"revision":expected_revision}
	return true
func release_incident_corridor(id: String) -> bool:
	if not _incident_epoch_current(): return false
	if _incident_reservation.is_empty(): return true
	if _incident_reservation.id != id: return false
	_incident_reservation.clear(); return true
func _incident_hits_bounds(segment: Dictionary,bounds: AABB) -> bool:
	var half: Vector3 = segment.size*0.5+Vector3.ONE*0.002
	var expanded := AABB(bounds.position-half,bounds.size+half*2.0)
	return expanded.has_point(segment.from) or expanded.has_point(segment.to) or expanded.intersects_segment(segment.from,segment.to) != null
func _reservation_clear(bounds: AABB) -> bool:
	if not bounds.position.is_finite() or not bounds.size.is_finite() or minf(bounds.size.x,minf(bounds.size.y,bounds.size.z)) < 0 or not _incident_epoch_current(): return false
	if _incident_reservation.is_empty(): return true
	for segment: Dictionary in _incident_reservation.segments:
		if _incident_hits_bounds(segment,bounds): return false
	return true

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
	if clear and _placement_render >= 0:
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

func _refresh_contact_index(force: bool = false) -> void:
	var host: RefCounted = _host()
	if host == null: _contact_index.clear(); return
	var frame: int = Engine.get_process_frames()
	if not force and frame == _contact_index_frame and is_same(host.p,_contact_index_player) and is_same(host.s,_contact_index_state) and is_same(host.npcs,_contact_index_array) and host.npcs.size() == _contact_index_size: return
	_contact_index.clear(); _contact_index_unique = true
	for index: int in range(host.npcs.size()):
		var actor: Dictionary = host.npcs[index]; var id: String = str(actor.get("id",""))
		if _contact_index.has(id): _contact_index_unique = false
		else: _contact_index[id] = {"index":index,"actor":actor}
	_contact_index_array = host.npcs; _contact_index_size = host.npcs.size(); _contact_index_frame = frame
	_contact_index_player = host.p; _contact_index_state = host.s; contact_index_builds += 1

func _indexed_contact_actor(id: String) -> Dictionary:
	_refresh_contact_index()
	var host: RefCounted = _host()
	if host == null: return {}
	var entry: Dictionary = _contact_index.get(id,{})
	if entry.is_empty() or not is_same(host.npcs[int(entry.index)],entry.actor) or str(entry.actor.get("id","")) != id:
		_refresh_contact_index(true); entry = _contact_index.get(id,{})
	return entry.actor if not entry.is_empty() else {}

func _contact_peers(body: Dictionary) -> Array[Dictionary]:
	var peers: Array[Dictionary] = []
	var host: RefCounted = _host()
	if host == null: return peers
	if str(body.get("id","player")) != "player":
		var actor: Dictionary = _indexed_contact_actor(str(body.get("id","")))
		if _contact_index_unique:
			if not actor.is_empty() and not _contact_live(actor,host): return peers
		else:
			for candidate: Dictionary in host.npcs:
				if str(candidate.get("id","")) == str(body.get("id","")) and not _contact_live(candidate,host): return peers
		if _valid_body(host.p): peers.append({"id":"player","x":host.p.x,"y":host.p.y,"w":host.p.w,"h":host.p.h,"neutral":false})
		return peers
	for actor: Dictionary in host.npcs:
		if not _contact_live(actor,host) or not _valid_body(actor): continue
		peers.append({"id":str(actor.get("id","")),"x":actor.x,"y":actor.y,"w":actor.w,"h":actor.h,
			"neutral":not actor.get("hostile",false) and not actor.get("aggro",false)})
	return peers

func _contact_live(actor: Dictionary,host: RefCounted) -> bool:
	if actor.get("dead",false) or actor.get("departed",false): return false
	# Exact Day.actor_visible predicate: sleeping services must not leave an
	# invisible physical blocker. This reads the shared clock; it owns no timer.
	var night: bool = float(host.s.dayTime) < 0.25 or float(host.s.dayTime) > 0.75
	return not (night and (actor.get("id","") in ["mom","pete"] or actor.get("daytimeOnly",false)))

func _neutral_body(body: Dictionary) -> bool:
	var host: RefCounted = _host()
	var id: String = str(body.get("id","player"))
	if host == null or id == "player": return false
	var actor: Dictionary = _indexed_contact_actor(id)
	return not actor.is_empty() and not actor.get("hostile",false) and not actor.get("aggro",false)

func _peer_clear(body: Dictionary,point: Vector2,peers: Array[Dictionary]) -> bool:
	for peer: Dictionary in peers:
		body_contact_tests += 1
		if Contact.penetrating(body,point,peer): return false
	return true

func _repair_peer_placement(body: Dictionary,point: Vector2,original: Vector2) -> Vector2:
	var peers: Array[Dictionary] = _contact_peers(body)
	if _peer_clear(body,point,peers): return point
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null: return point
	for candidate: Vector2 in Contact.repair_candidates(body,point,peers):
		if candidate.distance_to(original) > 100.0001 or not _peer_clear(body,candidate,peers): continue
		body_contact_tests += peers.size()
		var crossing: Dictionary = Contact.first_hit(body,point,candidate-point,peers)
		if not crossing.is_empty() and float(crossing.fraction) < 0.999999: continue
		if not _clear(body,candidate,false): continue
		var query: PhysicsShapeQueryParameters3D = _query(body,point)
		query.motion = Vector3(candidate.x-point.x,0,candidate.y-point.y)*SCALE
		query_count += 1
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions.size() >= 2 and fractions[0] >= 0.999999:
			body_repairs += 1
			return candidate
	# Peer overlap never turns a valid static placement into failed clear_actor:
	# that would suppress the entire source AI/combat step. Escape remains legal.
	body_repairs_deferred += 1
	return point

func _move_body_raw(body: Dictionary,intended: Vector2,stop_on_block: bool) -> Dictionary:
	var origin := Vector2(float(body.x),float(body.y))
	var failed := {"position":origin,"blocked":true,"body_contact":false}
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null or not _clear(body,origin): return failed
	var position: Vector2 = origin
	var motion: Vector3 = Vector3(intended.x-origin.x,0,intended.y-origin.y)*SCALE
	var blocked: bool = false
	var peer_contact: bool = false
	var wall_responses: int = 0
	var peers: Array[Dictionary] = _contact_peers(body)
	for iteration: int in range(4):
		if motion.length_squared() < 0.00000001: break
		var full_plane_motion := Vector2(motion.x,motion.z)/SCALE
		body_contact_tests += peers.size()
		var hit: Dictionary = Contact.first_hit(body,position,full_plane_motion,peers)
		var contact_fraction: float = float(hit.fraction) if not hit.is_empty() else 1.0
		var cast_motion: Vector3 = motion*contact_fraction
		var query: PhysicsShapeQueryParameters3D = _query(body,position)
		query.motion = cast_motion
		var fractions := PackedFloat32Array([1.0,1.0])
		if cast_motion.length_squared() > 0.000000000001:
			query_count += 1
			fractions = space.cast_motion(query)
		if fractions.size() < 2: return failed
		var safe: float = fractions[0]
		var step_from: Vector2 = position
		var plane_motion := Vector2(cast_motion.x,cast_motion.z)/SCALE
		var proposed: Vector2 = step_from+plane_motion*safe
		var endpoint_clear: bool = _clear(body,proposed,false)
		if safe >= 0.999999 and endpoint_clear:
			position = proposed
			if hit.is_empty(): break
			peer_contact = true; body_contacts += 1
			if stop_on_block: break
			var remaining: Vector2 = full_plane_motion*(1.0-contact_fraction)
			var tangent_motion: Vector2 = remaining.slide(hit.normal)
			if tangent_motion.length_squared() <= 0.00000001 and (hit.neutral or _neutral_body(body)):
				tangent_motion = Contact.tangent(hit.normal,str(body.get("id","player")),hit.peer_id)*remaining.length()
			motion = Vector3(tangent_motion.x,0,tangent_motion.y)*SCALE
			continue
		blocked = true
		wall_responses += 1
		# A cast's safe fraction can still fail the same-margin overlap query on the
		# next frame. Retain skin before contact; never weaken _clear to hide it.
		var skinned: float = maxf(0.0,safe-CONTACT_SKIN/maxf(cast_motion.length(),0.000001))
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
		if stop_on_block or wall_responses >= 2: break
		# Query the first unsafe overlap for the current live wall normal.
		query.transform.origin += cast_motion*minf(1.0,float(fractions[1])+0.0001)
		query.motion = Vector3.ZERO
		query_count += 1
		var contact: Dictionary = space.get_rest_info(query)
		if contact.is_empty(): break
		var normal: Vector3 = contact.normal
		motion = (motion*(1.0-safe*contact_fraction)).slide(normal)
	return {"position":position,"blocked":blocked,"body_contact":peer_contact}

func clear_placement(body: Dictionary) -> Variant:
	if not _valid_body(body): return null
	_sync_navigation_epoch()
	var origin := Vector2(float(body.x),float(body.y))
	if _clear(body,origin): return _repair_peer_placement(body,origin,origin)
	for radius: float in [4.0,8.0,16.0,24.0,40.0,64.0,100.0]:
		for index: int in range(16):
			var angle: float = float(index)*TAU/16.0
			var candidate := origin+Vector2(cos(angle),sin(angle))*radius
			if _clear(body,candidate): return _repair_peer_placement(body,candidate,origin)
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

func bind_interactive_props(actions: RefCounted,view: Node3D) -> bool:
	if actions == null or view == null or not actions.has_method(&"render_records") or not actions.has_method(&"ready") or not view.has_method(&"collision_rid") or not view.has_method(&"collider") or not view.has_method(&"clear_active"): return false
	_interactive_actions_ref = weakref(actions); _interactive_view_ref = weakref(view)
	return true

func sync_interactive_props() -> bool:
	var view: Object = _interactive_view_ref.get_ref() if _interactive_view_ref != null else null
	var actions: Object = _interactive_actions_ref.get_ref() if _interactive_actions_ref != null else null
	return view != null and actions != null and view.sync_current() == true

func begin_interactive_epoch() -> bool:
	var host: RefCounted = _host()
	if host == null: return false
	if is_same(_interactive_epoch_player,host.p) and is_same(_interactive_epoch_state,host.s): return true
	var view: Object = _interactive_view_ref.get_ref() if _interactive_view_ref != null else null
	if view != null: view.clear_active()
	_interactive_approaches.clear()
	_interactive_epoch_player = host.p; _interactive_epoch_state = host.s
	return true

func _dynamic_interactive() -> bool:
	var world: Node3D = _world()
	return world != null and world.get("dynamic_interactive") == true

func _interactive_reservations(exclude_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var host: RefCounted = _host()
	if host == null: return result
	var actions: Object = _interactive_actions_ref.get_ref() if _interactive_actions_ref != null else null
	var rows: Array = actions.render_records() if actions != null and actions.ready() else []
	for id: String in _interactive_approaches:
		if id == exclude_id: continue
		var certificate: Dictionary = _interactive_approaches[id]
		if not is_same(certificate.player,host.p) or not is_same(certificate.state,host.s): continue
		if actions != null:
			var index: int = _interactive_index(id)
			if rows.size() != 14 or index < 0: continue
			var row: Dictionary = rows[index]
			if not row.get("placed",false) or row.get("pending",true) or row.get("broken",false) or Vector2(row.x,row.y) != certificate.point: continue
		result.append(certificate)
	return result

func _interactive_envelope(kind: String,point: Vector2) -> AABB:
	var radius: float = 0.33 if kind == "trashcan" else 0.065
	var height: float = 0.84 if kind == "trashcan" else 0.35
	return AABB(Content.to_world(point)+Vector3(-radius,0,-radius),Vector3(radius*2,height,radius*2))

func _interactive_actor_envelopes(host: RefCounted) -> Array[AABB]:
	# Startup may stage before actor collision nodes exist. Use the same live-body
	# predicate and source footprint as contact, with registered physical height.
	var result: Array[AABB] = []
	for actor: Dictionary in host.npcs:
		if not _contact_live(actor,host) or not _valid_body(actor): continue
		var height: float = _height(str(actor.get("id","")),actor)
		result.append(AABB(Content.to_world(Vector2(actor.x,actor.y),FEET),Vector3(float(actor.w)*SCALE,height,float(actor.h)*SCALE)))
	return result

func _protect_interactive_approaches(kind: String,point: Vector2,reserved: Array[Dictionary]) -> bool:
	var box: AABB = _interactive_envelope(kind,point)
	var radius: float = 0.33 if kind == "trashcan" else 0.065
	var world_point: Vector3 = Content.to_world(point)
	for certificate: Dictionary in reserved:
		var approach: Vector3 = certificate.approach
		if Vector2(world_point.x-approach.x,world_point.z-approach.z).length_squared() <= pow(0.48+radius+0.006,2): return false
		var eye := Vector3(approach.x,FEET+1.63,approach.z)
		var target: Vector3 = Content.to_world(certificate.point,0.50 if certificate.kind == "trashcan" else 0.17)
		if box.intersects_segment(eye,target) != null: return false
		if box.intersects(_interactive_envelope(certificate.kind,certificate.point)): return false
	return true

func _interactive_index(id: String) -> int:
	if not id.begins_with("interactive:"): return -1
	var suffix: String = id.trim_prefix("interactive:")
	if not suffix.is_valid_int(): return -1
	var index: int = int(suffix)
	return index if index >= 0 and index < 14 and str(index) == suffix else -1

func _interactive_record(id: String) -> Dictionary:
	var actions: Object = _interactive_actions_ref.get_ref() if _interactive_actions_ref != null else null
	var view: Object = _interactive_view_ref.get_ref() if _interactive_view_ref != null else null
	var index: int = _interactive_index(id)
	if actions == null or view == null or index < 0 or not actions.ready(): return {}
	var row: Dictionary = actions.render_record(id)
	if row.get("id") != id or not row.get("placed",false) or row.get("pending",true) or row.get("broken",false): return {}
	var body: StaticBody3D = view.collider(id)
	if body == null or (body.collision_layer & 1) == 0: return {}
	var expected: Vector3 = Content.to_world(Vector2(row.x,row.y))
	if Vector2(body.global_position.x-expected.x,body.global_position.z-expected.z).length_squared() > 0.00000001: return {}
	return row

func _interactive_exclude(id: String) -> Array[RID]:
	var result: Array[RID] = []
	var view: Object = _interactive_view_ref.get_ref() if _interactive_view_ref != null else null
	if view != null:
		var body: RID = view.collision_rid(id)
		if body.is_valid(): result.append(body)
	return result

func _interactive_ray(from: Vector3,to: Vector3,exclude: Array[RID]) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null: return {"unavailable":true}
	var query := PhysicsRayQueryParameters3D.create(from,to,1,exclude)
	query.hit_from_inside = true; query_count += 1
	return space.intersect_ray(query)

func _interactive_target_clear(id: String,origin: Vector2,point: Vector2,height: float) -> bool:
	var hit: Dictionary = _ray(Content.to_world(origin,FEET+1.63),Content.to_world(point,height))
	if hit.is_empty(): return true
	var index: int = _interactive_index(id)
	return index >= 0 and hit.get("collider") is CollisionObject3D and str(hit.collider.get_meta("source_owner","")) == "interactiveProps:%d" % index

func interactive_approach(id: String,source_point: Vector2 = Vector2.INF) -> Vector3:
	var certificate: Dictionary = _interactive_approaches.get(id,{})
	var host: RefCounted = _host()
	if certificate.is_empty() or host == null or not is_same(certificate.player,host.p) or not is_same(certificate.state,host.s): return Vector3.INF
	if source_point.is_finite() and certificate.point != source_point: return Vector3.INF
	return certificate.approach

func _interactive_approach_at(_id: String,kind: String,point: Vector2,exclude: Array[RID],reserved: Array[Dictionary]) -> Vector3:
	var host: RefCounted = _host(); var space: PhysicsDirectSpaceState3D = _space()
	if host == null or space == null or not _valid_body(host.p): return Vector3.INF
	var half := Vector2(float(host.p.w),float(host.p.h))*0.5
	var body: Dictionary = {"id":"player","x":0.0,"y":0.0,"w":host.p.w,"h":host.p.h}
	var peers: Array[Dictionary] = _contact_peers(body)
	var bounds: Dictionary = host.content.world.bounds
	var weapon: Dictionary = host.content.catalogs.weapons.get(host.p.get("weapon","fists"),host.content.catalogs.weapons.fists)
	var reach: float = 36.0+float(weapon.get("reach",0.0))
	# Cardinal approaches fall inside the existing source melee rectangle, with
	# clearance between the real player capsule and the prop's visual envelope.
	for radius: float in [22.0,28.0,36.0,44.0,49.0]:
		if kind == "trashcan" and radius >= 50.0: continue
		for direction: Vector2 in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
			var front: float = absf(direction.x)*half.x+absf(direction.y)*half.y
			if kind == "b_bottle" and radius >= front+reach: continue
			var center: Vector2 = point+direction*radius
			var top_left: Vector2 = center-half
			if top_left.x < 0 or top_left.y < 0 or top_left.x+body.w > bounds.w or top_left.y+body.h > bounds.h: continue
			if not _peer_clear(body,top_left,peers): continue
			var eye: Vector3 = Content.to_world(center,FEET+1.63)
			var target: Vector3 = Content.to_world(point,0.50 if kind == "trashcan" else 0.17)
			var reserved_clear: bool = true
			for certificate: Dictionary in reserved:
				var other: Vector3 = Content.to_world(certificate.point)
				var other_radius: float = 0.33 if certificate.kind == "trashcan" else 0.065
				if Vector2(eye.x-other.x,eye.z-other.z).length_squared() <= pow(0.48+other_radius+0.006,2) or _interactive_envelope(certificate.kind,certificate.point).intersects_segment(eye,target) != null:
					reserved_clear = false; break
			if not reserved_clear: continue
			var query: PhysicsShapeQueryParameters3D = _query(body,top_left); query.exclude = exclude
			query_count += 1
			if not space.intersect_shape(query,1).is_empty(): continue
			var target_height: float = 0.50 if kind == "trashcan" else 0.17
			if _interactive_ray(Content.to_world(center,FEET+1.63),Content.to_world(point,target_height),exclude).is_empty(): return Content.to_world(center,FEET)
	return Vector3.INF

func stage_interactive_prop(id: String,kind: String,desired: Vector2,maximum_px: float = 100.0) -> Variant:
	var index: int = _interactive_index(id)
	if index < 0 or kind != ("trashcan" if index < 6 else "b_bottle") or not desired.is_finite() or not is_finite(maximum_px) or maximum_px < 0 or maximum_px > 100: return null
	var host: RefCounted = _host(); var space: PhysicsDirectSpaceState3D = _space()
	if host == null or space == null: return null
	if not is_same(_interactive_epoch_player,host.p) or not is_same(_interactive_epoch_state,host.s):
		if not begin_interactive_epoch(): return null
	var bounds: Dictionary = host.content.world.bounds
	if desired.x < 0 or desired.y < 0 or desired.x > bounds.w or desired.y > bounds.h: return null
	var player_epoch: Dictionary = host.p; var state_epoch: Dictionary = host.s
	var exclude: Array[RID] = _interactive_exclude(id)
	var reserved: Array[Dictionary] = _interactive_reservations(id)
	var actor_envelopes: Array[AABB] = _interactive_actor_envelopes(host)
	var radius: float = 0.33 if kind == "trashcan" else 0.065
	var height: float = 0.84 if kind == "trashcan" else 0.35
	if not _interactive_shapes.has(kind):
		var shape := CylinderShape3D.new(); shape.radius = radius; shape.height = height-0.01; _interactive_shapes[kind] = shape
	var candidates: Array[Vector2] = [desired]
	var radii: Array[float] = []
	for distance: float in [4.0,8.0,16.0,24.0,40.0,64.0,100.0]:
		if distance <= maximum_px: radii.append(distance)
	if maximum_px > 0 and (radii.is_empty() or radii[-1] != maximum_px): radii.append(maximum_px)
	for distance: float in radii:
		for sample: int in range(16):
			var angle: float = float(sample)*TAU/16.0
			candidates.append(desired+Vector2(cos(angle),sin(angle))*distance)
	for point: Vector2 in candidates:
		if point.distance_to(desired) > maximum_px+0.0001 or point.x < radius/SCALE or point.y < radius/SCALE or point.x > float(bounds.w)-radius/SCALE or point.y > float(bounds.h)-radius/SCALE: continue
		var prop_envelope: AABB = _interactive_envelope(kind,point)
		if not _reservation_clear(prop_envelope): continue
		# A newly committed parked cart may precede its PhysicsServer transform.
		# Read its one authoritative record; mounted art has no parked exclusion.
		if _world().get("dynamic_cart") == true and host.p.get("cartMounted") == false:
			var cart: Dictionary = _cart_record()
			if not cart.is_empty() and prop_envelope.intersects(_cart_envelope(Vector2(cart.x,cart.y))): continue
		var actor_clear: bool = true
		for actor_envelope: AABB in actor_envelopes:
			if prop_envelope.intersects(actor_envelope): actor_clear = false; break
		if not actor_clear: continue
		if not _protect_interactive_approaches(kind,point,reserved): continue
		if point != desired and not _interactive_ray(Content.to_world(desired,height*0.5),Content.to_world(point,height*0.5),exclude).is_empty(): continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _interactive_shapes[kind]; query.transform = Transform3D(Basis.IDENTITY,Content.to_world(point,(height+0.01)*0.5))
		query.collision_mask = 1; query.margin = 0; query.exclude = exclude; query_count += 1
		if not space.intersect_shape(query,1).is_empty(): continue
		var approach: Vector3 = _interactive_approach_at(id,kind,point,exclude,reserved)
		if not approach.is_finite(): continue
		if not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return null
		_interactive_approaches[id] = {"point":point,"approach":approach,"kind":kind,"player":player_epoch,"state":state_epoch}
		return point
	return null

func bind_cart(travel: RefCounted,view: Node3D) -> bool:
	var host: RefCounted = _host()
	if host == null or _world() == null or _world().get("dynamic_cart") != true or travel == null or view == null or not is_same(travel.get("host"),host): return false
	for method: StringName in [&"sync",&"clear_active",&"parked_body",&"collision_rids"]:
		if not view.has_method(method): return false
	if not travel.has_method(&"cart_record") or str(view.get("target_id")).is_empty(): return false
	_cart_travel_ref = weakref(travel); _cart_view_ref = weakref(view)
	return begin_cart_epoch()

func begin_cart_epoch() -> bool:
	var host: RefCounted = _host()
	if host == null: return false
	if is_same(_cart_player_epoch,host.p) and is_same(_cart_state_epoch,host.s): return true
	var view: Object = _cart_view_ref.get_ref() if _cart_view_ref != null else null
	if view != null: view.clear_active()
	_cart_certificate.clear(); _cart_player_epoch = host.p; _cart_state_epoch = host.s
	return true

func sync_cart() -> bool:
	if not begin_cart_epoch(): return false
	var view: Object = _cart_view_ref.get_ref() if _cart_view_ref != null else null
	return view != null and view.sync() == true

func _cart_record() -> Dictionary:
	var host: RefCounted = _host()
	var travel: Object = _cart_travel_ref.get_ref() if _cart_travel_ref != null else null
	if host == null or travel == null or not is_same(travel.get("host"),host) or not host.s.get("travelRuntime") is Dictionary or not host.s.travelRuntime.get("cart") is Dictionary: return {}
	var cart: Dictionary = host.s.travelRuntime.cart
	if cart.get("type") != "cart" or cart.get("w") != 24.0 or cart.get("h") != 20.0 or not host.p.get("cartMounted") is bool: return {}
	for key: String in ["x","y"]:
		if not (cart.get(key) is int or cart.get(key) is float) or not is_finite(float(cart[key])): return {}
	var bounds: Dictionary = host.content.world.bounds
	if cart.x < 0 or cart.y < 0 or cart.x+24.0 > bounds.w or cart.y+20.0 > bounds.h: return {}
	return cart

func _cart_envelope(point: Vector2) -> AABB:
	# Parked wheels extend .0148m beyond each side of the .96m frame;
	# the handle also extends beyond source h=20. Preserve all original art.
	return AABB(Content.to_world(point,0.01)+Vector3(-0.0148,0,0),Vector3(0.9896,1.055,0.925))

func _cart_exclude() -> Array[RID]:
	var view: Object = _cart_view_ref.get_ref() if _cart_view_ref != null else null
	var result: Array[RID] = []
	if view != null: result.assign(view.collision_rids())
	return result

func _cart_capsule_clear(center: Vector2,box: AABB) -> bool:
	var world_center: Vector3 = Content.to_world(center)
	var nearest := Vector2(clampf(world_center.x,box.position.x,box.end.x),clampf(world_center.z,box.position.z,box.end.z))
	return nearest.distance_squared_to(Vector2(world_center.x,world_center.z)) > pow(0.482,2)

func _cart_approach_at(point: Vector2,exclude: Array[RID]) -> Vector3:
	var host: RefCounted = _host(); var space: PhysicsDirectSpaceState3D = _space()
	if host == null or space == null or not _valid_body(host.p): return Vector3.INF
	var half := Vector2(host.p.w,host.p.h)*0.5
	var body := {"id":"player","x":0.0,"y":0.0,"w":host.p.w,"h":host.p.h}
	var peers: Array[Dictionary] = _contact_peers(body)
	var bounds: Dictionary = host.content.world.bounds
	var envelope: AABB = _cart_envelope(point)
	var target: Vector3 = Content.to_world(point+Vector2(12,22),1.02)
	for radius: float in [24.0,30.0,35.5]:
		for sample: int in range(16):
			var angle: float = float(sample)*TAU/16.0
			var center: Vector2 = point+Vector2(cos(angle),sin(angle))*radius
			var top_left: Vector2 = center-half
			if top_left.x < 0 or top_left.y < 0 or top_left.x+body.w > bounds.w or top_left.y+body.h > bounds.h: continue
			if not _cart_capsule_clear(center,envelope) or not _peer_clear(body,top_left,peers): continue
			var query: PhysicsShapeQueryParameters3D = _query(body,top_left); query.exclude = exclude; query_count += 1
			if not space.intersect_shape(query,1).is_empty(): continue
			if not _interactive_ray(Content.to_world(center,FEET+1.63),target,exclude).is_empty(): continue
			return Content.to_world(center,FEET)
	return Vector3.INF

func cart_approach(point: Vector2) -> Vector3:
	var host: RefCounted = _host()
	var cart: Dictionary = _cart_record()
	if host == null or not point.is_finite() or cart.is_empty() or point != Vector2(cart.x,cart.y): return Vector3.INF
	# A live NPC can enter an approach without changing static obstacle revision.
	# This service is queried on placement/request, never during stable pose ticks.
	var approach: Vector3 = _cart_approach_at(point,_cart_exclude())
	if approach.is_finite(): _cart_certificate = {"point":point,"approach":approach,"player":host.p,"state":host.s,"revision":_collision_revision}
	return approach

func _cart_live_record(id: String) -> Dictionary:
	var host: RefCounted = _host()
	var view: Object = _cart_view_ref.get_ref() if _cart_view_ref != null else null
	if host == null or view == null or id != str(view.get("target_id")) or host.p.get("cartMounted") != false or not is_same(_cart_player_epoch,host.p) or not is_same(_cart_state_epoch,host.s): return {}
	var record: Dictionary = _cart_record()
	if record.is_empty(): return {}
	var body: StaticBody3D = view.parked_body()
	if body == null or not body.is_inside_tree() or (body.collision_layer & 1) == 0: return {}
	var expected: Vector3 = Content.to_world(Vector2(record.x+12.0,record.y+10.0))
	if body.global_position.distance_squared_to(expected) > 0.0000001: return {}
	return record

func find_cart_drop(preferred: Vector2,maximum_px: float) -> Variant:
	var host: RefCounted = _host(); var space: PhysicsDirectSpaceState3D = _space(); var world: Node3D = _world()
	var view: Object = _cart_view_ref.get_ref() if _cart_view_ref != null else null
	if host == null or space == null or world == null or world.get("dynamic_cart") != true or view == null or _cart_record().is_empty() or host.p.get("cartMounted") != true: return null
	if not preferred.is_finite() or not is_finite(maximum_px) or maximum_px < 0 or maximum_px > 50 or not _valid_body(host.p): return null
	if not begin_cart_epoch(): return null
	var player_epoch: Dictionary = host.p; var state_epoch: Dictionary = host.s
	var bounds: Dictionary = host.content.world.bounds
	if preferred.x < 0 or preferred.y < 0 or preferred.x > bounds.w or preferred.y > bounds.h: return null
	var exclude: Array[RID] = _cart_exclude()
	var actor_boxes: Array[AABB] = _interactive_actor_envelopes(host)
	var reserved: Array[Dictionary] = _interactive_reservations("")
	var candidates: Array[Vector2] = [preferred]
	var radii: Array[float] = []
	for radius: float in [4.0,8.0,16.0,24.0,32.0,40.0,50.0]:
		if radius <= maximum_px: radii.append(radius)
	if maximum_px > 0 and (radii.is_empty() or radii[-1] != maximum_px): radii.append(maximum_px)
	for radius: float in radii:
		for sample: int in range(16):
			var angle: float = float(sample)*TAU/16.0; candidates.append(preferred+Vector2(cos(angle),sin(angle))*radius)
	if _cart_query_shape == null: _cart_query_shape = BoxShape3D.new(); _cart_query_shape.size = _cart_envelope(Vector2.ZERO).size
	var player_rect := Rect2(host.p.x,host.p.y,host.p.w,host.p.h)
	for candidate: Vector2 in candidates:
		if candidate.distance_to(preferred) > maximum_px or candidate.x-0.37 < 0 or candidate.y < 0 or candidate.x+24.37 > bounds.w or candidate.y+23.125 > bounds.h: continue
		var envelope: AABB = _cart_envelope(candidate)
		if player_rect.intersects(Rect2(candidate,Vector2(24,20))) or not _cart_capsule_clear(host.player_center(),envelope) or not _reservation_clear(envelope): continue
		var clear: bool = true
		for box: AABB in actor_boxes:
			if envelope.intersects(box): clear = false; break
		if not clear: continue
		for certificate: Dictionary in reserved:
			if envelope.intersects(_interactive_envelope(certificate.kind,certificate.point)) or not _cart_capsule_clear(Content.to_source(certificate.approach),envelope): clear = false; break
			var eye := Vector3(certificate.approach.x,FEET+1.63,certificate.approach.z)
			if envelope.intersects_segment(eye,Content.to_world(certificate.point,0.50 if certificate.kind == "trashcan" else 0.17)) != null: clear = false; break
		if not clear: continue
		# The shared logical obstacle index covers same-frame collider publication.
		for obstacle: Dictionary in _navigation._records:
			if obstacle.owner == str(view.get("source_owner")): continue
			var rect: Rect2 = obstacle.rect
			var box := AABB(Content.to_world(rect.position,obstacle.low),Vector3(rect.size.x*SCALE,obstacle.high-obstacle.low,rect.size.y*SCALE))
			if envelope.intersects(box): clear = false; break
		if not clear: continue
		if candidate != preferred and not _interactive_ray(Content.to_world(preferred+Vector2(12,10),0.5),Content.to_world(candidate+Vector2(12,10),0.5),exclude).is_empty(): continue
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = _cart_query_shape; query.transform = Transform3D(Basis.IDENTITY,envelope.get_center()); query.collision_mask = 1; query.exclude = exclude; query.margin = 0.002; query_count += 1
		if not space.intersect_shape(query,1).is_empty(): continue
		if not _interactive_ray(Content.to_world(host.player_center(),FEET+1.63),Content.to_world(candidate+Vector2(12,22),1.02),exclude).is_empty(): continue
		var approach: Vector3 = _cart_approach_at(candidate,exclude)
		if not approach.is_finite(): continue
		if not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return null
		_cart_certificate = {"point":candidate,"approach":approach,"player":host.p,"state":host.s,"revision":_collision_revision}
		return candidate
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
	if target_id.begins_with("interactive:") and _dynamic_interactive():
		var prop: Dictionary = _interactive_record(target_id)
		if prop.is_empty() or prop.get("type") != "b_bottle": return false
		return _interactive_target_clear(target_id,from_center,Vector2(prop.x,prop.y),0.17)
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
	if world.get("dynamic_cart") == true:
		var cart_view: Object = _cart_view_ref.get_ref() if _cart_view_ref != null else null
		var cart_service: Dictionary = world.service_points.get(id,{})
		if cart_service.get("kind") == "cart" or (cart_view != null and id == str(cart_view.get("target_id"))):
			var cart: Dictionary = _cart_live_record(id)
			if cart.is_empty() or cart_service.is_empty(): return false
			var point := Vector2(cart.x,cart.y)
			if origin.distance_squared_to(point) >= 36.0*36.0: return false
			var hit: Dictionary = _ray(Content.to_world(origin,FEET+1.63),cart_service.target)
			return hit.is_empty() or (hit.get("collider") is CollisionObject3D and str(hit.collider.get_meta("source_owner","")) == str(cart_view.get("source_owner")))
	if id.begins_with("interactive:") and _dynamic_interactive():
		var prop: Dictionary = _interactive_record(id)
		if prop.is_empty() or prop.get("type") != "trashcan": return false
		var point := Vector2(prop.x,prop.y)
		return origin.distance_squared_to(point) < 2500.0 and _interactive_target_clear(id,origin,point,0.50)
	var target: Vector3
	var source_target: Vector2
	var reach: float = 0.0
	var owner: String = ""
	var found: bool = false
	if id == "quest:crown":
		var crown: Variant = host.s.get("crownPickup")
		if not crown is Dictionary or crown.get("collected",true): return false
		source_target = Vector2(crown.x,crown.y)
		target = Content.to_world(source_target,0.14); reach = 0.72; found = true
	elif id.begins_with("cash:"):
		for pile: Dictionary in host.cash_piles:
			if str(pile.id) != id.substr(5) or pile.get("collected",false) == true: continue
			source_target = Vector2(pile.x,pile.y)
			target = Content.to_world(source_target,0.14); reach = 0.56; found = true; break
		if not found: return false
	else:
		for actor: Dictionary in host.npcs:
			if str(actor.id) != id: continue
			if actor.get("dead",false) == true: return false
			source_target = Vector2(actor.x+actor.w*0.5,actor.y+actor.h*0.5)
			target = Content.to_world(source_target,FEET+_height(id)*0.7); reach = 2.4; found = true; break
	var services: Variant = world.get("service_points")
	if services is Dictionary and services.has(id):
		var service: Dictionary = services[id]
		owner = str(service.structure_id) if service.kind != "actor" else ""
		if not found:
			target = service.target; source_target = service.get("source_point",Content.to_source(target)); reach = float(service.reach); found = true
	if not found or not target.is_finite() or not source_target.is_finite(): return false
	# Range belongs to the source model. World-space float32 subtraction can round
	# an exact44/58/72px edge just inside its metre radius at distant courts.
	var source_reach: float = reach/SCALE
	if origin.distance_squared_to(source_target) >= source_reach*source_reach: return false
	var eye: Vector3 = Content.to_world(origin,FEET+1.63)
	var hit: Dictionary = _ray(eye,target)
	return hit.is_empty() or (not owner.is_empty() and hit.get("collider") is CollisionObject3D and str(hit.collider.get_meta("source_owner","")) == owner)

func site_focus(id: String) -> Vector3:
	var world: Node3D = _world()
	var host: RefCounted = _host()
	if world == null or host == null: return Vector3.INF
	var services: Variant = world.get("service_points")
	if not services is Dictionary or not services.has(id): return Vector3.INF
	var service: Dictionary = services[id]
	if service.get("kind") != "site" or not service.get("site_rect") is Rect2: return Vector3.INF
	var rect: Rect2 = service.site_rect
	var eye: Vector3 = Content.to_world(host.player_center(),FEET+1.63)
	var point := Vector2(eye.x,eye.z)
	var nearest: Vector2 = point.clamp(rect.position,rect.end)
	if rect.has_point(point):
		var edges: Array[Vector2] = [Vector2(rect.position.x,point.y),Vector2(rect.end.x,point.y),Vector2(point.x,rect.position.y),Vector2(point.x,rect.end.y)]
		nearest = edges[0]
		for edge: Vector2 in edges:
			if edge.distance_squared_to(point) < nearest.distance_squared_to(point): nearest = edge
	return Vector3(nearest.x,1.25,nearest.y)

func can_use_site(id: String) -> bool:
	var target: Vector3 = site_focus(id)
	if not target.is_finite(): return false
	var world: Node3D = _world()
	var host: RefCounted = _host()
	var service: Dictionary = world.get("service_points")[id]
	var rect: Rect2 = service.site_rect.grow(20.0*SCALE)
	var origin: Vector3 = Content.to_world(host.player_center(),FEET+1.63)
	if origin.x <= rect.position.x or origin.x >= rect.end.x or origin.z <= rect.position.y or origin.z >= rect.end.y: return false
	var body := {"id":"player","x":host.p.x,"y":host.p.y,"w":host.p.w,"h":host.p.h}
	if not _valid_body(body) or not _clear(body,Vector2(body.x,body.y)): return false
	var hit: Dictionary = _ray(origin,target)
	var owner: String = str(service.get("structure_id",""))
	return hit.is_empty() or (not owner.is_empty() and hit.get("collider") is CollisionObject3D and str(hit.collider.get_meta("source_owner","")) == owner)

func can_use_zone(id: String) -> bool:
	# Zone verbs do not require a walk or ray to their map guidance marker.
	# Exact venue membership and availability are owned by MemoryLoop.
	var known: bool = id == "market"
	for spot: Dictionary in Content.definition("src/systems/concessions.js","SMOKE_SPOTS",[]):
		if spot.id == id: known = true; break
	if not known: return false
	var host: RefCounted = _host()
	if host == null: return false
	var body := {"id":"player","x":host.p.x,"y":host.p.y,"w":host.p.w,"h":host.p.h}
	return _valid_body(body) and _clear(body,Vector2(body.x,body.y))

# P14 day-event exits. Geometry planning is bounded per existing render serial;
# only ActorDirector may commit motion or remove a live actor.
const DEPARTURE_STEP := 10.0
const DEPARTURE_WIDTH := 860
const DEPARTURE_HEIGHT := 560
const DEPARTURE_EXPANSIONS := 120000
const DEPARTURE_VISITED := 160000
const DEPARTURE_WORK := 256
const DEPARTURE_US := 1000
var _departure_entries: Dictionary = {}
var _departure_queue: Array[String] = []
var _departure_frame: int = -1
var _departure_work: int = 0
var _departure_us: int = 0
var _departure_sweeps: int = 0
var _departure_totals: Dictionary = {"started":0,"ready":0,"failed":0,"cache_hits":0,"max_work":0,"max_us":0,"max_sweeps":0,"max_entries":0}

func departure_metrics() -> Dictionary:
	var result: Dictionary = _departure_totals.duplicate()
	result.entries = _departure_entries.size(); result.queued = _departure_queue.size()
	result.frame = _departure_frame; result.work = _departure_work; result.microseconds = _departure_us
	return result

func departure_status(id: String) -> Dictionary:
	_sync_navigation_epoch()
	var entry: Dictionary = _departure_entries.get(id,{})
	if entry.is_empty(): return {"status":"absent"}
	return {"status":entry.status,"reason":entry.get("reason",""),"expanded":entry.expanded,
		"visited":entry.costs.size(),"revision":entry.revision,"exit_id":entry.get("exit_id","")}

func _departure_forget(id: String) -> void:
	_departure_entries.erase(id); _departure_queue.erase(id)

func _departure_actor(body: Dictionary,edge: String) -> Dictionary:
	var host: RefCounted = _host()
	if host == null or edge not in ["east","west"] or not _valid_body(body): return {}
	var id: String = str(body.get("id",""))
	var actor: Dictionary = _indexed_contact_actor(id)
	if not _contact_index_unique or actor.is_empty() or actor.get("dead",false) or not actor.get("wanderOff",false): return {}
	var allowed: bool = (id == "price_guy" and actor.get("isPriceGuy",false)) or (id.begins_with("day3_visitor_") and actor.get("isDay3Visitor",false))
	if not allowed: return {}
	var target: Variant = actor.get("targetX")
	if not (target is int or target is float) or not is_finite(float(target)): return {}
	if edge == "west" and float(target) >= 0 or edge == "east" and float(target) <= 8600: return {}
	for key: String in ["x","y","w","h"]:
		if float(actor.get(key,NAN)) != float(body[key]): return {}
	for key: String in ["sprite","name"]:
		if body.has(key) and body[key] != actor.get(key): return {}
	return actor

func resolve_departure(body: Dictionary,edge: String) -> Dictionary:
	_sync_navigation_epoch()
	var actor: Dictionary = _departure_actor(body,edge)
	var id: String = str(body.get("id",""))
	if actor.is_empty(): _departure_forget(id); return {}
	var shape := Vector3(float(body.w),float(body.h),_height(id,body))
	var center := Vector2(float(body.x)+shape.x*0.5,float(body.y)+shape.y*0.5)
	var entry: Dictionary = _departure_entries.get(id,{})
	if not entry.is_empty():
		var drift: float = center.distance_to(entry.last)
		if not is_same(entry.actor,actor) or entry.shape != shape or entry.edge != edge or entry.revision != _collision_revision or drift > (24.0 if entry.status == "ready" else 1.0):
			_departure_forget(id); entry = {}
	if entry.is_empty():
		if _departure_entries.size() >= 2: return {}
		var world: Node3D = _world()
		if world == null or not world.has_method(&"departure_pads"): return {}
		var pads: Variant = world.call(&"departure_pads")
		if not pads is Array or not is_same(_navigation_player,_host().p) or not is_same(_navigation_state,_host().s): return {}
		var candidates: Array[Dictionary] = []
		for pad: Variant in pads:
			if pad is Dictionary and pad.get("edge") == edge and pad.get("id") is String and pad.get("source") is Vector2 and pad.source.is_finite():
				candidates.append(pad.duplicate(true))
		if candidates.is_empty() or candidates.size() > 9: return {}
		entry = {"actor":actor,"body":body.duplicate(true),"shape":shape,"edge":edge,"last":center,"start":center,
			"player":_host().p,"state":_host().s,"revision":_collision_revision,"physics":Engine.get_physics_frames(),
			"status":"pending","reason":"","pads":candidates,"expanded":0,"costs":{},"parents":{},"closed":{},"blocked":{},
			"heap":[],"goals":{},"raw":[],"route":[],"exit_id":"","target":Vector2.INF,"cursor":0,"probe":0}
		_departure_entries[id] = entry; _departure_queue.append(id)
		_departure_totals.started += 1
		_departure_totals.max_entries = maxi(_departure_totals.max_entries,_departure_entries.size())
	entry.last = center
	_departure_pump()
	if entry.status != "ready" or _departure_actor(body,edge).is_empty(): return {}
	_departure_totals.cache_hits += 1
	return {"exit_id":entry.exit_id,"target":entry.target,"route":entry.route.duplicate()}

func _departure_valid(entry: Dictionary) -> bool:
	var host: RefCounted = _host()
	if host == null or not is_same(entry.player,host.p) or not is_same(entry.state,host.s) or entry.revision != _collision_revision: return false
	var actor: Dictionary = _indexed_contact_actor(str(entry.body.id))
	if actor.is_empty() or not is_same(actor,entry.actor) or _departure_actor(actor,entry.edge).is_empty(): return false
	if Vector3(float(actor.w),float(actor.h),_height(str(actor.id),actor)) != entry.shape: return false
	if entry.status != "ready" and entry.status != "failed" and (Vector2(actor.x,actor.y)+Vector2(actor.w,actor.h)*0.5).distance_to(entry.start) > 1.0: return false
	return true

func _departure_pump() -> void:
	if _placement_render < 0: return
	for id: String in _departure_entries.keys():
		if not _departure_valid(_departure_entries[id]): _departure_forget(id)
	if _departure_frame != _placement_render:
		_departure_frame = _placement_render; _departure_work = 0; _departure_us = 0; _departure_sweeps = 0
	var started: int = Time.get_ticks_usec()
	var waiting: int = 0
	while not _departure_queue.is_empty() and _departure_work < DEPARTURE_WORK and _departure_us+Time.get_ticks_usec()-started < DEPARTURE_US:
		var id: String = _departure_queue.pop_front()
		var entry: Dictionary = _departure_entries.get(id,{})
		if entry.is_empty(): continue
		if not _departure_valid(entry): _departure_entries.erase(id); continue
		if entry.status == "certifying" and (_departure_sweeps >= 4 or Engine.get_physics_frames() <= entry.physics):
			_departure_queue.append(id); waiting += 1
			if waiting >= _departure_queue.size(): break
			continue
		waiting = 0; _departure_work += 1
		_departure_step(entry)
		if entry.status not in ["ready","failed"]: _departure_queue.append(id)
	_departure_us += Time.get_ticks_usec()-started
	_departure_totals.max_work = maxi(_departure_totals.max_work,_departure_work)
	_departure_totals.max_us = maxi(_departure_totals.max_us,_departure_us)
	_departure_totals.max_sweeps = maxi(_departure_totals.max_sweeps,_departure_sweeps)

func _departure_point(index: int) -> Vector2:
	return Vector2(float(index%DEPARTURE_WIDTH)*DEPARTURE_STEP+5.0,float(index/DEPARTURE_WIDTH)*DEPARTURE_STEP+5.0)

func _departure_index(point: Vector2) -> int:
	return clampi(int(floor(point.y/DEPARTURE_STEP)),0,DEPARTURE_HEIGHT-1)*DEPARTURE_WIDTH+clampi(int(floor(point.x/DEPARTURE_STEP)),0,DEPARTURE_WIDTH-1)

func _departure_segment(a: Vector2,b: Vector2,shape: Vector3) -> bool:
	var half := Vector2(shape.x,shape.y)*0.5
	if not a.is_finite() or not b.is_finite() or a.x < half.x or a.y < half.y or b.x < half.x or b.y < half.y or a.x > 8600-half.x or b.x > 8600-half.x or a.y > 5600-half.y or b.y > 5600-half.y: return false
	var padding: Vector2 = half+Vector2.ONE*0.05
	var region := Rect2(a.min(b)-padding,(a-b).abs()+padding*2.0)
	for index: int in _navigation._indices(region):
		if not _navigation._height_matches(index,shape): continue
		var rect: Rect2 = _navigation._expanded(index,shape)
		if rect.has_point(a) or rect.has_point(b) or Navigation._segment_entry(a,b,rect) < INF: return false
	return true

func _departure_cell(entry: Dictionary,index: int) -> bool:
	if index < 0 or index >= DEPARTURE_WIDTH*DEPARTURE_HEIGHT: return false
	if not entry.blocked.has(index):
		var point: Vector2 = _departure_point(index)
		entry.blocked[index] = not _departure_segment(point,point,entry.shape)
	return not entry.blocked[index]

func _departure_near(entry: Dictionary,point: Vector2) -> int:
	var base: int = _departure_index(point)
	var best: int = -1; var distance: float = INF
	for dy: int in range(-1,2):
		for dx: int in range(-1,2):
			var x: int = base%DEPARTURE_WIDTH+dx; var y: int = base/DEPARTURE_WIDTH+dy
			if x < 0 or x >= DEPARTURE_WIDTH or y < 0 or y >= DEPARTURE_HEIGHT: continue
			var index: int = y*DEPARTURE_WIDTH+x; var at: Vector2 = _departure_point(index)
			if at.distance_squared_to(point) >= distance or not _departure_cell(entry,index) or not _departure_segment(point,at,entry.shape): continue
			best = index; distance = at.distance_squared_to(point)
	return best

func _departure_heuristic(entry: Dictionary,index: int) -> float:
	var result: float = INF
	for goal: int in entry.goals:
		var dx: int = absi(index%DEPARTURE_WIDTH-goal%DEPARTURE_WIDTH)
		var dy: int = absi(index/DEPARTURE_WIDTH-goal/DEPARTURE_WIDTH)
		result = minf(result,float(maxi(dx,dy))+0.41421356237*mini(dx,dy))
	return result

func _departure_less(a: Vector3,b: Vector3) -> bool:
	return a.x < b.x or (a.x == b.x and (a.y < b.y or a.y == b.y and a.z < b.z))
func _departure_push(entry: Dictionary,item: Vector3) -> void:
	var index: int = entry.heap.size(); entry.heap.append(item)
	while index > 0:
		var parent: int = (index-1)/2
		if not _departure_less(item,entry.heap[parent]): break
		entry.heap[index] = entry.heap[parent]; index = parent
	entry.heap[index] = item
func _departure_pop(entry: Dictionary) -> Vector3:
	var result: Vector3 = entry.heap[0]; var last: Vector3 = entry.heap.pop_back()
	if entry.heap.is_empty(): return result
	var index: int = 0
	while index*2+1 < entry.heap.size():
		var child: int = index*2+1
		if child+1 < entry.heap.size() and _departure_less(entry.heap[child+1],entry.heap[child]): child += 1
		if not _departure_less(entry.heap[child],last): break
		entry.heap[index] = entry.heap[child]; index = child
	entry.heap[index] = last; return result

func _departure_fail(entry: Dictionary,reason: String) -> void:
	entry.status = "failed"; entry.reason = reason
	entry.heap.clear(); entry.parents.clear(); entry.closed.clear(); entry.blocked.clear()
	_departure_totals.failed += 1

func _departure_step(entry: Dictionary) -> void:
	if entry.status == "pending":
		# At most nine fixed authored targets; each nearest-cell scan is bounded9.
		for pad: Dictionary in entry.pads:
			var index: int = _departure_near(entry,pad.source)
			if index >= 0: entry.goals[index] = pad
		var start: int = _departure_near(entry,entry.start)
		if start < 0 or entry.goals.is_empty(): _departure_fail(entry,"no_clear_pad_or_start"); return
		entry.costs[start] = 0.0; entry.parents[start] = -1
		var h: float = _departure_heuristic(entry,start)
		_departure_push(entry,Vector3(h,h,start)); entry.status = "searching"; return
	if entry.status == "searching":
		if entry.heap.is_empty(): _departure_fail(entry,"unreachable"); return
		if entry.expanded >= DEPARTURE_EXPANSIONS or entry.costs.size() > DEPARTURE_VISITED or entry.heap.size() > DEPARTURE_VISITED*2:
			_departure_fail(entry,"work_cap"); return
		var current: int = int(_departure_pop(entry).z)
		if entry.closed.has(current): return
		entry.closed[current] = true; entry.expanded += 1
		if entry.goals.has(current):
			var pad: Dictionary = entry.goals[current]
			entry.exit_id = pad.id; entry.target = pad.source
			entry.cursor = current; entry.raw = [pad.source]; entry.status = "backtracking"; return
		var at: Vector2 = _departure_point(current)
		var x: int = current%DEPARTURE_WIDTH; var y: int = current/DEPARTURE_WIDTH
		for dy: int in range(-1,2):
			for dx: int in range(-1,2):
				if dx == 0 and dy == 0: continue
				var nx: int = x+dx; var ny: int = y+dy
				if nx < 0 or nx >= DEPARTURE_WIDTH or ny < 0 or ny >= DEPARTURE_HEIGHT: continue
				var next: int = ny*DEPARTURE_WIDTH+nx
				if entry.closed.has(next) or not _departure_cell(entry,next): continue
				var cost: float = float(entry.costs[current])+(1.41421356237 if dx != 0 and dy != 0 else 1.0)
				if cost >= float(entry.costs.get(next,INF)) or not _departure_segment(at,_departure_point(next),entry.shape): continue
				entry.costs[next] = cost; entry.parents[next] = current
				var h: float = _departure_heuristic(entry,next)
				_departure_push(entry,Vector3(cost+h,h,next))
		return
	if entry.status == "backtracking":
		if entry.cursor < 0:
			entry.raw.append(entry.start); entry.raw.reverse()
			entry.route = [entry.start]; entry.cursor = 0
			entry.probe = mini(entry.raw.size()-1,64); entry.status = "compressing"; return
		entry.raw.append(_departure_point(entry.cursor))
		entry.cursor = int(entry.parents[entry.cursor]); return
	if entry.status == "compressing":
		if entry.cursor >= entry.raw.size()-1:
			entry.cursor = 0; entry.status = "certifying"; return
		if entry.probe <= entry.cursor: _departure_fail(entry,"compression_clearance"); return
		if _departure_segment(entry.raw[entry.cursor],entry.raw[entry.probe],entry.shape):
			entry.route.append(entry.raw[entry.probe]); entry.cursor = entry.probe
			entry.probe = mini(entry.raw.size()-1,entry.cursor+64)
			if entry.route.size() > 2048: _departure_fail(entry,"route_point_cap")
		else: entry.probe -= 1
		return
	if entry.status == "certifying":
		var space: PhysicsDirectSpaceState3D = _space()
		if space == null: _departure_fail(entry,"space_unavailable"); return
		var a: Vector2 = entry.route[entry.cursor]
		var b: Vector2 = entry.route[mini(entry.cursor+1,entry.route.size()-1)]
		_departure_sweeps += 1
		if not _departure_segment(a,b,entry.shape): _departure_fail(entry,"logical_obstruction"); return
		var half := Vector2(entry.shape.x,entry.shape.y)*0.5
		var query: PhysicsShapeQueryParameters3D = _query(entry.body,a-half)
		query_count += 1
		if not space.intersect_shape(query,1).is_empty(): _departure_fail(entry,"physical_start"); return
		query.motion = Vector3(b.x-a.x,0,b.y-a.y)*SCALE; query_count += 1
		var fraction: PackedFloat32Array = space.cast_motion(query)
		if fraction.size() != 2 or fraction[0] < 0.999999: _departure_fail(entry,"physical_segment"); return
		query.motion = Vector3.ZERO; query.transform.origin = Content.to_world(b,FEET+entry.shape.z*0.5); query_count += 1
		if not space.intersect_shape(query,1).is_empty(): _departure_fail(entry,"physical_end"); return
		entry.cursor += 1
		if entry.cursor >= entry.route.size()-1:
			if not _departure_valid(entry): _departure_fail(entry,"epoch_changed"); return
			entry.status = "ready"; entry.raw.clear(); entry.heap.clear(); entry.parents.clear(); entry.closed.clear(); entry.blocked.clear()
			_departure_totals.ready += 1
