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
