extends SceneTree
const Adapter = preload("res://scripts/world_adapter.gd")
const State = preload("res://scripts/game_state.gd")
const Content = preload("res://scripts/content_catalog.gd")
class TestWorld extends Node3D:
	var service_points: Dictionary = {}

class ObservedAdapter:
	extends "res://scripts/world_adapter.gd"
	var shape_lookups: int = 0
	var peer_builds: int = 0
	func _shape(body: Dictionary,resolved_height: float = -1.0) -> Shape3D:
		shape_lookups += 1
		return super._shape(body,resolved_height)
	func _contact_peers(body: Dictionary) -> Array[Dictionary]:
		peer_builds += 1
		return super._contact_peers(body)

# Frozen pre-optimization query construction from332be27. It runs against the
# same live PhysicsServer; paired outcomes/counts protect query order and normals.
class ConstructionReference:
	extends "res://scripts/world_adapter.gd"
	var shape_lookups: int = 0
	var peer_builds: int = 0
	func _shape(body: Dictionary,resolved_height: float = -1.0) -> Shape3D:
		shape_lookups += 1
		return super._shape(body,resolved_height)
	func _contact_peers(body: Dictionary) -> Array[Dictionary]:
		peer_builds += 1
		return super._contact_peers(body)
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
		var clear: bool = space.intersect_shape(_query(body,point,height),1).is_empty()
		if clear and _placement_render >= 0:
			_placement_clear[id] = {"point":point,"width":body.w,"depth":body.h,"height":height,"revision":_collision_revision}
		elif not clear: _placement_clear.erase(id)
		return clear

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



# The reference differs only at the new sufficient test. Its repair path keeps
# the accepted call-local query setup and therefore tests this change in isolation.
class PrefilterObserved:
	extends ObservedAdapter
	var placement_trace: Array = []
	func _clear_prepared(body: Dictionary,point: Vector2,allow_certificate: bool = true,prepared: BodyQuery = null) -> bool:
		var before_query: int = query_count
		var before_hits: int = placement_cache_hits
		var result: bool = super._clear_prepared(body,point,allow_certificate,prepared)
		placement_trace.append([point,allow_certificate,result,query_count-before_query,placement_cache_hits-before_hits])
		return result

class UnfilteredPlacementReference:
	extends PrefilterObserved
	func _player_footprint_separated(_body: Dictionary,_point: Vector2) -> bool:
		return false

var prefilter_completed: bool = false


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
	await _query_setup_equivalence()
	await _prefilter_equivalence()
	_check(prefilter_completed,"prefilter async group completed")
	await _query_resource_equivalence()
	_check(resource_completed,"query resource async group completed")
	if failures.is_empty():
		print("3D PHYSICS ADAPTER GATE: PASS (%d checks; native shape/ray/sphere sweeps, slide/charge, live access, no model mutation)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D PHYSICS ADAPTER GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)


func _query_setup_equivalence() -> void:
	var world := TestWorld.new(); root.add_child(world)
	_box(world,Vector3(0,-0.1,0),Vector3(100,0.2,100))
	var wall: StaticBody3D = _box(world,Vector3(0,1.5,0),Vector3(0.2,3,20))
	var host := State.new(); host.npcs.clear(); host.p.x = 500.0; host.p.y = 500.0
	var actual := ObservedAdapter.new(world,host)
	var reference := ConstructionReference.new(world,host)
	await physics_frame; await physics_frame
	var cases: Array[Dictionary] = [
		{"name":"free capsule","body":{"id":"player","x":900.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(980,840),"stop":false},
		{"name":"wall slide retains sweep normal","body":{"id":"player","x":1000.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1100,900),"stop":false},
		{"name":"wall charge","body":{"id":"player","x":1000.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1100,900),"stop":true},
		{"name":"box glancing contact","body":{"id":"query_actor","x":990.0,"y":840.0,"w":28.0,"h":34.0},"to":Vector2(1080,910),"stop":false},
		{"name":"exact zero clear","body":{"id":"player","x":1000.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1000,840),"stop":false},
		{"name":"exact zero blocked","body":{"id":"player","x":1038.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1038,840),"stop":false},
		{"name":"tiny nonzero below existing loop threshold","body":{"id":"player","x":1000.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1000.001,840),"stop":false},
		{"name":"tiny nonzero actual sweep","body":{"id":"player","x":1000.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1000.003,840),"stop":false},
	]
	for row: Dictionary in cases:
		_prepare_pair(actual,reference)
		var frozen: Dictionary = row.body.duplicate(true)
		var got: Dictionary = actual.move_body(row.body,row.to,null,row.stop)
		var expected: Dictionary = reference.move_body(row.body,row.to,null,row.stop)
		_check(got == expected,row.name+": exact original motion/blocked/contact output")
		_compare_queries(actual,reference,row.name)
		_check(row.body == frozen,row.name+": source body unchanged")
		if row.name == "wall slide retains sweep normal":
			_check(got.position.y > float(row.body.y)+5.0 and actual.shape_lookups < reference.shape_lookups,"slide reuses setup while preserving the live wall normal and all probes")
		if row.name == "exact zero clear":
			_check(actual.placement_overlap_queries == 1 and actual.peer_builds == 0 and reference.peer_builds == 1,"zero motion proves origin before skipping only unused peer construction")
		if row.name == "tiny nonzero below existing loop threshold":
			_check(actual.peer_builds == reference.peer_builds and actual.peer_builds == 1,"nonzero input does not take the new exact-zero shortcut")

	# Retain real symmetric contact, neutral sliding and overlap recovery.
	host.npcs.append({"id":"contact_peer","x":980.0,"y":840.0,"w":28.0,"h":34.0,"dead":false,"hostile":false,"aggro":false})
	var player := {"id":"player","x":900.0,"y":840.0,"w":24.0,"h":28.0}
	_prepare_pair(actual,reference)
	var contact: Dictionary = actual.move_body(player,Vector2(1010,840))
	var contact_reference: Dictionary = reference.move_body(player,Vector2(1010,840))
	_check(contact == contact_reference and contact.body_contact,"neutral peer slide remains the original real contact result")
	_compare_queries(actual,reference,"neutral peer slide")
	player.x = 980.0
	_prepare_pair(actual,reference)
	var repaired: Variant = actual.clear_placement(player)
	var repair_reference: Variant = reference.clear_placement(player)
	_check(repaired == repair_reference and repaired is Vector2 and repaired != Vector2(player.x,player.y),"peer repair remains the same bounded physically swept point")
	_compare_queries(actual,reference,"peer repair")
	host.npcs.clear()

	for point: Vector2 in [Vector2(1038,840),Vector2(-1000,-1000)]:
		player.x = point.x; player.y = point.y
		_prepare_pair(actual,reference)
		var placed: Variant = actual.clear_placement(player)
		var expected_place: Variant = reference.clear_placement(player)
		_check(placed == expected_place,"bounded placement recovery/refusal matches original: "+str(point))
		_compare_queries(actual,reference,"placement "+str(point))
		if point.x > 0:
			_check(placed is Vector2 and actual.shape_lookups < reference.shape_lookups,"placement search reuses shape setup without reducing actual overlaps")

	# Paired positive certificates and their next-call invalidations stay exact.
	player.x = 1000.0; player.y = 840.0
	_prepare_pair(actual,reference)
	for item: RefCounted in [actual,reference]:
		item.clear_placement(player)
		var moved: Dictionary = item.move_body(player,Vector2(1001,840))
		var committed: Dictionary = player.duplicate(true)
		committed.x = moved.position.x; committed.y = moved.position.y
		item.clear_placement(committed)
	_compare_queries(actual,reference,"published endpoint and next origin")
	_check(actual.placement_cache_hits >= 2,"prepared endpoint proof remains reusable only by the existing certificate policy")
	for epoch_key: String in ["p","s"]:
		_prepare_pair(actual,reference)
		actual.clear_placement(player); reference.clear_placement(player)
		if epoch_key == "p": host.p = host.p.duplicate(true)
		else: host.s = host.s.duplicate(true)
		var before: int = actual.query_count
		_check(actual.move_body(player,Vector2(player.x,player.y)) == reference.move_body(player,Vector2(player.x,player.y)),epoch_key+" replacement preserves zero-motion outcome")
		_check(actual.query_count == before+1,epoch_key+" replacement still invalidates origin before exact-zero return")
		_compare_queries(actual,reference,epoch_key+" replacement")
	# A new physical revision between calls must not reuse any call-local setup.
	wall.position.x = -1.5
	await physics_frame; await physics_frame
	actual.invalidate_placement_cache(); reference.invalidate_placement_cache()
	_check(actual.move_body(player,Vector2(player.x,player.y)).blocked and reference.move_body(player,Vector2(player.x,player.y)).blocked,"changed collider is checked after the previous setup has expired")
	_compare_queries(actual,reference,"changed collider")
	world.queue_free(); await process_frame; await physics_frame
	_check(actual.clear_placement(player) == reference.clear_placement(player),"freed world retains bounded placement refusal")


func _prepare_pair(actual: RefCounted,reference: RefCounted) -> void:
	for item: RefCounted in [actual,reference]:
		item.reset_navigation(); item.begin_navigation_frame(99,0.0)
		item.query_count = 0; item.placement_overlap_queries = 0; item.placement_cache_hits = 0
		item.body_contact_tests = 0; item.body_contacts = 0; item.body_repairs = 0; item.body_repairs_deferred = 0
		item.shape_lookups = 0; item.peer_builds = 0


func _compare_queries(actual: RefCounted,reference: RefCounted,label: String) -> void:
	for key: String in ["query_count","placement_overlap_queries","placement_cache_hits","body_contact_tests","body_contacts","body_repairs","body_repairs_deferred"]:
		_check(actual.get(key) == reference.get(key),label+": same "+key)
	_check(actual._placement_clear == reference._placement_clear,label+": exact certificate contents")


func _prefilter_equivalence() -> void:
	var world := TestWorld.new(); root.add_child(world)
	_box(world,Vector3(0,-0.1,0),Vector3(100,0.2,100))
	var wall: StaticBody3D = _box(world,Vector3(0,1.5,0),Vector3(0.2,3,20))
	var host := State.new(); host.npcs.clear()
	var actual := PrefilterObserved.new(world,host)
	var reference := UnfilteredPlacementReference.new(world,host)
	await physics_frame; await physics_frame
	var cases: Array[Dictionary] = [
		{"name":"far x","at":Vector2(900,840),"player":Vector2(500,840),"skip":true},
		{"name":"far y","at":Vector2(900,840),"player":Vector2(900,500),"skip":true},
		{"name":"threshold just outside","at":Vector2(900,840),"player":Vector2(926.999,843),"skip":true},
		{"name":"threshold just inside","at":Vector2(900,840),"player":Vector2(926.997,843),"skip":false},
		{"name":"initial peer overlap","at":Vector2(900,840),"player":Vector2(900,840),"skip":false},
		{"name":"peer repair beside wall","at":Vector2(1018,840),"player":Vector2(1018,840),"skip":false},
		{"name":"static wall recovery","at":Vector2(1038,840),"player":Vector2(500,500)},
		{"name":"outside world refusal","at":Vector2(-1000,-1000),"player":Vector2(500,500)},
		{"name":"hidden near actor","at":Vector2(900,840),"player":Vector2(900,840),"id":"pete","night":true,"skip":false},
		{"name":"dead near actor","at":Vector2(900,840),"player":Vector2(900,840),"dead":true,"skip":false},
		{"name":"departed near actor","at":Vector2(900,840),"player":Vector2(900,840),"departed":true,"skip":false},
		{"name":"tiny quarter overlap outside","at":Vector2(900,840),"player":Vector2(900.4,840),"tiny":true,"skip":true},
		{"name":"tiny quarter overlap inside","at":Vector2(900,840),"player":Vector2(900.2,840),"tiny":true,"skip":false},
		{"name":"player branch","at":Vector2(900,840),"player":Vector2(500,500),"id":"player","skip":false},
	]
	var completed: int = 0
	for row: Dictionary in cases:
		host.npcs.clear(); host.s.dayTime = 0.8 if row.get("night",false) else 0.4
		host.p.x = row.player.x; host.p.y = row.player.y
		host.p.w = 0.5 if row.get("tiny",false) else 24.0
		host.p.h = 0.75 if row.get("tiny",false) else 28.0
		var body: Dictionary = {"id":row.get("id","prefilter_actor"),"x":row.at.x,"y":row.at.y,
			"w":0.5 if row.get("tiny",false) else 28.0,"h":0.75 if row.get("tiny",false) else 34.0,
			"dead":row.get("dead",false),"departed":row.get("departed",false)}
		if body.id != "player": host.npcs.append(body)
		var frozen_player: Dictionary = host.p.duplicate(true)
		var frozen_body: Dictionary = body.duplicate(true)
		_prefilter_prepare(actual,reference)
		var got: Variant = actual.clear_placement(body)
		var expected: Variant = reference.clear_placement(body)
		_check(got == expected,row.name+": same exact returned placement/refusal")
		_prefilter_compare(actual,reference,row.name)
		_check(host.p == frozen_player and body == frozen_body,row.name+": no authoritative geometry mutation")
		if row.has("skip"):
			_check(actual._player_footprint_separated(body,row.at) == row.skip,row.name+": expected sufficient-test branch")
			if row.skip: _check(actual.peer_builds == 0 and reference.peer_builds == 1,row.name+": avoids only unnecessary peer construction")
			else: _check(actual.peer_builds == reference.peer_builds,row.name+": keeps original repair path")
		completed += 1
	_check(completed == 14,"all paired prefilter cases completed")

	# An unchanged static certificate must not retain player separation. An earlier
	# actor can move the same player dictionary before the next actor clearance.
	host.npcs.clear(); host.s.dayTime = 0.4
	host.p.w = 24.0; host.p.h = 28.0; host.p.x = 500.0; host.p.y = 500.0
	var live_body := {"id":"live_prefilter","x":900.0,"y":840.0,"w":28.0,"h":34.0}
	host.npcs.append(live_body)
	_prefilter_prepare(actual,reference)
	_check(actual.clear_placement(live_body) == reference.clear_placement(live_body),"first live player placement matches")
	host.p.x = 900.0; host.p.y = 840.0
	var repaired: Variant = actual.clear_placement(live_body)
	_check(repaired == reference.clear_placement(live_body) and repaired != Vector2(900,840),"same-dictionary current player forces real repair despite static certificate")
	_prefilter_compare(actual,reference,"current player after earlier actor")
	_check(actual.placement_cache_hits > 0,"current-player witness actually used a static certificate")

	for epoch_kind: String in ["p","s","fresh","restore"]:
		_prefilter_prepare(actual,reference)
		actual.clear_placement(live_body); reference.clear_placement(live_body)
		if epoch_kind == "p": host.p = host.p.duplicate(true)
		elif epoch_kind == "s": host.s = host.s.duplicate(true)
		elif epoch_kind == "fresh": _check(host.fresh(),"actual fresh accepted for prefilter epoch")
		else: _check(host.restore(host.snapshot()).get("ok",false),"actual restore accepted for prefilter epoch")
		host.npcs.clear(); host.npcs.append(live_body)
		host.s.dayTime = 0.4; host.p.x = 900.0; host.p.y = 840.0; host.p.w = 24.0; host.p.h = 28.0
		var query_before: int = actual.query_count
		_check(actual.clear_placement(live_body) == reference.clear_placement(live_body),epoch_kind+": current epoch repair matches")
		_check(actual.query_count > query_before,epoch_kind+": changed epoch requires an actual origin proof")
		_prefilter_compare(actual,reference,epoch_kind+" epoch")

	# Input rejection is tested directly; malformed bodies never reach the engine.
	var original_player: Dictionary = host.p.duplicate(true)
	for invalid: Variant in [NAN,INF,-INF,"bad",null]:
		host.p.x = invalid
		_check(not actual._player_footprint_separated(live_body,Vector2(900,840)),"invalid current player falls through: "+str(invalid))
	host.p = original_player
	host.p.x = 1.0e39
	_check(not actual._player_footprint_separated(live_body,Vector2(900,840)),"finite scalar overflowing Vector2 falls through")
	host.p.x = 500.0
	_check(not actual._player_footprint_separated(live_body,Vector2(NAN,840)),"nonfinite point falls through")
	var invalid_body: Dictionary = live_body.duplicate(true); invalid_body.w = -1.0
	_check(not actual._player_footprint_separated(invalid_body,Vector2(900,840)),"invalid body falls through")
	invalid_body.w = 1.0e39
	_check(not actual._player_footprint_separated(invalid_body,Vector2(900,840)),"finite extents overflowing Vector2 fall through")

	# A static world mutation still invalidates the exact same certificates.
	_prefilter_prepare(actual,reference)
	actual.clear_placement(live_body); reference.clear_placement(live_body)
	wall.position.x = -5.5
	await physics_frame; await physics_frame
	actual.invalidate_placement_cache(); reference.invalidate_placement_cache()
	_check(actual.clear_placement(live_body) == reference.clear_placement(live_body),"changed wall uses live physical recovery")
	_prefilter_compare(actual,reference,"changed physical wall")
	world.queue_free(); await process_frame; await physics_frame
	prefilter_completed = true


func _prefilter_prepare(actual: RefCounted,reference: RefCounted) -> void:
	_prepare_pair(actual,reference)
	actual.placement_trace.clear(); reference.placement_trace.clear()


func _prefilter_compare(actual: RefCounted,reference: RefCounted,label: String) -> void:
	for key: String in ["query_count","placement_overlap_queries","placement_cache_hits","body_contacts","body_repairs","body_repairs_deferred"]:
		_check(actual.get(key) == reference.get(key),label+": same "+key)
	_check(actual.placement_trace == reference.placement_trace,label+": same ordered static-query attempts/results/cache use")
	_check(actual._placement_clear == reference._placement_clear,label+": same exact placement certificates")
	_check(actual.body_contact_tests <= reference.body_contact_tests,label+": removes only unnecessary contact tests")


class ReentrantResourceTrace:
	extends "res://tests/fixtures/query_resource_candidate.gd"
	var trigger_nested: bool = false
	var nested_seen: bool = false
	var nested_distinct: bool = false
	var nested_clear: bool = false
	func _height(id: String,hints: Dictionary = {}) -> float:
		if trigger_nested:
			trigger_nested = false
			var outer: BodyQuery = _query_scratch
			var nested: BodyQuery = _borrow_body_query({"id":"player","x":900.0,"y":840.0,"w":24.0,"h":28.0},_space(),1.8)
			nested_seen = true
			nested_distinct = nested != outer and _query_scratch_busy
			nested_clear = _clear_prepared(nested.body,Vector2(900,840),false,nested)
			_release_body_query(nested)
			nested_distinct = nested_distinct and _query_scratch_busy and _query_scratch == outer
		return super._height(id,hints)

var resource_completed: bool = false

func _resource_pair(actual: RefCounted,reference: RefCounted,body: Dictionary,target: Vector2,stop: bool,label: String) -> void:
	actual.query_trace.clear(); reference.query_trace.clear()
	var before: Dictionary = body.duplicate(true)
	var a: Dictionary = actual.move_body(body,target,null,stop)
	var b: Dictionary = reference.move_body(body,target,null,stop)
	_check(a == b,label+": exact motion/contact/block result")
	_check(actual.query_trace == reference.query_trace,label+": ordered actual overlap/cast/rest arguments and returned results")
	_check(actual.query_count == reference.query_count and actual.placement_overlap_queries == reference.placement_overlap_queries,label+": exact physical query counters")
	_check(actual.placement_cache_hits == reference.placement_cache_hits and actual._placement_clear == reference._placement_clear,label+": exact positive certificate publication/hits")
	_check(body == before,label+": detached body unchanged")
	_check(not actual._query_scratch_busy,label+": no leaked scratch lease")
	if actual._query_scratch != null:
		_check(actual._query_scratch.body.is_empty() and actual._query_scratch.space == null and actual._query_scratch.bounds.is_empty(),label+": released model/space references")

func _resource_place(actual: RefCounted,reference: RefCounted,body: Dictionary,label: String) -> void:
	actual.query_trace.clear(); reference.query_trace.clear()
	var a: Variant = actual.clear_placement(body)
	var b: Variant = reference.clear_placement(body)
	_check(a == b,label+": exact placement/recovery")
	_check(actual.query_trace == reference.query_trace,label+": ordered real placement queries/results")
	_check(actual.query_count == reference.query_count and actual.placement_overlap_queries == reference.placement_overlap_queries,label+": same placement query counts")
	_check(actual._placement_clear == reference._placement_clear and actual.placement_cache_hits == reference.placement_cache_hits,label+": placement certificate identity")
	_check(not actual._query_scratch_busy,label+": placement releases lease")

func _poison_resource_query(query: PhysicsShapeQueryParameters3D,wall: StaticBody3D) -> void:
	var poison := SphereShape3D.new(); poison.radius = 9.0
	query.shape = poison
	query.collision_mask = 0; query.margin = 4.0
	query.transform = Transform3D(Basis.from_euler(Vector3(1,2,3)),Vector3(777,888,999))
	query.motion = Vector3(50,60,70)
	var excluded: Array[RID] = [wall.get_rid()]
	query.exclude = excluded
	query.collide_with_bodies = false; query.collide_with_areas = true

func _query_resource_equivalence() -> void:
	var world := TestWorld.new(); root.add_child(world)
	_box(world,Vector3(0,-0.1,0),Vector3(100,0.2,100))
	var wall: StaticBody3D = _box(world,Vector3(0,1.5,0),Vector3(0.2,3,20))
	var host := State.new(); host.npcs.clear(); host.p.x = 500.0; host.p.y = 500.0
	var actual: RefCounted = preload("res://tests/fixtures/query_resource_candidate.gd").new(world,host)
	var reference: RefCounted = preload("res://tests/fixtures/query_resource_reference.gd").new(world,host)
	await physics_frame; await physics_frame
	var cases: Array[Dictionary] = [
		{"label":"free player","body":{"id":"player","x":900.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(980,840),"stop":false},
		{"label":"wall slide","body":{"id":"player","x":1000.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1100,900),"stop":false},
		{"label":"wall charge","body":{"id":"player","x":1000.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1100,900),"stop":true},
		{"label":"NPC glancing corner","body":{"id":"query_actor","x":990.0,"y":840.0,"w":28.0,"h":34.0},"to":Vector2(1080,910),"stop":false},
		{"label":"large box","body":{"id":"wide","x":950.0,"y":840.0,"w":48.0,"h":60.0},"to":Vector2(1080,890),"stop":false},
		{"label":"zero clear","body":{"id":"player","x":900.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(900,840),"stop":false},
		{"label":"invalid origin","body":{"id":"player","x":1040.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(1100,840),"stop":false},
		{"label":"tiny step","body":{"id":"player","x":900.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(900.00006,840),"stop":false},
		{"label":"bad target","body":{"id":"player","x":900.0,"y":840.0,"w":24.0,"h":28.0},"to":Vector2(NAN,840),"stop":false}]
	for item: RefCounted in [actual,reference]: item.begin_navigation_frame(700,0.0)
	for row: Dictionary in cases: _resource_pair(actual,reference,row.body,row.to,row.stop,row.label)
	var body: Dictionary = cases[0].body
	var scratch: RefCounted = actual._query_scratch
	var overlap: PhysicsShapeQueryParameters3D = scratch.overlap
	var sweep: PhysicsShapeQueryParameters3D = scratch.sweep
	_check(overlap != null and sweep != null and overlap != sweep,"two independent lazy query resources exist")
	_poison_resource_query(overlap,wall); _poison_resource_query(sweep,wall)
	_resource_pair(actual,reference,cases[1].body,cases[1].to,false,"poisoned pooled resources")
	_check(actual._query_scratch == scratch and scratch.overlap == overlap and scratch.sweep == sweep,"warm calls reuse only the same private resources")
	var public_a: PhysicsShapeQueryParameters3D = actual._query(body,Vector2(body.x,body.y))
	var public_b: PhysicsShapeQueryParameters3D = actual._query(body,Vector2(body.x,body.y))
	_check(public_a != public_b and public_a != overlap and public_a != sweep,"public query always returns a distinct unpooled object")
	_poison_resource_query(public_a,wall)
	_resource_pair(actual,reference,cases[1].body,cases[1].to,false,"retained poisoned public query")
	_check(public_b.collision_mask == 1 and public_b.margin == reference._query(body,Vector2(body.x,body.y)).margin and public_b.exclude.is_empty(),"public sibling remains unchanged")
	for shape_width: float in [16.0,32.0,48.0]:
		var varied := {"id":"query_actor","x":900.0,"y":840.0,"w":shape_width,"h":shape_width+4.0}
		_resource_place(actual,reference,varied,"shape dimensions "+str(shape_width))
	_resource_place(actual,reference,cases[6].body,"blocked bounded recovery")
	_resource_place(actual,reference,{"id":"far","x":-1000.0,"y":-1000.0,"w":24.0,"h":28.0},"all recovery candidates invalid")
	var marker := Node3D.new(); world.add_child(marker)
	for height: float in [0.8,2.5,1.2]:
		actual.register_body("query_actor",marker,height); reference.register_body("query_actor",marker,height)
		_resource_pair(actual,reference,cases[3].body,cases[3].to,false,"current profile height "+str(height))
	actual.unregister_body("query_actor"); reference.unregister_body("query_actor")
	_resource_pair(actual,reference,cases[3].body,cases[3].to,false,"unregistered current height")
	for epoch_key: String in ["p","s"]:
		host.set(epoch_key,host.get(epoch_key).duplicate(true))
		_resource_pair(actual,reference,body,Vector2(980,840),false,epoch_key+" epoch replacement")
	host.p.x = 900.0; host.p.y = 840.0
	host.npcs.append({"id":"query_actor","x":920.0,"y":840.0,"w":28.0,"h":34.0,"hostile":false})
	_resource_pair(actual,reference,body,Vector2(1000,840),false,"live neutral peer tangent")
	_resource_place(actual,reference,{"id":"query_actor","x":900.0,"y":840.0,"w":28.0,"h":34.0},"current player overlap repair")
	var reentrant := ReentrantResourceTrace.new(world,host)
	reentrant.trigger_nested = true
	var lease: Variant = reentrant._borrow_body_query(body,reentrant._space())
	_check(reentrant.nested_seen and reentrant.nested_distinct and reentrant.nested_clear,"reentrant helper uses distinct fallback and retains outer lease")
	var outer_query: PhysicsShapeQueryParameters3D = reentrant._prepared_query(lease,Vector2(900,840),true)
	outer_query.motion = Vector3(1,0,2)
	var outer_before: Dictionary = reentrant._trace_arguments(outer_query)
	var fallback: Variant = reentrant._borrow_body_query(cases[3].body,reentrant._space())
	reentrant._prepared_query(fallback,Vector2(990,840),true)
	reentrant._release_body_query(fallback)
	_check(reentrant._trace_arguments(outer_query) == outer_before and reentrant._query_scratch_busy,"nested sweep cannot overwrite outer sweep or unlock it")
	reentrant._release_body_query(lease)
	_check(not reentrant._query_scratch_busy,"outer release ends lease after nested fallback")
	# A separately owned World3D ensures cached resources cannot retain its space.
	var viewport := SubViewport.new(); viewport.own_world_3d = true; root.add_child(viewport)
	var other := TestWorld.new(); viewport.add_child(other)
	_box(other,Content.to_world(Vector2(912,854),1.0),Vector3(2,2,2))
	await physics_frame; await physics_frame
	actual._world_ref = weakref(other); reference._world_ref = weakref(other)
	actual.invalidate_placement_cache(); reference.invalidate_placement_cache()
	_resource_pair(actual,reference,body,Vector2(980,840),false,"new actual space obstruction")
	actual._world_ref = weakref(world); reference._world_ref = weakref(world)
	actual.invalidate_placement_cache(); reference.invalidate_placement_cache()
	_resource_pair(actual,reference,body,Vector2(980,840),false,"return to original actual space")
	wall.collision_layer = 0
	actual.invalidate_placement_cache(); reference.invalidate_placement_cache()
	_resource_pair(actual,reference,cases[1].body,cases[1].to,false,"same-frame collider revision")
	viewport.queue_free(); world.queue_free(); await process_frame; await physics_frame
	_resource_pair(actual,reference,body,Vector2(980,840),false,"freed world fails closed")
	_resource_place(actual,reference,body,"freed-world placement")
	resource_completed = true
