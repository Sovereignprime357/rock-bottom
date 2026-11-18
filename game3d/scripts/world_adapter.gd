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
	for segment: Variant in frozen:
		if not _incident_segment_valid(segment): return false
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
func _reservation_clear(bounds: AABB) -> bool:
	if not bounds.position.is_finite() or not bounds.size.is_finite() or minf(bounds.size.x,minf(bounds.size.y,bounds.size.z)) < 0 or not _incident_epoch_current(): return false
	if _incident_reservation.is_empty(): return true
	for segment: Dictionary in _incident_reservation.segments:
		var half: Vector3 = segment.size*0.5+Vector3.ONE*0.002
		var expanded := AABB(bounds.position-half,bounds.size+half*2.0)
		if expanded.has_point(segment.from) or expanded.has_point(segment.to) or expanded.intersects_segment(segment.from,segment.to) != null: return false
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
	return view != null and actions != null and view.sync(actions.render_records()) == true

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
	var rows: Array = actions.render_records()
	if rows.size() != 14 or not rows[index] is Dictionary: return {}
	var row: Dictionary = rows[index]
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
